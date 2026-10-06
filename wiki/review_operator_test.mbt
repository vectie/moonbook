///|
fn operator_field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn operator_text(value : Json, key : String) -> String {
  match operator_field(value, key) {
    String(text) => text
    _ => ""
  }
}

///|
async fn operator_inspect(root : String, id : String) -> Json {
  let (status, response) = @wiki.review_operator_request(
    root,
    "POST",
    "/api/wiki/reviews/inspect",
    { "review_id": id },
  )
  assert_eq(status, 200, msg=response.stringify())
  operator_field(response, "detail")
}

///|
async fn operator_decide(
  root : String,
  detail : Json,
  decision : String,
) -> (Int, Json) {
  @wiki.review_operator_request(root, "POST", "/api/wiki/reviews/resolve", {
    "review_id": operator_text(detail, "review_id"),
    "expected_digest": operator_text(detail, "review_digest"),
    "decision": decision,
    "scope": "local-book-review",
  })
}

///|
async test "operator lists all legacy reviews and reads exact detail without writing" {
  let root = @fs.tmpdir(prefix="book-operator-legacy-")
  ignore(@wiki.init_workspace(root))
  let mut pending = "# Pending Review\n\n## Items\n\n"
  for i in 0..<6 {
    pending += "### Query review | Legacy \{i}\n\n- Review ID: `legacy-\{i}`\n- Status: `pending`\n- Candidate insight: human-selected legacy detail \{i}\n\n"
  }
  @fs.write_file(root + "/wiki/reviews/pending.md", pending)
  let (status, response) = @wiki.review_operator_request(
    root,
    "GET",
    "/api/wiki/reviews",
    Json::null(),
  )
  assert_eq(status, 200)
  guard operator_field(response, "items") is Array(items) else {
    fail("queue array required")
  }
  assert_eq(items.length(), 6)
  let detail = operator_inspect(root, "legacy-5")
  assert_true(
    operator_text(detail, "review_text").contains(
      "human-selected legacy detail 5",
    ),
  )
  assert_eq(operator_field(detail, "native_binding"), Json::null())
  assert_eq(operator_field(detail, "can_resolve"), true.to_json())
  assert_eq(@fs.read_file(root + "/wiki/reviews/pending.md").text(), pending)
  let (resolved, response) = operator_decide(root, detail, "reject")
  assert_eq(resolved, 200, msg=response.stringify())
  let observed = operator_inspect(root, "legacy-5")
  assert_eq(operator_text(observed, "status"), "rejected")
  assert_eq(operator_field(observed, "can_resolve"), false.to_json())
}

///|
async test "explicit native approve and reject preserve exact result and unevaluated acceptance" {
  for decision in ["approve", "reject"] {
    let root = @fs.realpath(@fs.tmpdir(prefix="book-operator-native-"))
    ignore(@wiki.init_workspace(root))
    let summary = "Exact full human-visible result: " +
      "long engineering detail ".repeat(25) +
      "\n### Nested result heading\nEND-OF-RESULT"
    let result : @wiki.BookResult = @json.from_json({
      "result_id": "operator-result",
      "summary": summary,
      "artifacts": ["wiki/CODE_PATCH.md", "wiki/TEST_RESULTS.md"],
      "memory_candidates": [],
      "requires_review": true,
      "notify_town": true,
    })
    let work = "operator-native-" + decision
    let request = @wiki.executable_sha256("request-" + decision)[7:].to_owned()
    let payload_digest = @wiki.executable_sha256(result.to_json().stringify())[7:].to_owned()
    ignore(
      @wiki.persist_result_payload(root, {
        "book_result": result.to_json(),
        "native_import": {
          "contract": "moontown.wenyu.import.v1",
          "work_id": work,
          "request_digest": request,
          "payload_digest": payload_digest,
        },
      }),
    )
    let id = "result-review-native-wenyu-" +
      @wiki.executable_sha256(work)[7:].to_owned()
    let detail = operator_inspect(root, id)
    assert_true(operator_text(detail, "result_text").contains("END-OF-RESULT"))
    assert_true(
      operator_text(detail, "result_text").contains("wiki/CODE_PATCH.md"),
    )
    assert_eq(
      operator_text(operator_field(detail, "native_binding"), "work_id"),
      work,
    )
    assert_eq(
      operator_text(operator_field(detail, "native_binding"), "status"),
      "pending",
    )
    let event = @fs.read_file(root + "/events/latest.json").text()
    let (status, response) = operator_decide(root, detail, decision)
    assert_eq(status, 200, msg=response.stringify())
    let expected = if decision == "approve" { "approved" } else { "rejected" }
    let readback = operator_inspect(root, id)
    assert_eq(operator_text(readback, "status"), expected)
    assert_eq(
      operator_text(operator_field(readback, "native_binding"), "status"),
      expected,
    )
    assert_eq(
      operator_text(readback, "original_task_acceptance"),
      "unevaluated",
    )
    assert_eq(operator_field(readback, "can_resolve"), false.to_json())
    assert_eq(@fs.read_file(root + "/events/latest.json").text(), event)
    let approved = @fs.read_file(root + "/wiki/reviews/approved.md").text()
    let evidence = @fs.read_file(root + "/wiki/synthesis/evidence.md").text()
    let (duplicate_status, duplicate) = operator_decide(root, detail, decision)
    assert_eq(duplicate_status, 409)
    assert_eq(
      operator_text(operator_field(duplicate, "detail"), "status"),
      expected,
    )
    assert_eq(
      @fs.read_file(root + "/wiki/reviews/approved.md").text(),
      approved,
    )
    assert_eq(
      @fs.read_file(root + "/wiki/synthesis/evidence.md").text(),
      evidence,
    )
  }
}

