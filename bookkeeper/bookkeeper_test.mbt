///|
fn evidence_reference() -> @bookkeeper.EvidenceReference {
  {
    reference_id: "evidence-1",
    digest: "sha256:evidence",
    provenance_ref: "provenance-1",
  }
}

///|
fn binding_receipt(id : String) -> @bookkeeper.BindingReceipt {
  {
    receipt_id: id,
    candidate_id: "candidate-1",
    candidate_version: "3",
    candidate_digest: "sha256:candidate",
    complete: true,
    evidence_refs: ["evidence-1"],
  }
}

///|
fn acceptance_requirements() -> ReadOnlyArray[@bookkeeper.AcceptanceRequirement] {
  @bookkeeper.project_acceptance_requirements(
    pack_id="pack-1",
    pack_version="2",
    [
      {
        requirement_id: "requirement-evidence",
        kind: Evidence,
        description: "Evidence is complete.",
        required: true,
      },
      {
        requirement_id: "requirement-checklist",
        kind: Checklist,
        description: "Checklist passed.",
        required: true,
      },
    ],
  )
}

///|
fn valid_candidate(
  observed_digest? : String = "sha256:artifact",
  observed_version? : String = "5",
  include_checklist_requirement? : Bool = true,
  delivery_authorization? : @bookkeeper.AuthorizationState = Authorized(
    "authority-delivery",
  ),
  reviewer_authorized? : Bool = true,
) -> @bookkeeper.DeliverableCandidate {
  let requirement_results : Array[@bookkeeper.RequirementResult] = [
    {
      requirement_id: "requirement-evidence",
      satisfied: true,
      evidence_refs: ["evidence-1"],
    },
  ]
  if include_checklist_requirement {
    requirement_results.push({
      requirement_id: "requirement-checklist",
      satisfied: true,
      evidence_refs: ["evidence-1"],
    })
  }
  @bookkeeper.DeliverableCandidate::new(
    candidate_id="candidate-1",
    candidate_version="3",
    candidate_digest="sha256:candidate",
    proposed_bundle_id="bundle-1",
    proposed_bundle_version="7",
    pack_id="pack-1",
    pack_version="2",
    artifacts=[
      {
        artifact_id: "artifact-1",
        candidate_id: "candidate-1",
        candidate_version: "3",
        declared_version: "5",
        observed_version,
        declared_digest: "sha256:artifact",
        observed_digest,
      },
    ],
    acceptance_requirements=acceptance_requirements(),
    requirement_results~,
    evidence_refs=[evidence_reference()],
    provenance_refs=["provenance-1"],
    workflow_receipts=[binding_receipt("workflow-1")],
    gate_receipts=[binding_receipt("gate-1")],
    cost_receipts=[binding_receipt("cost-1")],
    authority_receipts=[
      binding_receipt("authority-reviewer"),
      binding_receipt("authority-delivery"),
    ],
    checklist_results=[
      {
        checklist_id: "checklist-1",
        candidate_id: "candidate-1",
        candidate_version: "3",
        candidate_digest: "sha256:candidate",
        passed: true,
        evidence_refs: ["evidence-1"],
      },
    ],
    reviewer={
      reviewer_id: "reviewer-1",
      authority_ref: "authority-reviewer",
      authorized: reviewer_authorized,
      evidence_refs: ["evidence-1"],
    },
    release_receipt=binding_receipt("release-1"),
    acceptance_receipt=binding_receipt("acceptance-1"),
    retention_ref="retention-1",
    rollback_ref="rollback-1",
    delivery_authorization~,
    publication_authorization=NotRequested,
  )
}

///|
fn matching_outcome() -> @bookkeeper.OutcomeObservation {
  @bookkeeper.OutcomeObservation::new(
    observation_id="outcome-1",
    observation_version="1",
    bundle_id="bundle-1",
    bundle_version="7",
    candidate_id="candidate-1",
    candidate_version="3",
    candidate_digest="sha256:candidate",
    observed_at=101,
    summary="Observed result.",
    evidence_refs=[evidence_reference()],
  )
}

///|
test "pack requirement projection preserves identity version and order" {
  let first = acceptance_requirements()
  let replay = acceptance_requirements()
  assert_true(first == replay)
  assert_eq(first[0].pack_id, "pack-1")
  assert_eq(first[0].pack_version, "2")
  assert_eq(first[0].requirement_id, "requirement-evidence")
  assert_eq(first[1].requirement_id, "requirement-checklist")
}

///|
test "public acceptance freezes bundle and exact outcome linkage" {
  let outcome = matching_outcome()
  let decision = @bookkeeper.finalize_deliverable(
    valid_candidate(),
    requested=Accept,
    decision_id="decision-1",
    decided_at=100,
    outcome~,
  )
  assert_true(decision.is_deliverable())
  assert_true(decision.disposition == Accept)
  let bundle = decision.accepted_bundle().unwrap()
  assert_eq(bundle.bundle_id, "bundle-1")
  assert_eq(bundle.bundle_version, "7")
  assert_eq(bundle.candidate_version, "3")
  assert_eq(bundle.artifacts[0].declared_version, "5")
  assert_eq(bundle.artifacts[0].observed_version, "5")
  assert_eq(bundle.artifacts[0].declared_digest, "sha256:artifact")
  assert_eq(bundle.artifacts[0].observed_digest, "sha256:artifact")
  assert_eq(bundle.reviewer.authority_ref, "authority-reviewer")
  assert_eq(bundle.retention_ref, "retention-1")
  assert_eq(bundle.rollback_ref, "rollback-1")
  assert_true(bundle.matches_outcome(outcome))
  assert_true(@bookkeeper.validate_outcome_linkage(bundle, outcome).is_empty())
}

