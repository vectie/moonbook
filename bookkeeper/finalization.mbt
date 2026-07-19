///|
fn evidence_reference_exists(
  evidence : ReadOnlyArray[EvidenceReference],
  reference_id : String,
) -> Bool {
  evidence.any(fn(item) { item.reference_id == reference_id })
}

///|
fn append_missing_text(
  issues : Array[BookkeeperIssue],
  value : String,
  label : String,
) -> Unit {
  if value.is_blank() {
    issues.push(MissingReference(label))
  }
}

///|
fn validate_evidence_references(
  evidence : ReadOnlyArray[EvidenceReference],
  provenance : ReadOnlyArray[String],
  issues : Array[BookkeeperIssue],
) -> Unit {
  if evidence.is_empty() {
    issues.push(MissingReference("evidence"))
  }
  if provenance.is_empty() {
    issues.push(MissingReference("provenance"))
  }
  for item in evidence {
    append_missing_text(issues, item.reference_id, "evidence reference id")
    append_missing_text(issues, item.digest, "evidence digest")
    append_missing_text(issues, item.provenance_ref, "evidence provenance")
    if !item.provenance_ref.is_blank() &&
      !provenance.contains(item.provenance_ref) {
      issues.push(CandidateBindingMismatch(item.reference_id))
    }
  }
}

///|
fn validate_evidence_ids(
  label : String,
  refs : ReadOnlyArray[String],
  evidence : ReadOnlyArray[EvidenceReference],
  issues : Array[BookkeeperIssue],
) -> Unit {
  if refs.is_empty() {
    issues.push(MissingReference("\{label} evidence"))
  }
  for reference_id in refs {
    if !evidence_reference_exists(evidence, reference_id) {
      issues.push(CandidateBindingMismatch("\{label}:\{reference_id}"))
    }
  }
}

///|
fn validate_receipt(
  label : String,
  receipt : BindingReceipt,
  candidate : DeliverableCandidate,
  issues : Array[BookkeeperIssue],
) -> Unit {
  append_missing_text(issues, receipt.receipt_id, "\{label} receipt id")
  if receipt.candidate_id != candidate.candidate_id ||
    receipt.candidate_version != candidate.candidate_version ||
    receipt.candidate_digest != candidate.candidate_digest {
    issues.push(CandidateBindingMismatch("\{label}:\{receipt.receipt_id}"))
  }
  if !receipt.complete {
    issues.push(IncompleteReceipt("\{label}:\{receipt.receipt_id}"))
  }
  validate_evidence_ids(
    "\{label} receipt",
    receipt.evidence_refs,
    candidate.evidence_refs,
    issues,
  )
}

///|
fn validate_receipt_group(
  label : String,
  receipts : ReadOnlyArray[BindingReceipt],
  candidate : DeliverableCandidate,
  issues : Array[BookkeeperIssue],
) -> Unit {
  if receipts.is_empty() {
    issues.push(MissingReference("\{label} receipts"))
  }
  for receipt in receipts {
    validate_receipt(label, receipt, candidate, issues)
  }
}

///|
fn validate_artifacts(
  candidate : DeliverableCandidate,
  issues : Array[BookkeeperIssue],
) -> Unit {
  if candidate.artifacts.is_empty() {
    issues.push(MissingReference("artifacts"))
  }
  for artifact in candidate.artifacts {
    append_missing_text(issues, artifact.artifact_id, "artifact id")
    append_missing_text(
      issues,
      artifact.declared_version,
      "declared artifact version",
    )
    append_missing_text(
      issues,
      artifact.observed_version,
      "observed artifact version",
    )
    if artifact.candidate_id != candidate.candidate_id {
      issues.push(CandidateBindingMismatch(artifact.artifact_id))
    }
    if artifact.candidate_version != candidate.candidate_version ||
      artifact.declared_version != artifact.observed_version {
      issues.push(ArtifactVersionMismatch(artifact.artifact_id))
    }
    if artifact.declared_digest.is_blank() ||
      artifact.observed_digest.is_blank() ||
      artifact.declared_digest != artifact.observed_digest {
      issues.push(ArtifactDigestMismatch(artifact.artifact_id))
    }
  }
}

