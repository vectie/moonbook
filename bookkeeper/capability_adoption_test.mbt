///|
fn bk3_evidence(id : String) -> @bookkeeper.VersionedEvidenceReference {
  {
    reference_id: id,
    reference_version: "1",
    digest: "sha256:\{id}",
    provenance_ref: "provenance:\{id}",
  }
}

///|
fn bk3_old_capability() -> @bookkeeper.VersionedRecordReference {
  {
    record_id: "capability-1",
    record_version: "4",
    record_digest: "sha256:capability-4",
  }
}

///|
fn bk3_new_capability() -> @bookkeeper.VersionedRecordReference {
  {
    record_id: "capability-1",
    record_version: "5",
    record_digest: "sha256:proposal-bk3",
  }
}

///|
fn bk3_changed_artifacts() -> Array[@bookkeeper.ChangedArtifactReference] {
  [
    {
      artifact_id: "artifact-b",
      artifact_version: "2",
      artifact_digest: "sha256:artifact-b",
    },
    {
      artifact_id: "artifact-a",
      artifact_version: "1",
      artifact_digest: "sha256:artifact-a",
    },
  ]
}

///|
fn bk3_proposal(
  proposal_id? : String = "proposal-bk3",
  proposal_digest? : String = "sha256:proposal-bk3",
) -> @bookkeeper.CapabilityProposal {
  @bookkeeper.aggregate_capability_proposal(
    promotion_policy(),
    [
      review_finding("finding-bk3-a", InformationGap),
      review_finding("finding-bk3-b", RecognitionGap),
      review_finding("finding-bk3-c", DecisivenessGap),
    ],
    proposal_id~,
    proposal_version="1",
    capability_id="capability-1",
    capability_version="5",
    owner_route="owner-1",
    proposal_digest~,
    summary="Generic governed capability result.",
    supersedes_version="4",
  ).proposal.unwrap()
}

///|
fn bk3_work_reviewer(
  reviewer_id? : String = "work-human-1",
  authority_ref? : String = "authority-work-human",
  authorized? : Bool = true,
) -> @bookkeeper.ReviewerAuthority {
  { reviewer_id, authority_ref, authorized, evidence_refs: ["evidence-1"] }
}

///|
fn bk3_review_and_work_order(
  proposal : @bookkeeper.CapabilityProposal,
  reviewer : @bookkeeper.ReviewerAuthority,
  suffix? : String = "current",
) -> (@bookkeeper.LearningReceipt, @bookkeeper.MoonCodeWorkOrderProjection) {
  let review = @bookkeeper.review_capability_proposal(
    proposal,
    receipt_id="learning-review-\{suffix}",
    receipt_version="1",
    receipt_digest="sha256:learning-review-\{suffix}",
    reviewer~,
    requested=Accept,
    evidence_refs=[evidence_reference()],
  )
  let request = @bookkeeper.WorkOrderProjectionRequest::new(
    request={
      record_id: "projection-\{suffix}",
      record_version: "1",
      record_digest: "sha256:projection-\{suffix}",
    },
    work_order={
      record_id: "work-order-\{suffix}",
      record_version: "1",
      record_digest: "sha256:work-order-\{suffix}",
    },
    evidence_refs=[canonical_evidence()],
  )
  let attestation = @bookkeeper.ReviewAuthorityAttestation::new(
    attestation={
      record_id: "work-review-attestation-\{suffix}",
      record_version: "1",
      record_digest: "sha256:work-review-attestation-\{suffix}",
    },
    proposal,
    review,
    reviewer_kind=Human,
    reviewer~,
    evidence_refs=[canonical_evidence()],
    projection_request=request,
  )
  let projection = @bookkeeper.project_mooncode_work_order(
    proposal,
    review,
    request,
    Some(attestation),
  )
  (review, projection.work_order.unwrap())
}

///|
fn bk3_result_reference(
  version? : String = "1",
  digest? : String = "sha256:work-result",
) -> @bookkeeper.VersionedRecordReference {
  { record_id: "work-result-1", record_version: version, record_digest: digest }
}