///|
test "acceptance replay is deterministic" {
  let candidate = valid_candidate()
  let outcome = matching_outcome()
  let first = @bookkeeper.finalize_deliverable(
    candidate,
    requested=Accept,
    decision_id="decision-replay",
    decided_at=100,
    outcome~,
  )
  let replay = @bookkeeper.finalize_deliverable(
    candidate,
    requested=Accept,
    decision_id="decision-replay",
    decided_at=100,
    outcome~,
  )
  assert_true(first == replay)
}

///|
test "acceptance fails closed on artifact digest mismatch" {
  let decision = @bookkeeper.finalize_deliverable(
    valid_candidate(observed_digest="sha256:different"),
    requested=Accept,
    decision_id="decision-digest",
    decided_at=100,
  )
  assert_false(decision.is_deliverable())
  assert_true(decision.bundle is None)
  assert_true(decision.disposition == Revise)
  assert_true(
    decision.issues.any(fn(issue) {
      issue is ArtifactDigestMismatch("artifact-1")
    }),
  )
}

///|
test "acceptance fails closed on artifact version mismatch" {
  let decision = @bookkeeper.finalize_deliverable(
    valid_candidate(observed_version="6"),
    requested=Accept,
    decision_id="decision-version",
    decided_at=100,
  )
  assert_false(decision.is_deliverable())
  assert_true(
    decision.issues.any(fn(issue) {
      issue is ArtifactVersionMismatch("artifact-1")
    }),
  )
}

///|
test "acceptance fails closed on missing projected requirement" {
  let decision = @bookkeeper.finalize_deliverable(
    valid_candidate(include_checklist_requirement=false),
    requested=Accept,
    decision_id="decision-requirement",
    decided_at=100,
  )
  assert_false(decision.is_deliverable())
  assert_true(
    decision.issues.any(fn(issue) {
      issue is MissingRequirement("requirement-checklist")
    }),
  )
}

///|
test "acceptance fails closed on unauthorized delivery" {
  let decision = @bookkeeper.finalize_deliverable(
    valid_candidate(delivery_authorization=Unauthorized("not authorized")),
    requested=Accept,
    decision_id="decision-delivery",
    decided_at=100,
  )
  assert_false(decision.is_deliverable())
  assert_true(
    decision.issues.any(fn(issue) { issue is UnauthorizedAction("delivery") }),
  )
}

///|
test "acceptance fails closed without reviewer authority" {
  let decision = @bookkeeper.finalize_deliverable(
    valid_candidate(reviewer_authorized=false),
    requested=Accept,
    decision_id="decision-reviewer",
    decided_at=100,
  )
  assert_false(decision.is_deliverable())
  assert_true(decision.issues.contains(ReviewerAuthorityMissing))
}

///|
test "acceptance fails closed on outcome version mismatch" {
  let mismatched = @bookkeeper.OutcomeObservation::new(
    observation_id="outcome-mismatch",
    observation_version="1",
    bundle_id="bundle-1",
    bundle_version="8",
    candidate_id="candidate-1",
    candidate_version="3",
    candidate_digest="sha256:candidate",
    observed_at=101,
    summary="Observed result.",
    evidence_refs=[evidence_reference()],
  )
  let decision = @bookkeeper.finalize_deliverable(
    valid_candidate(),
    requested=Accept,
    decision_id="decision-outcome",
    decided_at=100,
    outcome=mismatched,
  )
  assert_false(decision.is_deliverable())
  assert_true(
    decision.issues.any(fn(issue) {
      issue is OutcomeLinkMismatch("bundle version")
    }),
  )
}

///|
test "reject revise and escalate remain non-deliverable" {
  for disposition in [@bookkeeper.Reject, Revise, Escalate] {
    let decision = @bookkeeper.finalize_deliverable(
      valid_candidate(),
      requested=disposition,
      decision_id="decision-non-accept",
      decided_at=100,
    )
    assert_true(decision.disposition == disposition)
    assert_false(decision.is_deliverable())
    assert_true(decision.bundle is None)
  }
}

///|
test "gap assessment keeps all three dimensions explicit" {
  let assessment = @bookkeeper.ThreeGapAssessment::new(
    assessment_id="assessment-1",
    assessment_version="1",
    subject_id="subject-1",
    subject_version="2",
    owner_route="owner-1",
    information_gap={
      present: true,
      severity: 2,
      summary: "More facts are required.",
      evidence_refs: ["evidence-1"],
    },
    recognition_gap={
      present: false,
      severity: 0,
      summary: "Pattern recognized.",
      evidence_refs: ["evidence-1"],
    },
    decisiveness_gap={
      present: true,
      severity: 1,
      summary: "Decision threshold is unmet.",
      evidence_refs: ["evidence-1"],
    },
  )
  assert_true(assessment.information_gap.present)
  assert_false(assessment.recognition_gap.present)
  assert_true(assessment.decisiveness_gap.present)
}

