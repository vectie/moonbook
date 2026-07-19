///|
pub fn bookkeeper_work_order_bridge_contract_version() -> String {
  "moonbook.bookkeeper.work-order-bridge.v1"
}

///|
fn bridge_required_string(
  fields : Map[String, Json],
  key : String,
) -> Result[String, String] {
  match fields.get(key) {
    Some(String(value)) if !value.is_blank() => Ok(value)
    _ => Err("capability proposal payload is missing " + key)
  }
}

///|
fn bridge_required_bool(
  fields : Map[String, Json],
  key : String,
) -> Result[Bool, String] {
  match fields.get(key) {
    Some(True) => Ok(true)
    Some(False) => Ok(false)
    _ => Err("capability proposal payload is missing boolean " + key)
  }
}

///|
fn bridge_required_json(
  fields : Map[String, Json],
  key : String,
) -> Result[Json, String] {
  match fields.get(key) {
    Some(value) => Ok(value)
    None => Err("capability proposal payload is missing " + key)
  }
}

///|
fn bridge_find_record(
  snapshot : BookkeeperStoreSnapshot,
  reference : @bookkeeper.VersionedRecordReference,
) -> DurableBookkeeperRecord? {
  for record in snapshot.records {
    if record.record == reference {
      return Some(record)
    }
  }
  None
}

///|
fn bridge_find_review(
  snapshot : BookkeeperStoreSnapshot,
  reference : @bookkeeper.VersionedRecordReference,
) -> GovernedReviewReceipt? {
  for review in snapshot.reviews {
    if review.receipt == reference {
      return Some(review)
    }
  }
  None
}

///|
fn bridge_legacy_evidence(
  evidence : ArrayView[@bookkeeper.VersionedEvidenceReference],
) -> Array[@bookkeeper.EvidenceReference] {
  evidence.map(fn(reference) {
    {
      reference_id: reference.reference_id,
      digest: reference.digest,
      provenance_ref: reference.provenance_ref,
    }
  })
}

///|
fn bridge_reviewer(
  review : GovernedReviewReceipt,
) -> @bookkeeper.ReviewerAuthority {
  {
    reviewer_id: review.reviewer.reviewer_id,
    authority_ref: review.reviewer.authority_ref,
    authorized: review.reviewer.authorized,
    evidence_refs: ReadOnlyArray::from_array(review.reviewer.evidence_refs),
  }
}

///|
async fn bridge_active_grant_matches_review(
  root : String,
  grant_reference : @bookkeeper.VersionedRecordReference,
  review : GovernedReviewReceipt,
) -> Bool {
  let registry = read_authority_registry(root)
  let mut latest : BookkeeperAuthorityGrant? = None
  for grant in registry.grants {
    if grant.reviewer_id != review.reviewer.reviewer_id ||
      grant.authority_ref != review.reviewer.authority_ref {
      continue
    }
    match latest {
      None => latest = Some(grant)
      Some(current) =>
        if grant.granted_at > current.granted_at {
          latest = Some(grant)
        }
    }
  }
  match latest {
    Some(grant) =>
      grant.grant == grant_reference &&
      authority_grant_matches(grant, review.reviewer_kind, review.reviewer)
    None => false
  }
}

