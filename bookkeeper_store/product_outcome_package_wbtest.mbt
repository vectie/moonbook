///|
fn package_test_fixture() -> Json {
  let bytes = "Original source <&> 中文\n"
  let evidence : @bookkeeper.VersionedEvidenceReference = {
    reference_id: "retained-result",
    reference_version: "1",
    digest: outcome_source_digest(bytes),
    provenance_ref: "fixture://digital-result",
  }
  let absent : ProductOutcomeGapStatement = {
    present: false,
    severity: 0,
    summary: "Explicit fixture statement: no additional gap asserted in this limited digital outcome",
    evidence_refs: [evidence.reference_id],
  }
  let submission : ProductOutcomeSubmission = {
    ..submission_fixture(),
    source_product: "moonmoon",
    evidence_refs: [evidence],
    decision_evidence_id: evidence.reference_id,
    information_gap: absent,
    recognition_gap: absent,
    decisiveness_gap: absent,
    capability_id: None,
    capability_version: None,
    capability_change_digest: None,
    capability_summary: None,
  }
  let payload : Json = {
    "submission": submission.to_json(),
    "artifacts": [
      {
        "reference": evidence.to_json(),
        "text": bytes,
        "media_type": "application/json",
      },
    ],
  }
  let text = payload.stringify()
  {
    "contract_version": "moonbook.product-outcome-package.v1",
    "package_digest": outcome_source_digest(text),
    "payload_json": text,
  }
}

///|
async fn package_test_operation(
  root : String,
  operation : String,
  payload : Json,
) -> Json {
  let (status, value) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/" + operation,
    payload,
  )
  assert_eq(status, 200, msg=value.stringify())
  lesson_handoff_field(value, "result")
}

///|
async test "general product intake retains sources and exact retries across both existing gates" {
  let root = @fs.tmpdir(prefix="moonbook-package-")
  let source_pack = package_test_fixture()
  let submission = decode_product_outcome_package(source_pack)
  let request : Json = { "submission": submission.submission.to_json() }
  let first = package_test_operation(root, "product-import", source_pack)
  assert_eq(lesson_handoff_field(first, "package"), source_pack)
  assert_eq(
    lesson_handoff_field(lesson_handoff_field(first, "progress"), "state"),
    "deliverable_review_required",
  )
  let original = replay_bookkeeper_store(root)
  assert_eq(package_test_operation(root, "product-import", source_pack), first)
  assert_eq(replay_bookkeeper_store(root).last_sequence, original.last_sequence)
  let deliverable = original.records[0]
  ignore(
    closure_test_decide(root, deliverable, "package-accept", @bookkeeper.Accept),
  )
  let accepted = package_test_operation(root, "product-read", request)
  assert_eq(
    lesson_handoff_field(lesson_handoff_field(accepted, "progress"), "state"),
    "continue_required",
  )
  // Reimport cannot cross a review gate; explicit Continue reuses existing assessment.
  assert_eq(
    package_test_operation(root, "product-import", source_pack),
    accepted,
  )
  let continued = package_test_operation(root, "product-continue", request)
  assert_eq(
    lesson_handoff_field(lesson_handoff_field(continued, "progress"), "state"),
    "assessment_review_required",
  )
  let snapshot = replay_bookkeeper_store(root)
  let assessment = snapshot.records.filter(record => {
      record.stage == ThreeGapFinding
    })[0]
  ignore(
    closure_test_decide(
      root,
      assessment,
      "package-assessment",
      @bookkeeper.Accept,
    ),
  )
  let reviewed = package_test_operation(root, "product-read", request)
  assert_eq(
    lesson_handoff_field(lesson_handoff_field(reviewed, "progress"), "state"),
    "reviewed_source_available",
  )
  assert_eq(lesson_handoff_field(reviewed, "package"), source_pack)
  guard lesson_handoff_field(reviewed, "reviews") is Array(reviews) else {
    fail("reviews")
  }
  assert_eq(reviews.length(), 2)
  assert_eq(
    find_record(replay_bookkeeper_store(root), deliverable.record),
    Some(deliverable),
  )
  let before = replay_bookkeeper_store(root).last_sequence
  ignore(package_test_operation(root, "product-read", request))
  ignore(package_test_operation(root, "product-list", {}))
  assert_eq(replay_bookkeeper_store(root).last_sequence, before)
}