///|
fn bk3_bind_candidate(
  proposal : @bookkeeper.CapabilityProposal,
  review : @bookkeeper.LearningReceipt,
  work_order : @bookkeeper.MoonCodeWorkOrderProjection,
) -> @bookkeeper.MoonCodeWorkResultCandidate {
  @bookkeeper.bind_mooncode_work_result_candidate(
    proposal,
    review,
    work_order,
    result=bk3_result_reference(),
    old_capability=bk3_old_capability(),
    new_capability=bk3_new_capability(),
    changed_artifacts=bk3_changed_artifacts(),
    evidence_refs=[bk3_evidence("result-evidence"), canonical_evidence()],
  ).candidate.unwrap()
}

///|
fn bk3_test_result(
  id : String,
  evidence : @bookkeeper.VersionedEvidenceReference,
  complete? : Bool = true,
  passed? : Bool = true,
) -> @bookkeeper.CapabilityTestResult {
  {
    test_record: {
      record_id: id,
      record_version: "1",
      record_digest: "sha256:\{id}",
    },
    complete,
    passed,
    evidence_refs: [evidence],
  }
}

///|
fn bk3_metric(
  id : String,
  kind : @bookkeeper.CapabilityMetricKind,
  evidence : @bookkeeper.VersionedEvidenceReference,
) -> @bookkeeper.CapabilityMetricRecord {
  {
    metric: {
      record_id: id,
      record_version: "1",
      record_digest: "sha256:\{id}",
    },
    kind,
    evidence_refs: [evidence],
  }
}

///|
fn bk3_rollback(
  version? : String = "1",
  digest? : String = "sha256:rollback",
) -> @bookkeeper.VersionedRecordReference {
  { record_id: "rollback-plan", record_version: version, record_digest: digest }
}

///|
fn bk3_evaluation(
  candidate : @bookkeeper.MoonCodeWorkResultCandidate,
) -> @bookkeeper.CapabilityEvaluation {
  let evaluation_evidence = bk3_evidence("evaluation-evidence")
  let metric_evidence = bk3_evidence("metric-evidence")
  @bookkeeper.CapabilityEvaluation::new(
    candidate,
    evaluation={
      record_id: "evaluation-1",
      record_version: "1",
      record_digest: "sha256:evaluation",
    },
    test_results=[
      bk3_test_result("test-b", metric_evidence),
      bk3_test_result("test-a", evaluation_evidence),
    ],
    evidence_refs=[metric_evidence, evaluation_evidence],
    metric_records=[
      bk3_metric("metric-b", MetricReceipt, evaluation_evidence),
      bk3_metric("metric-a", MetricObservation, metric_evidence),
    ],
    declared_result=Passed,
    rollback=bk3_rollback(),
  )
}

///|
fn bk3_adoption_reviewer(
  reviewer_id? : String = "adoption-human-1",
  authority_ref? : String = "authority-adoption-human",
  authorized? : Bool = true,
) -> @bookkeeper.ReviewerAuthority {
  {
    reviewer_id,
    authority_ref,
    authorized,
    evidence_refs: ["result-evidence", "evaluation-evidence"],
  }
}

///|
fn bk3_adoption_evidence() -> Array[@bookkeeper.VersionedEvidenceReference] {
  [
    bk3_evidence("metric-evidence"),
    canonical_evidence(),
    bk3_evidence("result-evidence"),
    bk3_evidence("evaluation-evidence"),
  ]
}

///|
fn bk3_attestation(
  proposal : @bookkeeper.CapabilityProposal,
  review : @bookkeeper.LearningReceipt,
  work_order : @bookkeeper.MoonCodeWorkOrderProjection,
  candidate : @bookkeeper.MoonCodeWorkResultCandidate,
  evaluation : @bookkeeper.CapabilityEvaluation,
  reviewer : @bookkeeper.ReviewerAuthority,
  reviewer_kind? : @bookkeeper.ReviewerKind = Human,
) -> @bookkeeper.CapabilityAdoptionAttestation {
  @bookkeeper.CapabilityAdoptionAttestation::new(
    attestation={
      record_id: "adoption-attestation-1",
      record_version: "1",
      record_digest: "sha256:adoption-attestation",
    },
    candidate,
    evaluation,
    proposal,
    review,
    work_order,
    reviewer_kind~,
    reviewer~,
    evidence_refs=bk3_adoption_evidence(),
    requested=Accept,
    old_capability=bk3_old_capability(),
    new_capability=bk3_new_capability(),
    rollback=bk3_rollback(),
  )
}

