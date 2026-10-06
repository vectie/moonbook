///|
fn optional_capability_keys() -> Array[String] {
  [
    "capability_id", "capability_version", "capability_change_digest", "capability_summary",
  ]
}

///|
fn optional_capability_no_change() -> ProductOutcomeSubmission {
  {
    ..optional_capability_legacy_submission(),
    capability_id: None,
    capability_version: None,
    capability_change_digest: None,
    capability_summary: None,
  }
}

///|
fn optional_capability_closure_wire() -> Json {
  let submission = optional_capability_legacy_submission()
  let request : ProductOutcomeClosureRequest = {
    contract_version: product_outcome_closure_contract_version(),
    request: submission.submission,
    source_product: submission.source_product,
    deliverable: submission_test_ref("deliverable"),
    result: submission_test_ref("result"),
    deliverable_review: submission_test_ref("review"),
    observed_at: submission.observed_at,
    recorded_at: submission.recorded_at,
    outcome_summary: submission.outcome_summary,
    owner_route: submission.owner_route,
    evidence_refs: submission.evidence_refs,
    information_gap: submission.information_gap,
    recognition_gap: submission.recognition_gap,
    decisiveness_gap: submission.decisiveness_gap,
    capability_id: submission.capability_id,
    capability_version: submission.capability_version,
    capability_change_digest: submission.capability_change_digest,
    capability_summary: submission.capability_summary,
  }
  request.to_json()
}

///|
fn optional_wire_copy(value : Json) -> Map[String, Json] raise {
  guard @json.parse(value.stringify()) is Object(fields) else {
    fail("wire object")
  }
  fields
}

///|
fn optional_descriptor_cases(
  kind : String,
  complete : Json,
) -> Array[Json] raise {
  let cases : Array[Json] = []
  fn add(id : String, wire : Json, valid : Bool) -> Unit {
    cases.push({
      "id": kind + "-" + id,
      "kind": kind,
      "valid": valid,
      "wire": wire,
    })
  }
  add("legacy-no-gap", complete, true)
  let omitted = optional_wire_copy(complete)
  for key in optional_capability_keys() {
    ignore(omitted.remove(key))
  }
  add("omitted-no-gap", Json::object(omitted), true)
  for mask in 1..<15 {
    let fields = optional_wire_copy(complete)
    for index in 0..<4 {
      if mask / [1, 2, 4, 8][index] % 2 == 0 {
        ignore(fields.remove(optional_capability_keys()[index]))
      }
    }
    add("partial-\{mask}", Json::object(fields), false)
  }
  for key in optional_capability_keys() {
    for
      (label, value) in [
        ("null", Json::null()),
        ("number", Json::number(1)),
        ("array", Json::array([Json::string("x")])),
        ("blank", Json::string("")),
        ("whitespace", Json::string(" \t\n")),
      ] {
      let fields = optional_wire_copy(complete)
      fields[key] = value
      add(key + "-" + label, Json::object(fields), false)
    }
  }
  let all_null = optional_wire_copy(complete)
  for key in optional_capability_keys() {
    all_null[key] = Json::null()
  }
  add("all-null", Json::object(all_null), false)
  for
    (label, digest) in [
      ("upper", "sha256:" + "A".repeat(64)),
      ("short", "sha256:abc"),
      ("prefix", "SHA256:" + "a".repeat(64)),
    ] {
    let fields = optional_wire_copy(complete)
    fields["capability_change_digest"] = Json::string(digest)
    add("digest-" + label, Json::object(fields), false)
  }
  for key in ["information_gap", "recognition_gap", "decisiveness_gap"] {
    for
      (label, present, severity, valid) in [
        ("present-with-descriptor", true, 1, true),
        ("present-omitted", true, 1, false),
        ("nonzero-omitted", false, 1, false),
      ] {
      let fields = optional_wire_copy(
        if label == "present-with-descriptor" {
          complete
        } else {
          Json::object(omitted)
        },
      )
      guard fields[key] is Object(gap) else { fail("gap object") }
      gap["present"] = present.to_json()
      gap["severity"] = severity.to_json()
      add(key + "-" + label, Json::object(fields), valid)
    }
    let missing = optional_wire_copy(Json::object(omitted))
    ignore(missing.remove(key))
    add(key + "-missing", Json::object(missing), false)
    for field in ["present", "severity"] {
      let fields = optional_wire_copy(Json::object(omitted))
      guard fields[key] is Object(gap) else { fail("gap object") }
      ignore(gap.remove(field))
      add(key + "-missing-" + field, Json::object(fields), false)
    }
  }
  cases
}