///|
fn find_requirement_result(
  results : ReadOnlyArray[RequirementResult],
  requirement_id : String,
) -> RequirementResult? {
  results
  .iter()
  .find_first(fn(result) { result.requirement_id == requirement_id })
}

///|
fn validate_requirements(
  candidate : DeliverableCandidate,
  issues : Array[BookkeeperIssue],
) -> Unit {
  if candidate.acceptance_requirements.is_empty() {
    issues.push(MissingReference("acceptance requirements"))
  }
  let seen : Array[String] = []
  for requirement in candidate.acceptance_requirements {
    if seen.contains(requirement.requirement_id) {
      issues.push(DuplicateRequirement(requirement.requirement_id))
    } else {
      seen.push(requirement.requirement_id)
    }
    if requirement.pack_id != candidate.pack_id ||
      requirement.pack_version != candidate.pack_version {
      issues.push(CandidateBindingMismatch(requirement.requirement_id))
    }
    if requirement.required {
      match
        find_requirement_result(
          candidate.requirement_results,
          requirement.requirement_id,
        ) {
        None => issues.push(MissingRequirement(requirement.requirement_id))
        Some(result) => {
          if !result.satisfied {
            issues.push(RequirementFailed(requirement.requirement_id))
          }
          validate_evidence_ids(
            "requirement \{requirement.requirement_id}",
            result.evidence_refs,
            candidate.evidence_refs,
            issues,
          )
        }
      }
    }
  }
}

///|
fn validate_checklists(
  candidate : DeliverableCandidate,
  issues : Array[BookkeeperIssue],
) -> Unit {
  if candidate.checklist_results.is_empty() {
    issues.push(MissingReference("checklist results"))
  }
  for result in candidate.checklist_results {
    if result.candidate_id != candidate.candidate_id ||
      result.candidate_version != candidate.candidate_version ||
      result.candidate_digest != candidate.candidate_digest {
      issues.push(CandidateBindingMismatch("checklist:\{result.checklist_id}"))
    }
    if !result.passed {
      issues.push(RequirementFailed("checklist:\{result.checklist_id}"))
    }
    validate_evidence_ids(
      "checklist \{result.checklist_id}",
      result.evidence_refs,
      candidate.evidence_refs,
      issues,
    )
  }
}

///|
fn authority_receipt_exists(
  candidate : DeliverableCandidate,
  receipt_id : String,
) -> Bool {
  candidate.authority_receipts.any(fn(receipt) {
    receipt.receipt_id == receipt_id && receipt.complete
  })
}

///|
fn validate_authorization(
  label : String,
  authorization : AuthorizationState,
  candidate : DeliverableCandidate,
  issues : Array[BookkeeperIssue],
) -> Unit {
  match authorization {
    NotRequested => ()
    Unauthorized(_) => issues.push(UnauthorizedAction(label))
    Authorized(receipt_id) =>
      if receipt_id.is_blank() ||
        !authority_receipt_exists(candidate, receipt_id) {
        issues.push(UnauthorizedAction(label))
      }
  }
}

///|
fn validate_reviewer(
  candidate : DeliverableCandidate,
  issues : Array[BookkeeperIssue],
) -> Unit {
  let reviewer = candidate.reviewer
  if reviewer.reviewer_id.is_blank() ||
    reviewer.authority_ref.is_blank() ||
    !reviewer.authorized ||
    !authority_receipt_exists(candidate, reviewer.authority_ref) {
    issues.push(ReviewerAuthorityMissing)
  }
  validate_evidence_ids(
    "reviewer",
    reviewer.evidence_refs,
    candidate.evidence_refs,
    issues,
  )
}