///|
fn bk3_decide(
  proposal : @bookkeeper.CapabilityProposal,
  review : @bookkeeper.LearningReceipt,
  work_order : @bookkeeper.MoonCodeWorkOrderProjection,
  candidate : @bookkeeper.MoonCodeWorkResultCandidate,
  evaluation : @bookkeeper.CapabilityEvaluation,
  reviewer : @bookkeeper.ReviewerAuthority,
  attestation : @bookkeeper.CapabilityAdoptionAttestation?,
) -> @bookkeeper.CapabilityAdoptionDecision {
  @bookkeeper.decide_capability_adoption(
    proposal,
    review,
    work_order,
    candidate,
    evaluation,
    decision={
      record_id: "adoption-decision-1",
      record_version: "1",
      record_digest: "sha256:adoption-decision",
    },
    requested=Accept,
    reviewer~,
    attestation,
  )
}

///|
test "BK-3 result candidate is exact canonical and replay-idempotent" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
  )
  let artifacts = bk3_changed_artifacts()
  artifacts.push(artifacts[0])
  let evidence = [bk3_evidence("result-evidence"), canonical_evidence()]
  evidence.push(evidence[0])
  let first = @bookkeeper.bind_mooncode_work_result_candidate(
    proposal,
    review,
    work_order,
    result=bk3_result_reference(),
    old_capability=bk3_old_capability(),
    new_capability=bk3_new_capability(),
    changed_artifacts=artifacts,
    evidence_refs=evidence,
  )
  let replay = @bookkeeper.bind_mooncode_work_result_candidate(
    proposal,
    review,
    work_order,
    result=bk3_result_reference(),
    old_capability=bk3_old_capability(),
    new_capability=bk3_new_capability(),
    changed_artifacts=bk3_changed_artifacts().rev(),
    evidence_refs=[canonical_evidence(), bk3_evidence("result-evidence")],
  )
  assert_true(first.is_candidate())
  assert_true(first == replay)
  let candidate = first.candidate.unwrap()
  assert_eq(candidate.changed_artifacts.length(), 2)
  assert_eq(candidate.changed_artifacts[0].artifact_id, "artifact-a")
  assert_eq(candidate.evidence_refs[0].reference_id, "evidence-1")
  assert_eq(candidate.proposal.record_id, "proposal-bk3")
  assert_eq(candidate.learning_receipt.record_id, "learning-review-current")
  assert_eq(candidate.projection.record_id, "projection-current")
  assert_false(candidate.side_effects_applied)
}

///|
test "BK-3 result candidate rejects conflicting artifact and evidence identities" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
    suffix="conflict",
  )
  let artifacts = bk3_changed_artifacts()
  artifacts.push({
    artifact_id: "artifact-a",
    artifact_version: "9",
    artifact_digest: "sha256:stale-artifact-a",
  })
  let evidence = [canonical_evidence(), bk3_evidence("result-evidence")]
  evidence.push({
    ..bk3_evidence("result-evidence"),
    reference_version: "0",
    digest: "sha256:stale-result-evidence",
  })
  let decision = @bookkeeper.bind_mooncode_work_result_candidate(
    proposal,
    review,
    work_order,
    result=bk3_result_reference(),
    old_capability=bk3_old_capability(),
    new_capability=bk3_new_capability(),
    changed_artifacts=artifacts,
    evidence_refs=evidence,
  )
  assert_false(decision.is_candidate())
  assert_true(decision.candidate is None)
  assert_true(
    decision.issues.contains(ConflictingArtifactIdentity("artifact-a")),
  )
  assert_true(
    decision.issues.contains(ConflictingEvidenceIdentity("result-evidence")),
  )
  assert_false(decision.side_effects_applied)
}

