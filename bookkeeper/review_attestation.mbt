///|
/// Explicit reviewer classification for authority attestations. Fast-loop
/// review and work-order projection accept `Human` only; the other kinds remain
/// representable for fail-closed audit decisions and cannot be mistaken for a
/// person from a string value.
pub(all) enum ReviewerKind {
  Human
  Automation
  Agent
  System
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Internal version for the immutable authority-attestation contract.
fn review_authority_attestation_contract_version() -> String {
  "moonbook.bookkeeper.review_authority_attestation.v1"
}

///|
/// Internal version for the immutable fast-loop review attestation contract.
fn finding_review_authority_attestation_contract_version() -> String {
  "moonbook.bookkeeper.finding_review_authority_attestation.v1"
}

///|
/// Opaque authority attestation for one exact fast-loop finding review. It is
/// bound to the finding, replay-safety keys, proposed receipt, reviewer,
/// evidence set, and requested disposition. Callers cannot construct or alter
/// its fields directly.
pub struct FindingReviewAuthorityAttestation {
  contract_version : String
  attestation : VersionedRecordReference
  finding : VersionedRecordReference
  learning_key : VersionedRecordReference
  subject : VersionedRecordReference
  learning_receipt : VersionedRecordReference
  reviewer_kind : ReviewerKind
  reviewer : ReviewerAuthority
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
  requested : BookkeeperDisposition
} derive(Debug, Eq, ToJson)

///|
/// Create an immutable authority statement over the exact values presented for
/// fast-loop review. Construction is non-applying; the review boundary accepts
/// it only after every binding is revalidated and the reviewer kind is human.
pub fn FindingReviewAuthorityAttestation::new(
  attestation~ : VersionedRecordReference,
  finding : CanonicalGapFinding,
  receipt~ : VersionedRecordReference,
  reviewer_kind~ : ReviewerKind,
  reviewer~ : ReviewerAuthority,
  evidence_refs~ : ArrayView[VersionedEvidenceReference],
  requested~ : BookkeeperDisposition,
) -> FindingReviewAuthorityAttestation {
  {
    contract_version: finding_review_authority_attestation_contract_version(),
    attestation,
    finding: finding.finding,
    learning_key: finding.learning_key,
    subject: finding.subject,
    learning_receipt: receipt,
    reviewer_kind,
    reviewer,
    evidence_refs: ReadOnlyArray::from_array(evidence_refs),
    requested,
  }
}

///|
/// Immutable, versioned request to project one exact work-order reference with
/// exact evidence. Construction records intent only and has no submission,
/// persistence, execution, or application behavior.
pub struct WorkOrderProjectionRequest {
  contract_version : String
  request : VersionedRecordReference
  work_order : VersionedRecordReference
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
} derive(Debug, Eq, ToJson)

///|
/// Construct a side-effect-free projection request. Validation remains at the
/// projection boundary so malformed or stale requests produce typed issues.
pub fn WorkOrderProjectionRequest::new(
  request~ : VersionedRecordReference,
  work_order~ : VersionedRecordReference,
  evidence_refs~ : ArrayView[VersionedEvidenceReference],
) -> WorkOrderProjectionRequest {
  {
    contract_version: review_authority_attestation_contract_version(),
    request,
    work_order,
    evidence_refs: ReadOnlyArray::from_array(evidence_refs),
  }
}

///|
/// Opaque authority attestation bound to one proposal, learning receipt,
/// reviewer authority, evidence set, and projection request. Callers cannot
/// construct or alter its fields directly; projection revalidates every binding.
pub struct ReviewAuthorityAttestation {
  contract_version : String
  attestation : VersionedRecordReference
  proposal : VersionedRecordReference
  learning_receipt : VersionedRecordReference
  reviewer_kind : ReviewerKind
  reviewer : ReviewerAuthority
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
  projection_request : VersionedRecordReference
  work_order : VersionedRecordReference
} derive(Debug, Eq, ToJson)

///|
/// Create an immutable authority statement over the exact values presented to
/// the reviewer. This emits no approval side effect: only projection can accept
/// the statement, and only after all fail-closed checks pass.
pub fn ReviewAuthorityAttestation::new(
  attestation~ : VersionedRecordReference,
  proposal : CapabilityProposal,
  review : LearningReceipt,
  reviewer_kind~ : ReviewerKind,
  reviewer~ : ReviewerAuthority,
  evidence_refs~ : ArrayView[VersionedEvidenceReference],
  projection_request~ : WorkOrderProjectionRequest,
) -> ReviewAuthorityAttestation {
  {
    contract_version: review_authority_attestation_contract_version(),
    attestation,
    proposal: {
      record_id: proposal.proposal_id,
      record_version: proposal.proposal_version,
      record_digest: proposal.change_digest,
    },
    learning_receipt: {
      record_id: review.receipt_id,
      record_version: review.receipt_version,
      record_digest: review.receipt_digest,
    },
    reviewer_kind,
    reviewer,
    evidence_refs: ReadOnlyArray::from_array(evidence_refs),
    projection_request: projection_request.request,
    work_order: projection_request.work_order,
  }
}

///|
fn versioned_evidence_refs_match(
  left : ReadOnlyArray[VersionedEvidenceReference],
  right : ReadOnlyArray[VersionedEvidenceReference],
) -> Bool {
  left.length() == right.length() &&
  left.all(fn(reference) { right.contains(reference) }) &&
  right.all(fn(reference) { left.contains(reference) })
}