///|
test "capability learning is versioned reviewed owner-routed and non-applying" {
  let proposal = @bookkeeper.CapabilityProposal::new(
    proposal_id="proposal-1",
    proposal_version="2",
    capability_id="capability-1",
    capability_version="4",
    owner_route="owner-1",
    change_digest="sha256:change",
    summary="Proposed reviewed improvement.",
    evidence_refs=[evidence_reference()],
    supersedes_version="3",
  )
  assert_true(proposal.is_reviewable())
  assert_true(proposal.review_required)
  assert_false(proposal.self_application_allowed)
  let receipt = @bookkeeper.review_capability_proposal(
    proposal,
    receipt_id="learning-1",
    receipt_version="1",
    reviewer={
      reviewer_id: "reviewer-1",
      authority_ref: "authority-reviewer",
      authorized: true,
      evidence_refs: ["evidence-1"],
    },
    requested=Accept,
    evidence_refs=[evidence_reference()],
  )
  assert_true(receipt.disposition == Accept)
  assert_eq(receipt.owner_route, "owner-1")
  assert_true(receipt.review_complete)
  assert_false(receipt.permits_self_modification())
  assert_false(receipt.self_modification_applied)
}

///|
fn canonical_evidence() -> @bookkeeper.VersionedEvidenceReference {
  {
    reference_id: "evidence-1",
    reference_version: "1",
    digest: "sha256:evidence",
    provenance_ref: "provenance-1",
  }
}

///|
fn canonical_outcome() -> @bookkeeper.OutcomeObservation {
  @bookkeeper.OutcomeObservation::new(
    observation_id="outcome-1",
    observation_version="1",
    observation_digest="sha256:outcome",
    bundle_id="bundle-1",
    bundle_version="7",
    bundle_digest="sha256:candidate",
    candidate_id="candidate-1",
    candidate_version="3",
    candidate_digest="sha256:candidate",
    observed_at=101,
    summary="Observed result.",
    evidence_refs=[evidence_reference()],
  )
}

///|
fn exact_deliverable() -> @bookkeeper.DeliverableReference {
  {
    bundle_id: "bundle-1",
    bundle_version: "7",
    bundle_digest: "sha256:candidate",
    candidate_id: "candidate-1",
    candidate_version: "3",
    candidate_digest: "sha256:candidate",
  }
}

///|
fn outcome_evidence_record(
  id : String,
  kind : @bookkeeper.OutcomeEvidenceKind,
  deliverable? : @bookkeeper.DeliverableReference = exact_deliverable(),
) -> @bookkeeper.OutcomeEvidenceRecord {
  @bookkeeper.OutcomeEvidenceRecord::new(
    record={ record_id: id, record_version: "1", record_digest: "sha256:\{id}" },
    kind~,
    deliverable~,
    observation={
      record_id: "outcome-1",
      record_version: "1",
      record_digest: "sha256:outcome",
    },
    summary="Versioned outcome evidence.",
    evidence_refs=[canonical_evidence()],
  )
}

///|
fn finalized_bundle() -> @bookkeeper.DeliverableBundle {
  @bookkeeper.finalize_deliverable(
    valid_candidate(),
    requested=Accept,
    decision_id="decision-canonical",
    decided_at=100,
    outcome=canonical_outcome(),
  )
  .accepted_bundle()
  .unwrap()
}

///|
fn complete_outcome_evidence() -> Array[@bookkeeper.OutcomeEvidenceRecord] {
  [
    outcome_evidence_record("metric", MetricEvidence),
    outcome_evidence_record("feedback", FeedbackEvidence),
    outcome_evidence_record("operator-time", OperatorTimeEvidence),
    outcome_evidence_record("defect", DefectEvidence),
    outcome_evidence_record("cost", CostEvidence),
  ]
}

///|
test "canonical outcome evidence binds all categories with stable exact dedup" {
  let bundle = finalized_bundle()
  let records = complete_outcome_evidence()
  records.push(outcome_evidence_record("feedback", FeedbackEvidence))
  let first = @bookkeeper.bind_outcome_evidence(
    bundle,
    canonical_outcome(),
    binding={
      record_id: "outcome-binding-1",
      record_version: "1",
      record_digest: "sha256:outcome-binding",
    },
    records,
  )
  let replay = @bookkeeper.bind_outcome_evidence(
    bundle,
    canonical_outcome(),
    binding={
      record_id: "outcome-binding-1",
      record_version: "1",
      record_digest: "sha256:outcome-binding",
    },
    complete_outcome_evidence().rev(),
  )
  assert_true(first.is_bound())
  assert_true(replay.is_bound())
  assert_eq(first.binding.unwrap().records.length(), 5)
  assert_true(first.binding == replay.binding)
  assert_eq(first.binding.unwrap().records[0].record.record_id, "cost")
}

///|
test "canonical outcome evidence fails closed on exact digest mismatch" {
  let records = complete_outcome_evidence()
  records[0] = outcome_evidence_record("metric", MetricEvidence, deliverable={
    ..exact_deliverable(),
    bundle_digest: "sha256:different",
  })
  let decision = @bookkeeper.bind_outcome_evidence(
    finalized_bundle(),
    canonical_outcome(),
    binding={
      record_id: "outcome-binding-mismatch",
      record_version: "1",
      record_digest: "sha256:outcome-binding-mismatch",
    },
    records,
  )
  assert_false(decision.is_bound())
  assert_true(decision.binding is None)
  assert_true(
    decision.issues.contains(ExactLinkMismatch("metric bundle digest")),
  )
}