///|
async test "decline revision and escalation retain source and never imply acceptance" {
  for
    disposition in [
      @bookkeeper.Reject,
      @bookkeeper.Revise,
      @bookkeeper.Escalate,
    ] {
    let root = @fs.tmpdir(prefix="moonbook-package-deferred-")
    let source_pack = package_test_fixture()
    ignore(package_test_operation(root, "product-import", source_pack))
    let submission = decode_product_outcome_package(source_pack)
    let request : Json = { "submission": submission.submission.to_json() }
    let original = replay_bookkeeper_store(root).records[0]
    let review = closure_test_decide(
      root, original, "package-decision", disposition,
    )
    let readback = package_test_operation(root, "product-continue", request)
    assert_eq(lesson_handoff_field(readback, "package"), source_pack)
    assert_eq(lesson_handoff_field(readback, "reviews"), [review.to_json()])
    assert_eq(
      lesson_handoff_field(lesson_handoff_field(readback, "progress"), "state"),
      if disposition == @bookkeeper.Reject {
        "deliverable_rejected"
      } else {
        "deliverable_review_required"
      },
    )
    assert_eq(replay_bookkeeper_store(root).records.length(), 1)
  }
}

///|
async test "changed package bytes missing evidence and conflicting immutable identity fail before writes" {
  let root = @fs.tmpdir(prefix="moonbook-package-invalid-")
  let source_pack = package_test_fixture()
  ignore(package_test_operation(root, "product-import", source_pack))
  let before = replay_bookkeeper_store(root).last_sequence
  let bad_bytes : Json = {
    "contract_version": "moonbook.product-outcome-package.v1",
    "package_digest": lesson_handoff_field(source_pack, "package_digest"),
    "payload_json": "{}",
  }
  assert_eq(
    outcome_lesson_request(
      root, "/api/bookkeeper/lessons/product-import", bad_bytes,
    ).0,
    422,
  )
  guard lesson_handoff_field(source_pack, "payload_json") is String(source) else {
    fail("fixture payload")
  }
  let changed = source.replace(old="Original source", new="Changed source")
  let changed_package : Json = {
    "contract_version": "moonbook.product-outcome-package.v1",
    "package_digest": outcome_source_digest(changed),
    "payload_json": changed,
  }
  assert_eq(
    outcome_lesson_request(
      root, "/api/bookkeeper/lessons/product-import", changed_package,
    ).0,
    422,
  )
  let changed_statement = source.replace(
    old="One evidence-bound research idea was accepted.",
    new="Changed operator interpretation",
  )
  let conflicting : Json = {
    "contract_version": "moonbook.product-outcome-package.v1",
    "package_digest": outcome_source_digest(changed_statement),
    "payload_json": changed_statement,
  }
  assert_eq(
    outcome_lesson_request(
      root, "/api/bookkeeper/lessons/product-import", conflicting,
    ).0,
    422,
  )
  assert_eq(replay_bookkeeper_store(root).last_sequence, before)
  assert_eq(
    lesson_handoff_field(
      package_test_operation(root, "product-read", {
        "submission": decode_product_outcome_package(source_pack).submission.to_json(),
      }),
      "package",
    ),
    source_pack,
  )
}

///|
// Optional source-integration fixture. The .mbtx runner first imports the real
// exported MoonMoon bytes with the production CLI into this isolated Book root.
// Only this test installs fixture reviewer authority; production intake cannot.
async test "product outcome actual CLI crossing fixture decisions" {
  guard @env.get_env_var("MOONBOOK_PRODUCT_JOURNEY") is Some(directory) else {
    return
  }
  let root = directory + "/book-store"
  let source_pack = @json.parse(
    @fsx.read_file(directory + "/source-package.json"),
  )
  let submission = decode_product_outcome_package(source_pack)
  assert_eq(submission.source_product, "moonmoon")
  let request : Json = { "submission": submission.submission.to_json() }
  let before = package_test_operation(root, "product-read", request)
  assert_eq(lesson_handoff_field(before, "package"), source_pack)
  let snapshot = replay_bookkeeper_store(root)
  assert_eq(snapshot.records.length(), 1)
  let deliverable = snapshot.records[0]
  ignore(
    closure_test_decide(
      root,
      deliverable,
      "fixture-moonmoon-deliverable",
      @bookkeeper.Accept,
    ),
  )
  let continued = package_test_operation(root, "product-continue", request)
  let assessment_ref : @bookkeeper.VersionedRecordReference = @json.from_json(
    lesson_handoff_field(
      lesson_handoff_field(continued, "progress"),
      "next_record",
    ),
  )
  let assessment = find_record(replay_bookkeeper_store(root), assessment_ref).unwrap()
  ignore(
    closure_test_decide(
      root,
      assessment,
      "fixture-moonmoon-assessment",
      @bookkeeper.Accept,
    ),
  )
  let readback = package_test_operation(root, "product-read", request)
  assert_eq(
    lesson_handoff_field(lesson_handoff_field(readback, "progress"), "state"),
    "reviewed_source_available",
  )
  @fs.write_file(
    directory + "/fixture-reviewed.json",
    readback.stringify(indent=2),
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    directory + "/read-request.json",
    request.stringify(indent=2),
    create_mode=CreateOrTruncate,
  )
}

