///|
/// Stable version for the governed MoonCode result and capability-adoption
/// value protocol. The protocol is pure and exposes no execution operation.
pub fn capability_adoption_contract_version() -> String {
  "moonbook.bookkeeper.capability_adoption.v1"
}

///|
/// Explicit evaluation outcome. A declared pass is still non-authorizing until
/// every test, evidence, metric, rollback, and exact-link check succeeds.
pub(all) enum CapabilityEvaluationResult {
  Passed
  Failed
} derive(Debug, Eq, ToJson)

///|
/// Metric evidence may be a direct observation or an immutable receipt.
pub(all) enum CapabilityMetricKind {
  MetricObservation
  MetricReceipt
} derive(Debug, Eq, ToJson)

///|
/// Versioned digest of one artifact reported as changed by MoonCode.
pub(all) struct ChangedArtifactReference {
  artifact_id : String
  artifact_version : String
  artifact_digest : String
} derive(Debug, Eq, ToJson)

///|
/// One declared test result with exact versioned supporting evidence.
pub(all) struct CapabilityTestResult {
  test_record : VersionedRecordReference
  complete : Bool
  passed : Bool
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
} derive(Debug, Eq, ToJson)

///|
/// One versioned metric observation or receipt with exact evidence linkage.
pub(all) struct CapabilityMetricRecord {
  metric : VersionedRecordReference
  kind : CapabilityMetricKind
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
} derive(Debug, Eq, ToJson)

///|
/// Typed fail-closed findings for result, evaluation, and adoption review.
pub(all) enum CapabilityAdoptionIssue {
  MissingAdoptionReference(String)
  InvalidAdoptionContract(String)
  AdoptionLinkMismatch(String)
  ConflictingArtifactIdentity(String)
  ConflictingEvidenceIdentity(String)
  ConflictingTestIdentity(String)
  ConflictingMetricIdentity(String)
  CapabilityReviewNotAccepted
  WorkOrderNotHumanAttested
  EvaluationEvidenceMissing
  EvaluationTestsMissing
  EvaluationMetricsMissing
  EvaluationTestIncomplete(String)
  EvaluationTestFailed(String)
  EvaluationNotPassing
  RollbackReferenceInvalid
  AdoptionAttestationMissing
  AdoptionAttestationMismatch(String)
  NonHumanAdoptionAttestation(ReviewerKind)
  UnauthorizedAdoptionReviewer
} derive(Debug, Eq, ToJson)

///|
/// Opaque, canonical MoonCode result bound to one exact prior human-attested
/// work-order projection, proposal, and accepted learning receipt.
pub struct MoonCodeWorkResultCandidate {
  contract_version : String
  result : VersionedRecordReference
  proposal : VersionedRecordReference
  learning_receipt : VersionedRecordReference
  projection : VersionedRecordReference
  work_order : VersionedRecordReference
  work_order_review_attestation : VersionedRecordReference
  work_order_reviewer_id : String
  work_order_reviewer_authority_ref : String
  old_capability : VersionedRecordReference
  new_capability : VersionedRecordReference
  changed_artifacts : ReadOnlyArray[ChangedArtifactReference]
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
  side_effects_applied : Bool
} derive(Debug, Eq, ToJson)