///|
test "canonical outcome evidence requires every typed evidence category" {
  let records = complete_outcome_evidence()
  ignore(records.pop())
  let decision = @bookkeeper.bind_outcome_evidence(
    finalized_bundle(),
    canonical_outcome(),
    binding={
      record_id: "outcome-binding-incomplete",
      record_version: "1",
      record_digest: "sha256:outcome-binding-incomplete",
    },
    records,
  )
  assert_false(decision.is_bound())
  assert_true(
    decision.issues.contains(MissingOutcomeEvidenceKind(CostEvidence)),
  )
}

///|
fn gap_finding(
  id : String,
  gap_class : @bookkeeper.ThreeGapClass,
  severity? : Int = 3,
  owner_route? : String = "owner-1",
  finding_version? : String = "1",
  finding_digest? : String = "",
) -> @bookkeeper.CanonicalGapFinding {
  let resolved_digest = if finding_digest.is_blank() {
    "sha256:\{id}"
  } else {
    finding_digest
  }
  @bookkeeper.CanonicalGapFinding::new(
    finding={
      record_id: id,
      record_version: finding_version,
      record_digest: resolved_digest,
    },
    learning_key={
      record_id: "learning-pattern-1",
      record_version: "2",
      record_digest: "sha256:learning-pattern",
    },
    subject={
      record_id: "outcome-1",
      record_version: "1",
      record_digest: "sha256:outcome",
    },
    gap_class~,
    severity~,
    owner_route~,
    summary="Reviewed generic gap.",
    evidence_refs=[canonical_evidence()],
  )
}

///|
fn finding_receipt(id : String) -> @bookkeeper.VersionedRecordReference {
  {
    record_id: "receipt-\{id}",
    record_version: "1",
    record_digest: "sha256:receipt-\{id}",
  }
}

///|
fn finding_reviewer() -> @bookkeeper.ReviewerAuthority {
  {
    reviewer_id: "human-reviewer-1",
    authority_ref: "authority-reviewer",
    authorized: true,
    evidence_refs: ["evidence-1"],
  }
}

///|
fn finding_review_attestation(
  finding : @bookkeeper.CanonicalGapFinding,
  receipt : @bookkeeper.VersionedRecordReference,
  reviewer : @bookkeeper.ReviewerAuthority,
  reviewer_kind? : @bookkeeper.ReviewerKind = Human,
) -> @bookkeeper.FindingReviewAuthorityAttestation {
  @bookkeeper.FindingReviewAuthorityAttestation::new(
    attestation={
      record_id: "attestation-\{receipt.record_id}",
      record_version: "1",
      record_digest: "sha256:attestation-\{receipt.record_id}",
    },
    finding,
    receipt~,
    reviewer_kind~,
    reviewer~,
    evidence_refs=[canonical_evidence()],
    requested=Accept,
  )
}

///|
fn review_finding(
  id : String,
  gap_class : @bookkeeper.ThreeGapClass,
  severity? : Int = 3,
) -> @bookkeeper.ReviewedGapFinding {
  let finding = gap_finding(id, gap_class, severity~)
  let receipt = finding_receipt(id)
  let reviewer = finding_reviewer()
  @bookkeeper.review_three_gap_finding(
    finding,
    receipt~,
    reviewer~,
    requested=Accept,
    Some(finding_review_attestation(finding, receipt, reviewer)),
  ).reviewed_finding.unwrap()
}

///|
fn promotion_policy(
  minimum_reviewed_findings? : Int = 3,
) -> @bookkeeper.CapabilityPromotionPolicy {
  @bookkeeper.CapabilityPromotionPolicy::new(
    policy={
      record_id: "policy-1",
      record_version: "4",
      record_digest: "sha256:policy",
    },
    minimum_reviewed_findings~,
    minimum_severity=2,
    required_gap_classes=[InformationGap, RecognitionGap, DecisivenessGap],
    evidence_refs=[canonical_evidence()],
  )
}

///|
fn aggregate(
  findings : ArrayView[@bookkeeper.ReviewedGapFinding],
) -> @bookkeeper.CapabilityAggregationDecision {
  @bookkeeper.aggregate_capability_proposal(
    promotion_policy(),
    findings,
    proposal_id="proposal-canonical",
    proposal_version="1",
    capability_id="capability-1",
    capability_version="5",
    owner_route="owner-1",
    proposal_digest="sha256:proposal-canonical",
    summary="Generic capability change proposal.",
  )
}

///|
test "fast loop classifies transitions and records no side effects" {
  for
    item in [
      (@bookkeeper.InformationGap, @bookkeeper.UnknownToKnown, "information"),
      (RecognitionGap, KnownToMatters, "recognition"),
      (DecisivenessGap, MattersToAct, "decisiveness"),
    ] {
    let (gap_class, transition, id) = item
    let finding = gap_finding("finding-\{id}", gap_class)
    let receipt = finding_receipt(id)
    let reviewer = finding_reviewer()
    let decision = @bookkeeper.review_three_gap_finding(
      finding,
      receipt~,
      reviewer~,
      requested=Accept,
      Some(finding_review_attestation(finding, receipt, reviewer)),
    )
    assert_true(decision.is_reviewed())
    assert_true(decision.receipt.transition == transition)
    assert_false(decision.receipt.has_side_effects())
  }
}

