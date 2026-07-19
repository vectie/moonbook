///|
/// Stable protocol identifier for the generic Bookkeeper finalization API.
pub fn bookkeeper_contract_version() -> String {
  "moonbook.bookkeeper.v1"
}

///|
/// Typed decision vocabulary used by Bookkeeper reviews.
pub(all) enum BookkeeperDisposition {
  Accept
  Reject
  Revise
  Escalate
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Domain-neutral categories that a pack can declare as acceptance requirements.
pub(all) enum AcceptanceRequirementKind {
  Evidence
  Provenance
  Workflow
  Gate
  Cost
  Authority
  Checklist
  Artifact
  Release
  Acceptance
  Retention
  Rollback
  DeliveryAuthorization
  PublicationAuthorization
  Custom(String)
} derive(Debug, Eq, ToJson)

///|
/// One acceptance rule declared by a pack before it is projected onto a candidate.
pub(all) struct PackAcceptanceRequirement {
  requirement_id : String
  kind : AcceptanceRequirementKind
  description : String
  required : Bool
} derive(Debug, Eq, ToJson)

///|
/// A pack rule projected with its exact pack identity and version.
pub struct AcceptanceRequirement {
  pack_id : String
  pack_version : String
  requirement_id : String
  kind : AcceptanceRequirementKind
  description : String
  required : Bool
} derive(Debug, Eq, ToJson)

///|
/// Project pack-declared rules without interpreting domain-specific categories.
/// Declaration order is retained, making projection deterministic and replayable.
pub fn project_acceptance_requirements(
  pack_id~ : String,
  pack_version~ : String,
  declarations : ArrayView[PackAcceptanceRequirement],
) -> ReadOnlyArray[AcceptanceRequirement] {
  let projected : Array[AcceptanceRequirement] = []
  for declaration in declarations {
    projected.push({
      pack_id,
      pack_version,
      requirement_id: declaration.requirement_id,
      kind: declaration.kind,
      description: declaration.description,
      required: declaration.required,
    })
  }
  ReadOnlyArray::from_array(projected)
}

///|
/// Evidence with an immutable digest and an explicit provenance reference.
pub(all) struct EvidenceReference {
  reference_id : String
  digest : String
  provenance_ref : String
} derive(Debug, Eq, ToJson)

///|
/// A versioned artifact binding. Acceptance requires declared and observed digests
/// to match and the candidate identity/version to be exact.
pub(all) struct ArtifactBinding {
  artifact_id : String
  candidate_id : String
  candidate_version : String
  declared_version : String
  observed_version : String
  declared_digest : String
  observed_digest : String
} derive(Debug, Eq, ToJson)

///|
/// A replayable receipt tied to the candidate identity, version, and digest.
pub(all) struct BindingReceipt {
  receipt_id : String
  candidate_id : String
  candidate_version : String
  candidate_digest : String
  complete : Bool
  evidence_refs : ReadOnlyArray[String]
} derive(Debug, Eq, ToJson)

///|
/// The observed result of one projected acceptance requirement.
pub(all) struct RequirementResult {
  requirement_id : String
  satisfied : Bool
  evidence_refs : ReadOnlyArray[String]
} derive(Debug, Eq, ToJson)

///|
/// A checklist result bound to the exact candidate under review.
pub(all) struct ChecklistResult {
  checklist_id : String
  candidate_id : String
  candidate_version : String
  candidate_digest : String
  passed : Bool
  evidence_refs : ReadOnlyArray[String]
} derive(Debug, Eq, ToJson)

///|
/// Reviewer identity plus the authority receipt used for this decision.
pub(all) struct ReviewerAuthority {
  reviewer_id : String
  authority_ref : String
  authorized : Bool
  evidence_refs : ReadOnlyArray[String]
} derive(Debug, Eq, ToJson)

///|
/// Explicit authorization state for delivery or publication. `NotRequested`
/// is distinct from denial; an unauthorized requested action fails acceptance.
pub(all) enum AuthorizationState {
  NotRequested
  Authorized(String)
  Unauthorized(String)
} derive(Debug, Eq, ToJson)

///|
/// Validation findings are typed so callers do not need to parse prose.
pub(all) enum BookkeeperIssue {
  MissingReference(String)
  MissingRequirement(String)
  RequirementFailed(String)
  DuplicateRequirement(String)
  CandidateBindingMismatch(String)
  ArtifactVersionMismatch(String)
  ArtifactDigestMismatch(String)
  IncompleteReceipt(String)
  UnauthorizedAction(String)
  ReviewerAuthorityMissing
  OutcomeLinkMismatch(String)
  InvalidContract(String)
} derive(Debug, Eq, ToJson)

///|
/// Generic candidate presented to Bookkeeper. Collection inputs are copied into
/// read-only arrays so later caller mutation cannot alter the reviewed input.
pub struct DeliverableCandidate {
  contract_version : String
  candidate_id : String
  candidate_version : String
  candidate_digest : String
  proposed_bundle_id : String
  proposed_bundle_version : String
  proposed_bundle_digest : String
  pack_id : String
  pack_version : String
  artifacts : ReadOnlyArray[ArtifactBinding]
  acceptance_requirements : ReadOnlyArray[AcceptanceRequirement]
  requirement_results : ReadOnlyArray[RequirementResult]
  evidence_refs : ReadOnlyArray[EvidenceReference]
  provenance_refs : ReadOnlyArray[String]
  workflow_receipts : ReadOnlyArray[BindingReceipt]
  gate_receipts : ReadOnlyArray[BindingReceipt]
  cost_receipts : ReadOnlyArray[BindingReceipt]
  authority_receipts : ReadOnlyArray[BindingReceipt]
  checklist_results : ReadOnlyArray[ChecklistResult]
  reviewer : ReviewerAuthority
  release_receipt : BindingReceipt
  acceptance_receipt : BindingReceipt
  retention_ref : String
  rollback_ref : String
  delivery_authorization : AuthorizationState
  publication_authorization : AuthorizationState
} derive(Debug, Eq, ToJson)

///|
/// Build an immutable candidate record for finalization.
pub fn DeliverableCandidate::new(
  candidate_id~ : String,
  candidate_version~ : String,
  candidate_digest~ : String,
  proposed_bundle_id~ : String,
  proposed_bundle_version~ : String,
  proposed_bundle_digest? : String = "",
  pack_id~ : String,
  pack_version~ : String,
  artifacts~ : ArrayView[ArtifactBinding],
  acceptance_requirements~ : ArrayView[AcceptanceRequirement],
  requirement_results~ : ArrayView[RequirementResult],
  evidence_refs~ : ArrayView[EvidenceReference],
  provenance_refs~ : ArrayView[String],
  workflow_receipts~ : ArrayView[BindingReceipt],
  gate_receipts~ : ArrayView[BindingReceipt],
  cost_receipts~ : ArrayView[BindingReceipt],
  authority_receipts~ : ArrayView[BindingReceipt],
  checklist_results~ : ArrayView[ChecklistResult],
  reviewer~ : ReviewerAuthority,
  release_receipt~ : BindingReceipt,
  acceptance_receipt~ : BindingReceipt,
  retention_ref~ : String,
  rollback_ref~ : String,
  delivery_authorization~ : AuthorizationState,
  publication_authorization~ : AuthorizationState,
) -> DeliverableCandidate {
  let bundle_digest = if proposed_bundle_digest.is_blank() {
    candidate_digest
  } else {
    proposed_bundle_digest
  }
  {
    contract_version: bookkeeper_contract_version(),
    candidate_id,
    candidate_version,
    candidate_digest,
    proposed_bundle_id,
    proposed_bundle_version,
    proposed_bundle_digest: bundle_digest,
    pack_id,
    pack_version,
    artifacts: ReadOnlyArray::from_array(artifacts),
    acceptance_requirements: ReadOnlyArray::from_array(acceptance_requirements),
    requirement_results: ReadOnlyArray::from_array(requirement_results),
    evidence_refs: ReadOnlyArray::from_array(evidence_refs),
    provenance_refs: ReadOnlyArray::from_array(provenance_refs),
    workflow_receipts: ReadOnlyArray::from_array(workflow_receipts),
    gate_receipts: ReadOnlyArray::from_array(gate_receipts),
    cost_receipts: ReadOnlyArray::from_array(cost_receipts),
    authority_receipts: ReadOnlyArray::from_array(authority_receipts),
    checklist_results: ReadOnlyArray::from_array(checklist_results),
    reviewer,
    release_receipt,
    acceptance_receipt,
    retention_ref,
    rollback_ref,
    delivery_authorization,
    publication_authorization,
  }
}

///|
/// Immutable accepted bundle. No public constructor exists: Bookkeeper creates
/// this value only after every fail-closed acceptance check passes.
pub struct DeliverableBundle {
  contract_version : String
  bundle_id : String
  bundle_version : String
  bundle_digest : String
  decision_id : String
  decided_at : Int
  candidate_id : String
  candidate_version : String
  candidate_digest : String
  pack_id : String
  pack_version : String
  artifacts : ReadOnlyArray[ArtifactBinding]
  acceptance_requirements : ReadOnlyArray[AcceptanceRequirement]
  requirement_results : ReadOnlyArray[RequirementResult]
  evidence_refs : ReadOnlyArray[EvidenceReference]
  provenance_refs : ReadOnlyArray[String]
  workflow_receipts : ReadOnlyArray[BindingReceipt]
  gate_receipts : ReadOnlyArray[BindingReceipt]
  cost_receipts : ReadOnlyArray[BindingReceipt]
  authority_receipts : ReadOnlyArray[BindingReceipt]
  checklist_results : ReadOnlyArray[ChecklistResult]
  reviewer : ReviewerAuthority
  release_receipt : BindingReceipt
  acceptance_receipt : BindingReceipt
  retention_ref : String
  rollback_ref : String
  delivery_authorization : AuthorizationState
  publication_authorization : AuthorizationState
} derive(Debug, Eq, ToJson)

///|
/// Final review record. Only `Accept` can carry a bundle; reject, revise, and
/// escalate decisions are always non-deliverable.
pub struct BookkeeperDecision {
  contract_version : String
  decision_id : String
  decided_at : Int
  requested : BookkeeperDisposition
  disposition : BookkeeperDisposition
  candidate_id : String
  candidate_version : String
  candidate_digest : String
  reviewer_id : String
  reviewer_authority_ref : String
  issues : ReadOnlyArray[BookkeeperIssue]
  bundle : DeliverableBundle?
} derive(Debug, Eq, ToJson)

///|
/// True only for a validated accept decision carrying its immutable bundle.
pub fn BookkeeperDecision::is_deliverable(self : BookkeeperDecision) -> Bool {
  self.disposition == Accept && self.bundle is Some(_)
}

///|
/// Return the accepted bundle, if and only if the decision is deliverable.
pub fn BookkeeperDecision::accepted_bundle(
  self : BookkeeperDecision,
) -> DeliverableBundle? {
  if self.is_deliverable() {
    self.bundle
  } else {
    None
  }
}

///|
/// Versioned outcome evidence linked to one exact accepted bundle and candidate
/// version. It cannot be used as evidence for another bundle or replay version.
pub struct OutcomeObservation {
  contract_version : String
  observation_id : String
  observation_version : String
  observation_digest : String
  bundle_id : String
  bundle_version : String
  bundle_digest : String
  candidate_id : String
  candidate_version : String
  candidate_digest : String
  observed_at : Int
  summary : String
  evidence_refs : ReadOnlyArray[EvidenceReference]
} derive(Debug, Eq, ToJson)

///|
/// Construct an outcome observation with exact bundle and candidate linkage.
pub fn OutcomeObservation::new(
  observation_id~ : String,
  observation_version~ : String,
  observation_digest? : String = "",
  bundle_id~ : String,
  bundle_version~ : String,
  bundle_digest? : String = "",
  candidate_id~ : String,
  candidate_version~ : String,
  candidate_digest~ : String,
  observed_at~ : Int,
  summary~ : String,
  evidence_refs~ : ArrayView[EvidenceReference],
) -> OutcomeObservation {
  let exact_bundle_digest = if bundle_digest.is_blank() {
    candidate_digest
  } else {
    bundle_digest
  }
  {
    contract_version: bookkeeper_contract_version(),
    observation_id,
    observation_version,
    observation_digest,
    bundle_id,
    bundle_version,
    bundle_digest: exact_bundle_digest,
    candidate_id,
    candidate_version,
    candidate_digest,
    observed_at,
    summary,
    evidence_refs: ReadOnlyArray::from_array(evidence_refs),
  }
}

///|
/// One explicit gap dimension with its supporting evidence.
pub(all) struct GapFinding {
  present : Bool
  severity : Int
  summary : String
  evidence_refs : ReadOnlyArray[String]
} derive(Debug, Eq, ToJson)

///|
/// Explicit three-gap assessment: information, recognition, and decisiveness
/// are separate fields and cannot be collapsed into one generic score.
pub struct ThreeGapAssessment {
  contract_version : String
  assessment_id : String
  assessment_version : String
  subject_id : String
  subject_version : String
  owner_route : String
  information_gap : GapFinding
  recognition_gap : GapFinding
  decisiveness_gap : GapFinding
} derive(Debug, Eq, ToJson)

///|
/// Construct a versioned, owner-routed three-gap assessment.
pub fn ThreeGapAssessment::new(
  assessment_id~ : String,
  assessment_version~ : String,
  subject_id~ : String,
  subject_version~ : String,
  owner_route~ : String,
  information_gap~ : GapFinding,
  recognition_gap~ : GapFinding,
  decisiveness_gap~ : GapFinding,
) -> ThreeGapAssessment {
  {
    contract_version: bookkeeper_contract_version(),
    assessment_id,
    assessment_version,
    subject_id,
    subject_version,
    owner_route,
    information_gap,
    recognition_gap,
    decisiveness_gap,
  }
}