///|
fn bridge_policy_proposal(
  record : DurableBookkeeperRecord,
) -> Result[@bookkeeper.CapabilityProposal, String] {
  guard record.payload is Object(fields) else {
    return Err("capability proposal payload must be an object")
  }
  guard bridge_required_string(fields, "contract_version")
    is Ok(contract_version) else {
    return Err("capability proposal payload is missing contract_version")
  }
  if contract_version != @bookkeeper.bookkeeper_contract_version() {
    return Err("capability proposal uses an unsupported contract")
  }
  guard bridge_required_string(fields, "proposal_id") is Ok(proposal_id) else {
    return Err("capability proposal payload is missing proposal_id")
  }
  guard bridge_required_string(fields, "proposal_version")
    is Ok(proposal_version) else {
    return Err("capability proposal payload is missing proposal_version")
  }
  guard bridge_required_string(fields, "capability_id") is Ok(capability_id) else {
    return Err("capability proposal payload is missing capability_id")
  }
  guard bridge_required_string(fields, "capability_version")
    is Ok(capability_version) else {
    return Err("capability proposal payload is missing capability_version")
  }
  guard bridge_required_string(fields, "change_digest") is Ok(change_digest) else {
    return Err("capability proposal payload is missing change_digest")
  }
  guard bridge_required_string(fields, "summary") is Ok(summary) else {
    return Err("capability proposal payload is missing summary")
  }
  guard bridge_required_string(fields, "owner_route") is Ok(owner_route) else {
    return Err("capability proposal payload is missing owner_route")
  }
  guard bridge_required_string(fields, "aggregation_digest")
    is Ok(aggregation_digest) else {
    return Err("capability proposal payload is missing aggregation_digest")
  }
  guard bridge_required_json(fields, "source_finding_refs") is Ok(source_json) else {
    return Err("capability proposal payload is missing source_finding_refs")
  }
  let source_finding_refs : Array[@bookkeeper.VersionedRecordReference] = @json.from_json(
    source_json,
  ) catch {
    error => return Err("invalid source_finding_refs: \{error}")
  }
  guard bridge_required_json(fields, "promotion_policy_ref") is Ok(policy_json) else {
    return Err("capability proposal payload is missing promotion_policy_ref")
  }
  let promotion_policy_ref : @bookkeeper.VersionedRecordReference = @json.from_json(
    policy_json,
  ) catch {
    error => return Err("invalid promotion_policy_ref: \{error}")
  }
  guard bridge_required_json(fields, "evidence_refs") is Ok(evidence_json) else {
    return Err("capability proposal payload is missing evidence_refs")
  }
  let payload_evidence : Array[@bookkeeper.VersionedEvidenceReference] = @json.from_json(
    evidence_json,
  ) catch {
    error => return Err("invalid capability proposal evidence: \{error}")
  }
  if proposal_id != record.record.record_id ||
    proposal_version != record.record.record_version ||
    owner_route != record.owner_route ||
    summary != record.summary ||
    source_finding_refs != record.links ||
    payload_evidence != record.evidence_refs {
    return Err("capability proposal payload differs from its durable record")
  }
  guard bridge_required_bool(fields, "policy_promoted") is Ok(policy_promoted) else {
    return Err("capability proposal payload is missing policy_promoted")
  }
  guard bridge_required_bool(fields, "review_required") is Ok(review_required) else {
    return Err("capability proposal payload is missing review_required")
  }
  guard bridge_required_bool(fields, "self_application_allowed")
    is Ok(self_application_allowed) else {
    return Err(
      "capability proposal payload is missing self_application_allowed",
    )
  }
  if !policy_promoted || !review_required || self_application_allowed {
    return Err("capability proposal is not policy-promoted and review-bound")
  }
  @bookkeeper.reconstruct_policy_promoted_capability_proposal(
    proposal_id~,
    proposal_version~,
    capability_id~,
    capability_version~,
    owner_route~,
    change_digest~,
    summary~,
    evidence_refs=bridge_legacy_evidence(record.evidence_refs),
    source_finding_refs~,
    promotion_policy_ref~,
    aggregation_digest~,
  )
}

///|
fn bridge_work_order_payload(
  proposal_record : DurableBookkeeperRecord,
  proposal_review : GovernedReviewReceipt,
  projection_request : @bookkeeper.VersionedRecordReference,
  attestation : @bookkeeper.VersionedRecordReference,
) -> Result[Json, String] {
  guard proposal_record.payload is Object(fields) else {
    return Err("capability proposal payload must be an object")
  }
  guard bridge_required_string(fields, "capability_id") is Ok(capability_id) else {
    return Err("capability proposal payload is missing capability_id")
  }
  guard bridge_required_string(fields, "capability_version")
    is Ok(capability_version) else {
    return Err("capability proposal payload is missing capability_version")
  }
  guard bridge_required_string(fields, "change_digest") is Ok(change_digest) else {
    return Err("capability proposal payload is missing change_digest")
  }
  guard bridge_required_json(fields, "promotion_policy_ref")
    is Ok(promotion_policy) else {
    return Err("capability proposal payload is missing promotion_policy_ref")
  }
  Ok({
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "record_kind": "mooncode_work_order",
    "projection_request": projection_request.to_json(),
    "proposal": proposal_record.record.to_json(),
    "proposal_change": {
      "record_id": proposal_record.record.record_id,
      "record_version": proposal_record.record.record_version,
      "record_digest": change_digest,
    },
    "capability": {
      "record_id": capability_id,
      "record_version": capability_version,
      "record_digest": change_digest,
    },
    "promotion_policy": promotion_policy,
    "owner_route": proposal_record.owner_route,
    "summary": proposal_record.summary,
    "evidence_refs": proposal_record.evidence_refs.to_json(),
    "proposal_review": proposal_review.receipt.to_json(),
    "review_attestation": attestation.to_json(),
    "authority_grant": proposal_review.reviewer.grant.to_json(),
    "reviewer_kind": proposal_review.reviewer_kind.to_json(),
    "reviewer_id": proposal_review.reviewer.reviewer_id,
    "reviewer_authority_ref": proposal_review.reviewer.authority_ref,
    "draft_only": true,
    "external_activation_allowed": false,
    "side_effects_applied": false,
  })
}

