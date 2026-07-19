///|
/// Version identifier for the canonical, side-effect-free Three-Gap protocol.
pub fn three_gap_contract_version() -> String {
  "moonbook.bookkeeper.three_gap.v1"
}

///|
/// Stable identity, version, and digest for an immutable protocol record.
pub(all) struct VersionedRecordReference {
  record_id : String
  record_version : String
  record_digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Evidence reference with the version required by the Three-Gap protocol.
pub(all) struct VersionedEvidenceReference {
  reference_id : String
  reference_version : String
  digest : String
  provenance_ref : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Exact accepted-bundle identity used by every outcome evidence record.
pub(all) struct DeliverableReference {
  bundle_id : String
  bundle_version : String
  bundle_digest : String
  candidate_id : String
  candidate_version : String
  candidate_digest : String
} derive(Debug, Eq, ToJson)

///|
/// Typed, machine-readable failures for canonical learning operations.
pub(all) enum LearningProtocolIssue {
  MissingLearningReference(String)
  InvalidProtocolContract(String)
  ExactLinkMismatch(String)
  ConflictingRecordIdentity(String)
  MissingOutcomeEvidenceKind(OutcomeEvidenceKind)
  InvalidSeverity(Int)
  UnauthorizedLearningReview
  LearningReceiptMismatch(String)
  InvalidPromotionPolicy(String)
  InsufficientReviewedFindings(Int, Int)
  InsufficientSeverity(Int, Int)
  MissingRequiredGapClass(ThreeGapClass)
  WorkOrderProjectionDenied(String)
  ReviewAttestationMissing
  ReviewAttestationMismatch(String)
  NonHumanReviewAttestation(ReviewerKind)
} derive(Debug, Eq, ToJson)

///|
/// Required outcome evidence categories. A record may report an empty or zero
/// result, but an exact record for every category is required.
pub(all) enum OutcomeEvidenceKind {
  FeedbackEvidence
  DefectEvidence
  CostEvidence
  OperatorTimeEvidence
  MetricEvidence
} derive(Debug, Eq, ToJson)

///|
/// One versioned outcome evidence record. Construction copies evidence; binding
/// performs the fail-closed exact-link validation.
pub struct OutcomeEvidenceRecord {
  contract_version : String
  record : VersionedRecordReference
  kind : OutcomeEvidenceKind
  deliverable : DeliverableReference
  observation : VersionedRecordReference
  summary : String
  evidence_refs : ReadOnlyArray[VersionedEvidenceReference]
} derive(Debug, Eq, ToJson)

///|
/// Construct an immutable outcome evidence record without binding or storing it.
pub fn OutcomeEvidenceRecord::new(
  record~ : VersionedRecordReference,
  kind~ : OutcomeEvidenceKind,
  deliverable~ : DeliverableReference,
  observation~ : VersionedRecordReference,
  summary~ : String,
  evidence_refs~ : ArrayView[VersionedEvidenceReference],
) -> OutcomeEvidenceRecord {
  {
    contract_version: three_gap_contract_version(),
    record,
    kind,
    deliverable,
    observation,
    summary,
    evidence_refs: ReadOnlyArray::from_array(evidence_refs),
  }
}

///|
/// Opaque valid binding of one finalized bundle, its exact outcome observation,
/// and the five required evidence categories. It is a value only: no persistence
/// or mutation operation is exposed.
pub struct OutcomeEvidenceBinding {
  contract_version : String
  binding : VersionedRecordReference
  deliverable : DeliverableReference
  observation : VersionedRecordReference
  records : ReadOnlyArray[OutcomeEvidenceRecord]
} derive(Debug, Eq, ToJson)

///|
/// Fail-closed result of binding outcome evidence. A binding exists only when
/// every issue check passes.
pub struct OutcomeEvidenceBindingDecision {
  contract_version : String
  issues : ReadOnlyArray[LearningProtocolIssue]
  binding : OutcomeEvidenceBinding?
} derive(Debug, Eq, ToJson)

///|
pub fn OutcomeEvidenceBindingDecision::is_bound(
  self : OutcomeEvidenceBindingDecision,
) -> Bool {
  self.issues.is_empty() && self.binding is Some(_)
}

///|
fn append_learning_missing(
  issues : Array[LearningProtocolIssue],
  value : String,
  label : String,
) -> Unit {
  if value.is_blank() {
    issues.push(MissingLearningReference(label))
  }
}

///|
fn validate_record_reference(
  reference : VersionedRecordReference,
  label : String,
  issues : Array[LearningProtocolIssue],
) -> Unit {
  append_learning_missing(issues, reference.record_id, "\{label} id")
  append_learning_missing(issues, reference.record_version, "\{label} version")
  append_learning_missing(issues, reference.record_digest, "\{label} digest")
}

///|
fn validate_versioned_evidence(
  refs : ReadOnlyArray[VersionedEvidenceReference],
  observation_evidence : ReadOnlyArray[EvidenceReference],
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
    if !observation_evidence.any(fn(item) {
        item.reference_id == reference.reference_id &&
        item.digest == reference.digest &&
        item.provenance_ref == reference.provenance_ref
      }) {
      issues.push(
        ExactLinkMismatch("\{label} evidence:\{reference.reference_id}"),
      )
    }
  }
}

///|
fn outcome_record_compare(
  left : OutcomeEvidenceRecord,
  right : OutcomeEvidenceRecord,
) -> Int {
  let by_id = left.record.record_id.compare(right.record.record_id)
  if by_id != 0 {
    return by_id
  }
  let by_version = left.record.record_version.compare(
    right.record.record_version,
  )
  if by_version != 0 {
    return by_version
  }
  left.record.record_digest.compare(right.record.record_digest)
}

///|
fn validate_deliverable_reference(
  expected : DeliverableReference,
  actual : DeliverableReference,
  label : String,
  issues : Array[LearningProtocolIssue],
) -> Unit {
  if actual.bundle_id != expected.bundle_id {
    issues.push(ExactLinkMismatch("\{label} bundle id"))
  }
  if actual.bundle_version != expected.bundle_version {
    issues.push(ExactLinkMismatch("\{label} bundle version"))
  }
  if actual.bundle_digest != expected.bundle_digest {
    issues.push(ExactLinkMismatch("\{label} bundle digest"))
  }
  if actual.candidate_id != expected.candidate_id {
    issues.push(ExactLinkMismatch("\{label} candidate id"))
  }
  if actual.candidate_version != expected.candidate_version {
    issues.push(ExactLinkMismatch("\{label} candidate version"))
  }
  if actual.candidate_digest != expected.candidate_digest {
    issues.push(ExactLinkMismatch("\{label} candidate digest"))
  }
}

///|
/// Bind all learning evidence to an exact finalized deliverable and observation.
/// Input order is erased by stable sorting. Exact duplicate records are removed;
/// the same id/version with different content fails closed.
pub fn bind_outcome_evidence(
  bundle : DeliverableBundle,
  observation : OutcomeObservation,
  binding~ : VersionedRecordReference,
  records : ArrayView[OutcomeEvidenceRecord],
) -> OutcomeEvidenceBindingDecision {
  let issues : Array[LearningProtocolIssue] = []
  let deliverable : DeliverableReference = {
    bundle_id: bundle.bundle_id,
    bundle_version: bundle.bundle_version,
    bundle_digest: bundle.bundle_digest,
    candidate_id: bundle.candidate_id,
    candidate_version: bundle.candidate_version,
    candidate_digest: bundle.candidate_digest,
  }
  let observation_ref : VersionedRecordReference = {
    record_id: observation.observation_id,
    record_version: observation.observation_version,
    record_digest: observation.observation_digest,
  }
  validate_record_reference(binding, "outcome evidence binding", issues)
  validate_record_reference(observation_ref, "observation", issues)
  if !bundle.matches_outcome(observation) {
    issues.push(ExactLinkMismatch("outcome observation"))
  }
  append_learning_missing(issues, deliverable.bundle_digest, "bundle digest")
  let sorted : Array[OutcomeEvidenceRecord] = []
  for record in records {
    sorted.push(record)
  }
  sorted.sort_by(outcome_record_compare)
  let unique : Array[OutcomeEvidenceRecord] = []
  for record in sorted {
    validate_record_reference(record.record, "outcome evidence record", issues)
    if record.contract_version != three_gap_contract_version() {
      issues.push(InvalidProtocolContract(record.contract_version))
    }
    validate_deliverable_reference(
      deliverable,
      record.deliverable,
      record.record.record_id,
      issues,
    )
    if record.observation != observation_ref {
      issues.push(ExactLinkMismatch("\{record.record.record_id} observation"))
    }
    append_learning_missing(issues, record.summary, "outcome evidence summary")
    validate_versioned_evidence(
      record.evidence_refs,
      observation.evidence_refs,
      record.record.record_id,
      issues,
    )
    match unique.last() {
      Some(previous) if previous.record.record_id == record.record.record_id &&
        previous.record.record_version == record.record.record_version =>
        if previous != record {
          issues.push(ConflictingRecordIdentity(record.record.record_id))
        }
      _ => unique.push(record)
    }
  }
  for
    required in [
      FeedbackEvidence,
      DefectEvidence,
      CostEvidence,
      OperatorTimeEvidence,
      MetricEvidence,
    ] {
    if !unique.any(fn(record) { record.kind == required }) {
      issues.push(MissingOutcomeEvidenceKind(required))
    }
  }
  let binding = if issues.is_empty() {
    Some({
      contract_version: three_gap_contract_version(),
      binding,
      deliverable,
      observation: observation_ref,
      records: ReadOnlyArray::from_array(unique),
    })
  } else {
    None
  }
  {
    contract_version: three_gap_contract_version(),
    issues: ReadOnlyArray::from_array(issues),
    binding,
  }
}