///|
fn validate_candidate(
  candidate : DeliverableCandidate,
) -> Array[BookkeeperIssue] {
  let issues : Array[BookkeeperIssue] = []
  if candidate.contract_version != bookkeeper_contract_version() {
    issues.push(InvalidContract(candidate.contract_version))
  }
  append_missing_text(issues, candidate.candidate_id, "candidate id")
  append_missing_text(issues, candidate.candidate_version, "candidate version")
  append_missing_text(issues, candidate.candidate_digest, "candidate digest")
  append_missing_text(issues, candidate.proposed_bundle_id, "bundle id")
  append_missing_text(
    issues,
    candidate.proposed_bundle_version,
    "bundle version",
  )
  append_missing_text(issues, candidate.pack_id, "pack id")
  append_missing_text(issues, candidate.pack_version, "pack version")
  append_missing_text(issues, candidate.retention_ref, "retention reference")
  append_missing_text(issues, candidate.rollback_ref, "rollback reference")
  validate_evidence_references(
    candidate.evidence_refs,
    candidate.provenance_refs,
    issues,
  )
  validate_artifacts(candidate, issues)
  validate_requirements(candidate, issues)
  validate_receipt_group(
    "workflow",
    candidate.workflow_receipts,
    candidate,
    issues,
  )
  validate_receipt_group("gate", candidate.gate_receipts, candidate, issues)
  validate_receipt_group("cost", candidate.cost_receipts, candidate, issues)
  validate_receipt_group(
    "authority",
    candidate.authority_receipts,
    candidate,
    issues,
  )
  validate_checklists(candidate, issues)
  validate_reviewer(candidate, issues)
  validate_receipt("release", candidate.release_receipt, candidate, issues)
  validate_receipt(
    "acceptance",
    candidate.acceptance_receipt,
    candidate,
    issues,
  )
  validate_authorization(
    "delivery",
    candidate.delivery_authorization,
    candidate,
    issues,
  )
  validate_authorization(
    "publication",
    candidate.publication_authorization,
    candidate,
    issues,
  )
  issues
}

///|
/// Validate exact outcome-to-bundle and outcome-to-candidate linkage.
pub fn validate_outcome_linkage(
  bundle : DeliverableBundle,
  observation : OutcomeObservation,
) -> ReadOnlyArray[BookkeeperIssue] {
  let issues : Array[BookkeeperIssue] = []
  if observation.contract_version != bookkeeper_contract_version() {
    issues.push(InvalidContract(observation.contract_version))
  }
  append_missing_text(issues, observation.observation_id, "observation id")
  append_missing_text(
    issues,
    observation.observation_version,
    "observation version",
  )
  if observation.bundle_id != bundle.bundle_id {
    issues.push(OutcomeLinkMismatch("bundle id"))
  }
  if observation.bundle_version != bundle.bundle_version {
    issues.push(OutcomeLinkMismatch("bundle version"))
  }
  if observation.bundle_digest != bundle.bundle_digest {
    issues.push(OutcomeLinkMismatch("bundle digest"))
  }
  if observation.candidate_id != bundle.candidate_id {
    issues.push(OutcomeLinkMismatch("candidate id"))
  }
  if observation.candidate_version != bundle.candidate_version {
    issues.push(OutcomeLinkMismatch("candidate version"))
  }
  if observation.candidate_digest != bundle.candidate_digest {
    issues.push(OutcomeLinkMismatch("candidate digest"))
  }
  if observation.evidence_refs.is_empty() {
    issues.push(MissingReference("outcome evidence"))
  }
  ReadOnlyArray::from_array(issues)
}

///|
/// True when the observation points to this exact bundle and candidate version.
pub fn DeliverableBundle::matches_outcome(
  self : DeliverableBundle,
  observation : OutcomeObservation,
) -> Bool {
  validate_outcome_linkage(self, observation).is_empty()
}