///|
async test "stale detail duplicate identity and malformed action never resolve another review" {
  let root = @fs.tmpdir(prefix="book-operator-stale-")
  ignore(@wiki.init_workspace(root))
  let pending = "# Pending Review\n\n## Items\n\n### Query review | Old detail\n\n- Review ID: `stale-id`\n- Status: `pending`\n- Candidate insight: old\n"
  @fs.write_file(root + "/wiki/reviews/pending.md", pending)
  let detail = operator_inspect(root, "stale-id")
  let changed = pending
    .replace(old="insight: old", new="insight: changed by human")
    .to_string()
  @fs.write_file(root + "/wiki/reviews/pending.md", changed)
  assert_eq(operator_decide(root, detail, "approve").0, 409)
  assert_eq(@fs.read_file(root + "/wiki/reviews/pending.md").text(), changed)
  let fresh = operator_inspect(root, "stale-id")
  assert_eq(operator_decide(root, fresh, "accept-goal").0, 400)
  assert_eq(
    @wiki.review_operator_request(root, "POST", "/api/wiki/reviews/resolve", {
      "review_id": "stale-id",
      "decision": "approve",
      "expected_digest": operator_text(fresh, "review_digest"),
    }).0,
    400,
  )
  @fs.write_file(root + "/wiki/reviews/pending.md", changed + "\n" + changed)
  assert_eq(
    @wiki.review_operator_request(
      root,
      "GET",
      "/api/wiki/reviews",
      Json::null(),
    ).0,
    409,
  )
  assert_eq(
    @wiki.review_operator_request(root, "POST", "/api/wiki/reviews/inspect", {
      "review_id": "stale-id",
    }).0,
    409,
  )
  assert_eq(
    @wiki.review_operator_request(root, "POST", "/api/wiki/reviews/inspect", {
      "review_id": "missing",
    }).0,
    404,
  )
}

///|
async test "two explicit browser decisions serialize and only one resolves the exact review" {
  let root = @fs.tmpdir(prefix="book-operator-repeat-")
  ignore(@wiki.init_workspace(root))
  @fs.write_file(
    root + "/wiki/reviews/pending.md",
    "# Pending Review\n\n## Items\n\n### Query review | Repeated click\n\n- Review ID: `repeat-id`\n- Status: `pending`\n- Candidate insight: one local decision\n",
  )
  let detail = operator_inspect(root, "repeat-id")
  let statuses : Array[Int] = []
  @async.with_task_group(group => {
    for _ in 0..<2 {
      group.spawn_bg(() => {
        statuses.push(operator_decide(root, detail, "reject").0)
      })
    }
  })
  statuses.sort()
  assert_eq(statuses, [200, 409])
  let approved = @fs.read_file(root + "/wiki/reviews/approved.md").text()
  assert_eq(approved.split("- Resolution:").to_array().length(), 2)
  assert_eq(
    operator_text(operator_inspect(root, "repeat-id"), "status"),
    "rejected",
  )
}