///|
test "fast loop fails closed without named authorized reviewer" {
  let finding = gap_finding("finding-unauthorized", InformationGap)
  let receipt = finding_receipt("unauthorized")
  let reviewer : @bookkeeper.ReviewerAuthority = {
    reviewer_id: "",
    authority_ref: "authority-reviewer",
    authorized: true,
    evidence_refs: ["evidence-1"],
  }
  let decision = @bookkeeper.review_three_gap_finding(
    finding,
    receipt~,
    reviewer~,
    requested=Accept,
    Some(finding_review_attestation(finding, receipt, reviewer)),
  )
  assert_false(decision.is_reviewed())
  assert_true(decision.reviewed_finding is None)
  assert_true(decision.receipt.disposition == Revise)
  assert_true(decision.issues.contains(UnauthorizedLearningReview))
  assert_false(decision.receipt.has_side_effects())
}

///|
test "fast loop fails closed without a review attestation" {
  let finding = gap_finding("finding-missing-attestation", InformationGap)
  let receipt = finding_receipt("missing-attestation")
  let decision = @bookkeeper.review_three_gap_finding(
    finding,
    receipt~,
    reviewer=finding_reviewer(),
    requested=Accept,
    None,
  )
  assert_false(decision.is_reviewed())
  assert_true(decision.reviewed_finding is None)
  assert_true(decision.receipt.disposition == Revise)
  assert_true(decision.issues.contains(ReviewAttestationMissing))
  assert_false(decision.receipt.has_side_effects())
}

///|
test "fast loop rejects authorized non-human attestations" {
  for reviewer_kind in [@bookkeeper.Automation, Agent, System] {
    let finding = gap_finding("finding-non-human", RecognitionGap)
    let receipt = finding_receipt("non-human")
    let reviewer : @bookkeeper.ReviewerAuthority = {
      reviewer_id: "authorized-non-human-reviewer",
      authority_ref: "authority-non-human-reviewer",
      authorized: true,
      evidence_refs: ["evidence-1"],
    }
    let decision = @bookkeeper.review_three_gap_finding(
      finding,
      receipt~,
      reviewer~,
      requested=Accept,
      Some(
        finding_review_attestation(finding, receipt, reviewer, reviewer_kind~),
      ),
    )
    assert_false(decision.is_reviewed())
    assert_true(decision.reviewed_finding is None)
    assert_true(
      decision.issues.contains(NonHumanReviewAttestation(reviewer_kind)),
    )
    assert_false(decision.receipt.has_side_effects())
  }
}

///|
test "fast loop rejects an unnamed review attestation" {
  let finding = gap_finding("finding-unnamed-attestation", DecisivenessGap)
  let receipt = finding_receipt("unnamed-attestation")
  let reviewer = finding_reviewer()
  let attestation = @bookkeeper.FindingReviewAuthorityAttestation::new(
    attestation={
      record_id: "",
      record_version: "1",
      record_digest: "sha256:unnamed-attestation",
    },
    finding,
    receipt~,
    reviewer_kind=Human,
    reviewer~,
    evidence_refs=[canonical_evidence()],
    requested=Accept,
  )
  let decision = @bookkeeper.review_three_gap_finding(
    finding,
    receipt~,
    reviewer~,
    requested=Accept,
    Some(attestation),
  )
  assert_false(decision.is_reviewed())
  assert_true(decision.reviewed_finding is None)
  assert_true(
    decision.issues.contains(
      MissingLearningReference("finding review authority attestation id"),
    ),
  )
  assert_false(decision.receipt.has_side_effects())
}

///|
test "fast loop rejects an unauthorized review attestation" {
  let finding = gap_finding("finding-revoked-attestation", InformationGap)
  let receipt = finding_receipt("revoked-attestation")
  let reviewer : @bookkeeper.ReviewerAuthority = {
    reviewer_id: "reviewer-revoked",
    authority_ref: "authority-reviewer-revoked",
    authorized: false,
    evidence_refs: ["evidence-1"],
  }
  let decision = @bookkeeper.review_three_gap_finding(
    finding,
    receipt~,
    reviewer~,
    requested=Accept,
    Some(finding_review_attestation(finding, receipt, reviewer)),
  )
  assert_false(decision.is_reviewed())
  assert_true(decision.reviewed_finding is None)
  assert_true(decision.issues.contains(UnauthorizedLearningReview))
  assert_false(decision.receipt.has_side_effects())
}

///|
test "fast loop rejects a stale receipt attestation" {
  let finding = gap_finding("finding-stale-receipt", InformationGap)
  let current_receipt = finding_receipt("stale-receipt")
  let stale_receipt : @bookkeeper.VersionedRecordReference = {
    record_id: current_receipt.record_id,
    record_version: "0",
    record_digest: "sha256:stale-receipt",
  }
  let reviewer = finding_reviewer()
  let attestation = finding_review_attestation(finding, stale_receipt, reviewer)
  let decision = @bookkeeper.review_three_gap_finding(
    finding,
    receipt=current_receipt,
    reviewer~,
    requested=Accept,
    Some(attestation),
  )
  assert_false(decision.is_reviewed())
  assert_true(decision.reviewed_finding is None)
  assert_true(
    decision.issues.contains(ReviewAttestationMismatch("learning receipt")),
  )
  assert_false(decision.receipt.has_side_effects())
}

