///|
/// Canonical Three-Gap classification.
pub(all) enum ThreeGapClass {
  InformationGap
  RecognitionGap
  DecisivenessGap
} derive(Debug, Eq, ToJson)

///|
/// The semantic transition represented by each gap class.
pub(all) enum GapTransition {
  UnknownToKnown
  KnownToMatters
  MattersToAct
} derive(Debug, Eq, ToJson)

///|
pub fn ThreeGapClass::transition(self : ThreeGapClass) -> GapTransition {
  match self {
    InformationGap => UnknownToKnown
    RecognitionGap => KnownToMatters
    DecisivenessGap => MattersToAct
  }
}

///|
/// Stable, typed finding submitted to the fast loop. It is only promoted to a
/// reviewed finding by `review_three_gap_finding` after fail-closed validation.
pub struct CanonicalGapFinding {
  contract_version : String
  finding : VersionedRecordReference
  learning_key : VersionedRecordReference
  subject : VersionedRecordReference
  gap_class : ThreeGapClass
  transition : GapTransition
  severity : Int
  owner_route : String
  summary : String
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
} derive(Debug, Eq, ToJson)

///|
pub fn CanonicalGapFinding::new(
  finding~ : VersionedRecordReference,
  learning_key~ : VersionedRecordReference,
  subject~ : VersionedRecordReference,
  gap_class~ : ThreeGapClass,
  severity~ : Int,
  owner_route~ : String,
  summary~ : String,
  evidence_refs~ : ArrayView[VersionedEvidenceReference],
) -> CanonicalGapFinding {
  {
    contract_version: three_gap_contract_version(),
    finding,
    learning_key,
    subject,
    gap_class,
    transition: gap_class.transition(),
    severity,
    owner_route,
    summary,
    evidence_refs: ReadOnlyArray::from_array(evidence_refs),
  }
}

///|
/// Immediate human review receipt for one fast-loop finding. The four applied
/// flags are invariants, not permissions, and are always false.
pub struct CanonicalLearningReceipt {
  contract_version : String
  receipt : VersionedRecordReference
  finding : VersionedRecordReference
  learning_key : VersionedRecordReference
  gap_class : ThreeGapClass
  transition : GapTransition
  owner_route : String
  reviewer : ReviewerAuthority
  requested : BookkeeperDisposition
  disposition : BookkeeperDisposition
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
  review_complete : Bool
  source_change_applied : Bool
  policy_change_applied : Bool
  skill_change_applied : Bool
  capability_change_applied : Bool
} derive(Debug, Eq, ToJson)

///|
/// Canonical reviewed finding. There is no public constructor, so slow-loop
/// callers can only obtain it together with its exact human review receipt.
pub struct ReviewedGapFinding {
  finding : CanonicalGapFinding
  receipt : CanonicalLearningReceipt
} derive(Debug, Eq, ToJson)

///|
pub struct GapFindingReviewDecision {
  contract_version : String
  issues : ReadOnlyArray[LearningProtocolIssue]
  receipt : CanonicalLearningReceipt
  reviewed_finding : ReviewedGapFinding?
} derive(Debug, Eq, ToJson)

///|
pub fn GapFindingReviewDecision::is_reviewed(
  self : GapFindingReviewDecision,
) -> Bool {
  self.issues.is_empty() && self.reviewed_finding is Some(_)
}

///|
/// Receipts are auditable records only and never carry any mutation side effect.
pub fn CanonicalLearningReceipt::has_side_effects(
  self : CanonicalLearningReceipt,
) -> Bool {
  self.source_change_applied ||
  self.policy_change_applied ||
  self.skill_change_applied ||
  self.capability_change_applied
}

///|
fn validate_basic_learning_evidence(
  refs : ReadOnlyArray[VersionedEvidenceReference],
  label : String,
  issues : Array[LearningProtocolIssue],
) -> Unit {
  if refs.is_empty() {
    issues.push(MissingLearningReference("\{label} evidence"))
  }
  for reference in refs {
    append_learning_missing(issues, reference.reference_id, "evidence id")
    append_learning_missing(
      issues,
      reference.reference_version,
      "evidence version",
    )
    append_learning_missing(issues, reference.digest, "evidence digest")
    append_learning_missing(
      issues,
      reference.provenance_ref,
      "evidence provenance",
    )
  }
}