///|
pub async fn project_governed_mooncode_work_order(
  root : String,
  request : GovernedWorkOrderBridgeRequest,
) -> BookkeeperMutationResult {
  if request.contract_version != bookkeeper_work_order_bridge_contract_version() {
    return rejected_result(root, ["unsupported work-order bridge contract"])
  }
  let snapshot = replay_bookkeeper_store(root)
  if !snapshot.replay_issues.is_empty() {
    return rejected_result(root, ["Bookkeeper journal has replay issues"])
  }
  let proposal_record = match bridge_find_record(snapshot, request.proposal) {
    Some(record) if record.stage == CapabilityProposal => record
    _ => return rejected_result(root, ["exact capability proposal not found"])
  }
  let proposal_review = match
    bridge_find_review(snapshot, request.proposal_review) {
    Some(review) if review.stage == CapabilityProposal &&
      review.subject == proposal_record.record &&
      review.review_complete &&
      review.requested == @bookkeeper.Accept &&
      review.disposition == @bookkeeper.Accept &&
      review.reviewer_kind == @bookkeeper.Human &&
      review.issues.is_empty() &&
      !review.side_effects_applied => review
    _ =>
      return rejected_result(root, [
        "an exact named-human accepted capability-proposal review is required",
      ])
  }
  if !bridge_active_grant_matches_review(
      root,
      request.authority_grant,
      proposal_review,
    ) {
    return rejected_result(root, [
      "the proposal reviewer no longer has the exact active authority grant",
    ])
  }
  let proposal = match bridge_policy_proposal(proposal_record) {
    Ok(value) => value
    Err(error) => return rejected_result(root, [error])
  }
  let reviewer = bridge_reviewer(proposal_review)
  let review = @bookkeeper.review_capability_proposal(
    proposal,
    receipt_id=proposal_review.receipt.record_id,
    receipt_version=proposal_review.receipt.record_version,
    receipt_digest=proposal_review.receipt.record_digest,
    reviewer~,
    requested=@bookkeeper.Accept,
    evidence_refs=bridge_legacy_evidence(proposal_record.evidence_refs),
  )
  let projection_basis : Json = {
    "contract_version": bookkeeper_work_order_bridge_contract_version(),
    "proposal": proposal_record.record.to_json(),
    "proposal_review": proposal_review.receipt.to_json(),
    "authority_grant": request.authority_grant.to_json(),
    "evidence_refs": proposal_record.evidence_refs.to_json(),
  }
  let projection_request : @bookkeeper.VersionedRecordReference = {
    record_id: "mooncode-projection:" + proposal_record.record.record_id,
    record_version: proposal_record.record.record_version,
    record_digest: bookkeeper_payload_digest(projection_basis),
  }
  let attestation_basis : Json = {
    "contract_version": bookkeeper_work_order_bridge_contract_version(),
    "projection_request": projection_request.to_json(),
    "proposal": proposal_record.record.to_json(),
    "proposal_review": proposal_review.receipt.to_json(),
    "authority_grant": request.authority_grant.to_json(),
    "reviewer_id": proposal_review.reviewer.reviewer_id,
    "reviewer_authority_ref": proposal_review.reviewer.authority_ref,
    "evidence_refs": proposal_record.evidence_refs.to_json(),
  }
  let attestation_reference : @bookkeeper.VersionedRecordReference = {
    record_id: "mooncode-attestation:" + proposal_record.record.record_id,
    record_version: proposal_record.record.record_version,
    record_digest: bookkeeper_payload_digest(attestation_basis),
  }
  let provisional_payload = match
    bridge_work_order_payload(
      proposal_record, proposal_review, projection_request, attestation_reference,
    ) {
    Ok(value) => value
    Err(error) => return rejected_result(root, [error])
  }
  let work_order_reference : @bookkeeper.VersionedRecordReference = {
    record_id: "mooncode-work-order:" + proposal_record.record.record_id,
    record_version: proposal_record.record.record_version,
    record_digest: bookkeeper_payload_digest(provisional_payload),
  }
  let projection = @bookkeeper.WorkOrderProjectionRequest::new(
    request=projection_request,
    work_order=work_order_reference,
    evidence_refs=proposal_record.evidence_refs,
  )
  let authority = @bookkeeper.ReviewAuthorityAttestation::new(
    attestation=attestation_reference,
    proposal,
    review,
    reviewer_kind=@bookkeeper.Human,
    reviewer~,
    evidence_refs=proposal_record.evidence_refs,
    projection_request=projection,
  )
  let decision = @bookkeeper.project_mooncode_work_order(
    proposal,
    review,
    projection,
    Some(authority),
  )
  if !decision.is_ready() {
    return rejected_result(root, [
      "canonical MoonCode projection denied: " + decision.to_json().stringify(),
    ])
  }
  persist_bookkeeper_record(root, {
    contract_version: bookkeeper_store_contract_version(),
    record: work_order_reference,
    stage: MoonCodeWorkOrder,
    subject: Some(proposal_record.record),
    links: [proposal_record.record, proposal_review.receipt],
    title: "MoonCode work order for " + proposal_record.title,
    summary: proposal_record.summary,
    owner_route: proposal_record.owner_route,
    status: "awaiting human review",
    evidence_refs: proposal_record.evidence_refs,
    issue_refs: [],
    requires_human_review: true,
    next_action: "named human must separately review the exact MoonCode work order",
    source_product: "moonbook",
    recorded_at: proposal_review.decided_at,
    payload: provisional_payload,
    side_effects_applied: false,
  })
}