///|
test "BK-3 result candidate rejects stale proposal receipt and capability links" {
  let proposal = bk3_proposal()
  let reviewer = bk3_work_reviewer()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    reviewer,
    suffix="exact-chain",
  )
  let stale_proposal = bk3_proposal(
    proposal_id="proposal-bk3-stale",
    proposal_digest="sha256:proposal-bk3-stale",
  )
  let stale_proposal_decision = @bookkeeper.bind_mooncode_work_result_candidate(
    stale_proposal,
    review,
    work_order,
    result=bk3_result_reference(),
    old_capability=bk3_old_capability(),
    new_capability={
      ..bk3_new_capability(),
      record_digest: "sha256:proposal-bk3-stale",
    },
    changed_artifacts=bk3_changed_artifacts(),
    evidence_refs=[canonical_evidence(), bk3_evidence("result-evidence")],
  )
  assert_false(stale_proposal_decision.is_candidate())
  assert_true(
    stale_proposal_decision.issues.contains(
      AdoptionLinkMismatch("capability proposal"),
    ),
  )
  let (stale_review, _) = bk3_review_and_work_order(
    proposal,
    reviewer,
    suffix="stale-review",
  )
  let stale_receipt_decision = @bookkeeper.bind_mooncode_work_result_candidate(
    proposal,
    stale_review,
    work_order,
    result=bk3_result_reference(),
    old_capability=bk3_old_capability(),
    new_capability=bk3_new_capability(),
    changed_artifacts=bk3_changed_artifacts(),
    evidence_refs=[canonical_evidence(), bk3_evidence("result-evidence")],
  )
  assert_false(stale_receipt_decision.is_candidate())
  assert_true(
    stale_receipt_decision.issues.contains(
      AdoptionLinkMismatch("accepted learning receipt"),
    ),
  )
  let stale_versions = @bookkeeper.bind_mooncode_work_result_candidate(
    proposal,
    review,
    work_order,
    result=bk3_result_reference(),
    old_capability={ ..bk3_old_capability(), record_version: "3" },
    new_capability={ ..bk3_new_capability(), record_version: "6" },
    changed_artifacts=bk3_changed_artifacts(),
    evidence_refs=[canonical_evidence(), bk3_evidence("result-evidence")],
  )
  assert_false(stale_versions.is_candidate())
  assert_true(
    stale_versions.issues.contains(AdoptionLinkMismatch("old capability")),
  )
  assert_true(
    stale_versions.issues.contains(AdoptionLinkMismatch("new capability")),
  )
}

///|
test "BK-3 evaluation canonicalizes order and requires complete proof" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
    suffix="evaluation",
  )
  let candidate = bk3_bind_candidate(proposal, review, work_order)
  let first = bk3_evaluation(candidate)
  let evaluation_evidence = bk3_evidence("evaluation-evidence")
  let metric_evidence = bk3_evidence("metric-evidence")
  let replay = @bookkeeper.CapabilityEvaluation::new(
    candidate,
    evaluation={
      record_id: "evaluation-1",
      record_version: "1",
      record_digest: "sha256:evaluation",
    },
    test_results=[
      bk3_test_result("test-a", evaluation_evidence),
      bk3_test_result("test-b", metric_evidence),
    ],
    evidence_refs=[evaluation_evidence, metric_evidence],
    metric_records=[
      bk3_metric("metric-a", MetricObservation, metric_evidence),
      bk3_metric("metric-b", MetricReceipt, evaluation_evidence),
    ],
    declared_result=Passed,
    rollback=bk3_rollback(),
  )
  assert_true(first.is_passing())
  assert_true(first == replay)
  assert_eq(first.test_results[0].test_record.record_id, "test-a")
  assert_eq(first.metric_records[0].metric.record_id, "metric-a")
  assert_false(first.side_effects_applied)
}

///|
test "BK-3 evaluation keeps failed and incomplete attempts auditable" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
    suffix="failed-evaluation",
  )
  let candidate = bk3_bind_candidate(proposal, review, work_order)
  let evidence = bk3_evidence("evaluation-evidence")
  let failed = @bookkeeper.CapabilityEvaluation::new(
    candidate,
    evaluation={
      record_id: "evaluation-failed",
      record_version: "1",
      record_digest: "sha256:evaluation-failed",
    },
    test_results=[bk3_test_result("test-failed", evidence, passed=false)],
    evidence_refs=[evidence],
    metric_records=[bk3_metric("metric-failed", MetricObservation, evidence)],
    declared_result=Failed,
    rollback=bk3_rollback(),
  )
  assert_false(failed.is_passing())
  assert_true(failed.issues.contains(EvaluationTestFailed("test-failed")))
  let incomplete = @bookkeeper.CapabilityEvaluation::new(
    candidate,
    evaluation={
      record_id: "evaluation-incomplete",
      record_version: "1",
      record_digest: "sha256:evaluation-incomplete",
    },
    test_results=[bk3_test_result("test-incomplete", evidence, complete=false)],
    evidence_refs=[evidence],
    metric_records=[bk3_metric("metric-incomplete", MetricReceipt, evidence)],
    declared_result=Passed,
    rollback=bk3_rollback(),
  )
  assert_false(incomplete.is_passing())
  assert_true(
    incomplete.issues.contains(EvaluationTestIncomplete("test-incomplete")),
  )
  assert_false(failed.side_effects_applied)
  assert_false(incomplete.side_effects_applied)
}

