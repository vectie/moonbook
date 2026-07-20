///|
/// Stable wire contract for handing an authorized, still non-applying
/// Bookkeeper decision to MoonFlow's activation functionality.
pub fn capability_activation_request_contract_version() -> String {
  "moonbook.bookkeeper.capability_activation_request.v1"
}

///|
/// A fail-closed projection of one exact capability receipt into a separately
/// reviewed rollout request. This value never installs or activates anything;
/// MoonFlow remains the sole owner of rollout state transitions.
pub(all) struct CapabilityActivationRequest {
  contract_version : String
  request : VersionedRecordReference
  receipt : VersionedRecordReference
  scope_id : String
  rollout_mode : String
  challenger_participant_ids : ReadOnlyArray[String]
  max_observations : Int
  experiment : VersionedRecordReference
  old_capability : VersionedRecordReference
  new_capability : VersionedRecordReference
  rollback : VersionedRecordReference
  activation_review : VersionedRecordReference
  activation_reviewer_id : String
  activation_reviewer_authority_ref : String
  requested_at : Int64
  adoption_authorized : Bool
  source_side_effects_applied : Bool
  activation_side_effects_applied : Bool
} derive(Debug, Eq, ToJson)

///|
fn valid_rollout_mode(mode : String) -> Bool {
  mode == "shadow" || mode == "canary" || mode == "full"
}

///|
fn valid_activation_participants(participant_ids : ArrayView[String]) -> Bool {
  let seen : Map[String, Bool] = {}
  for participant_id in participant_ids {
    if participant_id.is_blank() || seen.contains(participant_id) {
      return false
    }
    seen[participant_id] = true
  }
  true
}

///|
/// Project a separate activation request from an authorized adoption receipt.
/// Invalid scope, rollout, experiment, or human authority returns `None`; no
/// state is changed and no weaker request is emitted.
pub fn CapabilityVersionReceipt::activation_request(
  self : CapabilityVersionReceipt,
  request~ : VersionedRecordReference,
  scope_id~ : String,
  rollout_mode~ : String,
  challenger_participant_ids~ : Array[String],
  max_observations~ : Int,
  experiment~ : VersionedRecordReference,
  activation_review~ : VersionedRecordReference,
  activation_reviewer~ : ReviewerAuthority,
  requested_at~ : Int64,
) -> CapabilityActivationRequest? {
  if !self.adoption_authorized ||
    self.side_effects_applied ||
    scope_id.is_blank() ||
    !valid_rollout_mode(rollout_mode) ||
    (rollout_mode == "canary" && challenger_participant_ids.is_empty()) ||
    !valid_activation_participants(challenger_participant_ids) ||
    max_observations <= 0 ||
    requested_at < 0 ||
    request.record_id.is_blank() ||
    request.record_version.is_blank() ||
    request.record_digest.is_blank() ||
    experiment.record_id.is_blank() ||
    experiment.record_version.is_blank() ||
    experiment.record_digest.is_blank() ||
    activation_review.record_id.is_blank() ||
    activation_review.record_version.is_blank() ||
    activation_review.record_digest.is_blank() ||
    activation_reviewer.reviewer_id.is_blank() ||
    activation_reviewer.authority_ref.is_blank() ||
    !activation_reviewer.authorized {
    return None
  }
  Some({
    contract_version: capability_activation_request_contract_version(),
    request,
    receipt: self.receipt,
    scope_id,
    rollout_mode,
    challenger_participant_ids: ReadOnlyArray::from_array(
      challenger_participant_ids.copy(),
    ),
    max_observations,
    experiment,
    old_capability: self.old_capability,
    new_capability: self.new_capability,
    rollback: self.rollback,
    activation_review,
    activation_reviewer_id: activation_reviewer.reviewer_id,
    activation_reviewer_authority_ref: activation_reviewer.authority_ref,
    requested_at,
    adoption_authorized: true,
    source_side_effects_applied: false,
    activation_side_effects_applied: false,
  })
}
