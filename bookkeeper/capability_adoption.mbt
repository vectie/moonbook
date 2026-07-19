///|
fn append_adoption_missing(
  issues : Array[CapabilityAdoptionIssue],
  value : String,
  label : String,
) -> Unit {
  if value.is_blank() {
    issues.push(MissingAdoptionReference(label))
  }
}

///|
fn validate_adoption_record(
  reference : VersionedRecordReference,
  label : String,
  issues : Array[CapabilityAdoptionIssue],
) -> Unit {
  append_adoption_missing(issues, reference.record_id, "\{label} id")
  append_adoption_missing(issues, reference.record_version, "\{label} version")
  append_adoption_missing(issues, reference.record_digest, "\{label} digest")
}

///|
fn adoption_evidence_compare(
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
fn changed_artifact_compare(
  left : ChangedArtifactReference,
  right : ChangedArtifactReference,
) -> Int {
  let by_id = left.artifact_id.compare(right.artifact_id)
  if by_id != 0 {
    return by_id
  }
  let by_version = left.artifact_version.compare(right.artifact_version)
  if by_version != 0 {
    return by_version
  }
  left.artifact_digest.compare(right.artifact_digest)
}

///|
fn test_result_compare(
  left : CapabilityTestResult,
  right : CapabilityTestResult,
) -> Int {
  let by_id = left.test_record.record_id.compare(right.test_record.record_id)
  if by_id != 0 {
    return by_id
  }
  let by_version = left.test_record.record_version.compare(
    right.test_record.record_version,
  )
  if by_version != 0 {
    return by_version
  }
  left.test_record.record_digest.compare(right.test_record.record_digest)
}

///|
fn metric_record_compare(
  left : CapabilityMetricRecord,
  right : CapabilityMetricRecord,
) -> Int {
  let by_id = left.metric.record_id.compare(right.metric.record_id)
  if by_id != 0 {
    return by_id
  }
  let by_version = left.metric.record_version.compare(
    right.metric.record_version,
  )
  if by_version != 0 {
    return by_version
  }
  left.metric.record_digest.compare(right.metric.record_digest)
}

///|
fn canonicalize_adoption_evidence(
  evidence : ArrayView[VersionedEvidenceReference],
  issues : Array[CapabilityAdoptionIssue],
) -> Array[VersionedEvidenceReference] {
  let sorted : Array[VersionedEvidenceReference] = []
  for reference in evidence {
    sorted.push(reference)
  }
  sorted.sort_by(adoption_evidence_compare)
  let unique : Array[VersionedEvidenceReference] = []
  for reference in sorted {
    append_adoption_missing(issues, reference.reference_id, "evidence id")
    append_adoption_missing(
      issues,
      reference.reference_version,
      "evidence version",
    )
    append_adoption_missing(issues, reference.digest, "evidence digest")
    append_adoption_missing(
      issues,
      reference.provenance_ref,
      "evidence provenance",
    )
    match unique.last() {
      Some(previous) if previous.reference_id == reference.reference_id =>
        if previous != reference {
          issues.push(ConflictingEvidenceIdentity(reference.reference_id))
        }
      _ => unique.push(reference)
    }
  }
  unique
}

///|
fn canonicalize_changed_artifacts(
  artifacts : ArrayView[ChangedArtifactReference],
  issues : Array[CapabilityAdoptionIssue],
) -> Array[ChangedArtifactReference] {
  let sorted : Array[ChangedArtifactReference] = []
  for artifact in artifacts {
    sorted.push(artifact)
  }
  sorted.sort_by(changed_artifact_compare)
  let unique : Array[ChangedArtifactReference] = []
  for artifact in sorted {
    append_adoption_missing(issues, artifact.artifact_id, "artifact id")
    append_adoption_missing(
      issues,
      artifact.artifact_version,
      "artifact version",
    )
    append_adoption_missing(issues, artifact.artifact_digest, "artifact digest")
    match unique.last() {
      Some(previous) if previous.artifact_id == artifact.artifact_id =>
        if previous != artifact {
          issues.push(ConflictingArtifactIdentity(artifact.artifact_id))
        }
      _ => unique.push(artifact)
    }
  }
  unique
}

///|
fn evidence_sets_match(
  left : ReadOnlyArray[VersionedEvidenceReference],
  right : ReadOnlyArray[VersionedEvidenceReference],
) -> Bool {
  left.length() == right.length() &&
  left.all(fn(reference) { right.contains(reference) }) &&
  right.all(fn(reference) { left.contains(reference) })
}

///|
fn artifact_sets_match(
  left : ReadOnlyArray[ChangedArtifactReference],
  right : ReadOnlyArray[ChangedArtifactReference],
) -> Bool {
  left.length() == right.length() &&
  left.all(fn(reference) { right.contains(reference) }) &&
  right.all(fn(reference) { left.contains(reference) })
}

///|
fn proposal_reference(
  proposal : CapabilityProposal,
) -> VersionedRecordReference {
  {
    record_id: proposal.proposal_id,
    record_version: proposal.proposal_version,
    record_digest: proposal.change_digest,
  }
}

///|
fn learning_receipt_reference(
  review : LearningReceipt,
) -> VersionedRecordReference {
  {
    record_id: review.receipt_id,
    record_version: review.receipt_version,
    record_digest: review.receipt_digest,
  }
}

///|
fn validate_result_chain(
  proposal : CapabilityProposal,
  review : LearningReceipt,
  work_order : MoonCodeWorkOrderProjection,
  old_capability : VersionedRecordReference,
  new_capability : VersionedRecordReference,
  issues : Array[CapabilityAdoptionIssue],
) -> Unit {
  if proposal.contract_version != bookkeeper_contract_version() {
    issues.push(InvalidAdoptionContract(proposal.contract_version))
  }
  if work_order.contract_version != three_gap_contract_version() {
    issues.push(InvalidAdoptionContract(work_order.contract_version))
  }
  if !proposal.is_policy_promoted() {
    issues.push(AdoptionLinkMismatch("policy-promoted proposal"))
  }
  let proposal_ref = proposal_reference(proposal)
  let review_ref = learning_receipt_reference(review)
  validate_adoption_record(proposal_ref, "capability proposal", issues)
  validate_adoption_record(review_ref, "accepted learning receipt", issues)
  validate_adoption_record(work_order.projection_request, "projection", issues)
  validate_adoption_record(work_order.work_order, "work order", issues)
  validate_adoption_record(
    work_order.review_attestation,
    "work order review attestation",
    issues,
  )
  validate_adoption_record(old_capability, "old capability", issues)
  validate_adoption_record(new_capability, "new capability", issues)
  if work_order.proposal != proposal_ref {
    issues.push(AdoptionLinkMismatch("capability proposal"))
  }
  if work_order.review_receipt != review_ref {
    issues.push(AdoptionLinkMismatch("accepted learning receipt"))
  }
  if review.proposal_id != proposal.proposal_id ||
    review.proposal_version != proposal.proposal_version ||
    review.capability_id != proposal.capability_id ||
    review.capability_version != proposal.capability_version ||
    review.owner_route != proposal.owner_route {
    issues.push(AdoptionLinkMismatch("proposal learning review"))
  }
  if !review.review_complete ||
    review.disposition != Accept ||
    review.self_modification_applied {
    issues.push(CapabilityReviewNotAccepted)
  }
  if work_order.reviewer_kind != Human ||
    work_order.reviewer_id.is_blank() ||
    work_order.reviewer_authority_ref.is_blank() ||
    work_order.reviewer_id != review.reviewer.reviewer_id ||
    work_order.reviewer_authority_ref != review.reviewer.authority_ref ||
    !review.reviewer.authorized ||
    work_order.side_effects_applied {
    issues.push(WorkOrderNotHumanAttested)
  }
  if new_capability.record_id != proposal.capability_id ||
    new_capability.record_version != proposal.capability_version ||
    new_capability.record_digest != proposal.change_digest ||
    work_order.capability != new_capability {
    issues.push(AdoptionLinkMismatch("new capability"))
  }
  match proposal.supersedes_version {
    Some(version) if old_capability.record_id == proposal.capability_id &&
      old_capability.record_version == version => ()
    _ => issues.push(AdoptionLinkMismatch("old capability"))
  }
  if old_capability.record_version == new_capability.record_version ||
    old_capability.record_digest == new_capability.record_digest {
    issues.push(AdoptionLinkMismatch("capability version transition"))
  }
  match proposal.promotion_policy_ref {
    Some(policy) if work_order.promotion_policy == policy => ()
    _ => issues.push(AdoptionLinkMismatch("promotion policy"))
  }
}

///|
/// Canonically bind one reported MoonCode result to the exact prior governed
/// chain. Exact duplicate artifacts and evidence are idempotent; conflicting
/// identities and every stale or mismatched binding fail closed.
pub fn bind_mooncode_work_result_candidate(
  proposal : CapabilityProposal,
  review : LearningReceipt,
  work_order : MoonCodeWorkOrderProjection,
  result~ : VersionedRecordReference,
  old_capability~ : VersionedRecordReference,
  new_capability~ : VersionedRecordReference,
  changed_artifacts~ : ArrayView[ChangedArtifactReference],
  evidence_refs~ : ArrayView[VersionedEvidenceReference],
) -> MoonCodeWorkResultDecision {
  let issues : Array[CapabilityAdoptionIssue] = []
  validate_adoption_record(result, "MoonCode work result", issues)
  validate_result_chain(
    proposal, review, work_order, old_capability, new_capability, issues,
  )
  let stable_artifacts = canonicalize_changed_artifacts(
    changed_artifacts, issues,
  )
  if stable_artifacts.is_empty() {
    issues.push(MissingAdoptionReference("changed artifacts"))
  }
  let stable_evidence = canonicalize_adoption_evidence(evidence_refs, issues)
  if stable_evidence.is_empty() {
    issues.push(MissingAdoptionReference("result evidence"))
  }
  let canonical_evidence = ReadOnlyArray::from_array(stable_evidence)
  for projected in work_order.evidence_refs {
    if !canonical_evidence.contains(projected) {
      issues.push(
        AdoptionLinkMismatch("work order evidence:\{projected.reference_id}"),
      )
    }
  }
  for reviewer_evidence in review.reviewer.evidence_refs {
    if !canonical_evidence.any(fn(reference) {
        reference.reference_id == reviewer_evidence
      }) {
      issues.push(
        AdoptionLinkMismatch("reviewer evidence:\{reviewer_evidence}"),
      )
    }
  }
  let candidate = if issues.is_empty() {
    Some({
      contract_version: capability_adoption_contract_version(),
      result,
      proposal: proposal_reference(proposal),
      learning_receipt: learning_receipt_reference(review),
      projection: work_order.projection_request,
      work_order: work_order.work_order,
      work_order_review_attestation: work_order.review_attestation,
      work_order_reviewer_id: work_order.reviewer_id,
      work_order_reviewer_authority_ref: work_order.reviewer_authority_ref,
      old_capability,
      new_capability,
      changed_artifacts: ReadOnlyArray::from_array(stable_artifacts),
      evidence_refs: canonical_evidence,
      side_effects_applied: false,
    })
  } else {
    None
  }
  {
    contract_version: capability_adoption_contract_version(),
    issues: ReadOnlyArray::from_array(issues),
    candidate,
    side_effects_applied: false,
  }
}

///|
fn normalize_test_results(
  results : ArrayView[CapabilityTestResult],
  evaluation_evidence : ReadOnlyArray[VersionedEvidenceReference],
  issues : Array[CapabilityAdoptionIssue],
) -> Array[CapabilityTestResult] {
  let sorted : Array[CapabilityTestResult] = []
  for result in results {
    validate_adoption_record(result.test_record, "declared test", issues)
    let evidence = canonicalize_adoption_evidence(result.evidence_refs, issues)
    let test_evidence = ReadOnlyArray::from_array(evidence)
    if test_evidence.is_empty() {
      issues.push(EvaluationEvidenceMissing)
    }
    for reference in test_evidence {
      if !evaluation_evidence.contains(reference) {
        issues.push(
          AdoptionLinkMismatch("test evidence:\{reference.reference_id}"),
        )
      }
    }
    if !result.complete {
      issues.push(EvaluationTestIncomplete(result.test_record.record_id))
    }
    if !result.passed {
      issues.push(EvaluationTestFailed(result.test_record.record_id))
    }
    sorted.push({ ..result, evidence_refs: test_evidence })
  }
  sorted.sort_by(test_result_compare)
  let unique : Array[CapabilityTestResult] = []
  for result in sorted {
    match unique.last() {
      Some(previous) if previous.test_record.record_id ==
        result.test_record.record_id =>
        if previous != result {
          issues.push(ConflictingTestIdentity(result.test_record.record_id))
        }
      _ => unique.push(result)
    }
  }
  unique
}

///|
fn normalize_metric_records(
  records : ArrayView[CapabilityMetricRecord],
  evaluation_evidence : ReadOnlyArray[VersionedEvidenceReference],
  issues : Array[CapabilityAdoptionIssue],
) -> Array[CapabilityMetricRecord] {
  let sorted : Array[CapabilityMetricRecord] = []
  for record in records {
    validate_adoption_record(record.metric, "metric record", issues)
    let evidence = canonicalize_adoption_evidence(record.evidence_refs, issues)
    let metric_evidence = ReadOnlyArray::from_array(evidence)
    if metric_evidence.is_empty() {
      issues.push(EvaluationEvidenceMissing)
    }
    for reference in metric_evidence {
      if !evaluation_evidence.contains(reference) {
        issues.push(
          AdoptionLinkMismatch("metric evidence:\{reference.reference_id}"),
        )
      }
    }
    sorted.push({ ..record, evidence_refs: metric_evidence })
  }
  sorted.sort_by(metric_record_compare)
  let unique : Array[CapabilityMetricRecord] = []
  for record in sorted {
    match unique.last() {
      Some(previous) if previous.metric.record_id == record.metric.record_id =>
        if previous != record {
          issues.push(ConflictingMetricIdentity(record.metric.record_id))
        }
      _ => unique.push(record)
    }
  }
  unique
}

///|
/// Create an immutable, auditable evaluation for one exact candidate. A failed
/// or incomplete evaluation is retained as a value with `passing = false`.
pub fn CapabilityEvaluation::new(
  candidate : MoonCodeWorkResultCandidate,
  evaluation~ : VersionedRecordReference,
  test_results~ : ArrayView[CapabilityTestResult],
  evidence_refs~ : ArrayView[VersionedEvidenceReference],
  metric_records~ : ArrayView[CapabilityMetricRecord],
  declared_result~ : CapabilityEvaluationResult,
  rollback~ : VersionedRecordReference,
) -> CapabilityEvaluation {
  let issues : Array[CapabilityAdoptionIssue] = []
  validate_adoption_record(evaluation, "capability evaluation", issues)
  let stable_evidence = canonicalize_adoption_evidence(evidence_refs, issues)
  let evaluation_evidence = ReadOnlyArray::from_array(stable_evidence)
  if evaluation_evidence.is_empty() {
    issues.push(EvaluationEvidenceMissing)
  }
  let stable_tests = normalize_test_results(
    test_results, evaluation_evidence, issues,
  )
  if stable_tests.is_empty() {
    issues.push(EvaluationTestsMissing)
  }
  let stable_metrics = normalize_metric_records(
    metric_records, evaluation_evidence, issues,
  )
  if stable_metrics.is_empty() {
    issues.push(EvaluationMetricsMissing)
  }
  validate_adoption_record(rollback, "rollback", issues)
  if rollback.record_id.is_blank() ||
    rollback.record_version.is_blank() ||
    rollback.record_digest.is_blank() {
    issues.push(RollbackReferenceInvalid)
  }
  let passing = declared_result == Passed && issues.is_empty()
  {
    contract_version: capability_adoption_contract_version(),
    evaluation,
    result_candidate: candidate.result,
    declared_result,
    test_results: ReadOnlyArray::from_array(stable_tests),
    evidence_refs: evaluation_evidence,
    metric_records: ReadOnlyArray::from_array(stable_metrics),
    rollback,
    issues: ReadOnlyArray::from_array(issues),
    passing,
    side_effects_applied: false,
  }
}

///|
fn canonical_evidence_without_issues(
  evidence : ArrayView[VersionedEvidenceReference],
) -> ReadOnlyArray[VersionedEvidenceReference] {
  let sorted : Array[VersionedEvidenceReference] = []
  for reference in evidence {
    sorted.push(reference)
  }
  sorted.sort_by(adoption_evidence_compare)
  let unique : Array[VersionedEvidenceReference] = []
  for reference in sorted {
    if !unique.contains(reference) {
      unique.push(reference)
    }
  }
  ReadOnlyArray::from_array(unique)
}

///|
fn canonical_artifacts_without_issues(
  artifacts : ArrayView[ChangedArtifactReference],
) -> ReadOnlyArray[ChangedArtifactReference] {
  let sorted : Array[ChangedArtifactReference] = []
  for artifact in artifacts {
    sorted.push(artifact)
  }
  sorted.sort_by(changed_artifact_compare)
  let unique : Array[ChangedArtifactReference] = []
  for artifact in sorted {
    if !unique.contains(artifact) {
      unique.push(artifact)
    }
  }
  ReadOnlyArray::from_array(unique)
}

///|
/// Construct an immutable authority statement over the exact adoption inputs.
/// Construction records review intent only; adoption revalidates every field.
pub fn CapabilityAdoptionAttestation::new(
  attestation~ : VersionedRecordReference,
  candidate : MoonCodeWorkResultCandidate,
  evaluation : CapabilityEvaluation,
  proposal : CapabilityProposal,
  review : LearningReceipt,
  work_order : MoonCodeWorkOrderProjection,
  reviewer_kind~ : ReviewerKind,
  reviewer~ : ReviewerAuthority,
  evidence_refs~ : ArrayView[VersionedEvidenceReference],
  requested~ : BookkeeperDisposition,
  old_capability~ : VersionedRecordReference,
  new_capability~ : VersionedRecordReference,
  rollback~ : VersionedRecordReference,
) -> CapabilityAdoptionAttestation {
  {
    contract_version: capability_adoption_contract_version(),
    attestation,
    result_candidate: candidate.result,
    evaluation: evaluation.evaluation,
    proposal: proposal_reference(proposal),
    learning_receipt: learning_receipt_reference(review),
    projection: work_order.projection_request,
    work_order: work_order.work_order,
    work_order_review_attestation: work_order.review_attestation,
    work_order_reviewer_id: work_order.reviewer_id,
    work_order_reviewer_authority_ref: work_order.reviewer_authority_ref,
    reviewer_kind,
    reviewer,
    evidence_refs: canonical_evidence_without_issues(evidence_refs),
    changed_artifacts: canonical_artifacts_without_issues(
      candidate.changed_artifacts,
    ),
    requested,
    old_capability,
    new_capability,
    rollback,
  }
}

///|
fn expected_adoption_evidence(
  candidate : MoonCodeWorkResultCandidate,
  evaluation : CapabilityEvaluation,
  issues : Array[CapabilityAdoptionIssue],
) -> ReadOnlyArray[VersionedEvidenceReference] {
  let combined : Array[VersionedEvidenceReference] = []
  for reference in candidate.evidence_refs {
    combined.push(reference)
  }
  for reference in evaluation.evidence_refs {
    combined.push(reference)
  }
  ReadOnlyArray::from_array(canonicalize_adoption_evidence(combined, issues))
}

///|
fn validate_adoption_attestation(
  proposal : CapabilityProposal,
  review : LearningReceipt,
  work_order : MoonCodeWorkOrderProjection,
  candidate : MoonCodeWorkResultCandidate,
  evaluation : CapabilityEvaluation,
  requested : BookkeeperDisposition,
  reviewer : ReviewerAuthority,
  attestation : CapabilityAdoptionAttestation?,
  issues : Array[CapabilityAdoptionIssue],
) -> CapabilityAdoptionAttestation? {
  match attestation {
    None => {
      issues.push(AdoptionAttestationMissing)
      None
    }
    Some(authority) => {
      if authority.contract_version != capability_adoption_contract_version() {
        issues.push(InvalidAdoptionContract(authority.contract_version))
      }
      validate_adoption_record(
        authority.attestation,
        "capability adoption attestation",
        issues,
      )
      if authority.result_candidate != candidate.result {
        issues.push(AdoptionAttestationMismatch("result candidate"))
      }
      if authority.evaluation != evaluation.evaluation {
        issues.push(AdoptionAttestationMismatch("evaluation"))
      }
      if authority.proposal != proposal_reference(proposal) {
        issues.push(AdoptionAttestationMismatch("capability proposal"))
      }
      if authority.learning_receipt != learning_receipt_reference(review) {
        issues.push(AdoptionAttestationMismatch("accepted learning receipt"))
      }
      if authority.projection != work_order.projection_request ||
        authority.work_order != work_order.work_order {
        issues.push(AdoptionAttestationMismatch("work order projection"))
      }
      if authority.work_order_review_attestation !=
        work_order.review_attestation {
        issues.push(AdoptionAttestationMismatch("work order attestation"))
      }
      if authority.work_order_reviewer_id != work_order.reviewer_id ||
        authority.work_order_reviewer_authority_ref !=
        work_order.reviewer_authority_ref {
        issues.push(AdoptionAttestationMismatch("work order review authority"))
      }
      if authority.reviewer_kind != Human {
        issues.push(NonHumanAdoptionAttestation(authority.reviewer_kind))
      }
      if authority.reviewer.reviewer_id.is_blank() ||
        authority.reviewer.authority_ref.is_blank() ||
        !authority.reviewer.authorized {
        issues.push(UnauthorizedAdoptionReviewer)
      }
      if authority.reviewer != reviewer {
        issues.push(AdoptionAttestationMismatch("adoption reviewer authority"))
      }
      let attestation_evidence = canonicalize_adoption_evidence(
        authority.evidence_refs,
        issues,
      )
      let exact_attestation_evidence = ReadOnlyArray::from_array(
        attestation_evidence,
      )
      let expected_evidence = expected_adoption_evidence(
        candidate, evaluation, issues,
      )
      if !evidence_sets_match(exact_attestation_evidence, expected_evidence) {
        issues.push(AdoptionAttestationMismatch("evidence"))
      }
      for reviewer_evidence in reviewer.evidence_refs {
        if !exact_attestation_evidence.any(fn(reference) {
            reference.reference_id == reviewer_evidence
          }) {
          issues.push(
            AdoptionAttestationMismatch(
              "reviewer evidence:\{reviewer_evidence}",
            ),
          )
        }
      }
      if !artifact_sets_match(
          authority.changed_artifacts,
          candidate.changed_artifacts,
        ) {
        issues.push(AdoptionAttestationMismatch("changed artifacts"))
      }
      if authority.requested != requested {
        issues.push(AdoptionAttestationMismatch("requested disposition"))
      }
      if authority.old_capability != candidate.old_capability {
        issues.push(AdoptionAttestationMismatch("old capability"))
      }
      if authority.new_capability != candidate.new_capability {
        issues.push(AdoptionAttestationMismatch("new capability"))
      }
      if authority.rollback != evaluation.rollback {
        issues.push(AdoptionAttestationMismatch("rollback"))
      }
      Some(authority)
    }
  }
}

///|
/// Decide adoption without applying it. Only an exact requested `Accept` with
/// a passing evaluation and exact named-human attestation emits an immutable
/// capability-version receipt. Invalid accepts fail closed to `Revise`.
pub fn decide_capability_adoption(
  proposal : CapabilityProposal,
  review : LearningReceipt,
  work_order : MoonCodeWorkOrderProjection,
  candidate : MoonCodeWorkResultCandidate,
  evaluation : CapabilityEvaluation,
  decision~ : VersionedRecordReference,
  requested~ : BookkeeperDisposition,
  reviewer~ : ReviewerAuthority,
  attestation : CapabilityAdoptionAttestation?,
) -> CapabilityAdoptionDecision {
  let issues : Array[CapabilityAdoptionIssue] = []
  validate_adoption_record(decision, "capability adoption decision", issues)
  if requested != Accept {
    return {
      contract_version: capability_adoption_contract_version(),
      decision,
      requested,
      disposition: requested,
      result_candidate: candidate.result,
      evaluation: evaluation.evaluation,
      issues: ReadOnlyArray::from_array(issues),
      version_receipt: None,
      side_effects_applied: false,
    }
  }
  if candidate.contract_version != capability_adoption_contract_version() {
    issues.push(InvalidAdoptionContract(candidate.contract_version))
  }
  validate_result_chain(
    proposal,
    review,
    work_order,
    candidate.old_capability,
    candidate.new_capability,
    issues,
  )
  if candidate.proposal != proposal_reference(proposal) {
    issues.push(AdoptionLinkMismatch("result candidate proposal"))
  }
  if candidate.learning_receipt != learning_receipt_reference(review) {
    issues.push(AdoptionLinkMismatch("result candidate learning receipt"))
  }
  if candidate.projection != work_order.projection_request ||
    candidate.work_order != work_order.work_order ||
    candidate.work_order_review_attestation != work_order.review_attestation {
    issues.push(AdoptionLinkMismatch("result candidate work order"))
  }
  if candidate.work_order_reviewer_id != work_order.reviewer_id ||
    candidate.work_order_reviewer_authority_ref !=
    work_order.reviewer_authority_ref {
    issues.push(AdoptionLinkMismatch("result candidate review authority"))
  }
  if evaluation.contract_version != capability_adoption_contract_version() {
    issues.push(InvalidAdoptionContract(evaluation.contract_version))
  }
  if evaluation.result_candidate != candidate.result {
    issues.push(AdoptionLinkMismatch("evaluation result candidate"))
  }
  if !evaluation.is_passing() {
    issues.push(EvaluationNotPassing)
  }
  validate_adoption_record(evaluation.rollback, "rollback", issues)
  let exact_attestation = validate_adoption_attestation(
    proposal, review, work_order, candidate, evaluation, requested, reviewer, attestation,
    issues,
  )
  let version_receipt = match exact_attestation {
    Some(authority) if issues.is_empty() =>
      Some({
        contract_version: capability_adoption_contract_version(),
        receipt: decision,
        old_capability: candidate.old_capability,
        new_capability: candidate.new_capability,
        result_candidate: candidate.result,
        evaluation: evaluation.evaluation,
        proposal: candidate.proposal,
        source_finding_refs: proposal.source_finding_refs,
        learning_receipt: candidate.learning_receipt,
        projection: candidate.projection,
        work_order: candidate.work_order,
        work_order_review_attestation: candidate.work_order_review_attestation,
        work_order_reviewer_id: candidate.work_order_reviewer_id,
        work_order_reviewer_authority_ref: candidate.work_order_reviewer_authority_ref,
        changed_artifacts: candidate.changed_artifacts,
        result_evidence_refs: candidate.evidence_refs,
        evaluation_evidence_refs: evaluation.evidence_refs,
        test_results: evaluation.test_results,
        metric_records: evaluation.metric_records,
        adoption_attestation: authority.attestation,
        adoption_reviewer_kind: authority.reviewer_kind,
        adoption_reviewer_id: authority.reviewer.reviewer_id,
        adoption_reviewer_authority_ref: authority.reviewer.authority_ref,
        adoption_evidence_refs: authority.evidence_refs,
        rollback: evaluation.rollback,
        adoption_authorized: true,
        side_effects_applied: false,
      })
    _ => None
  }
  let disposition = if version_receipt is Some(_) { Accept } else { Revise }
  {
    contract_version: capability_adoption_contract_version(),
    decision,
    requested,
    disposition,
    result_candidate: candidate.result,
    evaluation: evaluation.evaluation,
    issues: ReadOnlyArray::from_array(issues),
    version_receipt,
    side_effects_applied: false,
  }
}
