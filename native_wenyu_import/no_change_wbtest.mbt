///|
// Completion-policy and native-evidence validation belong to Town. These tests
// exercise Book's actual filesystem transaction for the unchanged owner result
// envelope; they do not claim that Book independently verifies no-change proof.
fn native_wenyu_no_change_result() -> BookResult {
  {
    result_id: "wenyu-no-change-code-patch",
    summary: "No net source change; required checks passed; human review required; original-task acceptance unevaluated.",
    artifacts: [
      "build/CODE_PATCH.md", "build/TEST_RESULTS.md", "raw/build/native/native-no-change-work/output-package.json",
    ],
    memory_candidates: [],
    requires_review: true,
    notify_town: true,
  }
}

///|
fn native_wenyu_no_change_payload(
  work_id? : String = "native-no-change-work",
) -> Json {
  native_wenyu_test_payload(work_id~, result=native_wenyu_no_change_result())
}

///|
async fn native_wenyu_assert_no_change_records(
  root : String,
  outcome : PersistResultOutcome,
) -> Unit {
  let key = native_wenyu_digest("native-no-change-work")
  assert_true(outcome.review_queued)
  assert_true(outcome.notify_town)
  assert_true(!outcome.executable_event.accepted)
  assert_eq(outcome.executable_event.event_type, "review_required")
  assert_eq(outcome.executable_event.lifecycle_proof, None)
  assert_eq(outcome.executable_event.run_id, None)
  assert_eq(
    outcome.executable_event.artifacts,
    native_wenyu_no_change_result().artifacts,
  )
  let evidence = @fsx.read_file(root + "/wiki/synthesis/evidence.md")
  assert_eq(native_wenyu_count_line(evidence, "### \{outcome.evidence_id}"), 1)
  assert_true(evidence.contains("- Status: `pending-review`"))
  assert_true(evidence.contains("original-task acceptance unevaluated"))
  let review = @fsx.read_file(root + "/wiki/reviews/pending.md")
  assert_eq(
    native_wenyu_count_line(
      review,
      "- Review ID: `result-review-native-wenyu-\{key}`",
    ),
    1,
  )
  assert_true(review.contains("- Status: `pending`"))
  assert_true(
    review.contains("native Wenyu result requires human product review"),
  )
  assert_true(!review.contains("native Wenyu implementation requires"))
  assert_eq(
    native_wenyu_count_line(
      @fsx.read_file(root + "/wiki/log.md"),
      "## [native-wenyu-\{key}] persist | wenyu-no-change-code-patch",
    ),
    1,
  )
  let event : ExecutableBookEvent = @json.from_json(
    @json.parse(@fsx.read_file(root + "/" + outcome.executable_event_path)),
  )
  assert_eq(event.to_json(), outcome.executable_event.to_json())
  assert_true(!event.accepted)
}

///|
async test "no change Book persistence recovers all twelve durable checkpoints without acceptance" {
  for checkpoint in 0..<=11 {
    let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-no-change-crash-"))
    let payload = native_wenyu_no_change_payload()
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
    let intent = native_wenyu_test_intent(root, "native-no-change-work")
    assert_eq(intent.writes.length(), 10)
    let key = native_wenyu_digest("native-no-change-work")
    let intent_path = ".moonbook/native-wenyu-imports/\{key}.intent.json"
    let intent_bytes = native_wenyu_read(root, intent_path)
    let outcome = persist_result_payload(root, payload)
    assert_eq(outcome.to_json(), intent.outcome.to_json())
    let receipt_path = ".moonbook/native-wenyu-imports/\{key}.receipt.json"
    let receipt_bytes = native_wenyu_read(root, receipt_path)
    assert_true(receipt_bytes is Some(_))
    assert_eq(
      persist_result_payload(root, payload).to_json(),
      outcome.to_json(),
    )
    assert_eq(native_wenyu_read(root, intent_path), intent_bytes)
    assert_eq(native_wenyu_read(root, receipt_path), receipt_bytes)
    for write in intent.writes {
      assert_eq(native_wenyu_read(root, write.path), Some(write.after))
    }
    native_wenyu_assert_no_change_records(root, outcome)
    assert_eq(@fsx.list_directory(root + "/events").length(), 2)
  }
}

///|
async test "no change committed replay preserves human review and newer latest event" {
  let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-no-change-human-replay-"))
  let payload = native_wenyu_no_change_payload()
  let first = persist_result_payload(root, payload)
  native_wenyu_assert_no_change_records(root, first)
  let second = persist_result_payload(
    root,
    native_wenyu_no_change_payload(work_id="native-no-change-newer-work"),
  )
  assert_true(first.evidence_id != second.evidence_id)
  let latest = @fsx.read_file(root + "/events/latest.json")
  let review_path = root + "/wiki/reviews/pending.md"
  let evidence_path = root + "/wiki/synthesis/evidence.md"
  let review = @fsx.read_file(review_path) + "\nHuman product review note.\n"
  let evidence = @fsx.read_file(evidence_path) +
    "\nHuman evidence annotation.\n"
  @fsx.write_to_file(review_path, review)
  @fsx.write_to_file(evidence_path, evidence)
  let first_event = @fsx.read_file(root + "/" + first.executable_event_path)
  let replayed = persist_result_payload(root, payload)
  assert_eq(replayed.to_json(), first.to_json())
  assert_eq(@fsx.read_file(review_path), review)
  assert_eq(@fsx.read_file(evidence_path), evidence)
  assert_eq(@fsx.read_file(root + "/events/latest.json"), latest)
  assert_eq(
    @fsx.read_file(root + "/" + first.executable_event_path),
    first_event,
  )
  assert_eq(@fsx.list_directory(root + "/events").length(), 3)
  assert_true(!replayed.executable_event.accepted)
}