///|
test "BK-3 evaluation requires evidence tests metrics and versioned rollback" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
    suffix="missing-evaluation-proof",
  )
  let candidate = bk3_bind_candidate(proposal, review, work_order)
  let evaluation = @bookkeeper.CapabilityEvaluation::new(
    candidate,
    evaluation={
      record_id: "evaluation-missing",
      record_version: "1",
      record_digest: "sha256:evaluation-missing",
    },
    test_results=[],
    evidence_refs=[],
    metric_records=[],
    declared_result=Passed,
    rollback={ record_id: "", record_version: "", record_digest: "" },
  )
  assert_false(evaluation.is_passing())
  assert_true(evaluation.issues.contains(EvaluationEvidenceMissing))
  assert_true(evaluation.issues.contains(EvaluationTestsMissing))
  assert_true(evaluation.issues.contains(EvaluationMetricsMissing))
  assert_true(evaluation.issues.contains(RollbackReferenceInvalid))
}

///|
test "BK-3 exact named-human accept authorizes only an immutable receipt" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
    suffix="accepted",
  )
  let candidate = bk3_bind_candidate(proposal, review, work_order)
  let evaluation = bk3_evaluation(candidate)
  let reviewer = bk3_adoption_reviewer()
  let attestation = bk3_attestation(
    proposal, review, work_order, candidate, evaluation, reviewer,
  )
  let first = bk3_decide(
    proposal,
    review,
    work_order,
    candidate,
    evaluation,
    reviewer,
    Some(attestation),
  )
  let replay = bk3_decide(
    proposal,
    review,
    work_order,
    candidate,
    evaluation,
    reviewer,
    Some(attestation),
  )
  assert_true(first.is_authorized())
  assert_true(first == replay)
  assert_true(first.disposition == Accept)
  assert_false(first.side_effects_applied)
  let receipt = first.authorized_version_receipt().unwrap()
  assert_true(receipt.adoption_authorized)
  assert_eq(receipt.old_capability.record_version, "4")
  assert_eq(receipt.new_capability.record_version, "5")
  assert_eq(receipt.source_finding_refs.length(), 3)
  assert_eq(receipt.changed_artifacts.length(), 2)
  assert_eq(receipt.test_results.length(), 2)
  assert_eq(receipt.metric_records.length(), 2)
  assert_true(receipt.adoption_reviewer_kind == Human)
  assert_eq(receipt.adoption_reviewer_id, "adoption-human-1")
  assert_eq(receipt.rollback.record_id, "rollback-plan")
  assert_false(receipt.has_side_effects())
}

///|
test "BK-3 invalid accept rejects result evaluation projection and reviewer mismatch" {
  let proposal = bk3_proposal()
  let reviewer = bk3_work_reviewer()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    reviewer,
    suffix="mismatch-a",
  )
  let candidate = bk3_bind_candidate(proposal, review, work_order)
  let evaluation = bk3_evaluation(candidate)
  let adoption_reviewer = bk3_adoption_reviewer()
  let attestation = bk3_attestation(
    proposal, review, work_order, candidate, evaluation, adoption_reviewer,
  )
  let (_, stale_work_order) = bk3_review_and_work_order(
    proposal,
    reviewer,
    suffix="mismatch-b",
  )
  let stale_projection = bk3_decide(
    proposal,
    review,
    stale_work_order,
    candidate,
    evaluation,
    adoption_reviewer,
    Some(attestation),
  )
  assert_false(stale_projection.is_authorized())
  assert_true(stale_projection.version_receipt is None)
  assert_true(stale_projection.disposition == Revise)
  assert_true(
    stale_projection.issues.contains(
      AdoptionLinkMismatch("result candidate work order"),
    ),
  )
  let changed_reviewer = bk3_adoption_reviewer(
    authority_ref="authority-adoption-current",
  )
  let reviewer_mismatch = bk3_decide(
    proposal,
    review,
    work_order,
    candidate,
    evaluation,
    changed_reviewer,
    Some(attestation),
  )
  assert_false(reviewer_mismatch.is_authorized())
  assert_true(
    reviewer_mismatch.issues.contains(
      AdoptionAttestationMismatch("adoption reviewer authority"),
    ),
  )
  assert_false(reviewer_mismatch.side_effects_applied)
}