///|
async test "interrupted deliverable and result intake reconcile to one original source chain" {
  let source_pack = package_test_fixture()
  let complete_root = @fs.tmpdir(prefix="moonbook-package-complete-")
  ignore(package_test_operation(complete_root, "product-import", source_pack))
  let complete = replay_bookkeeper_store(complete_root)
  let deliverable = complete.records[0]
  let result = complete.envelopes.filter(envelope => {
      envelope.message_kind == "product.result"
    })[0]
  for include_result in [false, true] {
    let root = @fs.tmpdir(prefix="moonbook-package-interrupted-")
    assert_true(persist_bookkeeper_record(root, deliverable).accepted)
    if include_result {
      assert_true(persist_transport_envelope(root, result).accepted)
    }
    let resumed = package_test_operation(root, "product-import", source_pack)
    assert_eq(lesson_handoff_field(resumed, "package"), source_pack)
    let snapshot = replay_bookkeeper_store(root)
    assert_eq(snapshot.records, complete.records)
    assert_eq(snapshot.envelopes, complete.envelopes)
    assert_eq(snapshot.reviews.length(), 0)
    assert_eq(
      package_test_operation(root, "product-import", source_pack),
      resumed,
    )
    assert_eq(
      replay_bookkeeper_store(root).last_sequence,
      snapshot.last_sequence,
    )
  }
}

///|
async test "assessment decline revision and escalation preserve exact original source" {
  for
    disposition in [
      @bookkeeper.Reject,
      @bookkeeper.Revise,
      @bookkeeper.Escalate,
    ] {
    let root = @fs.tmpdir(prefix="moonbook-package-assessment-")
    let source_pack = package_test_fixture()
    let submission = decode_product_outcome_package(source_pack)
    let request : Json = { "submission": submission.submission.to_json() }
    ignore(package_test_operation(root, "product-import", source_pack))
    ignore(
      closure_test_decide(
        root,
        replay_bookkeeper_store(root).records[0],
        "package-initial",
        @bookkeeper.Accept,
      ),
    )
    let continued = package_test_operation(root, "product-continue", request)
    let reference : @bookkeeper.VersionedRecordReference = @json.from_json(
      lesson_handoff_field(
        lesson_handoff_field(continued, "progress"),
        "next_record",
      ),
    )
    let assessment = find_record(replay_bookkeeper_store(root), reference).unwrap()
    let final_review = closure_test_decide(
      root, assessment, "package-assessment-negative", disposition,
    )
    let readback = package_test_operation(root, "product-read", request)
    assert_eq(lesson_handoff_field(readback, "package"), source_pack)
    guard lesson_handoff_field(readback, "reviews") is Array(reviews) else {
      fail("reviews")
    }
    assert_eq(reviews.length(), 2)
    assert_true(reviews.contains(final_review.to_json()))
    assert_eq(
      lesson_handoff_field(lesson_handoff_field(readback, "progress"), "state"),
      if disposition == @bookkeeper.Reject {
        "assessment_rejected"
      } else {
        "assessment_review_required"
      },
    )
    assert_eq(
      package_test_operation(root, "product-import", source_pack),
      readback,
    )
    assert_false(
      replay_bookkeeper_store(root).records.any(record => {
        record.stage == CapabilityProposal
      }),
    )
  }
}
