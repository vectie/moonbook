///|
pub fn bookkeeper_store_contract_version() -> String {
  "moonbook.bookkeeper.store.v1"
}

///|
pub fn bookkeeper_transport_contract_version() -> String {
  "moonbook.bookkeeper.transport.v1"
}

///|
pub(all) enum BookkeeperStage {
  DeliverableAcceptance
  OutcomeBinding
  ThreeGapFinding
  ThreeGapReview
  CapabilityProposal
  CapabilityReview
  MoonCodeWorkOrder
  MoonCodeResult
  Evaluation
  Adoption
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn BookkeeperStage::id(self : BookkeeperStage) -> String {
  match self {
    DeliverableAcceptance => "deliverable_acceptance"
    OutcomeBinding => "outcome_binding"
    ThreeGapFinding => "three_gap_finding"
    ThreeGapReview => "three_gap_review"
    CapabilityProposal => "capability_proposal"
    CapabilityReview => "capability_review"
    MoonCodeWorkOrder => "mooncode_work_order"
    MoonCodeResult => "mooncode_result"
    Evaluation => "evaluation"
    Adoption => "adoption"
  }
}

///|
pub fn BookkeeperStage::is_reviewable(self : BookkeeperStage) -> Bool {
  match self {
    DeliverableAcceptance
    | ThreeGapFinding
    | CapabilityProposal
    | MoonCodeWorkOrder
    | Evaluation
    | Adoption => true
    _ => false
  }
}

///|
pub(all) struct DurableBookkeeperRecord {
  contract_version : String
  record : @bookkeeper.VersionedRecordReference
  stage : BookkeeperStage
  subject : @bookkeeper.VersionedRecordReference?
  links : Array[@bookkeeper.VersionedRecordReference]
  title : String
  summary : String
  owner_route : String
  status : String
  evidence_refs : Array[@bookkeeper.VersionedEvidenceReference]
  issue_refs : Array[String]
  requires_human_review : Bool
  next_action : String
  source_product : String
  recorded_at : Int
  payload : Json
  side_effects_applied : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
/// JSON-facing reviewer authority snapshot. The core Bookkeeper type keeps
/// evidence immutable; the store copies it into an owned array for replay.
pub(all) struct StoreReviewerAuthority {
  grant : @bookkeeper.VersionedRecordReference
  reviewer_id : String
  authority_ref : String
  authorized : Bool
  evidence_refs : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperAuthorityGrant {
  contract_version : String
  grant : @bookkeeper.VersionedRecordReference
  reviewer_id : String
  reviewer_kind : @bookkeeper.ReviewerKind
  authority_ref : String
  evidence_refs : Array[String]
  active : Bool
  granted_at : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperAuthorityRegistry {
  contract_version : String
  grants : Array[BookkeeperAuthorityGrant]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct GovernedReviewMutation {
  contract_version : String
  mutation : @bookkeeper.VersionedRecordReference
  receipt : @bookkeeper.VersionedRecordReference
  stage : BookkeeperStage
  subject : @bookkeeper.VersionedRecordReference
  requested : @bookkeeper.BookkeeperDisposition
  reviewer_kind : @bookkeeper.ReviewerKind
  reviewer : StoreReviewerAuthority
  evidence_refs : Array[@bookkeeper.VersionedEvidenceReference]
  summary : String
  decided_at : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct GovernedReviewReceipt {
  contract_version : String
  mutation : @bookkeeper.VersionedRecordReference
  receipt : @bookkeeper.VersionedRecordReference
  stage : BookkeeperStage
  subject : @bookkeeper.VersionedRecordReference
  requested : @bookkeeper.BookkeeperDisposition
  disposition : @bookkeeper.BookkeeperDisposition
  reviewer_kind : @bookkeeper.ReviewerKind
  reviewer : StoreReviewerAuthority
  evidence_refs : Array[@bookkeeper.VersionedEvidenceReference]
  summary : String
  decided_at : Int
  issues : Array[String]
  review_complete : Bool
  side_effects_applied : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) enum EnvelopeDirection {
  Ingress
  Egress
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperTransportEnvelope {
  contract_version : String
  envelope : @bookkeeper.VersionedRecordReference
  direction : EnvelopeDirection
  source_product : String
  destination_product : String
  message_kind : String
  subject : @bookkeeper.VersionedRecordReference
  links : Array[@bookkeeper.VersionedRecordReference]
  evidence_refs : Array[@bookkeeper.VersionedEvidenceReference]
  authority_ref : String
  recorded_at : Int
  payload : Json
  external_activation_allowed : Bool
  side_effects_applied : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperJournalEvent {
  contract_version : String
  sequence : Int
  event : @bookkeeper.VersionedRecordReference
  event_kind : String
  recorded_at : Int
  record : DurableBookkeeperRecord?
  review : GovernedReviewReceipt?
  envelope : BookkeeperTransportEnvelope?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperStoreSnapshot {
  contract_version : String
  mut last_sequence : Int
  records : Array[DurableBookkeeperRecord]
  reviews : Array[GovernedReviewReceipt]
  envelopes : Array[BookkeeperTransportEnvelope]
  replay_issues : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperMutationResult {
  accepted : Bool
  idempotent : Bool
  event : @bookkeeper.VersionedRecordReference?
  review : GovernedReviewReceipt?
  issues : Array[String]
  ui_state_path : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Explicit operator request to project one accepted capability proposal into
/// a non-executing MoonCode work order. All remaining values are derived from
/// the durable proposal, its exact accepted review, and the installed grant.
pub(all) struct GovernedWorkOrderBridgeRequest {
  contract_version : String
  proposal : @bookkeeper.VersionedRecordReference
  proposal_review : @bookkeeper.VersionedRecordReference
  authority_grant : @bookkeeper.VersionedRecordReference
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Separate operator authorization for handing an accepted work order to the
/// generic transport boundary. This action cannot activate or execute it.
pub(all) struct GovernedWorkOrderEgressRequest {
  contract_version : String
  work_order : @bookkeeper.VersionedRecordReference
  work_order_review : @bookkeeper.VersionedRecordReference
  authority_grant : @bookkeeper.VersionedRecordReference
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Exact egress selection used by the optional draft-only MoonClaw importer.
pub(all) struct MoonCodeDraftImportRequest {
  contract_version : String
  envelope : @bookkeeper.VersionedRecordReference
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Idempotent delivery identity for one exact reviewed work-order egress.
pub(all) struct MoonCodeDraftDeliveryRequest {
  contract_version : String
  delivery_id : String
  delivery_version : String
  envelope : @bookkeeper.VersionedRecordReference
  expected_envelope_digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Durable pre-import plan. A persisted plan is a fail-closed claim: if the
/// importer outcome is interrupted before its receipt is committed, replay
/// cannot silently submit the packet again.
pub(all) struct MoonCodeDraftDeliveryPlan {
  contract_version : String
  request : MoonCodeDraftDeliveryRequest
  request_digest : String
  adapter_id : String
  adapter_version : String
  envelope : @bookkeeper.VersionedRecordReference
  work_order : @bookkeeper.VersionedRecordReference
  packet_path : String
  packet_digest : String
  claim_digest : String
  already_imported : Bool
  existing_receipt : MoonCodeDraftImportReceipt?
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Immutable evidence that MoonClaw accepted a draft proposal only. The false
/// authority fields are invariants and can never be promoted by this adapter.
pub(all) struct MoonCodeDraftImportReceipt {
  contract_version : String
  receipt : @bookkeeper.VersionedRecordReference
  request : MoonCodeDraftDeliveryRequest
  request_digest : String
  adapter_id : String
  adapter_version : String
  envelope : @bookkeeper.VersionedRecordReference
  work_order : @bookkeeper.VersionedRecordReference
  packet_digest : String
  moonclaw_proposal_id : String
  moonclaw_status : String
  moonclaw_output_digest : String
  confirmed : Bool
  executed : Bool
  external_effect_authorized : Bool
  side_effects_applied : Bool
} derive(Debug, Eq, ToJson, FromJson)