///|
fn candidate_to_bundle(
  candidate : DeliverableCandidate,
  decision_id : String,
  decided_at : Int,
) -> DeliverableBundle {
  {
    contract_version: bookkeeper_contract_version(),
    bundle_id: candidate.proposed_bundle_id,
    bundle_version: candidate.proposed_bundle_version,
    bundle_digest: candidate.proposed_bundle_digest,
    decision_id,
    decided_at,
    candidate_id: candidate.candidate_id,
    candidate_version: candidate.candidate_version,
    candidate_digest: candidate.candidate_digest,
    pack_id: candidate.pack_id,
    pack_version: candidate.pack_version,
    artifacts: candidate.artifacts,
    acceptance_requirements: candidate.acceptance_requirements,
    requirement_results: candidate.requirement_results,
    evidence_refs: candidate.evidence_refs,
    provenance_refs: candidate.provenance_refs,
    workflow_receipts: candidate.workflow_receipts,
    gate_receipts: candidate.gate_receipts,
    cost_receipts: candidate.cost_receipts,
    authority_receipts: candidate.authority_receipts,
    checklist_results: candidate.checklist_results,
    reviewer: candidate.reviewer,
    release_receipt: candidate.release_receipt,
    acceptance_receipt: candidate.acceptance_receipt,
    retention_ref: candidate.retention_ref,
    rollback_ref: candidate.rollback_ref,
    delivery_authorization: candidate.delivery_authorization,
    publication_authorization: candidate.publication_authorization,
  }
}

///|
/// Finalize a candidate deterministically. Accept fails closed: any incomplete
/// requirement, mismatched binding, missing authority, unauthorized action, or
/// mismatched supplied outcome becomes `Revise` and carries no bundle. Requested
/// reject, revise, and escalate decisions are always non-deliverable.
pub fn finalize_deliverable(
  candidate : DeliverableCandidate,
  requested~ : BookkeeperDisposition,
  decision_id~ : String,
  decided_at~ : Int,
  outcome? : OutcomeObservation,
) -> BookkeeperDecision {
  let reviewer_id = candidate.reviewer.reviewer_id
  let reviewer_authority_ref = candidate.reviewer.authority_ref
  if requested != Accept {
    return {
      contract_version: bookkeeper_contract_version(),
      decision_id,
      decided_at,
      requested,
      disposition: requested,
      candidate_id: candidate.candidate_id,
      candidate_version: candidate.candidate_version,
      candidate_digest: candidate.candidate_digest,
      reviewer_id,
      reviewer_authority_ref,
      issues: ReadOnlyArray::default(),
      bundle: None,
    }
  }
  let issues = validate_candidate(candidate)
  append_missing_text(issues, decision_id, "decision id")
  let bundle = candidate_to_bundle(candidate, decision_id, decided_at)
  match outcome {
    Some(observation) =>
      for issue in validate_outcome_linkage(bundle, observation) {
        issues.push(issue)
      }
    None => ()
  }
  if !issues.is_empty() {
    return {
      contract_version: bookkeeper_contract_version(),
      decision_id,
      decided_at,
      requested,
      disposition: Revise,
      candidate_id: candidate.candidate_id,
      candidate_version: candidate.candidate_version,
      candidate_digest: candidate.candidate_digest,
      reviewer_id,
      reviewer_authority_ref,
      issues: ReadOnlyArray::from_array(issues),
      bundle: None,
    }
  }
  {
    contract_version: bookkeeper_contract_version(),
    decision_id,
    decided_at,
    requested,
    disposition: Accept,
    candidate_id: candidate.candidate_id,
    candidate_version: candidate.candidate_version,
    candidate_digest: candidate.candidate_digest,
    reviewer_id,
    reviewer_authority_ref,
    issues: ReadOnlyArray::default(),
    bundle: Some(bundle),
  }
}
