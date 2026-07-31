///|
fn requirements_test_evidence(
  id : String,
) -> @bookkeeper.VersionedEvidenceReference {
  {
    reference_id: id,
    reference_version: "v1",
    digest: "sha256:\{id}",
    provenance_ref: "fixture://\{id}",
  }
}

///|
fn requirements_test_request() -> RequirementsPrepareRequest {
  {
    contract_version: requirements_prepare_contract_version(),
    request: {
      record_id: "request-product-review",
      record_version: "r3",
      record_digest: "sha256:request-product-review",
    },
    book_id: "product-review",
    goal: "Turn exact product evidence into reviewable requirements.",
    owner_route: "moonbook://books/product-review/requirements",
    recorded_at: 1785456000,
    evidence_refs: [
      requirements_test_evidence("source-b"),
      requirements_test_evidence("source-a"),
      requirements_test_evidence("source-a"),
    ],
    statements: [
      {
        statement_id: "question-1",
        kind: "unresolved_question",
        text: "Which acceptance threshold should the named reviewer choose?",
        evidence_refs: ["source-b"],
      },
      {
        statement_id: "fact-1",
        kind: "fact",
        text: "The source records the current product boundary.",
        evidence_refs: ["source-b", "source-a", "source-a"],
      },
      {
        statement_id: "inference-1",
        kind: "inference",
        text: "The boundary may require a pack-owned adapter.",
        evidence_refs: ["source-a"],
      },
      {
        statement_id: "calculation-1",
        kind: "calculation",
        text: "Two independent sources are in scope.",
        evidence_refs: ["source-b", "source-a"],
      },
    ],
  }
}

///|
test "requirements preparation is deterministic, separated, and review pending" {
  let first = prepare_requirements(requirements_test_request())
  let second = prepare_requirements(requirements_test_request())
  assert_eq(first, second)
  assert_eq(first.product_id, "moonbook")
  assert_eq(first.functionality, "moonwiki")
  assert_eq(first.capability, "moonbook/wiki.requirements.prepare@0.1.0")
  assert_eq(first.agent_runtime, "moonclaw")
  assert_false(first.agent_execution_requested)
  assert_eq(first.review_status, "pending")
  assert_false(first.accepted_truth)
  assert_false(first.accepted_into_book)
  assert_true(first.requires_human_review)
  assert_false(first.external_side_effects_applied)
  assert_eq(first.facts.length(), 1)
  assert_eq(first.calculations.length(), 1)
  assert_eq(first.inferences.length(), 1)
  assert_eq(first.unresolved_questions.length(), 1)
  assert_eq(first.evidence_refs.map(item => item.reference_id), [
    "source-a", "source-b",
  ])
  assert_eq(first.facts[0].evidence_refs, ["source-a", "source-b"])
  assert_true(executable_source_digest_is_valid(first.packet.record_digest))
  let reconciliation = reconcile_requirements_packet(
    requirements_test_request(),
    first,
  )
  assert_true(reconciliation.exact_match)
  assert_eq(reconciliation.status, "exact")
  assert_eq(reconciliation.review_status, "pending")
  assert_false(reconciliation.accepted_truth)
}

///|
test "requirements preparation rejects unknown evidence and statement kinds" {
  let unknown_evidence = requirements_test_request()
  unknown_evidence.statements[0].evidence_refs.push("not-in-packet")
  try prepare_requirements(unknown_evidence) catch {
    _ => ()
  } noraise {
    _ => fail("unknown evidence must fail closed")
  }
  let unknown_kind = requirements_test_request()
  unknown_kind.statements.push({
    statement_id: "opinion-1",
    kind: "opinion",
    text: "This category cannot cross the exact contract.",
    evidence_refs: ["source-a"],
  })
  try prepare_requirements(unknown_kind) catch {
    _ => ()
  } noraise {
    _ => fail("unknown epistemic kinds must fail closed")
  }
}

///|
test "requirements preparation rejects conflicting versioned evidence" {
  let request = requirements_test_request()
  request.evidence_refs.push({
    reference_id: "source-a",
    reference_version: "v2",
    digest: "sha256:source-a-v2",
    provenance_ref: "fixture://source-a-v2",
  })
  try prepare_requirements(request) catch {
    _ => ()
  } noraise {
    _ => fail("conflicting evidence identity must fail closed")
  }
}