///|
test "fast loop rejects a stale finding attestation" {
  let stale_finding = gap_finding("finding-stale-binding", RecognitionGap)
  let current_finding = gap_finding(
    "finding-stale-binding",
    RecognitionGap,
    finding_version="2",
    finding_digest="sha256:finding-current-binding",
  )
  let receipt = finding_receipt("stale-binding")
  let reviewer = finding_reviewer()
  let attestation = finding_review_attestation(stale_finding, receipt, reviewer)
  let decision = @bookkeeper.review_three_gap_finding(
    current_finding,
    receipt~,
    reviewer~,
    requested=Accept,
    Some(attestation),
  )
  assert_false(decision.is_reviewed())
  assert_true(decision.reviewed_finding is None)
  assert_true(decision.issues.contains(ReviewAttestationMismatch("finding")))
  assert_false(decision.receipt.has_side_effects())
}

///|
test "fast loop rejects an exact evidence-set mismatch" {
  let finding = gap_finding("finding-stale-evidence", DecisivenessGap)
  let receipt = finding_receipt("stale-evidence")
  let reviewer = finding_reviewer()
  let attestation = @bookkeeper.FindingReviewAuthorityAttestation::new(
    attestation={
      record_id: "attestation-stale-evidence",
      record_version: "1",
      record_digest: "sha256:attestation-stale-evidence",
    },
    finding,
    receipt~,
    reviewer_kind=Human,
    reviewer~,
    evidence_refs=[
      {
        reference_id: "evidence-1",
        reference_version: "0",
        digest: "sha256:evidence-stale",
        provenance_ref: "provenance-1",
      },
    ],
    requested=Accept,
  )
  let decision = @bookkeeper.review_three_gap_finding(
    finding,
    receipt~,
    reviewer~,
    requested=Accept,
    Some(attestation),
  )
  assert_false(decision.is_reviewed())
  assert_true(decision.reviewed_finding is None)
  assert_true(decision.issues.contains(ReviewAttestationMismatch("evidence")))
  assert_false(decision.receipt.has_side_effects())
}

///|
test "fast loop rejects a stale requested disposition attestation" {
  let finding = gap_finding("finding-stale-disposition", InformationGap)
  let receipt = finding_receipt("stale-disposition")
  let reviewer = finding_reviewer()
  let attestation = @bookkeeper.FindingReviewAuthorityAttestation::new(
    attestation={
      record_id: "attestation-stale-disposition",
      record_version: "1",
      record_digest: "sha256:attestation-stale-disposition",
    },
    finding,
    receipt~,
    reviewer_kind=Human,
    reviewer~,
    evidence_refs=[canonical_evidence()],
    requested=Reject,
  )
  let decision = @bookkeeper.review_three_gap_finding(
    finding,
    receipt~,
    reviewer~,
    requested=Accept,
    Some(attestation),
  )
  assert_false(decision.is_reviewed())
  assert_true(decision.reviewed_finding is None)
  assert_true(
    decision.issues.contains(ReviewAttestationMismatch("requested disposition")),
  )
  assert_false(decision.receipt.has_side_effects())
}

///|
test "slow loop is sorted deduplicated idempotent and threshold governed" {
  let information = review_finding("finding-b", InformationGap)
  let recognition = review_finding("finding-a", RecognitionGap)
  let decisiveness = review_finding("finding-c", DecisivenessGap)
  let first = aggregate([information, recognition, decisiveness, information])
  let replay = aggregate([decisiveness, information, recognition])
  assert_true(first.is_promoted())
  assert_true(first == replay)
  let proposal = first.proposal.unwrap()
  assert_true(proposal.is_policy_promoted())
  assert_false(proposal.self_application_allowed)
  assert_eq(proposal.source_finding_refs.length(), 3)
  assert_eq(proposal.source_finding_refs[0].record_id, "finding-a")
}

///|
test "slow loop gives explicit non-promotion reasons below threshold" {
  let decision = aggregate([
    review_finding("finding-a", InformationGap),
    review_finding("finding-b", RecognitionGap),
  ])
  assert_false(decision.is_promoted())
  assert_true(decision.proposal is None)
  assert_true(
    decision.non_promotion_reasons.contains(InsufficientReviewedFindings(3, 2)),
  )
  assert_true(
    decision.non_promotion_reasons.contains(
      MissingRequiredGapClass(DecisivenessGap),
    ),
  )
}