///|
test "BK-3 adoption rejects stale artifacts candidate and evaluation" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
    suffix="stale-values",
  )
  let candidate = bk3_bind_candidate(proposal, review, work_order)
  let evaluation = bk3_evaluation(candidate)
  let reviewer = bk3_adoption_reviewer()
  let stale_artifacts = bk3_changed_artifacts()
  stale_artifacts[0] = {
    ..stale_artifacts[0],
    artifact_version: "0",
    artifact_digest: "sha256:stale-artifact",
  }
  let stale_candidate = @bookkeeper.bind_mooncode_work_result_candidate(
    proposal,
    review,
    work_order,
    result=bk3_result_reference(),
    old_capability=bk3_old_capability(),
    new_capability=bk3_new_capability(),
    changed_artifacts=stale_artifacts,
    evidence_refs=[canonical_evidence(), bk3_evidence("result-evidence")],
  ).candidate.unwrap()
  let stale_artifact_attestation = bk3_attestation(
    proposal, review, work_order, stale_candidate, evaluation, reviewer,
  )
  let artifact_decision = bk3_decide(
    proposal,
    review,
    work_order,
    candidate,
    evaluation,
    reviewer,
    Some(stale_artifact_attestation),
  )
  assert_false(artifact_decision.is_authorized())
  assert_true(
    artifact_decision.issues.contains(
      AdoptionAttestationMismatch("changed artifacts"),
    ),
  )
  let other_candidate = @bookkeeper.bind_mooncode_work_result_candidate(
    proposal,
    review,
    work_order,
    result=bk3_result_reference(version="2", digest="sha256:work-result-2"),
    old_capability=bk3_old_capability(),
    new_capability=bk3_new_capability(),
    changed_artifacts=bk3_changed_artifacts(),
    evidence_refs=[canonical_evidence(), bk3_evidence("result-evidence")],
  ).candidate.unwrap()
  let other_evaluation_evidence = bk3_evidence("evaluation-evidence")
  let other_metric_evidence = bk3_evidence("metric-evidence")
  let other_evaluation = @bookkeeper.CapabilityEvaluation::new(
    other_candidate,
    evaluation={
      record_id: "evaluation-2",
      record_version: "1",
      record_digest: "sha256:evaluation-2",
    },
    test_results=[
      bk3_test_result("test-a", other_evaluation_evidence),
      bk3_test_result("test-b", other_metric_evidence),
    ],
    evidence_refs=[other_evaluation_evidence, other_metric_evidence],
    metric_records=[
      bk3_metric("metric-a", MetricObservation, other_metric_evidence),
      bk3_metric("metric-b", MetricReceipt, other_evaluation_evidence),
    ],
    declared_result=Passed,
    rollback=bk3_rollback(),
  )
  let candidate_mismatch_attestation = bk3_attestation(
    proposal, review, work_order, other_candidate, other_evaluation, reviewer,
  )
  let candidate_mismatch = bk3_decide(
    proposal,
    review,
    work_order,
    candidate,
    evaluation,
    reviewer,
    Some(candidate_mismatch_attestation),
  )
  assert_true(
    candidate_mismatch.issues.contains(
      AdoptionAttestationMismatch("result candidate"),
    ),
  )
  assert_true(
    candidate_mismatch.issues.contains(
      AdoptionAttestationMismatch("evaluation"),
    ),
  )
  let wrong_evaluation_decision = bk3_decide(
    proposal,
    review,
    work_order,
    candidate,
    other_evaluation,
    reviewer,
    Some(candidate_mismatch_attestation),
  )
  assert_true(
    wrong_evaluation_decision.issues.contains(
      AdoptionLinkMismatch("evaluation result candidate"),
    ),
  )
  assert_true(wrong_evaluation_decision.version_receipt is None)
}

