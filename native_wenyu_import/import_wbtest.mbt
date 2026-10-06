///|
async fn persist_result_payload(
  root : String,
  payload : Json,
) -> PersistResultOutcome {
  @json.from_json(persist(root, payload))
}

///|
fn native_wenyu_test_result(
  summary? : String = "Implemented the frozen Wenyu task.",
) -> BookResult {
  {
    result_id: "wenyu-goal-1-code-patch",
    summary,
    artifacts: ["wiki/CODE_PATCH.md", "wiki/TEST_RESULTS.md"],
    memory_candidates: [],
    requires_review: true,
    notify_town: true,
  }
}

///|
fn native_wenyu_test_payload(
  work_id? : String = "native-work-1",
  result? : BookResult = native_wenyu_test_result(),
  request_digest? : String = native_wenyu_digest("frozen-request"),
) -> Json {
  let book_result = result.to_json()
  {
    "book_result": book_result,
    "native_import": {
      "contract": "moontown.wenyu.import.v1",
      "work_id": work_id,
      "request_digest": request_digest,
      "payload_digest": native_wenyu_digest(book_result.stringify()),
    },
  }
}

///|
fn native_wenyu_count_line(text : String, target : String) -> Int {
  let mut count = 0
  for line in text.split("\n") {
    if line == target {
      count += 1
    }
  }
  count
}

///|
async fn native_wenyu_test_intent(
  root : String,
  work_id : String,
) -> NativeWenyuIntent {
  let key = native_wenyu_digest(work_id)
  @json.from_json(
    @json.parse(
      @fsx.read_file(
        "\{root}/.moonbook/native-wenyu-imports/\{key}.intent.json",
      ),
    ),
  )
}

///|
async test "native Wenyu import resumes after every write and after Book commit before Town acknowledgement" {
  // 0: durable intent; 1..10: individual projection/event writes;
  // 11: Book receipt committed but the caller has not received the outcome.
  for checkpoint in 0..<=11 {
    let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-native-wenyu-crash-"))
    let payload = native_wenyu_test_payload()
    try
      persist_native_wenyu_import(root, payload, fail_after=checkpoint)
    catch {
      error =>
        assert_true(
          "\{error}".contains("injected native Wenyu import interruption"),
        )
    } noraise {
      _ => fail("expected interruption at checkpoint \{checkpoint}")
    }
    let intent = native_wenyu_test_intent(root, "native-work-1")
    assert_eq(intent.writes.length(), 10)
    let resumed = persist_result_payload(root, payload)
    assert_eq(resumed.to_json(), intent.outcome.to_json())
    let replayed = persist_result_payload(root, payload)
    assert_eq(replayed.to_json(), resumed.to_json())
    for write in intent.writes {
      assert_eq(native_wenyu_read(root, write.path), Some(write.after))
    }
    assert_true(resumed.review_queued)
    assert_true(resumed.notify_town)
    assert_true(!resumed.executable_event.accepted)
    assert_eq(resumed.executable_event.event_type, "review_required")
    let evidence = @fsx.read_file(root + "/wiki/synthesis/evidence.md")
    assert_eq(
      native_wenyu_count_line(evidence, "### \{resumed.evidence_id}"),
      1,
    )
    let key = native_wenyu_digest("native-work-1")
    let reviews = @fsx.read_file(root + "/wiki/reviews/pending.md")
    assert_eq(
      native_wenyu_count_line(
        reviews,
        "- Review ID: `result-review-native-wenyu-\{key}`",
      ),
      1,
    )
    let log = @fsx.read_file(root + "/wiki/log.md")
    assert_eq(
      native_wenyu_count_line(
        log,
        "## [native-wenyu-\{key}] persist | wenyu-goal-1-code-patch",
      ),
      1,
    )
    assert_eq(@fsx.list_directory(root + "/events").length(), 2)
  }
}

///|
async test "native Wenyu import rejects same work with changed payload or request without effects" {
  let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-native-wenyu-identity-"))
  let first = persist_result_payload(root, native_wenyu_test_payload())
  let before_log = @fsx.read_file(root + "/wiki/log.md")
  let before_review = @fsx.read_file(root + "/wiki/reviews/pending.md")
  for
    payload in [
      native_wenyu_test_payload(
        result=native_wenyu_test_result(summary="Changed result"),
      ),
      native_wenyu_test_payload(
        request_digest=native_wenyu_digest("changed-request"),
      ),
    ] {
    try persist_result_payload(root, payload) catch {
      error =>
        assert_true(
          "\{error}".contains("already binds different request or payload"),
        )
    } noraise {
      _ => fail("changed identity must fail")
    }
  }
  assert_eq(@fsx.read_file(root + "/wiki/log.md"), before_log)
  assert_eq(@fsx.read_file(root + "/wiki/reviews/pending.md"), before_review)
  assert_eq(
    persist_result_payload(root, native_wenyu_test_payload()).to_json(),
    first.to_json(),
  )
}

