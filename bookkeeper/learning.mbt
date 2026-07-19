///|
/// Versioned capability change request. Construction always routes it to an
/// owner, requires review, links evidence, and forbids self-application.
pub struct CapabilityProposal {
  contract_version : String
  proposal_id : String
  proposal_version : String
  capability_id : String
  capability_version : String
  owner_route : String
  change_digest : String
  summary : String
  evidence_refs : ReadOnlyArray[EvidenceReference]
  supersedes_version : String?
  source_finding_refs : ReadOnlyArray[VersionedRecordReference]
  promotion_policy_ref : VersionedRecordReference?
  aggregation_digest : String?
  policy_promoted : Bool
  review_required : Bool
  self_application_allowed : Bool
} derive(Debug, Eq, ToJson)

///|
/// Construct a reviewable proposal. This records a request only; it has no API
/// that mutates the capability it describes.
pub fn CapabilityProposal::new(
  proposal_id~ : String,
  proposal_version~ : String,
  capability_id~ : String,
  capability_version~ : String,
  owner_route~ : String,
  change_digest~ : String,
  summary~ : String,
  evidence_refs~ : ArrayView[EvidenceReference],
  supersedes_version? : String,
) -> CapabilityProposal {
  {
    contract_version: bookkeeper_contract_version(),
    proposal_id,
    proposal_version,
    capability_id,
    capability_version,
    owner_route,
    change_digest,
    summary,
    evidence_refs: ReadOnlyArray::from_array(evidence_refs),
    supersedes_version,
    source_finding_refs: ReadOnlyArray::default(),
    promotion_policy_ref: None,
    aggregation_digest: None,
    policy_promoted: false,
    review_required: true,
    self_application_allowed: false,
  }
}

///|
/// Whether the proposal has the minimum version, owner, and evidence bindings
/// required to enter review.
pub fn CapabilityProposal::is_reviewable(self : CapabilityProposal) -> Bool {
  self.contract_version == bookkeeper_contract_version() &&
  !self.proposal_id.is_blank() &&
  !self.proposal_version.is_blank() &&
  !self.capability_id.is_blank() &&
  !self.capability_version.is_blank() &&
  !self.owner_route.is_blank() &&
  !self.change_digest.is_blank() &&
  !self.evidence_refs.is_empty() &&
  self.review_required &&
  !self.self_application_allowed
}

///|
/// True only for a canonical slow-loop proposal produced after explicit policy
/// thresholds were met. Manually constructed BK-1 proposals remain reviewable,
/// but cannot be projected into a work order.
pub fn CapabilityProposal::is_policy_promoted(
  self : CapabilityProposal,
) -> Bool {
  self.policy_promoted &&
  !self.source_finding_refs.is_empty() &&
  self.promotion_policy_ref is Some(_) &&
  self.aggregation_digest is Some(_)
}

///|
/// Reconstruct the canonical policy-promoted value from an already durable,
/// exact Bookkeeper record. This is intentionally stricter than the legacy
/// proposal constructor: malformed promotion bindings fail before a work-order
/// projection can be attempted, and the returned value still cannot apply or
/// execute a capability change.
pub fn reconstruct_policy_promoted_capability_proposal(
  proposal_id~ : String,
  proposal_version~ : String,
  capability_id~ : String,
  capability_version~ : String,
  owner_route~ : String,
  change_digest~ : String,
  summary~ : String,
  evidence_refs~ : ArrayView[EvidenceReference],
  source_finding_refs~ : ArrayView[VersionedRecordReference],
  promotion_policy_ref~ : VersionedRecordReference,
  aggregation_digest~ : String,
  supersedes_version? : String,
) -> Result[CapabilityProposal, String] {
  let reference_complete = fn(reference : VersionedRecordReference) {
    !reference.record_id.is_blank() &&
    !reference.record_version.is_blank() &&
    !reference.record_digest.is_blank()
  }
  if proposal_id.is_blank() ||
    proposal_version.is_blank() ||
    capability_id.is_blank() ||
    capability_version.is_blank() ||
    owner_route.is_blank() ||
    change_digest.is_blank() ||
    summary.is_blank() {
    return Err("policy-promoted proposal identity and summary are required")
  }
  if evidence_refs.is_empty() || !evidence_refs.all(evidence_reference_complete) {
    return Err("policy-promoted proposal requires complete exact evidence")
  }
  if source_finding_refs.length() < 2 ||
    !source_finding_refs.all(reference_complete) {
    return Err(
      "policy-promoted proposal requires at least two exact source findings",
    )
  }
  if !reference_complete(promotion_policy_ref) {
    return Err("policy-promoted proposal requires an exact promotion policy")
  }
  if aggregation_digest.is_blank() || aggregation_digest != change_digest {
    return Err(
      "policy-promoted proposal aggregation digest must equal its change digest",
    )
  }
  Ok({
    contract_version: bookkeeper_contract_version(),
    proposal_id,
    proposal_version,
    capability_id,
    capability_version,
    owner_route,
    change_digest,
    summary,
    evidence_refs: ReadOnlyArray::from_array(evidence_refs),
    supersedes_version,
    source_finding_refs: ReadOnlyArray::from_array(source_finding_refs),
    promotion_policy_ref: Some(promotion_policy_ref),
    aggregation_digest: Some(aggregation_digest),
    policy_promoted: true,
    review_required: true,
    self_application_allowed: false,
  })
}