///|
test "BK-3 adoption rejects stale evidence versions and rollback" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
    suffix="stale-evidence",
  )
  let candidate = bk3_bind_candidate(proposal, review, work_order)
  let evaluation = bk3_evaluation(candidate)
  let reviewer = bk3_adoption_reviewer()
  let stale_evidence = bk3_adoption_evidence()
  stale_evidence[0] = {
    ..stale_evidence[0],
    reference_version: "0",
    digest: "sha256:stale-metric-evidence",
  }
  let stale_evidence_attestation = @bookkeeper.CapabilityAdoptionAttestation::new(
    attestation={
      record_id: "adoption-attestation-stale-evidence",
      record_version: "1",
      record_digest: "sha256:adoption-attestation-stale-evidence",
    },
    candidate,
    evaluation,
    proposal,
    review,
    work_order,
    reviewer_kind=Human,
    reviewer~,
    evidence_refs=stale_evidence,
    requested=Accept,
    old_capability=bk3_old_capability(),
    new_capability=bk3_new_capability(),
    rollback={ ..bk3_rollback(), record_version: "0" },
  )
  let decision = bk3_decide(
    proposal,
    review,
    work_order,
    candidate,
    evaluation,
    reviewer,
    Some(stale_evidence_attestation),
  )
  assert_false(decision.is_authorized())
  assert_true(decision.issues.contains(AdoptionAttestationMismatch("evidence")))
  assert_true(decision.issues.contains(AdoptionAttestationMismatch("rollback")))
  assert_true(decision.version_receipt is None)
  assert_false(decision.side_effects_applied)
}

///|
test "BK-3 adoption rejects stale old and new capability versions" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
    suffix="stale-capability",
  )
  let candidate = bk3_bind_candidate(proposal, review, work_order)
  let evaluation = bk3_evaluation(candidate)
  let reviewer = bk3_adoption_reviewer()
  let attestation = @bookkeeper.CapabilityAdoptionAttestation::new(
    attestation={
      record_id: "adoption-attestation-stale-capability",
      record_version: "1",
      record_digest: "sha256:adoption-attestation-stale-capability",
    },
    candidate,
    evaluation,
    proposal,
    review,
    work_order,
    reviewer_kind=Human,
    reviewer~,
    evidence_refs=bk3_adoption_evidence(),
    requested=Accept,
    old_capability={ ..bk3_old_capability(), record_version: "3" },
    new_capability={ ..bk3_new_capability(), record_version: "6" },
    rollback=bk3_rollback(),
  )
  let decision = bk3_decide(
    proposal,
    review,
    work_order,
    candidate,
    evaluation,
    reviewer,
    Some(attestation),
  )
  assert_true(
    decision.issues.contains(AdoptionAttestationMismatch("old capability")),
  )
  assert_true(
    decision.issues.contains(AdoptionAttestationMismatch("new capability")),
  )
  assert_true(decision.version_receipt is None)
  let contradictory = @bookkeeper.CapabilityAdoptionAttestation::new(
    attestation={
      record_id: "adoption-attestation-contradictory",
      record_version: "1",
      record_digest: "sha256:adoption-attestation-contradictory",
    },
    candidate,
    evaluation,
    proposal,
    review,
    work_order,
    reviewer_kind=Human,
    reviewer~,
    evidence_refs=bk3_adoption_evidence(),
    requested=Reject,
    old_capability=bk3_old_capability(),
    new_capability=bk3_new_capability(),
    rollback=bk3_rollback(),
  )
  let contradictory_decision = bk3_decide(
    proposal,
    review,
    work_order,
    candidate,
    evaluation,
    reviewer,
    Some(contradictory),
  )
  assert_true(
    contradictory_decision.issues.contains(
      AdoptionAttestationMismatch("requested disposition"),
    ),
  )
  assert_true(contradictory_decision.version_receipt is None)
}