///|
async test "no change interrupted import preserves human conflicts and blocks newer work" {
  let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-no-change-human-conflict-"))
  let payload = native_wenyu_no_change_payload()
  try persist_native_wenyu_import(root, payload, fail_after=1) catch {
    error =>
      assert_true(
        "\{error}".contains("injected native Wenyu import interruption"),
      )
  } noraise {
    _ => fail("expected interruption")
  }
  let intent = native_wenyu_test_intent(root, "native-no-change-work")
  let observations_path = root + "/wiki/synthesis/observations.md"
  let prepared = @fsx.read_file(observations_path)
  let human = prepared + "\nHuman work after interrupted import.\n"
  @fsx.write_to_file(observations_path, human)
  try persist_result_payload(root, payload) catch {
    error => assert_true("\{error}".contains("destination conflict"))
  } noraise {
    _ => fail("must preserve human change")
  }
  try
    persist_result_payload(
      root,
      native_wenyu_no_change_payload(work_id="native-no-change-later-work"),
    )
  catch {
    error => assert_true("\{error}".contains("resume the earlier import"))
  } noraise {
    _ => fail("later work must wait for the original intent")
  }
  assert_eq(@fsx.read_file(observations_path), human)
  assert_true(!@fsx.exists(root + "/wiki/synthesis/evidence.md"))
  let key = native_wenyu_digest("native-no-change-work")
  assert_eq(
    native_wenyu_read(
      root,
      ".moonbook/native-wenyu-imports/\{key}.receipt.json",
    ),
    None,
  )
  assert_eq(
    native_wenyu_test_intent(root, "native-no-change-work").to_json(),
    intent.to_json(),
  )
  // Resolve only the synthetic fixture back to its saved prepared image.
  @fsx.write_to_file(observations_path, prepared)
  let outcome = persist_result_payload(root, payload)
  native_wenyu_assert_no_change_records(root, outcome)
}

///|
async test "no change same work rejects changed result or request without rewriting records" {
  let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-no-change-payload-conflict-"))
  let original = native_wenyu_no_change_payload()
  let outcome = persist_result_payload(root, original)
  let intent = native_wenyu_test_intent(root, "native-no-change-work")
  let changed_result = {
    ..native_wenyu_no_change_result(),
    summary: "Changed owner explanation under the same work",
  }
  for
    payload in [
      native_wenyu_test_payload(
        work_id="native-no-change-work",
        result=changed_result,
      ),
      native_wenyu_test_payload(
        work_id="native-no-change-work",
        result=native_wenyu_no_change_result(),
        request_digest=native_wenyu_digest("different frozen request"),
      ),
    ] {
    try persist_result_payload(root, payload) catch {
      error =>
        assert_true(
          "\{error}".contains("already binds different request or payload"),
        )
    } noraise {
      _ => fail("same work must retain the exact result and request")
    }
  }
  for write in intent.writes {
    assert_eq(native_wenyu_read(root, write.path), Some(write.after))
  }
  assert_eq(persist_result_payload(root, original).to_json(), outcome.to_json())
  native_wenyu_assert_no_change_records(root, outcome)
}

///|
async test "saved legacy Wenyu intent retains its original implementation wording on recovery" {
  let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-native-wenyu-legacy-intent-"))
  let payload = native_wenyu_test_payload()
  let (identity, result, payload_text) = decode_native_wenyu_import(payload)
  let prepared = prepare_native_wenyu_intent(
    root, identity, result, payload_text,
  )
  // Model an intent durably prepared by the previous version, before any
  // projection was applied. Saved intents remain authoritative across upgrades.
  let writes = prepared.writes.map(write => {
    if write.path == "wiki/reviews/pending.md" {
      {
        ..write,
        after: write.after
        .replace(
          old="native Wenyu result requires human product review",
          new="native Wenyu implementation requires human product review",
        )
        .to_string(),
      }
    } else {
      write
    }
  })
  let saved = { ..prepared, writes, }
  let key = native_wenyu_digest(identity.work_id)
  let intent_path = ".moonbook/native-wenyu-imports/\{key}.intent.json"
  let bytes = saved.to_json().stringify(indent=2)
  native_wenyu_write(root, intent_path, bytes)
  let resumed = persist_result_payload(root, payload)
  assert_eq(resumed.to_json(), saved.outcome.to_json())
  assert_eq(native_wenyu_read(root, intent_path), Some(bytes))
  for write in saved.writes {
    assert_eq(native_wenyu_read(root, write.path), Some(write.after))
  }
  let review = @fsx.read_file(root + "/wiki/reviews/pending.md")
  assert_true(
    review.contains("native Wenyu implementation requires human product review"),
  )
  assert_eq(persist_result_payload(root, payload).to_json(), resumed.to_json())
  assert_eq(@fsx.read_file(root + "/wiki/reviews/pending.md"), review)
  assert_true(!resumed.executable_event.accepted)
}