///|
fn bridge_moonclaw_packet(
  work_order : DurableBookkeeperRecord,
  review : GovernedReviewReceipt,
) -> Json {
  {
    "packet_id": "bookkeeper-" + work_order.record.record_id,
    "title": work_order.title,
    "summary": work_order.summary,
    "request_text": "Implement the exact reviewed MoonCode work order. Preserve every evidence and authority binding; return implementation and verification evidence to MoonBook without self-adoption.",
    "profile": "mooncode_work_order_controller",
    "output_contract": {
      "contract_version": @bookkeeper.capability_adoption_contract_version(),
      "result_kind": "mooncode.result",
      "source_work_order": work_order.record.to_json(),
      "human_adoption_required": true,
    },
    "source_path": ".moonbook/bookkeeper/snapshot.json",
    "context_pages": [
      ".moonbook/bookkeeper/snapshot.json", ".moonbook/bookkeeper/ui-state.json",
      "KEEPER.md",
    ],
    "related_pages": [],
    "skill_paths": ["skills/wiki-review/SKILL.md"],
    "notes": [
      "This packet is imported as a MoonClaw draft only; import must never confirm or execute it.",
      "MoonClaw remains the sole agent runtime and MoonCode is the coding surface.",
      "Do not mutate MoonBook durable records, fabricate human authority, or adopt the result.",
    ],
    "tags": ["bookkeeper", "mooncode", "reviewed-work-order"],
    "metadata": {
      "agent_runtime": "moonclaw",
      "implementation_surface": "mooncode",
      "durable_owner": "moonbook",
      "work_order": work_order.to_json(),
      "work_order_review": review.to_json(),
      "canonical_evidence_refs": work_order.evidence_refs.to_json(),
      "human_confirm_required": true,
      "auto_confirm": false,
      "auto_execute": false,
      "self_application_allowed": false,
    },
  }
}