///|
test "BK-3 missing non-human unnamed and unauthorized attestations fail closed" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
    suffix="authority",
  )
  let candidate = bk3_bind_candidate(proposal, review, work_order)
  let evaluation = bk3_evaluation(candidate)
  let reviewer = bk3_adoption_reviewer()
  let missing = bk3_decide(
    proposal,
    review,
    work_order,
    candidate,
    evaluation,
    reviewer,
    None,
  )
  assert_true(missing.issues.contains(AdoptionAttestationMissing))
  assert_true(missing.disposition == Revise)
  assert_true(missing.version_receipt is None)
  for kind in [@bookkeeper.Automation, Agent, System] {
    let attestation = bk3_attestation(
      proposal,
      review,
      work_order,
      candidate,
      evaluation,
      reviewer,
      reviewer_kind=kind,
    )
    let decision = bk3_decide(
      proposal,
      review,
      work_order,
      candidate,
      evaluation,
      reviewer,
      Some(attestation),
    )
    assert_true(decision.issues.contains(NonHumanAdoptionAttestation(kind)))
    assert_true(decision.version_receipt is None)
    assert_false(decision.side_effects_applied)
  }
  for
    invalid_reviewer in [
      bk3_adoption_reviewer(reviewer_id=""),
      bk3_adoption_reviewer(authorized=false),
    ] {
    let attestation = bk3_attestation(
      proposal, review, work_order, candidate, evaluation, invalid_reviewer,
    )
    let decision = bk3_decide(
      proposal,
      review,
      work_order,
      candidate,
      evaluation,
      invalid_reviewer,
      Some(attestation),
    )
    assert_true(decision.issues.contains(UnauthorizedAdoptionReviewer))
    assert_true(decision.version_receipt is None)
  }
}

///|
test "BK-3 failed evaluation cannot authorize adoption" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
    suffix="failed-adoption",
  )
  let candidate = bk3_bind_candidate(proposal, review, work_order)
  let evidence = bk3_evidence("evaluation-evidence")
  let evaluation = @bookkeeper.CapabilityEvaluation::new(
    candidate,
    evaluation={
      record_id: "evaluation-declared-failed",
      record_version: "1",
      record_digest: "sha256:evaluation-declared-failed",
    },
    test_results=[bk3_test_result("test-declared-failed", evidence)],
    evidence_refs=[evidence],
    metric_records=[
      bk3_metric("metric-declared-failed", MetricObservation, evidence),
    ],
    declared_result=Failed,
    rollback=bk3_rollback(),
  )
  let reviewer = {
    ..bk3_adoption_reviewer(),
    evidence_refs: ["result-evidence", "evaluation-evidence"],
  }
  let attestation = @bookkeeper.CapabilityAdoptionAttestation::new(
    attestation={
      record_id: "attestation-declared-failed",
      record_version: "1",
      record_digest: "sha256:attestation-declared-failed",
    },
    candidate,
    evaluation,
    proposal,
    review,
    work_order,
    reviewer_kind=Human,
    reviewer~,
    evidence_refs=[
      canonical_evidence(),
      bk3_evidence("result-evidence"),
      evidence,
    ],
    requested=Accept,
    old_capability=bk3_old_capability(),
    new_capability=bk3_new_capability(),
    rollback=bk3_rollback(),
  )
  let decision = bk3_decide(
    proposal,
    review,
    work_order,
    candidate,
    evaluation,
    reviewer,
    Some(attestation),
  )
  assert_true(decision.issues.contains(EvaluationNotPassing))
  assert_true(decision.version_receipt is None)
  assert_true(decision.disposition == Revise)
  assert_false(decision.side_effects_applied)
}

///|
test "BK-3 reject revise and escalate are always non-adopting audit decisions" {
  let proposal = bk3_proposal()
  let (review, work_order) = bk3_review_and_work_order(
    proposal,
    bk3_work_reviewer(),
    suffix="non-accept",
  )
  let candidate = bk3_bind_candidate(proposal, review, work_order)
  let evaluation = bk3_evaluation(candidate)
  for disposition in [@bookkeeper.Reject, Revise, Escalate] {
    let decision = @bookkeeper.decide_capability_adoption(
      proposal,
      review,
      work_order,
      candidate,
      evaluation,
      decision={
        record_id: "non-accept-\{to_repr(disposition)}",
        record_version: "1",
        record_digest: "sha256:non-accept-\{to_repr(disposition)}",
      },
      requested=disposition,
      reviewer=bk3_adoption_reviewer(),
      None,
    )
    assert_true(decision.disposition == disposition)
    assert_false(decision.is_authorized())
    assert_true(decision.version_receipt is None)
    assert_false(decision.side_effects_applied)
  }
}