///|
async test "submission and closure reject partial null and non-no-gap omission matrices" {
  let cases = optional_descriptor_cases(
      "submission",
      optional_capability_legacy_submission().to_json(),
    ) +
    optional_descriptor_cases("closure", optional_capability_closure_wire())
  for item in cases {
    let wire = lesson_handoff_field(item, "wire")
    let accepted = if lesson_handoff_text(item, "kind") == "submission" {
      let decoded : Result[ProductOutcomeSubmission, Error] = try? @json.from_json(
        wire,
      )
      match decoded {
        Err(_) => false
        Ok(value) => {
          assert_eq(value.to_json(), wire)
          true
        }
      }
    } else {
      let decoded : Result[ProductOutcomeClosureRequest, Error] = try? @json.from_json(
        wire,
      )
      match decoded {
        Err(_) => false
        Ok(value) => {
          assert_eq(value.to_json(), wire)
          true
        }
      }
    }
    assert_eq(
      accepted,
      lesson_handoff_field(item, "valid") is True,
      msg=lesson_handoff_text(item, "id"),
    )
  }
  if @env.get_env_var("MOONBOOK_OPTIONAL_SCHEMA_CASES") is Some(path) {
    @fs.write_file(
      path,
      cases.to_json().stringify(indent=2),
      create_mode=CreateOrTruncate,
    )
  }
}

///|
async test "native partial Option groups fail before records are written" {
  let root = @fs.tmpdir(prefix="book-partial-native-options-")
  let original = optional_capability_legacy_submission()
  for mask in 1..<15 {
    let invalid = {
      ..original,
      capability_id: if mask % 2 == 1 {
        original.capability_id
      } else {
        None
      },
      capability_version: if mask / 2 % 2 == 1 {
        original.capability_version
      } else {
        None
      },
      capability_change_digest: if mask / 4 % 2 == 1 {
        original.capability_change_digest
      } else {
        None
      },
      capability_summary: if mask / 8 % 2 == 1 {
        original.capability_summary
      } else {
        None
      },
    }
    try submit_product_outcome(root, invalid) catch {
      _ => ()
    } noraise {
      _ => fail("partial native descriptor accepted")
    }
    assert_true(replay_bookkeeper_store(root).records.is_empty())
    guard invalid.to_json() is Object(fields) else { fail("object") }
    assert_true(optional_capability_keys().any(key => fields.contains(key)))
  }
}

