///|
fn fixture_batch(
  id : String,
  version : String,
  kinds : Array[String],
  payload_content? : String,
) -> @policy_artifact_store.ArtifactBatch {
  let payloads : Array[@policy_artifact_store.ArtifactPayload] = kinds.map(kind => {
    record_id: id + kind,
    content: payload_content.unwrap_or("中文 & <fixture> " + kind),
  })
  let requests : Array[Json] = payloads.mapi((index, payload) => {
    "contract_id": "moonpoly.moonbook-append-request.v1",
    "operation_id": payload.record_id,
    "idempotency_key": payload.record_id,
    "book_id": "book",
    "case_id": "case",
    "expected_book_version": version,
    "requested_at": "fixture-logical-time",
    "gate_receipt_id": "local-fixture:workspace-write",
    "artifact": {
      "envelope": {
        "id": payload.record_id,
        "case_id": "case",
        "version": "1",
        "recorded_at": "fixture-logical-time",
        "subject_actor_id": "local-fixture",
        "created_by_actor_id": "local-fixture",
        "origin": "LocalFixtureProduced",
        "authority": "Advisory",
        "standing": "Proposed",
      },
      "kind": kinds[index],
      "content_uri": "moonbook://book/artifacts/" + payload.record_id,
      "content_digest": @policy_artifact_store.content_digest(payload.content),
    },
  })
  {
    contract_id: "moonbook.policy-artifact-batch.v1",
    execution_mode: "deterministic-local-fixture.v1",
    batch_id: id,
    book_id: "book",
    case_id: "case",
    expected_book_version: version,
    requests,
    payloads,
    context: {
      "contract_id": "moonpoly.policy-quality-transition-request.v2",
      "event_type": "writer-completed",
    },
  }
}

///|
async fn root(name : String) -> String {
  let base = @env.get_env_var("MOONSUITE_FIXTURE_ROOT").unwrap_or(
    "/tmp/moonsuite-policy-fixtures",
  )
  let path = base + "/" + name + "-" + @async.now().to_string()
  @fs.mkdir(path, recursive=true)
  path
}

///|
async test "Book atomically persists exact payloads and refuses stale partial replay and changed digest" {
  let path = root("book-atomic")
  let batch = fixture_batch("writer1", "0", ["DraftVersion", "ClaimTrace"])
  let partial = {
    ..batch,
    requests: [batch.requests[0]],
    payloads: [batch.payloads[0]],
  }
  assert_true(
    (try? @policy_artifact_store.append_batch(path, partial)) is Err(_),
  )
  assert_eq(@policy_artifact_store.read_journal(path).version, 0)
  let wrong = {
    ..batch,
    payloads: [{ ..batch.payloads[0], content: "changed", }, batch.payloads[1]],
  }
  assert_true((try? @policy_artifact_store.append_batch(path, wrong)) is Err(_))
  assert_eq(@policy_artifact_store.read_journal(path).version, 0)
  let saved = @policy_artifact_store.append_batch(path, batch)
  assert_eq(saved.receipts.length(), 2)
  let acknowledged = @policy_artifact_store.read_journal(path)
  assert_eq(acknowledged.version, 1)
  assert_eq(acknowledged.batches[0].batch.payloads, batch.payloads)
  assert_true((try? @policy_artifact_store.append_batch(path, batch)) is Err(_))
  assert_true(
    (try? @policy_artifact_store.append_batch(
      path,
      fixture_batch("writer2", "0", ["DraftVersion", "ClaimTrace"]),
    ))
    is Err(_),
  )
  assert_eq(@policy_artifact_store.read_journal(path), acknowledged)
}

