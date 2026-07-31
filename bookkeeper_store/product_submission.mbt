///|
/// A producing pack's generic, evidence-bound request to enter the existing
/// Bookkeeper outcome loop. External review evidence is evidence only: it
/// cannot replace MoonBook's own named-human acceptance gate.
pub fn product_outcome_submission_contract_version() -> String {
  "moonbook.bookkeeper.product_outcome_submission.v1"
}

///|
pub fn product_outcome_submission_receipt_contract_version() -> String {
  "moonbook.bookkeeper.product_outcome_submission_receipt.v1"
}

///|
pub(all) struct ProductOutcomeSubmission {
  contract_version : String
  submission : @bookkeeper.VersionedRecordReference
  source_product : String
  deliverable_title : String
  deliverable_summary : String
  outcome_summary : String
  owner_route : String
  evidence_refs : Array[@bookkeeper.VersionedEvidenceReference]
  decision_evidence_id : String
  observed_at : Int
  recorded_at : Int
  information_gap : ProductOutcomeGapStatement
  recognition_gap : ProductOutcomeGapStatement
  decisiveness_gap : ProductOutcomeGapStatement
  capability_id : String
  capability_version : String
  capability_change_digest : String
  capability_summary : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// The receipt is deliberately non-activating. Replaying the exact submission
/// after each MoonBook review advances the same durable closure chain.
pub(all) struct ProductOutcomeSubmissionReceipt {
  contract_version : String
  submission : @bookkeeper.VersionedRecordReference
  deliverable : @bookkeeper.VersionedRecordReference
  deliverable_review : @bookkeeper.VersionedRecordReference?
  result : @bookkeeper.VersionedRecordReference
  closure : ProductOutcomeClosureReceipt?
  state : String
  pending_human_gate : String
  activation_authorized : Bool
  external_side_effects_applied : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
fn submission_reference_complete(
  reference : @bookkeeper.VersionedRecordReference,
) -> Bool {
  !reference.record_id.is_blank() &&
  !reference.record_version.is_blank() &&
  !reference.record_digest.is_blank()
}

///|
fn submission_evidence_complete(
  reference : @bookkeeper.VersionedEvidenceReference,
) -> Bool {
  !reference.reference_id.is_blank() &&
  !reference.reference_version.is_blank() &&
  !reference.digest.is_blank() &&
  !reference.provenance_ref.is_blank()
}

///|
fn validate_product_outcome_submission(
  submission : ProductOutcomeSubmission,
) -> Unit raise {
  if submission.contract_version !=
    product_outcome_submission_contract_version() {
    fail("invalid product outcome submission contract")
  }
  if !submission_reference_complete(submission.submission) {
    fail("product outcome submission identity must be exact")
  }
  if submission.source_product.is_blank() ||
    submission.source_product == "moonbook" {
    fail("product outcome submission must name an external source product")
  }
  if submission.deliverable_title.is_blank() ||
    submission.deliverable_summary.is_blank() ||
    submission.outcome_summary.is_blank() ||
    submission.owner_route.is_blank() ||
    submission.decision_evidence_id.is_blank() ||
    submission.capability_id.is_blank() ||
    submission.capability_version.is_blank() ||
    submission.capability_change_digest.is_blank() ||
    submission.capability_summary.is_blank() {
    fail("product outcome submission metadata is incomplete")
  }
  if submission.observed_at < 0 ||
    submission.recorded_at < submission.observed_at {
    fail("product outcome submission timestamps are invalid")
  }
  if submission.evidence_refs.is_empty() ||
    !submission.evidence_refs.all(submission_evidence_complete) {
    fail("product outcome submission requires complete evidence")
  }
  let evidence_ids : Array[String] = []
  for evidence in submission.evidence_refs {
    if evidence_ids.contains(evidence.reference_id) {
      fail("product outcome submission evidence ids must be unique")
    }
    evidence_ids.push(evidence.reference_id)
  }
  if !evidence_ids.contains(submission.decision_evidence_id) {
    fail("decision evidence must be part of the exact submission evidence set")
  }
}

///|
fn submission_record_reference(
  submission : ProductOutcomeSubmission,
  suffix : String,
  payload : Json,
) -> @bookkeeper.VersionedRecordReference {
  {
    record_id: submission.submission.record_id + "." + suffix,
    record_version: submission.submission.record_version,
    record_digest: bookkeeper_payload_digest(payload),
  }
}

///|
fn submission_require_persisted(
  result : BookkeeperMutationResult,
  label : String,
) -> Unit raise {
  if !result.accepted {
    fail("\{label} rejected: \{result.issues.join("; ")}")
  }
}

///|
fn submission_exact_human_accept(
  snapshot : BookkeeperStoreSnapshot,
  subject : @bookkeeper.VersionedRecordReference,
) -> GovernedReviewReceipt? raise {
  let mut accepted : GovernedReviewReceipt? = None
  for review in snapshot.reviews {
    if review.subject == subject &&
      review.stage == DeliverableAcceptance &&
      review.review_complete &&
      review.disposition == @bookkeeper.Accept &&
      review.reviewer_kind == @bookkeeper.Human {
      match accepted {
        None => accepted = Some(review)
        Some(_) =>
          fail(
            "product outcome submission found ambiguous named-human Accept receipts",
          )
      }
    }
  }
  accepted
}

///|
fn product_submission_receipt(
  submission : ProductOutcomeSubmission,
  deliverable : @bookkeeper.VersionedRecordReference,
  review : GovernedReviewReceipt?,
  result : @bookkeeper.VersionedRecordReference,
  closure : ProductOutcomeClosureReceipt?,
  state : String,
  gate : String,
) -> ProductOutcomeSubmissionReceipt {
  {
    contract_version: product_outcome_submission_receipt_contract_version(),
    submission: submission.submission,
    deliverable,
    deliverable_review: review.map(item => item.receipt),
    result,
    closure,
    state,
    pending_human_gate: gate,
    activation_authorized: false,
    external_side_effects_applied: false,
  }
}

///|
/// Import a product outcome into the existing Bookkeeper store and advance it
/// only as far as already-recorded named-human decisions allow.
///
/// First execution creates a reviewable deliverable and a correlated
/// `product.result` ingress. A replay after MoonBook accepts the deliverable
/// delegates to `close_product_outcome`, which owns the deterministic
/// Three-Gap assessment and later proposal gates.
pub async fn submit_product_outcome(
  root : String,
  submission : ProductOutcomeSubmission,
) -> ProductOutcomeSubmissionReceipt {
  validate_product_outcome_submission(submission)
  let deliverable_payload : Json = {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "candidate_schema": "product_outcome_submission.v1",
    "submission": submission.submission.to_json(),
    "source_product": submission.source_product,
    "decision_evidence_id": submission.decision_evidence_id,
    "outcome_summary": submission.outcome_summary,
    "evidence_refs": submission.evidence_refs.to_json(),
  }
  let deliverable_ref = submission_record_reference(
    submission, "deliverable", deliverable_payload,
  )
  let deliverable : DurableBookkeeperRecord = {
    contract_version: bookkeeper_store_contract_version(),
    record: deliverable_ref,
    stage: DeliverableAcceptance,
    subject: None,
    links: [],
    title: submission.deliverable_title,
    summary: submission.deliverable_summary,
    owner_route: submission.owner_route,
    status: "awaiting human review",
    evidence_refs: submission.evidence_refs,
    issue_refs: [],
    requires_human_review: true,
    next_action: "review the exact deliverable in MoonBook",
    source_product: submission.source_product,
    recorded_at: submission.recorded_at,
    payload: deliverable_payload,
    side_effects_applied: false,
  }
  submission_require_persisted(
    persist_bookkeeper_record(root, deliverable),
    "product deliverable",
  )

  let result_payload : Json = {
    "contract_version": "moonsuite.product-result.v1",
    "submission": submission.submission.to_json(),
    "source_product": submission.source_product,
    "summary": submission.outcome_summary,
    "decision_evidence_id": submission.decision_evidence_id,
    "bookkeeper_acceptance_required": true,
    "external_activation_allowed": false,
  }
  let result_ref = submission_record_reference(
    submission, "result", result_payload,
  )
  let result : BookkeeperTransportEnvelope = {
    contract_version: bookkeeper_transport_contract_version(),
    envelope: result_ref,
    direction: Ingress,
    source_product: submission.source_product,
    destination_product: "moonbook",
    message_kind: "product.result",
    subject: deliverable_ref,
    links: [],
    evidence_refs: submission.evidence_refs,
    authority_ref: "review-evidence://" + submission.decision_evidence_id,
    recorded_at: submission.recorded_at,
    payload: result_payload,
    external_activation_allowed: false,
    side_effects_applied: false,
  }
  submission_require_persisted(
    persist_transport_envelope(root, result),
    "product result ingress",
  )

  let snapshot = replay_bookkeeper_store(root)
  let review = submission_exact_human_accept(snapshot, deliverable_ref)
  if review is None {
    return product_submission_receipt(
      submission,
      deliverable_ref,
      None,
      result_ref,
      None,
      "deliverable_review_required",
      "deliverable_acceptance",
    )
  }

  let closure_request : ProductOutcomeClosureRequest = {
    contract_version: product_outcome_closure_contract_version(),
    request: submission.submission,
    source_product: submission.source_product,
    deliverable: deliverable_ref,
    result: result_ref,
    deliverable_review: review.unwrap().receipt,
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
  let closure = close_product_outcome(root, closure_request)
  product_submission_receipt(
    submission,
    deliverable_ref,
    review,
    result_ref,
    Some(closure),
    closure.state,
    closure.pending_human_gate,
  )
}