///|
/// Versioned review receipt for a capability proposal. Even an accepted review
/// is not an application receipt and never silently modifies capability state.
pub struct LearningReceipt {
  contract_version : String
  receipt_id : String
  receipt_version : String
  receipt_digest : String
  proposal_id : String
  proposal_version : String
  capability_id : String
  capability_version : String
  owner_route : String
  reviewer : ReviewerAuthority
  requested : BookkeeperDisposition
  disposition : BookkeeperDisposition
  evidence_refs : ReadOnlyArray[EvidenceReference]
  review_complete : Bool
  self_modification_applied : Bool
} derive(Debug, Eq, ToJson)

///|
fn evidence_reference_complete(reference : EvidenceReference) -> Bool {
  !reference.reference_id.is_blank() &&
  !reference.digest.is_blank() &&
  !reference.provenance_ref.is_blank()
}

///|
fn evidence_reference_matches(
  left : EvidenceReference,
  right : EvidenceReference,
) -> Bool {
  left.reference_id == right.reference_id &&
  left.digest == right.digest &&
  left.provenance_ref == right.provenance_ref
}

///|
/// Review a capability proposal without applying it. Invalid or unauthorized
/// accept requests fail closed to `Revise`; all receipts keep application false.
pub fn review_capability_proposal(
  proposal : CapabilityProposal,
  receipt_id~ : String,
  receipt_version~ : String,
  receipt_digest? : String = "",
  reviewer~ : ReviewerAuthority,
  requested~ : BookkeeperDisposition,
  evidence_refs~ : ArrayView[EvidenceReference],
) -> LearningReceipt {
  let review_evidence = ReadOnlyArray::from_array(evidence_refs)
  let proposal_evidence_exact = proposal.evidence_refs.all(fn(reference) {
    evidence_reference_complete(reference) &&
    review_evidence.any(fn(review_reference) {
      evidence_reference_matches(reference, review_reference)
    })
  })
  let review_evidence_exact = review_evidence.all(fn(reference) {
    evidence_reference_complete(reference) &&
    proposal.evidence_refs.any(fn(proposal_reference) {
      evidence_reference_matches(reference, proposal_reference)
    })
  })
  let reviewer_evidence_exact = reviewer.evidence_refs.all(fn(reference_id) {
    review_evidence.any(fn(reference) { reference.reference_id == reference_id })
  })
  let review_ready = proposal.is_reviewable() &&
    !receipt_id.is_blank() &&
    !receipt_version.is_blank() &&
    !reviewer.reviewer_id.is_blank() &&
    !reviewer.authority_ref.is_blank() &&
    reviewer.authorized &&
    !reviewer.evidence_refs.is_empty() &&
    !review_evidence.is_empty() &&
    proposal_evidence_exact &&
    review_evidence_exact &&
    reviewer_evidence_exact
  let disposition = if requested == Accept && !review_ready {
    Revise
  } else {
    requested
  }
  {
    contract_version: bookkeeper_contract_version(),
    receipt_id,
    receipt_version,
    receipt_digest,
    proposal_id: proposal.proposal_id,
    proposal_version: proposal.proposal_version,
    capability_id: proposal.capability_id,
    capability_version: proposal.capability_version,
    owner_route: proposal.owner_route,
    reviewer,
    requested,
    disposition,
    evidence_refs: review_evidence,
    review_complete: review_ready,
    self_modification_applied: false,
  }
}

///|
/// Learning receipts never authorize silent self-modification.
pub fn LearningReceipt::permits_self_modification(
  self : LearningReceipt,
) -> Bool {
  self.self_modification_applied
}