///|
fn reviewer_evidence_matches(
  reviewer : ReviewerAuthority,
  evidence : ReadOnlyArray[VersionedEvidenceReference],
) -> Bool {
  !reviewer.evidence_refs.is_empty() &&
  reviewer.evidence_refs.all(fn(id) {
    evidence.any(fn(reference) { reference.reference_id == id })
  })
}

///|
fn reviewer_is_authorized_for_finding(
  reviewer : ReviewerAuthority,
  evidence : ReadOnlyArray[VersionedEvidenceReference],
) -> Bool {
  !reviewer.reviewer_id.is_blank() &&
  !reviewer.authority_ref.is_blank() &&
  reviewer.authorized &&
  reviewer_evidence_matches(reviewer, evidence)
}

///|
fn validate_finding_review_attestation(
  finding : CanonicalGapFinding,
  receipt : VersionedRecordReference,
  reviewer : ReviewerAuthority,
  requested : BookkeeperDisposition,
  attestation : FindingReviewAuthorityAttestation?,
  issues : Array[LearningProtocolIssue],
) -> Unit {
  match attestation {
    None => issues.push(ReviewAttestationMissing)
    Some(authority) => {
      if authority.contract_version !=
        finding_review_authority_attestation_contract_version() {
        issues.push(InvalidProtocolContract(authority.contract_version))
      }
      validate_record_reference(
        authority.attestation,
        "finding review authority attestation",
        issues,
      )
      if authority.finding != finding.finding {
        issues.push(ReviewAttestationMismatch("finding"))
      }
      if authority.learning_key != finding.learning_key {
        issues.push(ReviewAttestationMismatch("learning key"))
      }
      if authority.subject != finding.subject {
        issues.push(ReviewAttestationMismatch("finding subject"))
      }
      if authority.learning_receipt != receipt {
        issues.push(ReviewAttestationMismatch("learning receipt"))
      }
      if authority.reviewer_kind != Human {
        issues.push(NonHumanReviewAttestation(authority.reviewer_kind))
      }
      if !reviewer_is_authorized_for_finding(
          authority.reviewer,
          finding.evidence_refs,
        ) {
        issues.push(UnauthorizedLearningReview)
      }
      if authority.reviewer != reviewer {
        issues.push(ReviewAttestationMismatch("reviewer authority"))
      }
      if !versioned_evidence_refs_match(
          authority.evidence_refs,
          finding.evidence_refs,
        ) {
        issues.push(ReviewAttestationMismatch("evidence"))
      }
      if authority.requested != requested {
        issues.push(ReviewAttestationMismatch("requested disposition"))
      }
    }
  }
}

///|
/// Classify and immediately review a finding. Invalid accept attempts fail to
/// `Revise`; a receipt is still returned for the attempted review, but no opaque
/// reviewed finding is emitted. Review requires an exact authority attestation
/// from a named, authorized human; missing or stale attestations fail closed.
pub fn review_three_gap_finding(
  finding : CanonicalGapFinding,
  receipt~ : VersionedRecordReference,
  reviewer~ : ReviewerAuthority,
  requested~ : BookkeeperDisposition,
  attestation : FindingReviewAuthorityAttestation?,
) -> GapFindingReviewDecision {
  let issues : Array[LearningProtocolIssue] = []
  if finding.contract_version != three_gap_contract_version() {
    issues.push(InvalidProtocolContract(finding.contract_version))
  }
  validate_record_reference(finding.finding, "finding", issues)
  validate_record_reference(finding.learning_key, "learning key", issues)
  validate_record_reference(finding.subject, "finding subject", issues)
  validate_record_reference(receipt, "learning receipt", issues)
  append_learning_missing(issues, finding.owner_route, "finding owner route")
  append_learning_missing(issues, finding.summary, "finding summary")
  if finding.severity < 1 || finding.severity > 5 {
    issues.push(InvalidSeverity(finding.severity))
  }
  if finding.transition != finding.gap_class.transition() {
    issues.push(ExactLinkMismatch("gap transition"))
  }
  validate_basic_learning_evidence(finding.evidence_refs, "finding", issues)
  if !reviewer_is_authorized_for_finding(reviewer, finding.evidence_refs) {
    issues.push(UnauthorizedLearningReview)
  }
  validate_finding_review_attestation(
    finding, receipt, reviewer, requested, attestation, issues,
  )
  let review_complete = issues.is_empty()
  let disposition = if requested == Accept && !review_complete {
    Revise
  } else {
    requested
  }
  let learning_receipt : CanonicalLearningReceipt = {
    contract_version: three_gap_contract_version(),
    receipt,
    finding: finding.finding,
    learning_key: finding.learning_key,
    gap_class: finding.gap_class,
    transition: finding.transition,
    owner_route: finding.owner_route,
    reviewer,
    requested,
    disposition,
    evidence_refs: finding.evidence_refs,
    review_complete,
    source_change_applied: false,
    policy_change_applied: false,
    skill_change_applied: false,
    capability_change_applied: false,
  }
  let reviewed_finding = if review_complete {
    Some({ finding, receipt: learning_receipt })
  } else {
    None
  }
  {
    contract_version: three_gap_contract_version(),
    issues: ReadOnlyArray::from_array(issues),
    receipt: learning_receipt,
    reviewed_finding,
  }
}

