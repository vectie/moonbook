///|
/// Fail-closed issues for accepting a collaborative handover as outcome
/// evidence. MoonBook owns this acceptance boundary and the Three-Gap record;
/// MoonFlow remains the owner of collaboration and handover lifecycle state.
pub(all) enum CollaborativeOutcomeIssueV1 {
  HandoverCompletionMissing
  HandoverBindingMismatch(String)
  DeliverableOutcomeMismatch
  HumanReviewRequired
  ReviewerIdentityMismatch
  ReviewerAuthorityInvalid
  ReviewEvidenceMissing
  ThreeGapBindingMismatch(String)
  ThreeGapEvidenceMismatch(String)
  InvalidCollaborativeOutcomeTimestamp
} derive(Debug, Eq, ToJson)

///|
/// Immutable MoonBook record joining an exact MoonFlow handover completion,
/// accepted deliverable, observed outcome, human review, and Three-Gap
/// assessment. It is deliberately not a MoonFlow lifecycle receipt.
pub struct AcceptedHandoverOutcomeV1 {
  contract_id : String
  record_id : String
  handover_id : String
  handover_envelope_digest : @capability.DigestRefV1
  handover_bundle_digest : @capability.DigestRefV1
  completion_transition_id : String
  completion_head_digest : @capability.DigestRefV1
  completion_receipt : @capability.ContentAddressedEvidenceRefV1
  bundle_id : String
  bundle_version : String
  bundle_digest : @capability.DigestRefV1
  observation_id : String
  observation_version : String
  observation_digest : @capability.DigestRefV1
  reviewer : @capability.PrincipalRefV1
  reviewer_authority : @capability.AuthorityDecisionRefV1
  review_evidence : @capability.ContentAddressedEvidenceRefV1
  three_gap_assessment_id : String
  three_gap_assessment_version : String
  accepted_at : String
  content_digest : @capability.DigestRefV1
} derive(Debug, Eq)

///|
pub struct AcceptedHandoverOutcomeDecisionV1 {
  issues : ReadOnlyArray[CollaborativeOutcomeIssueV1]
  accepted : AcceptedHandoverOutcomeV1?
} derive(Debug, Eq)

///|
pub fn AcceptedHandoverOutcomeDecisionV1::is_accepted(
  self : AcceptedHandoverOutcomeDecisionV1,
) -> Bool {
  self.issues.is_empty() && self.accepted is Some(_)
}

///|
pub fn AcceptedHandoverOutcomeV1::content_digest(
  self : AcceptedHandoverOutcomeV1,
) -> @capability.DigestRefV1 {
  self.content_digest
}

///|
pub fn AcceptedHandoverOutcomeV1::handover_envelope_digest(
  self : AcceptedHandoverOutcomeV1,
) -> @capability.DigestRefV1 {
  self.handover_envelope_digest
}

///|
priv struct AcceptedHandoverOutcomePayloadWireV1 {
  contract_id : String
  record_id : String
  handover_id : String
  handover_envelope_digest : String
  handover_bundle_digest : String
  completion_transition_id : String
  completion_head_digest : String
  completion_receipt_ref : String
  completion_receipt_digest : String
  bundle_id : String
  bundle_version : String
  bundle_digest : String
  observation_id : String
  observation_version : String
  observation_digest : String
  reviewer : Json
  reviewer_authority : Json
  review_evidence_ref : String
  review_evidence_digest : String
  three_gap_assessment_id : String
  three_gap_assessment_version : String
  accepted_at : String
} derive(ToJson)

///|
priv struct AcceptedHandoverOutcomeWireV1 {
  payload : Json
  content_digest : String
} derive(ToJson)