///|
fn mooncode_work_order_envelope_basis(
  work_order : DurableBookkeeperRecord,
  review : GovernedReviewReceipt,
  packet : Json,
) -> Json {
  {
    "contract_version": bookkeeper_transport_contract_version(),
    "direction": "Egress",
    "source_product": "moonbook",
    "destination_product": "moonflow",
    "message_kind": "mooncode.work_order",
    "subject": work_order.record.to_json(),
    "links": [review.receipt.to_json()],
    "evidence_refs": work_order.evidence_refs.to_json(),
    "authority_ref": review.reviewer.authority_ref,
    "payload": packet,
    "external_activation_allowed": false,
    "side_effects_applied": false,
  }
}

///|
pub async fn emit_governed_mooncode_work_order(
  root : String,
  request : GovernedWorkOrderEgressRequest,
) -> BookkeeperMutationResult {
  if request.contract_version != bookkeeper_work_order_bridge_contract_version() {
    return rejected_result(root, ["unsupported work-order bridge contract"])
  }
  let snapshot = replay_bookkeeper_store(root)
  let work_order = match bridge_find_record(snapshot, request.work_order) {
    Some(record) if record.stage == MoonCodeWorkOrder => record
    _ => return rejected_result(root, ["exact MoonCode work order not found"])
  }
  let review = match bridge_find_review(snapshot, request.work_order_review) {
    Some(receipt) if receipt.stage == MoonCodeWorkOrder &&
      receipt.subject == work_order.record &&
      receipt.review_complete &&
      receipt.requested == @bookkeeper.Accept &&
      receipt.disposition == @bookkeeper.Accept &&
      receipt.reviewer_kind == @bookkeeper.Human &&
      receipt.issues.is_empty() &&
      !receipt.side_effects_applied => receipt
    _ =>
      return rejected_result(root, [
        "a separate named-human accepted MoonCode work-order review is required",
      ])
  }
  if !bridge_active_grant_matches_review(root, request.authority_grant, review) {
    return rejected_result(root, [
      "the work-order reviewer no longer has the exact active authority grant",
    ])
  }
  let packet = bridge_moonclaw_packet(work_order, review)
  let envelope_basis = mooncode_work_order_envelope_basis(
    work_order, review, packet,
  )
  let envelope : BookkeeperTransportEnvelope = {
    contract_version: bookkeeper_transport_contract_version(),
    envelope: {
      record_id: "mooncode-work-order-egress:" + work_order.record.record_id,
      record_version: work_order.record.record_version,
      record_digest: bookkeeper_payload_digest(envelope_basis),
    },
    direction: Egress,
    source_product: "moonbook",
    destination_product: "moonflow",
    message_kind: "mooncode.work_order",
    subject: work_order.record,
    links: [review.receipt],
    evidence_refs: work_order.evidence_refs,
    authority_ref: review.reviewer.authority_ref,
    recorded_at: review.decided_at,
    payload: packet,
    external_activation_allowed: false,
    side_effects_applied: false,
  }
  persist_transport_envelope(root, envelope)
}

///|
pub async fn materialize_mooncode_draft_packet(
  root : String,
  request : MoonCodeDraftImportRequest,
) -> Result[String, String] {
  if request.contract_version != bookkeeper_work_order_bridge_contract_version() {
    return Err("unsupported work-order bridge contract")
  }
  let snapshot = replay_bookkeeper_store(root)
  if !snapshot.replay_issues.is_empty() {
    return Err("Bookkeeper journal has replay issues")
  }
  let mut selected : BookkeeperTransportEnvelope? = None
  for item in snapshot.envelopes {
    if item.envelope == request.envelope {
      selected = Some(item)
      break
    }
  }
  let envelope = match selected {
    Some(item) if item.direction == Egress &&
      item.source_product == "moonbook" &&
      item.destination_product == "moonflow" &&
      item.message_kind == "mooncode.work_order" &&
      !item.external_activation_allowed &&
      !item.side_effects_applied => item
    _ => return Err("exact reviewed mooncode.work_order egress not found")
  }
  let path = @pathx.join(
    root,
    "keeper/jobs/mooncode-work-order-" +
    safe_record_key(envelope.subject.record_id) +
    "--" +
    safe_record_key(envelope.subject.record_version) +
    ".json",
  )
  @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true)
  let text = envelope.payload.stringify(indent=2)
  if @fsx.exists(path) {
    if @fsx.read_file(path) != text {
      return Err("draft packet identity already has conflicting content")
    }
    return Ok(path)
  }
  @fsx.write_to_file(path, text, create=0o600)
  Ok(path)
}