///|
/// Explicit slow-loop promotion policy. At least two independent reviewed
/// findings are always required, even if a caller supplies a lower threshold.
pub struct CapabilityPromotionPolicy {
  contract_version : String
  policy : VersionedRecordReference
  minimum_reviewed_findings : Int
  minimum_severity : Int
  required_gap_classes : ReadOnlyArray[ThreeGapClass]
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
} derive(Debug, Eq, ToJson)

///|
pub fn CapabilityPromotionPolicy::new(
  policy~ : VersionedRecordReference,
  minimum_reviewed_findings~ : Int,
  minimum_severity~ : Int,
  required_gap_classes~ : ArrayView[ThreeGapClass],
  evidence_refs~ : ArrayView[VersionedEvidenceReference],
) -> CapabilityPromotionPolicy {
  {
    contract_version: three_gap_contract_version(),
    policy,
    minimum_reviewed_findings,
    minimum_severity,
    required_gap_classes: ReadOnlyArray::from_array(required_gap_classes),
    evidence_refs: ReadOnlyArray::from_array(evidence_refs),
  }
}

///|
/// Deterministic aggregation result. Reasons are explicit whenever no proposal
/// is produced.
pub struct CapabilityAggregationDecision {
  contract_version : String
  policy : VersionedRecordReference
  learning_key : VersionedRecordReference?
  source_finding_refs : ReadOnlyArray[VersionedRecordReference]
  non_promotion_reasons : ReadOnlyArray[LearningProtocolIssue]
  proposal : CapabilityProposal?
} derive(Debug, Eq, ToJson)

///|
pub fn CapabilityAggregationDecision::is_promoted(
  self : CapabilityAggregationDecision,
) -> Bool {
  self.non_promotion_reasons.is_empty() && self.proposal is Some(_)
}

///|
fn reviewed_finding_compare(
  left : ReviewedGapFinding,
  right : ReviewedGapFinding,
) -> Int {
  let by_id = left.finding.finding.record_id.compare(
    right.finding.finding.record_id,
  )
  if by_id != 0 {
    return by_id
  }
  let by_version = left.finding.finding.record_version.compare(
    right.finding.finding.record_version,
  )
  if by_version != 0 {
    return by_version
  }
  left.finding.finding.record_digest.compare(
    right.finding.finding.record_digest,
  )
}