///|
async test "Book interruption leaves old journal and rejects forged capability or authority" {
  let path = root("book-interruption")
  let batch = fixture_batch("writer1", "0", ["DraftVersion", "ClaimTrace"])
  let wrong_mode = { ..batch, execution_mode: "live-provider", }
  assert_true(
    (try? @policy_artifact_store.append_batch(path, wrong_mode)) is Err(_),
  )
  @fs.write_file(
    path +
    "/pending-" +
    @policy_artifact_store.content_digest(batch.batch_id).replace_all(
      old=":",
      new="-",
    ) +
    ".json",
    "partial",
    create_mode=CreateNew,
  )
  assert_true((try? @policy_artifact_store.append_batch(path, batch)) is Err(_))
  assert_eq(@policy_artifact_store.read_journal(path).version, 0)
  assert_true(
    @fs.exists(
      path +
      "/pending-" +
      @policy_artifact_store.content_digest(batch.batch_id).replace_all(
        old=":",
        new="-",
      ) +
      ".json",
    ),
  )
}

///|
async test "Book corrupt receipt and symlink journal fail closed" {
  let path = root("book-corrupt")
  let batch = fixture_batch("writer1", "0", ["DraftVersion", "ClaimTrace"])
  ignore(@policy_artifact_store.append_batch(path, batch))
  let snapshot = @policy_artifact_store.read_journal(path)
  let bad = { ..snapshot, version: 2, }
  @fs.write_file(path + "/snapshot.json", bad.to_json().stringify())
  assert_true((try? @policy_artifact_store.read_journal(path)) is Err(_))
  let linked = root("book-symlink")
  @fs.symlink(target=path + "/snapshot.json", linked + "/snapshot.json")
  assert_true((try? @policy_artifact_store.read_journal(linked)) is Err(_))
}

///|
async test "Book payload limit counts UTF8 bytes below exact and above one MiB atomically" {
  let path = root("book-utf8-boundary")
  let cjk = "中".repeat(349525)
  let below = cjk
  let exact = cjk + "a"
  let above = cjk + "ab"
  assert_eq(@utf8.encode(below).length(), 1048575)
  assert_eq(@utf8.encode(exact).length(), 1048576)
  assert_eq(@utf8.encode(above).length(), 1048577)
  assert_true(above.length() < 1048576)
  let below_batch = fixture_batch(
    "below",
    "0",
    ["DraftVersion", "ClaimTrace"],
    payload_content=below,
  )
  ignore(@policy_artifact_store.append_batch(path, below_batch))
  assert_eq(@policy_artifact_store.read_journal(path).version, 1)
  let exact_batch = fixture_batch(
    "exact",
    "1",
    ["DraftVersion", "ClaimTrace"],
    payload_content=exact,
  )
  ignore(@policy_artifact_store.append_batch(path, exact_batch))
  assert_eq(@policy_artifact_store.read_journal(path).version, 2)
  let acknowledged = @fs.read_file(path + "/snapshot.json").binary()
  let above_batch = fixture_batch(
    "above",
    "2",
    ["DraftVersion", "ClaimTrace"],
    payload_content=above,
  )
  assert_true(
    (try? @policy_artifact_store.append_batch(path, above_batch)) is Err(_),
  )
  assert_eq(@fs.read_file(path + "/snapshot.json").binary(), acknowledged)
  let reproduced = "中".repeat(600000)
  assert_eq(@utf8.encode(reproduced).length(), 1800000)
  let regression = fixture_batch(
    "review-regression",
    "2",
    ["DraftVersion", "ClaimTrace"],
    payload_content=reproduced,
  )
  assert_true(
    (try? @policy_artifact_store.append_batch(path, regression)) is Err(_),
  )
  assert_eq(@fs.read_file(path + "/snapshot.json").binary(), acknowledged)
  assert_eq(@policy_artifact_store.read_journal(path).version, 2)
  let report : Json = {
    "finding": "R51-UTF8-01",
    "below_bytes": 1048575,
    "exact_bytes": 1048576,
    "over_bytes": 1048577,
    "review_regression_bytes": 1800000,
    "below_accepted": true,
    "exact_accepted": true,
    "over_refused": true,
    "regression_refused": true,
    "acknowledged_journal_bytes_unchanged": true,
    "final_version": 2,
  }
  @fs.write_file(
    path + "/BOUNDARY_RECEIPT.json",
    report.stringify(indent=2),
    create_mode=CreateNew,
  )
}