///|
async test "omitted descriptor completes existing human gates and never creates a capability proposal" {
  let root = @fs.tmpdir(prefix="book-no-change-complete-")
  let submission = optional_capability_no_change()
  let first = submit_product_outcome(root, submission)
  assert_eq(first.state, "deliverable_review_required")
  let deliverable = find_record(
    replay_bookkeeper_store(root),
    first.deliverable,
  ).unwrap()
  let review = closure_test_accept(root, deliverable, "no-change-deliverable")
  let request = submission_closure_request(
    submission,
    first.deliverable,
    first.result,
    review,
  )
  let before = replay_bookkeeper_store(root)
  for
    gap in [
      { ..request.information_gap, present: true, severity: 1, },
      { ..request.information_gap, severity: 2, },
      { ..request.information_gap, summary: " ", },
      { ..request.information_gap, evidence_refs: [], },
      { ..request.information_gap, evidence_refs: ["foreign"], },
      {
        ..request.information_gap,
        evidence_refs: [
          request.evidence_refs[0].reference_id,
          request.evidence_refs[0].reference_id,
        ],
      },
    ] {
    try
      close_product_outcome(root, { ..request, information_gap: gap, })
    catch {
      _ => ()
    } noraise {
      _ => fail("invalid no-change closure accepted")
    }
    assert_eq(replay_bookkeeper_store(root), before)
  }
  for mask in 1..<15 {
    let invalid = {
      ..request,
      capability_id: if mask % 2 == 1 {
        Some("real-capability")
      } else {
        None
      },
      capability_version: if mask / 2 % 2 == 1 {
        Some("1")
      } else {
        None
      },
      capability_change_digest: if mask / 4 % 2 == 1 {
        Some("sha256:" + "c".repeat(64))
      } else {
        None
      },
      capability_summary: if mask / 8 % 2 == 1 {
        Some("A supplied change")
      } else {
        None
      },
    }
    try close_product_outcome(root, invalid) catch {
      _ => ()
    } noraise {
      _ => fail("partial closure accepted")
    }
    assert_eq(replay_bookkeeper_store(root), before)
  }
  let second = submit_product_outcome(root, submission)
  assert_eq(second.state, "assessment_review_required")
  let assessment = find_record(
    replay_bookkeeper_store(root),
    second.closure.unwrap().three_gap_assessment,
  ).unwrap()
  assert_eq(assessment.summary, submission.outcome_summary)
  assert_eq(replay_bookkeeper_store(root).reviews.length(), 1)
  ignore(closure_test_accept(root, assessment, "no-change-assessment"))
  let final_receipt = submit_product_outcome(root, submission)
  assert_eq(final_receipt.state, "closed_no_capability_change")
  let final_snapshot = replay_bookkeeper_store(root)
  assert_false(
    final_snapshot.records.any(record => record.stage == CapabilityProposal),
  )
  assert_false(
    final_snapshot.envelopes.any(envelope => envelope.direction == Egress),
  )
  assert_eq(submit_product_outcome(root, submission), final_receipt)
  assert_eq(replay_bookkeeper_store(root), final_snapshot)
  try
    submit_product_outcome(root, optional_capability_legacy_submission())
  catch {
    _ => ()
  } noraise {
    _ => fail("changed descriptor admission silently reused identity")
  }
  assert_eq(replay_bookkeeper_store(root), final_snapshot)
}

///|
async test "native omission and complete invalid descriptors reject at both public boundaries before writes" {
  let root = @fs.tmpdir(prefix="book-native-descriptor-bypass-")
  let absent = optional_capability_no_change()
  let legacy = optional_capability_legacy_submission()
  let submissions : Array[ProductOutcomeSubmission] = [
    { ..legacy, capability_id: Some(" "), },
    { ..legacy, capability_version: Some(""), },
    { ..legacy, capability_change_digest: Some("sha256:wrong"), },
    { ..legacy, capability_summary: Some("\t"), },
  ]
  for
    gap in [
      { ..absent.information_gap, present: true, severity: 1, },
      { ..absent.information_gap, severity: 1, },
    ] {
    submissions.push({ ..absent, information_gap: gap, })
    submissions.push({ ..absent, recognition_gap: gap, })
    submissions.push({ ..absent, decisiveness_gap: gap, })
  }
  let empty = replay_bookkeeper_store(root)
  for invalid in submissions {
    try submit_product_outcome(root, invalid) catch {
      _ => ()
    } noraise {
      _ => fail("native invalid descriptor accepted")
    }
    assert_eq(replay_bookkeeper_store(root), empty)
  }
  let first = submit_product_outcome(root, absent)
  let deliverable = find_record(
    replay_bookkeeper_store(root),
    first.deliverable,
  ).unwrap()
  let review = closure_test_accept(
    root, deliverable, "native-bypass-deliverable",
  )
  let request = submission_closure_request(
    absent,
    first.deliverable,
    first.result,
    review,
  )
  let before = replay_bookkeeper_store(root)
  for invalid in submissions {
    let closure = {
      ..request,
      information_gap: invalid.information_gap,
      recognition_gap: invalid.recognition_gap,
      decisiveness_gap: invalid.decisiveness_gap,
      capability_id: invalid.capability_id,
      capability_version: invalid.capability_version,
      capability_change_digest: invalid.capability_change_digest,
      capability_summary: invalid.capability_summary,
    }
    try close_product_outcome(root, closure) catch {
      _ => ()
    } noraise {
      _ => fail("native invalid closure descriptor accepted")
    }
    assert_eq(replay_bookkeeper_store(root), before)
  }
}