///|
fn evidence_compare(
  left : VersionedEvidenceReference,
  right : VersionedEvidenceReference,
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
fn canonicalize_learning_evidence(
  evidence : ArrayView[VersionedEvidenceReference],
  label : String,
  issues : Array[LearningProtocolIssue],
) -> Array[VersionedEvidenceReference] {
  let sorted : Array[VersionedEvidenceReference] = []
  for reference in evidence {
    sorted.push(reference)
  }
  sorted.sort_by(evidence_compare)
  let unique : Array[VersionedEvidenceReference] = []
  for reference in sorted {
    match unique.last() {
      Some(previous) if previous.reference_id == reference.reference_id &&
        previous.reference_version == reference.reference_version =>
        if previous != reference {
          issues.push(
            ConflictingRecordIdentity(
              "\{label} evidence:\{reference.reference_id}",
            ),
          )
        }
      _ => unique.push(reference)
    }
  }
  unique
}

///|
fn canonical_evidence_to_legacy(
  evidence : Array[VersionedEvidenceReference],
) -> ReadOnlyArray[EvidenceReference] {
  evidence.sort_by(evidence_compare)
  let unique : Array[EvidenceReference] = []
  let seen : Array[VersionedEvidenceReference] = []
  for reference in evidence {
    if !seen.contains(reference) {
      seen.push(reference)
      unique.push({
        reference_id: reference.reference_id,
        digest: reference.digest,
        provenance_ref: reference.provenance_ref,
      })
    }
  }
  ReadOnlyArray::from_array(unique)
}

///|
/// Deterministically aggregate repeated reviewed findings. Input order and exact
/// replays do not change the result. Identity/version conflicts fail closed.
pub fn aggregate_capability_proposal(
  policy : CapabilityPromotionPolicy,
  findings : ArrayView[ReviewedGapFinding],
  proposal_id~ : String,
  proposal_version~ : String,
  capability_id~ : String,
  capability_version~ : String,
  owner_route~ : String,
  proposal_digest~ : String,
  summary~ : String,
  supersedes_version? : String,
) -> CapabilityAggregationDecision {
  let reasons : Array[LearningProtocolIssue] = []
  if policy.contract_version != three_gap_contract_version() {
    reasons.push(InvalidProtocolContract(policy.contract_version))
  }
  validate_record_reference(policy.policy, "promotion policy", reasons)
  validate_basic_learning_evidence(
    policy.evidence_refs,
    "promotion policy",
    reasons,
  )
  if policy.minimum_reviewed_findings < 2 {
    reasons.push(InvalidPromotionPolicy("minimum reviewed findings"))
  }
  if policy.minimum_severity < 1 || policy.minimum_severity > 5 {
    reasons.push(InvalidPromotionPolicy("minimum severity"))
  }
  for
    item in [
      ("proposal id", proposal_id),
      ("proposal version", proposal_version),
      ("capability id", capability_id),
      ("capability version", capability_version),
      ("owner route", owner_route),
      ("proposal digest", proposal_digest),
      ("proposal summary", summary),
    ] {
    let (label, value) = item
    append_learning_missing(reasons, value, label)
  }
  let sorted : Array[ReviewedGapFinding] = []
  for finding in findings {
    sorted.push(finding)
  }
  sorted.sort_by(reviewed_finding_compare)
  let unique : Array[ReviewedGapFinding] = []
  for reviewed in sorted {
    match unique.last() {
      Some(previous) if previous.finding.finding.record_id ==
        reviewed.finding.finding.record_id &&
        previous.finding.finding.record_version ==
        reviewed.finding.finding.record_version =>
        if previous != reviewed {
          reasons.push(
            ConflictingRecordIdentity(reviewed.finding.finding.record_id),
          )
        }
      _ => unique.push(reviewed)
    }
  }
  let learning_key = if unique.is_empty() {
    None
  } else {
    Some(unique[0].finding.learning_key)
  }
  let eligible : Array[ReviewedGapFinding] = []
  let mut maximum_severity = 0
  for reviewed in unique {
    let finding = reviewed.finding
    let receipt = reviewed.receipt
    if finding.severity > maximum_severity {
      maximum_severity = finding.severity
    }
    if receipt.finding != finding.finding ||
      receipt.learning_key != finding.learning_key ||
      receipt.gap_class != finding.gap_class ||
      receipt.transition != finding.transition ||
      receipt.owner_route != finding.owner_route {
      reasons.push(LearningReceiptMismatch(finding.finding.record_id))
    }
    match learning_key {
      Some(expected) if finding.learning_key != expected =>
        reasons.push(ExactLinkMismatch("learning key"))
      _ => ()
    }
    if finding.owner_route != owner_route {
      reasons.push(ExactLinkMismatch("finding owner route"))
    }
    if receipt.review_complete &&
      receipt.disposition == Accept &&
      finding.severity >= policy.minimum_severity {
      eligible.push(reviewed)
    }
  }
  if eligible.length() < policy.minimum_reviewed_findings {
    reasons.push(
      InsufficientReviewedFindings(
        policy.minimum_reviewed_findings,
        eligible.length(),
      ),
    )
  }
  if maximum_severity < policy.minimum_severity {
    reasons.push(
      InsufficientSeverity(policy.minimum_severity, maximum_severity),
    )
  }
  for required in policy.required_gap_classes {
    if !eligible.any(fn(reviewed) { reviewed.finding.gap_class == required }) {
      reasons.push(MissingRequiredGapClass(required))
    }
  }
  let source_finding_refs : Array[VersionedRecordReference] = []
  let canonical_evidence : Array[VersionedEvidenceReference] = []
  for reviewed in eligible {
    source_finding_refs.push(reviewed.finding.finding)
    for evidence in reviewed.finding.evidence_refs {
      canonical_evidence.push(evidence)
    }
  }
  for evidence in policy.evidence_refs {
    canonical_evidence.push(evidence)
  }
  let stable_evidence = canonicalize_learning_evidence(
    canonical_evidence, "proposal", reasons,
  )
  let proposal = if reasons.is_empty() {
    Some({
      contract_version: bookkeeper_contract_version(),
      proposal_id,
      proposal_version,
      capability_id,
      capability_version,
      owner_route,
      change_digest: proposal_digest,
      summary,
      evidence_refs: canonical_evidence_to_legacy(stable_evidence),
      supersedes_version,
      source_finding_refs: ReadOnlyArray::from_array(source_finding_refs),
      promotion_policy_ref: Some(policy.policy),
      aggregation_digest: Some(proposal_digest),
      policy_promoted: true,
      review_required: true,
      self_application_allowed: false,
    })
  } else {
    None
  }
  {
    contract_version: three_gap_contract_version(),
    policy: policy.policy,
    learning_key,
    source_finding_refs: ReadOnlyArray::from_array(source_finding_refs),
    non_promotion_reasons: ReadOnlyArray::from_array(reasons),
    proposal,
  }
}

///|
/// Generic MoonCode-ready projection. It is a review-bound value and exposes no
/// execution, persistence, application, or mutation operation.
pub struct MoonCodeWorkOrderProjection {
  contract_version : String
  projection_request : VersionedRecordReference
  work_order : VersionedRecordReference
  proposal : VersionedRecordReference
  capability : VersionedRecordReference
  promotion_policy : VersionedRecordReference
  owner_route : String
  summary : String
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
  reviewer_kind : ReviewerKind
  reviewer_id : String
  reviewer_authority_ref : String
  review_receipt : VersionedRecordReference
  review_attestation : VersionedRecordReference
  side_effects_applied : Bool
} derive(Debug, Eq, ToJson)

///|
pub struct WorkOrderProjectionDecision {
  contract_version : String
  issues : ReadOnlyArray[LearningProtocolIssue]
  work_order : MoonCodeWorkOrderProjection?
} derive(Debug, Eq, ToJson)

///|
pub fn WorkOrderProjectionDecision::is_ready(
  self : WorkOrderProjectionDecision,
) -> Bool {
  self.issues.is_empty() && self.work_order is Some(_)
}

///|
/// Project a policy-promoted proposal after an exact, versioned authority
/// attestation from a named, authorized human. Missing, stale, mismatched,
/// unnamed, unauthorized, and non-human attestations fail closed. This only
/// creates a work-order value; it does not submit, persist, execute, or apply it.
pub fn project_mooncode_work_order(
  proposal : CapabilityProposal,
  review : LearningReceipt,
  request : WorkOrderProjectionRequest,
  attestation : ReviewAuthorityAttestation?,
) -> WorkOrderProjectionDecision {
  let issues : Array[LearningProtocolIssue] = []
  if request.contract_version != review_authority_attestation_contract_version() {
    issues.push(InvalidProtocolContract(request.contract_version))
  }
  validate_record_reference(
    request.request,
    "work order projection request",
    issues,
  )
  validate_record_reference(request.work_order, "work order", issues)
  if !proposal.is_policy_promoted() {
    issues.push(WorkOrderProjectionDenied("proposal was not policy promoted"))
  }
  if review.proposal_id != proposal.proposal_id ||
    review.proposal_version != proposal.proposal_version ||
    review.capability_id != proposal.capability_id ||
    review.capability_version != proposal.capability_version ||
    review.owner_route != proposal.owner_route {
    issues.push(LearningReceiptMismatch(review.receipt_id))
  }
  if review.receipt_id.is_blank() ||
    review.receipt_version.is_blank() ||
    review.receipt_digest.is_blank() {
    issues.push(MissingLearningReference("capability review receipt binding"))
  }
  if !review.review_complete ||
    review.disposition != Accept ||
    review.reviewer.reviewer_id.is_blank() ||
    review.reviewer.authority_ref.is_blank() ||
    !review.reviewer.authorized {
    issues.push(UnauthorizedLearningReview)
  }
  let stable_evidence = canonicalize_learning_evidence(
    request.evidence_refs,
    "work order",
    issues,
  )
  let canonical_evidence = ReadOnlyArray::from_array(stable_evidence)
  validate_basic_learning_evidence(canonical_evidence, "work order", issues)
  for evidence in canonical_evidence {
    if !proposal.evidence_refs.any(fn(reference) {
        reference.reference_id == evidence.reference_id &&
        reference.digest == evidence.digest &&
        reference.provenance_ref == evidence.provenance_ref
      }) {
      issues.push(
        ExactLinkMismatch("work order evidence:\{evidence.reference_id}"),
      )
    }
  }
  for review_evidence in review.evidence_refs {
    if !canonical_evidence.any(fn(reference) {
        reference.reference_id == review_evidence.reference_id &&
        reference.digest == review_evidence.digest &&
        reference.provenance_ref == review_evidence.provenance_ref
      }) {
      issues.push(
        ExactLinkMismatch(
          "capability review evidence:\{review_evidence.reference_id}",
        ),
      )
    }
  }
  for reviewer_evidence in review.reviewer.evidence_refs {
    if !canonical_evidence.any(fn(reference) {
        reference.reference_id == reviewer_evidence
      }) {
      issues.push(ExactLinkMismatch("reviewer evidence:\{reviewer_evidence}"))
    }
  }
  match attestation {
    None => issues.push(ReviewAttestationMissing)
    Some(authority) => {
      if authority.contract_version !=
        review_authority_attestation_contract_version() {
        issues.push(InvalidProtocolContract(authority.contract_version))
      }
      validate_record_reference(
        authority.attestation,
        "review authority attestation",
        issues,
      )
      let expected_proposal : VersionedRecordReference = {
        record_id: proposal.proposal_id,
        record_version: proposal.proposal_version,
        record_digest: proposal.change_digest,
      }
      if authority.proposal != expected_proposal {
        issues.push(ReviewAttestationMismatch("capability proposal"))
      }
      let expected_receipt : VersionedRecordReference = {
        record_id: review.receipt_id,
        record_version: review.receipt_version,
        record_digest: review.receipt_digest,
      }
      if authority.learning_receipt != expected_receipt {
        issues.push(ReviewAttestationMismatch("learning receipt"))
      }
      if authority.projection_request != request.request ||
        authority.work_order != request.work_order {
        issues.push(ReviewAttestationMismatch("work order projection request"))
      }
      if authority.reviewer_kind != Human {
        issues.push(NonHumanReviewAttestation(authority.reviewer_kind))
      }
      if authority.reviewer.reviewer_id.is_blank() ||
        authority.reviewer.authority_ref.is_blank() ||
        !authority.reviewer.authorized {
        issues.push(UnauthorizedLearningReview)
      }
      if authority.reviewer != review.reviewer {
        issues.push(ReviewAttestationMismatch("reviewer authority"))
      }
      let stable_attestation_evidence = canonicalize_learning_evidence(
        authority.evidence_refs,
        "review authority attestation",
        issues,
      )
      let canonical_attestation_evidence = ReadOnlyArray::from_array(
        stable_attestation_evidence,
      )
      validate_basic_learning_evidence(
        canonical_attestation_evidence, "review authority attestation", issues,
      )
      if !versioned_evidence_refs_match(
          canonical_attestation_evidence, canonical_evidence,
        ) {
        issues.push(ReviewAttestationMismatch("evidence"))
      }
    }
  }
  let projection = match attestation {
    Some(authority) if issues.is_empty() => {
      let policy = proposal.promotion_policy_ref.unwrap()
      Some({
        contract_version: three_gap_contract_version(),
        projection_request: request.request,
        work_order: request.work_order,
        proposal: {
          record_id: proposal.proposal_id,
          record_version: proposal.proposal_version,
          record_digest: proposal.change_digest,
        },
        capability: {
          record_id: proposal.capability_id,
          record_version: proposal.capability_version,
          record_digest: proposal.change_digest,
        },
        promotion_policy: policy,
        owner_route: proposal.owner_route,
        summary: proposal.summary,
        evidence_refs: canonical_evidence,
        reviewer_kind: authority.reviewer_kind,
        reviewer_id: authority.reviewer.reviewer_id,
        reviewer_authority_ref: authority.reviewer.authority_ref,
        review_receipt: {
          record_id: review.receipt_id,
          record_version: review.receipt_version,
          record_digest: review.receipt_digest,
        },
        review_attestation: authority.attestation,
        side_effects_applied: false,
      })
    }
    _ => None
  }
  {
    contract_version: three_gap_contract_version(),
    issues: ReadOnlyArray::from_array(issues),
    work_order: projection,
  }
}