///|
test "named authorized review projects a generic non-applying work order" {
  let aggregation = aggregate([
    review_finding("finding-a", InformationGap),
    review_finding("finding-b", RecognitionGap),
    review_finding("finding-c", DecisivenessGap),
  ])
  let proposal = aggregation.proposal.unwrap()
  let reviewer : @bookkeeper.ReviewerAuthority = {
    reviewer_id: "human-reviewer-1",
    authority_ref: "authority-reviewer",
    authorized: true,
    evidence_refs: ["evidence-1"],
  }
  let review = @bookkeeper.review_capability_proposal(
    proposal,
    receipt_id="proposal-review-1",
    receipt_version="1",
    receipt_digest="sha256:proposal-review",
    reviewer~,
    requested=Accept,
    evidence_refs=[evidence_reference()],
  )
  let request = @bookkeeper.WorkOrderProjectionRequest::new(
    request={
      record_id: "projection-request-1",
      record_version: "1",
      record_digest: "sha256:projection-request",
    },
    work_order={
      record_id: "work-order-1",
      record_version: "1",
      record_digest: "sha256:work-order",
    },
    evidence_refs=[canonical_evidence()],
  )
  let attestation = @bookkeeper.ReviewAuthorityAttestation::new(
    attestation={
      record_id: "review-attestation-1",
      record_version: "1",
      record_digest: "sha256:review-attestation",
    },
    proposal,
    review,
    reviewer_kind=Human,
    reviewer~,
    evidence_refs=[canonical_evidence()],
    projection_request=request,
  )
  let decision = @bookkeeper.project_mooncode_work_order(
    proposal,
    review,
    request,
    Some(attestation),
  )
  assert_true(decision.is_ready())
  let work_order = decision.work_order.unwrap()
  assert_eq(work_order.owner_route, "owner-1")
  assert_eq(work_order.reviewer_id, "human-reviewer-1")
  assert_true(work_order.reviewer_kind == Human)
  assert_eq(work_order.review_receipt.record_digest, "sha256:proposal-review")
  assert_eq(
    work_order.review_attestation.record_digest,
    "sha256:review-attestation",
  )
  assert_false(work_order.side_effects_applied)
}

///|
test "legacy manual proposal cannot project to a work order" {
  let proposal = @bookkeeper.CapabilityProposal::new(
    proposal_id="proposal-legacy",
    proposal_version="1",
    capability_id="capability-1",
    capability_version="2",
    owner_route="owner-1",
    change_digest="sha256:legacy",
    summary="Legacy review-only proposal.",
    evidence_refs=[evidence_reference()],
  )
  let review = @bookkeeper.review_capability_proposal(
    proposal,
    receipt_id="legacy-review",
    receipt_version="1",
    receipt_digest="sha256:legacy-review",
    reviewer={
      reviewer_id: "human-reviewer-1",
      authority_ref: "authority-reviewer",
      authorized: true,
      evidence_refs: ["evidence-1"],
    },
    requested=Accept,
    evidence_refs=[evidence_reference()],
  )
  let request = @bookkeeper.WorkOrderProjectionRequest::new(
    request={
      record_id: "projection-request-legacy",
      record_version: "1",
      record_digest: "sha256:projection-request-legacy",
    },
    work_order={
      record_id: "work-order-legacy",
      record_version: "1",
      record_digest: "sha256:work-order-legacy",
    },
    evidence_refs=[canonical_evidence()],
  )
  let attestation = @bookkeeper.ReviewAuthorityAttestation::new(
    attestation={
      record_id: "review-attestation-legacy",
      record_version: "1",
      record_digest: "sha256:review-attestation-legacy",
    },
    proposal,
    review,
    reviewer_kind=Human,
    reviewer=review.reviewer,
    evidence_refs=[canonical_evidence()],
    projection_request=request,
  )
  let decision = @bookkeeper.project_mooncode_work_order(
    proposal,
    review,
    request,
    Some(attestation),
  )
  assert_false(decision.is_ready())
  assert_true(decision.work_order is None)
  assert_true(
    decision.issues.contains(
      WorkOrderProjectionDenied("proposal was not policy promoted"),
    ),
  )
}

///|
test "work-order projection requires named authorized human review" {
  let proposal = aggregate([
    review_finding("finding-a", InformationGap),
    review_finding("finding-b", RecognitionGap),
    review_finding("finding-c", DecisivenessGap),
  ]).proposal.unwrap()
  let review = @bookkeeper.review_capability_proposal(
    proposal,
    receipt_id="proposal-review-unauthorized",
    receipt_version="1",
    receipt_digest="sha256:proposal-review-unauthorized",
    reviewer={
      reviewer_id: "",
      authority_ref: "authority-reviewer",
      authorized: true,
      evidence_refs: ["evidence-1"],
    },
    requested=Accept,
    evidence_refs=[evidence_reference()],
  )
  let request = @bookkeeper.WorkOrderProjectionRequest::new(
    request={
      record_id: "projection-request-unauthorized",
      record_version: "1",
      record_digest: "sha256:projection-request-unauthorized",
    },
    work_order={
      record_id: "work-order-unauthorized",
      record_version: "1",
      record_digest: "sha256:work-order-unauthorized",
    },
    evidence_refs=[canonical_evidence()],
  )
  let attestation = @bookkeeper.ReviewAuthorityAttestation::new(
    attestation={
      record_id: "review-attestation-unauthorized",
      record_version: "1",
      record_digest: "sha256:review-attestation-unauthorized",
    },
    proposal,
    review,
    reviewer_kind=Human,
    reviewer=review.reviewer,
    evidence_refs=[canonical_evidence()],
    projection_request=request,
  )
  let decision = @bookkeeper.project_mooncode_work_order(
    proposal,
    review,
    request,
    Some(attestation),
  )
  assert_false(decision.is_ready())
  assert_true(decision.work_order is None)
  assert_true(decision.issues.contains(UnauthorizedLearningReview))
}