///|
/// Fail-closed result-binding decision. No candidate is exposed on any issue.
pub struct MoonCodeWorkResultDecision {
  contract_version : String
  issues : ReadOnlyArray[CapabilityAdoptionIssue]
  candidate : MoonCodeWorkResultCandidate?
  side_effects_applied : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn MoonCodeWorkResultDecision::is_candidate(
  self : MoonCodeWorkResultDecision,
) -> Bool {
  self.issues.is_empty() && self.candidate is Some(_)
}

///|
/// Immutable evaluation of one exact result candidate. Invalid, failed, and
/// incomplete evaluations remain inspectable but cannot authorize adoption.
pub struct CapabilityEvaluation {
  contract_version : String
  evaluation : VersionedRecordReference
  result_candidate : VersionedRecordReference
  declared_result : CapabilityEvaluationResult
  test_results : ReadOnlyArray[CapabilityTestResult]
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
  metric_records : ReadOnlyArray[CapabilityMetricRecord]
  rollback : VersionedRecordReference
  issues : ReadOnlyArray[CapabilityAdoptionIssue]
  passing : Bool
  side_effects_applied : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn CapabilityEvaluation::is_passing(self : CapabilityEvaluation) -> Bool {
  self.passing &&
  self.declared_result == Passed &&
  self.issues.is_empty() &&
  !self.side_effects_applied
}

///|
/// Opaque adoption authority statement over every exact reviewed input.
pub struct CapabilityAdoptionAttestation {
  contract_version : String
  attestation : VersionedRecordReference
  result_candidate : VersionedRecordReference
  evaluation : VersionedRecordReference
  proposal : VersionedRecordReference
  learning_receipt : VersionedRecordReference
  projection : VersionedRecordReference
  work_order : VersionedRecordReference
  work_order_review_attestation : VersionedRecordReference
  work_order_reviewer_id : String
  work_order_reviewer_authority_ref : String
  reviewer_kind : ReviewerKind
  reviewer : ReviewerAuthority
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
  changed_artifacts : ReadOnlyArray[ChangedArtifactReference]
  requested : BookkeeperDisposition
  old_capability : VersionedRecordReference
  new_capability : VersionedRecordReference
  rollback : VersionedRecordReference
} derive(Debug, Eq, ToJson)

///|
/// Immutable reviewed authorization value. There is no public constructor and
/// no operation that applies, executes, installs, persists, or deploys it.
pub struct CapabilityVersionReceipt {
  contract_version : String
  receipt : VersionedRecordReference
  old_capability : VersionedRecordReference
  new_capability : VersionedRecordReference
  result_candidate : VersionedRecordReference
  evaluation : VersionedRecordReference
  proposal : VersionedRecordReference
  source_finding_refs : ReadOnlyArray[VersionedRecordReference]
  learning_receipt : VersionedRecordReference
  projection : VersionedRecordReference
  work_order : VersionedRecordReference
  work_order_review_attestation : VersionedRecordReference
  work_order_reviewer_id : String
  work_order_reviewer_authority_ref : String
  changed_artifacts : ReadOnlyArray[ChangedArtifactReference]
  result_evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
  evaluation_evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
  test_results : ReadOnlyArray[CapabilityTestResult]
  metric_records : ReadOnlyArray[CapabilityMetricRecord]
  adoption_attestation : VersionedRecordReference
  adoption_reviewer_kind : ReviewerKind
  adoption_reviewer_id : String
  adoption_reviewer_authority_ref : String
  adoption_evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
  rollback : VersionedRecordReference
  adoption_authorized : Bool
  side_effects_applied : Bool
} derive(Debug, Eq, ToJson)

///|
/// The receipt is an authorization value only and is always non-applying.
pub fn CapabilityVersionReceipt::has_side_effects(
  self : CapabilityVersionReceipt,
) -> Bool {
  self.side_effects_applied
}

///|
/// Auditable adoption decision. Only a validated `Accept` can carry a receipt;
/// all decisions explicitly record that no side effect was applied.
pub struct CapabilityAdoptionDecision {
  contract_version : String
  decision : VersionedRecordReference
  requested : BookkeeperDisposition
  disposition : BookkeeperDisposition
  result_candidate : VersionedRecordReference
  evaluation : VersionedRecordReference
  issues : ReadOnlyArray[CapabilityAdoptionIssue]
  version_receipt : CapabilityVersionReceipt?
  side_effects_applied : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn CapabilityAdoptionDecision::is_authorized(
  self : CapabilityAdoptionDecision,
) -> Bool {
  self.requested == Accept &&
  self.disposition == Accept &&
  self.issues.is_empty() &&
  self.version_receipt is Some(_) &&
  !self.side_effects_applied
}

///|
/// Return the immutable reviewed version receipt only for an authorized accept.
pub fn CapabilityAdoptionDecision::authorized_version_receipt(
  self : CapabilityAdoptionDecision,
) -> CapabilityVersionReceipt? {
  if self.is_authorized() {
    self.version_receipt
  } else {
    None
  }
}
