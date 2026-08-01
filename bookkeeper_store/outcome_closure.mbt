///|
/// Versioned wire contract for the generic product-outcome closure operation.
pub fn product_outcome_closure_contract_version() -> String {
  "moonbook.bookkeeper.product_outcome_closure.v1"
}

///|
/// Versioned output contract for a replayable closure attempt.
pub fn product_outcome_closure_receipt_contract_version() -> String {
  "moonbook.bookkeeper.product_outcome_closure_receipt.v1"
}

///|
/// A product-supplied, evidence-bound statement for one Three-Gap dimension.
/// MoonBook validates and canonicalizes these statements; it does not ask an
/// LLM to invent or reclassify them.
pub(all) struct ProductOutcomeGapStatement {
  present : Bool
  severity : Int
  summary : String
  evidence_refs : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Generic closure request. The deliverable, product result, evidence set, and
/// named-human acceptance receipt must already exist in the durable store with
/// exact identity/version/digest linkage.
pub(all) struct ProductOutcomeClosureRequest {
  contract_version : String
  request : @bookkeeper.VersionedRecordReference
  source_product : String
  deliverable : @bookkeeper.VersionedRecordReference
  result : @bookkeeper.VersionedRecordReference
  deliverable_review : @bookkeeper.VersionedRecordReference
  observed_at : Int
  recorded_at : Int
  outcome_summary : String
  owner_route : String
  evidence_refs : Array[@bookkeeper.VersionedEvidenceReference]
  information_gap : ProductOutcomeGapStatement
  recognition_gap : ProductOutcomeGapStatement
  decisiveness_gap : ProductOutcomeGapStatement
  capability_id : String
  capability_version : String
  capability_change_digest : String
  capability_summary : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Durable progress receipt. Replaying the same request after a named human
/// reviews the assessment or proposal advances the same chain. No field in the
/// receipt grants activation authority.
pub(all) struct ProductOutcomeClosureReceipt {
  contract_version : String
  request : @bookkeeper.VersionedRecordReference
  outcome_binding : @bookkeeper.VersionedRecordReference
  three_gap_assessment : @bookkeeper.VersionedRecordReference
  assessment_review : @bookkeeper.VersionedRecordReference?
  assessment_disposition : @bookkeeper.BookkeeperDisposition?
  capability_proposal : @bookkeeper.VersionedRecordReference?
  proposal_review : @bookkeeper.VersionedRecordReference?
  proposal_disposition : @bookkeeper.BookkeeperDisposition?
  moonflow_handoff : @bookkeeper.VersionedRecordReference?
  state : String
  pending_human_gate : String
  activation_authorized : Bool
  workspace_records_applied : Bool
  external_side_effects_applied : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
fn closure_record_complete(
  reference : @bookkeeper.VersionedRecordReference,
) -> Bool {
  !reference.record_id.is_blank() &&
  !reference.record_version.is_blank() &&
  product_outcome_digest_valid(reference.record_digest)
}

///|
fn closure_evidence_compare(
  left : @bookkeeper.VersionedEvidenceReference,
  right : @bookkeeper.VersionedEvidenceReference,
) -> Int {
  let by_id = left.reference_id.compare(right.reference_id)
  if by_id != 0 {
    return by_id
  }
  let by_version = left.reference_version.compare(right.reference_version)
  if by_version != 0 {
    return by_version
  }
  let by_digest = left.digest.compare(right.digest)
  if by_digest != 0 {
    return by_digest
  }
  left.provenance_ref.compare(right.provenance_ref)
}

///|
fn closure_canonical_evidence(
  evidence : ArrayView[@bookkeeper.VersionedEvidenceReference],
) -> Array[@bookkeeper.VersionedEvidenceReference] raise {
  let sorted : Array[@bookkeeper.VersionedEvidenceReference] = []
  for reference in evidence {
    if reference.reference_id.is_blank() ||
      reference.reference_version.is_blank() ||
      !product_outcome_digest_valid(reference.digest) ||
      reference.provenance_ref.is_blank() {
      fail("product outcome closure evidence references must be complete")
    }
    sorted.push(reference)
  }
  sorted.sort_by(closure_evidence_compare)
  let unique : Array[@bookkeeper.VersionedEvidenceReference] = []
  for reference in sorted {
    match unique.last() {
      Some(previous) if previous.reference_id == reference.reference_id =>
        if previous != reference {
          fail(
            "product outcome closure has conflicting evidence identity " +
            reference.reference_id,
          )
        }
      _ => unique.push(reference)
    }
  }
  if unique.is_empty() {
    fail("product outcome closure requires evidence")
  }
  unique
}

///|
fn closure_find_envelope(
  snapshot : BookkeeperStoreSnapshot,
  reference : @bookkeeper.VersionedRecordReference,
) -> BookkeeperTransportEnvelope? {
  for envelope in snapshot.envelopes {
    if envelope.envelope == reference {
      return Some(envelope)
    }
  }
  None
}

///|
fn closure_find_review(
  snapshot : BookkeeperStoreSnapshot,
  reference : @bookkeeper.VersionedRecordReference,
) -> GovernedReviewReceipt? {
  for review in snapshot.reviews {
    if review.receipt == reference {
      return Some(review)
    }
  }
  None
}

///|
fn product_outcome_exact_human_decision(
  snapshot : BookkeeperStoreSnapshot,
  subject : @bookkeeper.VersionedRecordReference,
  stage : BookkeeperStage,
) -> GovernedReviewReceipt? raise {
  let mut decision : GovernedReviewReceipt? = None
  for review in snapshot.reviews {
    if review.subject == subject &&
      review.stage == stage &&
      review.review_complete &&
      (
        review.disposition == @bookkeeper.Accept ||
        review.disposition == @bookkeeper.Reject
      ) &&
      review.reviewer_kind == @bookkeeper.Human {
      match decision {
        None => decision = Some(review)
        Some(_) =>
          fail(
            "product outcome closure found ambiguous named-human final decisions",
          )
      }
    }
  }
  decision
}

///|
fn closure_gap_finding(
  statement : ProductOutcomeGapStatement,
  canonical_evidence : ArrayView[@bookkeeper.VersionedEvidenceReference],
  label : String,
) -> @bookkeeper.GapFinding raise {
  if statement.summary.is_blank() {
    fail("\{label} summary is required")
  }
  if (statement.present && (statement.severity < 1 || statement.severity > 5)) ||
    (!statement.present && statement.severity != 0) {
    fail("\{label} severity must be 1..5 when present and zero when absent")
  }
  if statement.evidence_refs.is_empty() {
    fail("\{label} evidence is required")
  }
  let seen : Map[String, Bool] = Map([])
  for reference_id in statement.evidence_refs {
    if reference_id.is_blank() || seen.contains(reference_id) {
      fail("\{label} evidence ids must be non-blank and unique")
    }
    if !canonical_evidence.any(fn(reference) {
        reference.reference_id == reference_id
      }) {
      fail("\{label} cites evidence outside the exact closure set")
    }
    seen[reference_id] = true
  }
  {
    present: statement.present,
    severity: statement.severity,
    summary: statement.summary,
    evidence_refs: ReadOnlyArray::from_array(statement.evidence_refs.copy()),
  }
}

///|
fn closure_reference(
  request : @bookkeeper.VersionedRecordReference,
  suffix : String,
  payload : Json,
) -> @bookkeeper.VersionedRecordReference {
  {
    record_id: request.record_id + "." + suffix,
    record_version: request.record_version,
    record_digest: bookkeeper_payload_digest(payload),
  }
}

///|
fn closure_require_persisted(
  result : BookkeeperMutationResult,
  label : String,
) -> Unit raise {
  if !result.accepted {
    fail("\{label} rejected: \{result.issues.join("; ")}")
  }
}

///|
fn closure_receipt(
  request : ProductOutcomeClosureRequest,
  outcome : @bookkeeper.VersionedRecordReference,
  assessment : @bookkeeper.VersionedRecordReference,
  assessment_review : GovernedReviewReceipt?,
  proposal : @bookkeeper.VersionedRecordReference?,
  proposal_review : GovernedReviewReceipt?,
  handoff : @bookkeeper.VersionedRecordReference?,
  state : String,
  pending_human_gate : String,
) -> ProductOutcomeClosureReceipt {
  {
    contract_version: product_outcome_closure_receipt_contract_version(),
    request: request.request,
    outcome_binding: outcome,
    three_gap_assessment: assessment,
    assessment_review: assessment_review.map(review => review.receipt),
    assessment_disposition: assessment_review.map(review => review.disposition),
    capability_proposal: proposal,
    proposal_review: proposal_review.map(review => review.receipt),
    proposal_disposition: proposal_review.map(review => review.disposition),
    moonflow_handoff: handoff,
    state,
    pending_human_gate,
    activation_authorized: false,
    workspace_records_applied: true,
    external_side_effects_applied: false,
  }
}

///|
fn validate_closure_source(
  snapshot : BookkeeperStoreSnapshot,
  request : ProductOutcomeClosureRequest,
) -> (
  DurableBookkeeperRecord,
  BookkeeperTransportEnvelope,
  GovernedReviewReceipt,
  Array[@bookkeeper.VersionedEvidenceReference],
) raise {
  if request.contract_version != product_outcome_closure_contract_version() {
    fail("invalid product outcome closure contract")
  }
  if !closure_record_complete(request.request) ||
    !closure_record_complete(request.deliverable) ||
    !closure_record_complete(request.result) ||
    !closure_record_complete(request.deliverable_review) {
    fail(
      "closure request, deliverable, result, and review references must be exact",
    )
  }
  if request.source_product.is_blank() || request.source_product == "moonbook" {
    fail("product outcome closure must name an external source product")
  }
  if request.owner_route.is_blank() ||
    request.outcome_summary.is_blank() ||
    request.capability_id.is_blank() ||
    request.capability_version.is_blank() ||
    !product_outcome_digest_valid(request.capability_change_digest) ||
    request.capability_summary.is_blank() {
    fail("product outcome closure metadata is incomplete")
  }
  if request.observed_at < 0 || request.recorded_at < request.observed_at {
    fail("product outcome closure timestamps are invalid")
  }
  let deliverable = match find_record(snapshot, request.deliverable) {
    Some(record) if record.stage == DeliverableAcceptance => record
    _ => fail("closure deliverable is not an exact acceptance record")
  }
  let review = match closure_find_review(snapshot, request.deliverable_review) {
    Some(receipt) if receipt.subject == deliverable.record &&
      receipt.stage == DeliverableAcceptance &&
      receipt.review_complete &&
      receipt.disposition == @bookkeeper.Accept &&
      receipt.reviewer_kind == @bookkeeper.Human => receipt
    _ =>
      fail(
        "closure deliverable review is not an exact named-human Accept receipt",
      )
  }
  let result = match closure_find_envelope(snapshot, request.result) {
    Some(envelope) if envelope.direction == Ingress &&
      envelope.source_product == request.source_product &&
      envelope.destination_product == "moonbook" &&
      envelope.message_kind == "product.result" &&
      envelope.subject == deliverable.record &&
      !envelope.external_activation_allowed &&
      !envelope.side_effects_applied => envelope
    _ =>
      fail(
        "closure result must be an exact product.result ingress for the deliverable",
      )
  }
  let expected_evidence : Array[@bookkeeper.VersionedEvidenceReference] = []
  for reference in deliverable.evidence_refs {
    expected_evidence.push(reference)
  }
  for reference in result.evidence_refs {
    expected_evidence.push(reference)
  }
  let canonical_expected = closure_canonical_evidence(expected_evidence)
  let canonical_request = closure_canonical_evidence(request.evidence_refs)
  if canonical_expected != canonical_request {
    fail(
      "closure evidence must exactly equal the canonical deliverable/result evidence set",
    )
  }
  (deliverable, result, review, canonical_request)
}

///|
fn closure_proposal_payload(
  request : ProductOutcomeClosureRequest,
  evidence : ArrayView[@bookkeeper.VersionedEvidenceReference],
) -> Json {
  let legacy_evidence : Array[@bookkeeper.EvidenceReference] = []
  for reference in evidence {
    legacy_evidence.push({
      reference_id: reference.reference_id,
      digest: reference.digest,
      provenance_ref: reference.provenance_ref,
    })
  }
  @bookkeeper.CapabilityProposal::new(
    proposal_id=request.request.record_id + ".capability-proposal",
    proposal_version=request.request.record_version,
    capability_id=request.capability_id,
    capability_version=request.capability_version,
    owner_route=request.owner_route,
    change_digest=request.capability_change_digest,
    summary=request.capability_summary,
    evidence_refs=legacy_evidence,
  ).to_json()
}

///|
/// Close one exact product outcome through the existing durable Bookkeeper
/// store. The first call records the outcome binding and one explicit Three-Gap
/// assessment. Replays advance only after separately persisted named-human
/// reviews: assessment review creates a reviewable proposal; proposal review
/// emits a non-activating MoonFlow handoff. The operation never approves its
/// own records and never activates a capability.
pub async fn close_product_outcome(
  root : String,
  request : ProductOutcomeClosureRequest,
) -> ProductOutcomeClosureReceipt {
  let source_snapshot = replay_bookkeeper_store(root)
  let (deliverable, result, deliverable_review, evidence) = validate_closure_source(
    source_snapshot, request,
  )
  let outcome_payload : Json = {
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "schema": "product_outcome_binding.v1",
    "request": request.request.to_json(),
    "deliverable": deliverable.record.to_json(),
    "result": result.envelope.to_json(),
    "deliverable_review": deliverable_review.receipt.to_json(),
    "observed_at": request.observed_at,
    "summary": request.outcome_summary,
    "evidence_refs": evidence.to_json(),
  }
  let outcome_ref = closure_reference(
    request.request,
    "outcome",
    outcome_payload,
  )
  let outcome : DurableBookkeeperRecord = {
    contract_version: bookkeeper_store_contract_version(),
    record: outcome_ref,
    stage: OutcomeBinding,
    subject: Some(deliverable.record),
    links: [deliverable.record, result.envelope, deliverable_review.receipt],
    title: "Observed product outcome",
    summary: request.outcome_summary,
    owner_route: request.owner_route,
    status: "observed",
    evidence_refs: evidence,
    issue_refs: [],
    requires_human_review: false,
    next_action: "review deterministic Three-Gap assessment",
    source_product: request.source_product,
    recorded_at: request.recorded_at,
    payload: outcome_payload,
    side_effects_applied: false,
  }
  closure_require_persisted(
    persist_bookkeeper_record(root, outcome),
    "outcome binding",
  )

  let information = closure_gap_finding(
    request.information_gap,
    evidence,
    "information gap",
  )
  let recognition = closure_gap_finding(
    request.recognition_gap,
    evidence,
    "recognition gap",
  )
  let decisiveness = closure_gap_finding(
    request.decisiveness_gap,
    evidence,
    "decisiveness gap",
  )
  let assessment = @bookkeeper.ThreeGapAssessment::new(
    assessment_id=request.request.record_id + ".three-gap",
    assessment_version=request.request.record_version,
    subject_id=outcome_ref.record_id,
    subject_version=outcome_ref.record_version,
    owner_route=request.owner_route,
    information_gap=information,
    recognition_gap=recognition,
    decisiveness_gap=decisiveness,
  )
  let assessment_payload : Json = {
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "candidate_schema": "three_gap_assessment.v1",
    "request": request.request.to_json(),
    "subject": outcome_ref.to_json(),
    "assessment": assessment.to_json(),
    "evidence_refs": evidence.to_json(),
  }
  let assessment_ref = closure_reference(
    request.request,
    "three-gap",
    assessment_payload,
  )
  let assessment_record : DurableBookkeeperRecord = {
    contract_version: bookkeeper_store_contract_version(),
    record: assessment_ref,
    stage: ThreeGapFinding,
    subject: Some(outcome_ref),
    links: [outcome_ref],
    title: "Three-Gap outcome assessment",
    summary: request.capability_summary,
    owner_route: request.owner_route,
    status: "awaiting human review",
    evidence_refs: evidence,
    issue_refs: [],
    requires_human_review: true,
    next_action: "named-human assessment review",
    source_product: "moonbook",
    recorded_at: request.recorded_at,
    payload: assessment_payload,
    side_effects_applied: false,
  }
  closure_require_persisted(
    persist_bookkeeper_record(root, assessment_record),
    "Three-Gap assessment",
  )

  let assessed_snapshot = replay_bookkeeper_store(root)
  let assessment_review = product_outcome_exact_human_decision(
    assessed_snapshot,
    assessment_ref,
    ThreeGapFinding,
  )
  if assessment_review is None {
    return closure_receipt(
      request,
      outcome_ref,
      assessment_ref,
      None,
      None,
      None,
      None,
      "assessment_review_required",
      "three_gap_assessment",
    )
  }
  if assessment_review.unwrap().disposition == @bookkeeper.Reject {
    return closure_receipt(
      request,
      outcome_ref,
      assessment_ref,
      assessment_review,
      None,
      None,
      None,
      "assessment_rejected",
      "",
    )
  }

  let any_gap = information.present ||
    recognition.present ||
    decisiveness.present
  if !any_gap {
    return closure_receipt(
      request,
      outcome_ref,
      assessment_ref,
      assessment_review,
      None,
      None,
      None,
      "closed_no_capability_change",
      "",
    )
  }

  let proposal_payload = closure_proposal_payload(request, evidence)
  let proposal_ref = closure_reference(
    request.request,
    "capability-proposal",
    proposal_payload,
  )
  let proposal_record : DurableBookkeeperRecord = {
    contract_version: bookkeeper_store_contract_version(),
    record: proposal_ref,
    stage: CapabilityProposal,
    subject: Some(assessment_ref),
    links: [assessment_ref, assessment_review.unwrap().receipt],
    title: "Capability improvement proposal",
    summary: request.capability_summary,
    owner_route: request.owner_route,
    status: "awaiting human review",
    evidence_refs: evidence,
    issue_refs: [],
    requires_human_review: true,
    next_action: "named-human capability proposal review",
    source_product: "moonbook",
    recorded_at: request.recorded_at,
    payload: proposal_payload,
    side_effects_applied: false,
  }
  closure_require_persisted(
    persist_bookkeeper_record(root, proposal_record),
    "capability proposal",
  )
  let proposed_snapshot = replay_bookkeeper_store(root)
  let proposal_review = product_outcome_exact_human_decision(
    proposed_snapshot,
    proposal_ref,
    CapabilityProposal,
  )
  if proposal_review is None {
    return closure_receipt(
      request,
      outcome_ref,
      assessment_ref,
      assessment_review,
      Some(proposal_ref),
      None,
      None,
      "proposal_review_required",
      "capability_proposal",
    )
  }
  if proposal_review.unwrap().disposition == @bookkeeper.Reject {
    return closure_receipt(
      request,
      outcome_ref,
      assessment_ref,
      assessment_review,
      Some(proposal_ref),
      proposal_review,
      None,
      "proposal_rejected",
      "",
    )
  }

  let handoff_payload : Json = {
    "contract_version": "moonbook.bookkeeper.capability_handoff.v1",
    "request": request.request.to_json(),
    "proposal": proposal_ref.to_json(),
    "proposal_review": proposal_review.unwrap().receipt.to_json(),
    "outcome_binding": outcome_ref.to_json(),
    "three_gap_assessment": assessment_ref.to_json(),
    "activation_authorized": false,
    "required_next_gate": "moonflow_evaluation_and_separate_activation_review",
    "evidence_refs": evidence.to_json(),
  }
  let handoff_ref = closure_reference(
    request.request,
    "moonflow-handoff",
    handoff_payload,
  )
  let handoff : BookkeeperTransportEnvelope = {
    contract_version: bookkeeper_transport_contract_version(),
    envelope: handoff_ref,
    direction: Egress,
    source_product: "moonbook",
    destination_product: "moonflow",
    message_kind: "bookkeeper.capability-proposal.reviewed",
    subject: proposal_ref,
    links: [
      deliverable.record,
      result.envelope,
      deliverable_review.receipt,
      outcome_ref,
      assessment_ref,
      assessment_review.unwrap().receipt,
      proposal_review.unwrap().receipt,
    ],
    evidence_refs: evidence,
    authority_ref: proposal_review.unwrap().reviewer.authority_ref,
    recorded_at: request.recorded_at,
    payload: handoff_payload,
    external_activation_allowed: false,
    side_effects_applied: false,
  }
  closure_require_persisted(
    persist_transport_envelope(root, handoff),
    "MoonFlow capability handoff",
  )
  closure_receipt(
    request,
    outcome_ref,
    assessment_ref,
    assessment_review,
    Some(proposal_ref),
    proposal_review,
    Some(handoff_ref),
    "reviewed_proposal_handed_off",
    "moonflow_evaluation_and_activation_review",
  )
}