///|
async test "legacy shared observations stay complete and all ledger edits invalidate stale decisions" {
  let root = @fs.tmpdir(prefix="book-operator-legacy-result-")
  ignore(@wiki.init_workspace(root))
  // This is the exact record framing emitted by extension_api.mbt's
  // persisted_result_block: summary is verbatim, followed by metadata/artifacts.
  let before = "### adjacent-before\n\n- Summary: BEFORE-ONLY\n- Requires review: `false`\n- Notify town: `false`\n\n"
  let selected = "### legacy-result\n\n- Summary: lead\n# Top-level summary heading\n## Summary details\n### Important failure\n\n- Summary: nested explanation is still result content\n- Requires review: `true`\n- Notify town: `false`\n### Embedded example\n\n- Summary: quoted writer framing is still summary content\nUNREAD-TAIL\n- Requires review: `true`\n- Notify town: `false`\n- Artifacts:\n  - `raw/first-output.md`\n  - `wiki/LAST-ARTIFACT.md`\n- Memory candidates:\n  - Important observation (`note` durable=`true`)\n\n"
  let after = "### adjacent-after\n\n- Summary: AFTER-ONLY\n- Requires review: `false`\n- Notify town: `false`\n\n"
  let observations = "# Observations\n\n## Results\n\n" +
    before +
    selected +
    after
  let pending = "# Pending Review\n\n## Items\n\n### Result review | legacy-result\n\n- Review ID: `legacy-result-review`\n- Status: `pending`\n- Result page: [legacy-result](../synthesis/observations.md)\n- Candidate insight: lead\n"
  @fs.write_file(root + "/wiki/synthesis/observations.md", observations)
  @fs.write_file(root + "/wiki/reviews/pending.md", pending)
  let detail = operator_inspect(root, "legacy-result-review")
  let displayed = operator_text(detail, "result_text")
  for
    expected in [
      "# Top-level summary heading", "## Summary details", "### Important failure",
      "nested explanation is still result content", "### Embedded example", "quoted writer framing is still summary content",
      "UNREAD-TAIL", "raw/first-output.md", "wiki/LAST-ARTIFACT.md", "Important observation",
    ] {
    assert_true(displayed.contains(expected), msg=expected)
  }
  assert_true(displayed.contains("Complete legacy observations page"))
  assert_true(displayed.contains("This page may include other results"))
  assert_true(displayed.has_suffix(observations))
  assert_true(displayed.contains("BEFORE-ONLY"))
  assert_true(displayed.contains("AFTER-ONLY"))
  let changed_tail = observations
    .replace(old="UNREAD-TAIL", new="CHANGED-TAIL")
    .to_string()
  @fs.write_file(root + "/wiki/synthesis/observations.md", changed_tail)
  assert_eq(operator_decide(root, detail, "approve").0, 409)
  assert_eq(@fs.read_file(root + "/wiki/reviews/pending.md").text(), pending)
  let refreshed = operator_inspect(root, "legacy-result-review")
  assert_true(operator_text(refreshed, "result_text").contains("CHANGED-TAIL"))
  let changed_artifact = changed_tail
    .replace(old="LAST-ARTIFACT.md", new="NEW-ARTIFACT.md")
    .to_string()
  @fs.write_file(root + "/wiki/synthesis/observations.md", changed_artifact)
  assert_eq(operator_decide(root, refreshed, "reject").0, 409)
  let final_detail = operator_inspect(root, "legacy-result-review")
  assert_true(
    operator_text(final_detail, "result_text").contains("NEW-ARTIFACT.md"),
  )
  let changed_neighbor = changed_artifact
    .replace(old="AFTER-ONLY", new="CHANGED-NEIGHBOR")
    .to_string()
  @fs.write_file(root + "/wiki/synthesis/observations.md", changed_neighbor)
  assert_eq(operator_decide(root, final_detail, "reject").0, 409)
  let reread = operator_inspect(root, "legacy-result-review")
  assert_true(operator_text(reread, "result_text").has_suffix(changed_neighbor))
  assert_eq(operator_decide(root, reread, "reject").0, 200)
}