///|
fn accepted_handover_outcome_payload_v1(
  record_id : String,
  envelope : @capability.HandoverControlEnvelopeV1,
  handover_bundle : @capability.HandoverBundleV1,
  completion_transition_id : String,
  completion_head_digest : @capability.DigestRefV1,
  completion_receipt : @capability.ContentAddressedEvidenceRefV1,
  bundle : DeliverableBundle,
  observation : OutcomeObservation,
  reviewer : @capability.PrincipalRefV1,
  reviewer_authority : @capability.AuthorityDecisionRefV1,
  review_evidence : @capability.ContentAddressedEvidenceRefV1,
  assessment : ThreeGapAssessment,
  accepted_at : String,
) -> AcceptedHandoverOutcomePayloadWireV1 {
  {
    contract_id: "moonbook.accepted-handover-outcome.v1",
    record_id,
    handover_id: envelope.handover_id(),
    handover_envelope_digest: envelope.envelope_digest().text(),
    handover_bundle_digest: handover_bundle.content_digest().text(),
    completion_transition_id,
    completion_head_digest: completion_head_digest.text(),
    completion_receipt_ref: completion_receipt.evidence_ref(),
    completion_receipt_digest: completion_receipt.evidence_digest(),
    bundle_id: bundle.bundle_id,
    bundle_version: bundle.bundle_version,
    bundle_digest: bundle.bundle_digest,
    observation_id: observation.observation_id,
    observation_version: observation.observation_version,
    observation_digest: observation.observation_digest,
    reviewer: @capability.encode_principal_ref_v1(reviewer),
    reviewer_authority: @capability.encode_authority_decision_ref_v1(
      reviewer_authority,
    ),
    review_evidence_ref: review_evidence.evidence_ref(),
    review_evidence_digest: review_evidence.evidence_digest(),
    three_gap_assessment_id: assessment.assessment_id,
    three_gap_assessment_version: assessment.assessment_version,
    accepted_at,
  }
}

///|
fn assessment_evidence_is_bound_v1(
  assessment : ThreeGapAssessment,
  observation : OutcomeObservation,
  issues : Array[CollaborativeOutcomeIssueV1],
) -> Unit {
  let known : Array[String] = observation.evidence_refs
    .map(item => item.reference_id)
    .iter()
    .to_array()
  let findings = [
    ("information", assessment.information_gap),
    ("recognition", assessment.recognition_gap),
    ("decisiveness", assessment.decisiveness_gap),
  ]
  for finding in findings {
    if finding.1.present && finding.1.evidence_refs.is_empty() {
      issues.push(ThreeGapEvidenceMismatch("\{finding.0}:missing"))
    }
    for reference in finding.1.evidence_refs {
      if !known.contains(reference) {
        issues.push(ThreeGapEvidenceMismatch("\{finding.0}:\{reference}"))
      }
    }
  }
}

