///|
/// Read one exact, currently-authorized named-human acceptance for a durable
/// deliverable subject. This query never manufactures or applies a review: it
/// returns the existing governed Bookkeeper receipt only after replay,
/// cardinality, receipt, evidence, and current-authority checks all pass.
pub async fn load_exact_governed_acceptance(
  root : String,
  subject : @bookkeeper.VersionedRecordReference,
) -> Result[GovernedReviewReceipt, String] {
  if !reference_complete(subject) {
    return Err("exact acceptance subject reference is incomplete")
  }
  let snapshot = replay_bookkeeper_store(root)
  if !snapshot.replay_issues.is_empty() {
    return Err(
      "Bookkeeper replay has issues: " + snapshot.replay_issues.join("; "),
    )
  }
  let durable_subject = match find_record(snapshot, subject) {
    Some(record) => record
    None => return Err("exact acceptance subject is not a durable record")
  }
  if durable_subject.stage != DeliverableAcceptance {
    return Err(
      "exact acceptance subject is not a deliverable acceptance record",
    )
  }
  let accepted : Array[GovernedReviewReceipt] = []
  for review in snapshot.reviews {
    if review.subject == subject &&
      review.stage == DeliverableAcceptance &&
      review.review_complete &&
      review.disposition == Accept &&
      review.reviewer_kind == Human {
      accepted.push(review)
    }
  }
  if accepted.is_empty() {
    return Err("exact subject has no named-human governed acceptance")
  }
  if accepted.length() != 1 {
    return Err("exact subject has ambiguous named-human governed acceptances")
  }
  let receipt = accepted[0]
  if !governed_acceptance_receipt_complete(durable_subject, receipt) {
    return Err("exact governed acceptance receipt is incomplete or unsafe")
  }
  if !reviewer_has_active_grant(root, governed_acceptance_mutation(receipt)) {
    return Err("exact governed acceptance reviewer authority is not current")
  }
  Ok(receipt)
}

///|
fn governed_acceptance_receipt_complete(
  subject : DurableBookkeeperRecord,
  receipt : GovernedReviewReceipt,
) -> Bool {
  receipt.contract_version == bookkeeper_store_contract_version() &&
  reference_complete(receipt.mutation) &&
  reference_complete(receipt.receipt) &&
  receipt.subject == subject.record &&
  receipt.stage == DeliverableAcceptance &&
  receipt.requested == Accept &&
  receipt.disposition == Accept &&
  receipt.reviewer_kind == Human &&
  reference_complete(receipt.reviewer.grant) &&
  !receipt.reviewer.reviewer_id.is_blank() &&
  !receipt.reviewer.authority_ref.is_blank() &&
  receipt.reviewer.authorized &&
  !receipt.reviewer.evidence_refs.is_empty() &&
  !receipt.evidence_refs.is_empty() &&
  receipt.evidence_refs.all(evidence_complete) &&
  review_subject_evidence_exact(subject, receipt.evidence_refs) &&
  receipt.issues.is_empty() &&
  receipt.review_complete &&
  !receipt.side_effects_applied
}

///|
/// Reuse the same installed-authority validation as review submission. The
/// conversion is lossless because a governed receipt persists every mutation
/// field checked by `reviewer_has_active_grant`.
fn governed_acceptance_mutation(
  receipt : GovernedReviewReceipt,
) -> GovernedReviewMutation {
  {
    contract_version: receipt.contract_version,
    mutation: receipt.mutation,
    receipt: receipt.receipt,
    stage: receipt.stage,
    subject: receipt.subject,
    requested: receipt.requested,
    reviewer_kind: receipt.reviewer_kind,
    reviewer: receipt.reviewer,
    evidence_refs: receipt.evidence_refs,
    summary: receipt.summary,
    decided_at: receipt.decided_at,
  }
}