///|
test "authorized automation attestation cannot project a work order" {
  let proposal = aggregate([
    review_finding("finding-a", InformationGap),
    review_finding("finding-b", RecognitionGap),
    review_finding("finding-c", DecisivenessGap),
  ]).proposal.unwrap()
  let reviewer : @bookkeeper.ReviewerAuthority = {
    reviewer_id: "automation-reviewer-1",
    authority_ref: "authority-automation",
    authorized: true,
    evidence_refs: ["evidence-1"],
  }
  let review = @bookkeeper.review_capability_proposal(
    proposal,
    receipt_id="proposal-review-automation",
    receipt_version="1",
    receipt_digest="sha256:proposal-review-automation",
    reviewer~,
    requested=Accept,
    evidence_refs=[evidence_reference()],
  )
  let request = @bookkeeper.WorkOrderProjectionRequest::new(
    request={
      record_id: "projection-request-automation",
      record_version: "1",
      record_digest: "sha256:projection-request-automation",
    },
    work_order={
      record_id: "work-order-automation",
      record_version: "1",
      record_digest: "sha256:work-order-automation",
    },
    evidence_refs=[canonical_evidence()],
  )
  let attestation = @bookkeeper.ReviewAuthorityAttestation::new(
    attestation={
      record_id: "review-attestation-automation",
      record_version: "1",
      record_digest: "sha256:review-attestation-automation",
    },
    proposal,
    review,
    reviewer_kind=Automation,
    reviewer~,
    evidence_refs=[canonical_evidence()],
    projection_request=request,
  )
  let decision = @bookkeeper.project_mooncode_work_order(
    proposal,
    review,
    request,
    Some(attestation),
  )
  assert_false(decision.is_ready())
  assert_true(decision.work_order is None)
  assert_true(decision.issues.contains(NonHumanReviewAttestation(Automation)))
}

///|
test "work-order projection rejects a stale exact request attestation" {
  let proposal = aggregate([
    review_finding("finding-a", InformationGap),
    review_finding("finding-b", RecognitionGap),
    review_finding("finding-c", DecisivenessGap),
  ]).proposal.unwrap()
  let reviewer : @bookkeeper.ReviewerAuthority = {
    reviewer_id: "human-reviewer-1",
    authority_ref: "authority-reviewer",
    authorized: true,
    evidence_refs: ["evidence-1"],
  }
  let review = @bookkeeper.review_capability_proposal(
    proposal,
    receipt_id="proposal-review-stale-request",
    receipt_version="1",
    receipt_digest="sha256:proposal-review-stale-request",
    reviewer~,
    requested=Accept,
    evidence_refs=[evidence_reference()],
  )
  let stale_request = @bookkeeper.WorkOrderProjectionRequest::new(
    request={
      record_id: "projection-request-exact",
      record_version: "1",
      record_digest: "sha256:projection-request-stale",
    },
    work_order={
      record_id: "work-order-exact",
      record_version: "1",
      record_digest: "sha256:work-order-stale",
    },
    evidence_refs=[canonical_evidence()],
  )
  let attestation = @bookkeeper.ReviewAuthorityAttestation::new(
    attestation={
      record_id: "review-attestation-stale-request",
      record_version: "1",
      record_digest: "sha256:review-attestation-stale-request",
    },
    proposal,
    review,
    reviewer_kind=Human,
    reviewer~,
    evidence_refs=[canonical_evidence()],
    projection_request=stale_request,
  )
  let current_request = @bookkeeper.WorkOrderProjectionRequest::new(
    request={
      record_id: "projection-request-exact",
      record_version: "2",
      record_digest: "sha256:projection-request-current",
    },
    work_order={
      record_id: "work-order-exact",
      record_version: "2",
      record_digest: "sha256:work-order-current",
    },
    evidence_refs=[canonical_evidence()],
  )
  let decision = @bookkeeper.project_mooncode_work_order(
    proposal,
    review,
    current_request,
    Some(attestation),
  )
  assert_false(decision.is_ready())
  assert_true(decision.work_order is None)
  assert_true(
    decision.issues.contains(
      ReviewAttestationMismatch("work order projection request"),
    ),
  )
}

///|
test "work-order projection rejects a missing review attestation" {
  let proposal = aggregate([
    review_finding("finding-a", InformationGap),
    review_finding("finding-b", RecognitionGap),
    review_finding("finding-c", DecisivenessGap),
  ]).proposal.unwrap()
  let review = @bookkeeper.review_capability_proposal(
    proposal,
    receipt_id="proposal-review-missing-attestation",
    receipt_version="1",
    receipt_digest="sha256:proposal-review-missing-attestation",
    reviewer={
      reviewer_id: "human-reviewer-1",
      authority_ref: "authority-reviewer",
      authorized: true,
      evidence_refs: ["evidence-1"],
    },
    requested=Accept,
    evidence_refs=[evidence_reference()],
  )
  let request = @bookkeeper.WorkOrderProjectionRequest::new(
    request={
      record_id: "projection-request-missing-attestation",
      record_version: "1",
      record_digest: "sha256:projection-request-missing-attestation",
    },
    work_order={
      record_id: "work-order-missing-attestation",
      record_version: "1",
      record_digest: "sha256:work-order-missing-attestation",
    },
    evidence_refs=[canonical_evidence()],
  )
  let decision = @bookkeeper.project_mooncode_work_order(
    proposal,
    review,
    request,
    None,
  )
  assert_false(decision.is_ready())
  assert_true(decision.work_order is None)
  assert_true(decision.issues.contains(ReviewAttestationMissing))
}
