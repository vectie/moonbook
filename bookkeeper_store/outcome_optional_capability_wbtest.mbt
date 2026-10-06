///|
fn optional_capability_legacy_submission() -> ProductOutcomeSubmission {
  let original = submission_fixture()
  {
    ..original,
    information_gap: {
      ..original.information_gap,
      present: false,
      severity: 0,
    },
    recognition_gap: {
      ..original.recognition_gap,
      present: false,
      severity: 0,
    },
    decisiveness_gap: {
      ..original.decisiveness_gap,
      present: false,
      severity: 0,
    },
  }
}

///|
async test "capture baseline legacy outcome bytes and persisted no-change journal" {
  if @env.get_env_var("MOONBOOK_CAPTURE_LEGACY_OUTCOME") is Some(path) {
    let root = @fs.tmpdir(prefix="book-no-change-legacy-")
    let submission = optional_capability_legacy_submission()
    let first = submit_product_outcome(root, submission)
    let deliverable = find_record(
      replay_bookkeeper_store(root),
      first.deliverable,
    ).unwrap()
    let review = closure_test_accept(
      root, deliverable, "optional-legacy-deliverable",
    )
    let closure = submission_closure_request(
      submission,
      first.deliverable,
      first.result,
      review,
    )
    let second = submit_product_outcome(root, submission)
    let assessment = find_record(
      replay_bookkeeper_store(root),
      second.closure.unwrap().three_gap_assessment,
    ).unwrap()
    ignore(closure_test_accept(root, assessment, "optional-legacy-assessment"))
    let final_receipt = submit_product_outcome(root, submission)
    assert_eq(final_receipt.state, "closed_no_capability_change")
    let fixture : Json = {
      "fixture": "Captured before optional-capability implementation; complete legacy descriptor",
      "submission_text": submission.to_json().stringify(),
      "closure_text": closure.to_json().stringify(),
      "receipt": final_receipt.to_json(),
      "root": root,
      "snapshot": replay_bookkeeper_store(root).to_json(),
    }
    @fs.write_file(path, fixture.stringify(indent=2), create_mode=CreateNew)
  }
}

///|
async test "no-gap outcome permits omitted descriptor without a sentinel identity" {
  let wire = optional_capability_legacy_submission().to_json()
  guard wire is Object(fields) else { fail("submission object") }
  for
    key in [
      "capability_id", "capability_version", "capability_change_digest", "capability_summary",
    ] {
    ignore(fields.remove(key))
  }
  let submission : ProductOutcomeSubmission = @json.from_json(wire)
  assert_eq(submission.to_json(), wire)
  let root = @fs.tmpdir(prefix="book-no-change-omitted-")
  let first = submit_product_outcome(root, submission)
  assert_eq(first.state, "deliverable_review_required")
  assert_eq(replay_bookkeeper_store(root).records.length(), 1)
}

///|
async test "complete legacy outcome bytes summaries and durable journal replay are unchanged" {
  if @env.get_env_var("MOONBOOK_LEGACY_BASELINE") is Some(path) {
    let fixture = @json.parse(@fs.read_file(path).text())
    let submission_text = lesson_handoff_text(fixture, "submission_text")
    let closure_text = lesson_handoff_text(fixture, "closure_text")
    let submission : ProductOutcomeSubmission = @json.from_json(
      @json.parse(submission_text),
    )
    let closure : ProductOutcomeClosureRequest = @json.from_json(
      @json.parse(closure_text),
    )
    assert_eq(submission.to_json().stringify(), submission_text)
    assert_eq(closure.to_json().stringify(), closure_text)
    let root = lesson_handoff_text(fixture, "root")
    let before : BookkeeperStoreSnapshot = @json.from_json(
      lesson_handoff_field(fixture, "snapshot"),
    )
    assert_eq(replay_bookkeeper_store(root), before)
    assert_eq(
      submit_product_outcome(root, submission).to_json(),
      lesson_handoff_field(fixture, "receipt"),
    )
    let receipt : ProductOutcomeSubmissionReceipt = @json.from_json(
      lesson_handoff_field(fixture, "receipt"),
    )
    assert_eq(close_product_outcome(root, closure), receipt.closure.unwrap())
    assert_eq(replay_bookkeeper_store(root), before)
    assert_true(before.replay_issues.is_empty())
  }
}