///|
async test "native Wenyu committed replay preserves reviewed pages and newer latest event" {
  let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-native-wenyu-newer-"))
  let first = persist_result_payload(root, native_wenyu_test_payload())
  let second = persist_result_payload(
    root,
    native_wenyu_test_payload(work_id="native-work-2"),
  )
  assert_true(first.evidence_id != second.evidence_id)
  assert_true(first.executable_event.id != second.executable_event.id)
  let latest = @fsx.read_file(root + "/events/latest.json")
  let review = @fsx.read_file(root + "/wiki/reviews/pending.md") +
    "\nHuman review note.\n"
  @fsx.write_to_file(root + "/wiki/reviews/pending.md", review)
  let replayed = persist_result_payload(root, native_wenyu_test_payload())
  assert_eq(replayed.to_json(), first.to_json())
  assert_eq(@fsx.read_file(root + "/events/latest.json"), latest)
  assert_eq(@fsx.read_file(root + "/wiki/reviews/pending.md"), review)
  assert_eq(@fsx.list_directory(root + "/events").length(), 3)
}

///|
async test "native Wenyu incomplete import blocks later work and preserves human destination changes" {
  let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-native-wenyu-conflict-"))
  try
    persist_native_wenyu_import(root, native_wenyu_test_payload(), fail_after=1)
  catch {
    _ => ()
  } noraise {
    _ => fail("expected interruption")
  }
  try
    persist_result_payload(
      root,
      native_wenyu_test_payload(work_id="native-work-2"),
    )
  catch {
    error => assert_true("\{error}".contains("resume the earlier import"))
  } noraise {
    _ => fail("later work must wait")
  }
  let observations_path = root + "/wiki/synthesis/observations.md"
  let before = @fsx.read_file(observations_path)
  @fsx.write_to_file(observations_path, before + "\nHuman edit.\n")
  try persist_result_payload(root, native_wenyu_test_payload()) catch {
    error => assert_true("\{error}".contains("destination conflict"))
  } noraise {
    _ => fail("must preserve human edit")
  }
  assert_eq(@fsx.read_file(observations_path), before + "\nHuman edit.\n")
  assert_true(!@fsx.exists(root + "/wiki/synthesis/evidence.md"))
  // Explicitly resolving the synthetic conflict back to the prepared image
  // permits exact continuation without duplicating the first applied effect.
  @fsx.write_to_file(observations_path, before)
  ignore(persist_result_payload(root, native_wenyu_test_payload()))
  ignore(
    persist_result_payload(
      root,
      native_wenyu_test_payload(work_id="native-work-2"),
    ),
  )
}

///|
async test "native Wenyu import rejects malformed opt in without downgrading to legacy" {
  let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-native-wenyu-invalid-"))
  let invalid_digest : Json = {
    "book_result": native_wenyu_test_result().to_json(),
    "native_import": {
      "contract": "moontown.wenyu.import.v1",
      "work_id": "native-work-1",
      "request_digest": native_wenyu_digest("request"),
      "payload_digest": native_wenyu_digest("different payload"),
    },
  }
  let unknown_field : Json = {
    "book_result": native_wenyu_test_result().to_json(),
    "native_import": {
      "contract": "moontown.wenyu.import.v1",
      "work_id": "native-work-1",
      "request_digest": native_wenyu_digest("request"),
      "payload_digest": native_wenyu_digest(
        native_wenyu_test_result().to_json().stringify(),
      ),
      "unexpected": true,
    },
  }
  for
    payload in [
      invalid_digest,
      unknown_field,
      {
        "book_result": native_wenyu_test_result().to_json(),
        "native_import": false,
      },
      native_wenyu_test_payload(request_digest="bad-digest"),
      native_wenyu_test_payload(result={
        ..native_wenyu_test_result(),
        requires_review: false,
      }),
      native_wenyu_test_payload(result={
        ..native_wenyu_test_result(),
        notify_town: false,
      }),
      native_wenyu_test_payload(result={
        ..native_wenyu_test_result(),
        memory_candidates: [
          {
            kind: "fact",
            title: "unsupported",
            detail: "unsupported",
            durable: true,
            target_page: None,
          },
        ],
      }),
    ] {
    try persist_result_payload(root, payload) catch {
      _ => ()
    } noraise {
      _ => fail("invalid opt in must fail closed")
    }
  }
  assert_true(!@fsx.exists(root + "/.moonbook"))
  assert_true(!@fsx.exists(root + "/wiki"))
}

///|
async test "native Wenyu import rejects symlink destinations and resumes after corrected first attempt" {
  let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-native-wenyu-symlink-"))
  let outside = @fs.realpath(@fs.tmpdir(prefix="moonbook-native-wenyu-outside-"))
  @fs.mkdir(root + "/wiki")
  @fs.symlink(target=outside, root + "/wiki/synthesis")
  try persist_result_payload(root, native_wenyu_test_payload()) catch {
    error => assert_true("\{error}".contains("symlink"))
  } noraise {
    _ => fail("symlink must be rejected")
  }
  assert_eq(@fsx.list_directory(outside).length(), 0)
  // Preserve the rejected symlink as evidence, correct the synthetic fixture,
  // then retry the exact same Work and Book after failed first preparation.
  @fs.rename(root + "/wiki/synthesis", root + "/rejected-synthesis-symlink")
  ignore(persist_result_payload(root, native_wenyu_test_payload()))
  assert_eq(@fsx.list_directory(outside).length(), 0)
}