///|
/// Accept a completed handover outcome only when its deliverable/outcome links,
/// named human reviewer, fresh exact authority, review evidence, and Three-Gap
/// subject are all exact. Comments cannot satisfy this API because it accepts
/// only a content-addressed review evidence reference.
pub fn accept_completed_handover_outcome_v1(
  record_id : String,
  envelope : @capability.HandoverControlEnvelopeV1,
  handover_bundle : @capability.HandoverBundleV1,
  completion_transition_id : String,
  completion_head_digest : @capability.DigestRefV1,
  completion_receipt : @capability.ContentAddressedEvidenceRefV1,
  bundle : DeliverableBundle,
  observation : OutcomeObservation,
  reviewer_kind : ReviewerKind,
  reviewer : @capability.PrincipalRefV1,
  reviewer_authority : @capability.AuthorityDecisionRefV1,
  reviewer_record : ReviewerAuthority,
  review_evidence : @capability.ContentAddressedEvidenceRefV1,
  assessment : ThreeGapAssessment,
  accepted_at : String,
) -> AcceptedHandoverOutcomeDecisionV1 {
  let issues : Array[CollaborativeOutcomeIssueV1] = []
  if !@capability.identifier_component_is_canonical(record_id) ||
    !@capability.wire_timestamp_is_canonical(accepted_at) {
    issues.push(InvalidCollaborativeOutcomeTimestamp)
  }
  if !@capability.identifier_component_is_canonical(completion_transition_id) ||
    completion_receipt.evidence_ref().is_blank() {
    issues.push(HandoverCompletionMissing)
  }
  if envelope.bundle_digest() != handover_bundle.content_digest() {
    issues.push(HandoverBindingMismatch("handover bundle digest"))
  }
  if !handover_bundle
    .entries()
    .any(entry => entry.artifact().evidence_digest() == bundle.bundle_digest) {
    issues.push(
      HandoverBindingMismatch("deliverable is absent from handover bundle"),
    )
  }
  if !bundle.matches_outcome(observation) {
    issues.push(DeliverableOutcomeMismatch)
  }
  if reviewer_kind != Human || reviewer.kind() != @capability.Human {
    issues.push(HumanReviewRequired)
  }
  if reviewer_record.reviewer_id != reviewer.principal_id() {
    issues.push(ReviewerIdentityMismatch)
  }
  if !reviewer_record.authorized ||
    reviewer_record.authority_ref != reviewer_authority.decision_id() ||
    !reviewer_authority.is_fresh_for(reviewer, accepted_at) {
    issues.push(ReviewerAuthorityInvalid)
  }
  if !reviewer_record.evidence_refs.contains(review_evidence.evidence_ref()) {
    issues.push(ReviewEvidenceMissing)
  }
  if assessment.subject_id != observation.observation_id ||
    assessment.subject_version != observation.observation_version ||
    assessment.owner_route.is_blank() {
    issues.push(ThreeGapBindingMismatch("outcome observation"))
  }
  assessment_evidence_is_bound_v1(assessment, observation, issues)
  if !issues.is_empty() {
    return { issues: ReadOnlyArray::from_array(issues), accepted: None }
  }
  let payload = accepted_handover_outcome_payload_v1(
    record_id, envelope, handover_bundle, completion_transition_id, completion_head_digest,
    completion_receipt, bundle, observation, reviewer, reviewer_authority, review_evidence,
    assessment, accepted_at,
  )
  let content_digest = @capability.sha256_digest_ref_v1(
    @encoding/utf8.encode(payload.to_json().stringify()),
  )
  {
    issues: ReadOnlyArray::from_array([]),
    accepted: Some({
      contract_id: "moonbook.accepted-handover-outcome.v1",
      record_id,
      handover_id: envelope.handover_id(),
      handover_envelope_digest: envelope.envelope_digest(),
      handover_bundle_digest: handover_bundle.content_digest(),
      completion_transition_id,
      completion_head_digest,
      completion_receipt,
      bundle_id: bundle.bundle_id,
      bundle_version: bundle.bundle_version,
      bundle_digest: @capability.digest_ref_v1(bundle.bundle_digest) catch {
        _ =>
          return {
            issues: ReadOnlyArray::from_array([
              HandoverBindingMismatch("bundle digest"),
            ]),
            accepted: None,
          }
      },
      observation_id: observation.observation_id,
      observation_version: observation.observation_version,
      observation_digest: @capability.digest_ref_v1(
        observation.observation_digest,
      ) catch {
        _ =>
          return {
            issues: ReadOnlyArray::from_array([DeliverableOutcomeMismatch]),
            accepted: None,
          }
      },
      reviewer,
      reviewer_authority,
      review_evidence,
      three_gap_assessment_id: assessment.assessment_id,
      three_gap_assessment_version: assessment.assessment_version,
      accepted_at,
      content_digest,
    }),
  }
}

///|
pub fn encode_accepted_handover_outcome_v1(
  accepted : AcceptedHandoverOutcomeV1,
) -> Json {
  AcceptedHandoverOutcomeWireV1::{
    payload: AcceptedHandoverOutcomePayloadWireV1::{
      contract_id: accepted.contract_id,
      record_id: accepted.record_id,
      handover_id: accepted.handover_id,
      handover_envelope_digest: accepted.handover_envelope_digest.text(),
      handover_bundle_digest: accepted.handover_bundle_digest.text(),
      completion_transition_id: accepted.completion_transition_id,
      completion_head_digest: accepted.completion_head_digest.text(),
      completion_receipt_ref: accepted.completion_receipt.evidence_ref(),
      completion_receipt_digest: accepted.completion_receipt.evidence_digest(),
      bundle_id: accepted.bundle_id,
      bundle_version: accepted.bundle_version,
      bundle_digest: accepted.bundle_digest.text(),
      observation_id: accepted.observation_id,
      observation_version: accepted.observation_version,
      observation_digest: accepted.observation_digest.text(),
      reviewer: @capability.encode_principal_ref_v1(accepted.reviewer),
      reviewer_authority: @capability.encode_authority_decision_ref_v1(
        accepted.reviewer_authority,
      ),
      review_evidence_ref: accepted.review_evidence.evidence_ref(),
      review_evidence_digest: accepted.review_evidence.evidence_digest(),
      three_gap_assessment_id: accepted.three_gap_assessment_id,
      three_gap_assessment_version: accepted.three_gap_assessment_version,
      accepted_at: accepted.accepted_at,
    }.to_json(),
    content_digest: accepted.content_digest.text(),
  }.to_json()
}
