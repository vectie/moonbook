///|
pub fn mooncode_draft_delivery_contract_version() -> String {
  "moonbook.bookkeeper.mooncode-draft-delivery.v1"
}

///|
fn mooncode_draft_delivery_adapter_id() -> String {
  "moonbook-mooncode-draft-delivery"
}

///|
fn mooncode_draft_delivery_adapter_version() -> String {
  "v1"
}

///|
fn draft_delivery_root(root : String) -> String {
  @pathx.join(store_root(root), "draft-deliveries")
}

///|
fn draft_delivery_key(request : MoonCodeDraftDeliveryRequest) -> String raise {
  if request.delivery_id.is_blank() ||
    request.delivery_version.is_blank() ||
    request.delivery_id.contains("/") ||
    request.delivery_id.contains("\\") ||
    request.delivery_id.contains("..") ||
    request.delivery_version.contains("/") ||
    request.delivery_version.contains("\\") ||
    request.delivery_version.contains("..") {
    fail("delivery identity must be safe and non-blank")
  }
  safe_record_key(request.delivery_id) +
  "--" +
  safe_record_key(request.delivery_version)
}

///|
fn draft_delivery_claim_path(
  root : String,
  request : MoonCodeDraftDeliveryRequest,
) -> String raise {
  @pathx.join(
    draft_delivery_root(root),
    draft_delivery_key(request) + ".claim.json",
  )
}

///|
fn draft_delivery_receipt_path(
  root : String,
  request : MoonCodeDraftDeliveryRequest,
) -> String raise {
  @pathx.join(
    draft_delivery_root(root),
    draft_delivery_key(request) + ".receipt.json",
  )
}

///|
fn draft_delivery_receipt_core(receipt : MoonCodeDraftImportReceipt) -> Json {
  {
    "contract_version": receipt.contract_version,
    "request": receipt.request.to_json(),
    "request_digest": receipt.request_digest,
    "adapter_id": receipt.adapter_id,
    "adapter_version": receipt.adapter_version,
    "envelope": receipt.envelope.to_json(),
    "work_order": receipt.work_order.to_json(),
    "packet_digest": receipt.packet_digest,
    "moonclaw_proposal_id": receipt.moonclaw_proposal_id,
    "moonclaw_status": receipt.moonclaw_status,
    "moonclaw_output_digest": receipt.moonclaw_output_digest,
    "confirmed": receipt.confirmed,
    "executed": receipt.executed,
    "external_effect_authorized": receipt.external_effect_authorized,
    "side_effects_applied": receipt.side_effects_applied,
  }
}

///|
fn draft_delivery_claim_core(
  request : MoonCodeDraftDeliveryRequest,
  request_digest : String,
  envelope : @bookkeeper.VersionedRecordReference,
  work_order : @bookkeeper.VersionedRecordReference,
  packet_path : String,
  packet_digest : String,
) -> Json {
  {
    "contract_version": mooncode_draft_delivery_contract_version(),
    "request": request.to_json(),
    "request_digest": request_digest,
    "adapter_id": mooncode_draft_delivery_adapter_id(),
    "adapter_version": mooncode_draft_delivery_adapter_version(),
    "envelope": envelope.to_json(),
    "work_order": work_order.to_json(),
    "packet_path": packet_path,
    "packet_digest": packet_digest,
    "confirmed": false,
    "executed": false,
    "external_effect_authorized": false,
  }
}

///|
/// Verify every immutable and no-authority invariant of a persisted MoonClaw
/// draft-import receipt. Product attestors use the same verifier as replay.
pub fn validate_mooncode_draft_import_receipt(
  receipt : MoonCodeDraftImportReceipt,
) -> Bool {
  receipt.contract_version == mooncode_draft_delivery_contract_version() &&
  receipt.request.contract_version == mooncode_draft_delivery_contract_version() &&
  receipt.adapter_id == mooncode_draft_delivery_adapter_id() &&
  receipt.adapter_version == mooncode_draft_delivery_adapter_version() &&
  receipt.request_digest == bookkeeper_payload_digest(receipt.request.to_json()) &&
  receipt.envelope == receipt.request.envelope &&
  receipt.request.expected_envelope_digest == receipt.envelope.record_digest &&
  reference_complete(receipt.envelope) &&
  reference_complete(receipt.work_order) &&
  receipt.receipt.record_id ==
  "mooncode-draft-import:" + receipt.request.delivery_id &&
  receipt.receipt.record_version == receipt.request.delivery_version &&
  receipt.receipt.record_digest ==
  bookkeeper_payload_digest(draft_delivery_receipt_core(receipt)) &&
  receipt.moonclaw_status == "Draft" &&
  !receipt.moonclaw_proposal_id.is_blank() &&
  !receipt.packet_digest.is_blank() &&
  !receipt.moonclaw_output_digest.is_blank() &&
  !receipt.confirmed &&
  !receipt.executed &&
  !receipt.external_effect_authorized &&
  !receipt.side_effects_applied
}

///|
fn exact_delivery_envelope(
  snapshot : BookkeeperStoreSnapshot,
  request : MoonCodeDraftDeliveryRequest,
) -> Result[
  (BookkeeperTransportEnvelope, DurableBookkeeperRecord, GovernedReviewReceipt),
  String,
] {
  let mut selected : BookkeeperTransportEnvelope? = None
  for envelope in snapshot.envelopes {
    if envelope.envelope == request.envelope {
      selected = Some(envelope)
      break
    }
  }
  let envelope = match selected {
    Some(value) => value
    None => return Err("exact Bookkeeper egress envelope not found")
  }
  if envelope.envelope.record_digest != request.expected_envelope_digest ||
    envelope.direction != Egress ||
    envelope.source_product != "moonbook" ||
    envelope.destination_product != "moonflow" ||
    envelope.message_kind != "mooncode.work_order" ||
    envelope.external_activation_allowed ||
    envelope.side_effects_applied {
    return Err("stale, wrong-kind, or authority-bearing egress envelope")
  }
  let work_order = match bridge_find_record(snapshot, envelope.subject) {
    Some(record) if record.stage == MoonCodeWorkOrder => record
    _ => return Err("egress subject is not an exact MoonCode work order")
  }
  let mut review : GovernedReviewReceipt? = None
  for link in envelope.links {
    match bridge_find_review(snapshot, link) {
      Some(candidate) if candidate.stage == MoonCodeWorkOrder &&
        candidate.subject == work_order.record &&
        candidate.review_complete &&
        candidate.requested == @bookkeeper.Accept &&
        candidate.disposition == @bookkeeper.Accept &&
        candidate.reviewer_kind == @bookkeeper.Human &&
        candidate.issues.is_empty() &&
        !candidate.side_effects_applied => review = Some(candidate)
      _ => ()
    }
  }
  let accepted_review = match review {
    Some(value) => value
    None => return Err("egress lacks its exact accepted work-order review")
  }
  let expected_digest = bookkeeper_payload_digest(
    mooncode_work_order_envelope_basis(
      work_order,
      accepted_review,
      envelope.payload,
    ),
  )
  if expected_digest != envelope.envelope.record_digest {
    return Err(
      "egress envelope digest does not match its current canonical body",
    )
  }
  Ok((envelope, work_order, accepted_review))
}

///|
pub async fn prepare_mooncode_draft_delivery(
  root : String,
  request : MoonCodeDraftDeliveryRequest,
) -> Result[MoonCodeDraftDeliveryPlan, String] {
  if request.contract_version != mooncode_draft_delivery_contract_version() ||
    request.expected_envelope_digest.is_blank() ||
    request.expected_envelope_digest != request.envelope.record_digest {
    return Err("invalid or stale MoonCode draft-delivery request")
  }
  let _delivery_key = draft_delivery_key(request) catch {
    error => return Err("\{error}")
  }
  let snapshot = replay_bookkeeper_store(root)
  if !snapshot.replay_issues.is_empty() {
    return Err("Bookkeeper journal has replay issues")
  }
  let (_, work_order, _) = match exact_delivery_envelope(snapshot, request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let request_digest = bookkeeper_payload_digest(request.to_json())
  let packet_path = match
    materialize_mooncode_draft_packet(root, {
      contract_version: bookkeeper_work_order_bridge_contract_version(),
      envelope: request.envelope,
    }) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let packet = @json.parse(@fsx.read_file(packet_path)) catch {
    error => return Err("invalid materialized MoonClaw packet: \{error}")
  }
  let packet_digest = bookkeeper_payload_digest(packet)
  let claim_core = draft_delivery_claim_core(
    request,
    request_digest,
    request.envelope,
    work_order.record,
    packet_path,
    packet_digest,
  )
  let claim_digest = bookkeeper_payload_digest(claim_core)
  let base_plan : MoonCodeDraftDeliveryPlan = {
    contract_version: mooncode_draft_delivery_contract_version(),
    request,
    request_digest,
    adapter_id: mooncode_draft_delivery_adapter_id(),
    adapter_version: mooncode_draft_delivery_adapter_version(),
    envelope: request.envelope,
    work_order: work_order.record,
    packet_path,
    packet_digest,
    claim_digest,
    already_imported: false,
    existing_receipt: None,
  }
  let receipt_path = draft_delivery_receipt_path(root, request)
  if @fsx.exists(receipt_path) {
    let receipt : MoonCodeDraftImportReceipt = @json.from_json(
      @json.parse(@fsx.read_file(receipt_path)),
    ) catch {
      _ => return Err("stored draft-import receipt is corrupt")
    }
    if !validate_mooncode_draft_import_receipt(receipt) ||
      receipt.request != request ||
      receipt.envelope != request.envelope ||
      receipt.work_order != work_order.record ||
      receipt.packet_digest != packet_digest {
      return Err("delivery identity has a conflicting immutable receipt")
    }
    return Ok({
      ..base_plan,
      already_imported: true,
      existing_receipt: Some(receipt),
    })
  }
  let claim_path = draft_delivery_claim_path(root, request)
  if @fsx.exists(claim_path) {
    let existing = @json.parse(@fsx.read_file(claim_path)) catch {
      _ => return Err("draft-delivery claim is corrupt")
    }
    if bookkeeper_payload_digest(existing) !=
      bookkeeper_payload_digest(claim_core) {
      return Err("delivery identity already has a different request body")
    }
    return Err(
      "draft-delivery claim has no receipt; reconcile MoonClaw before retrying",
    )
  }
  @fsx.make_directory(draft_delivery_root(root), recursive=true, exists_ok=true)
  write_atomic_json(claim_path, claim_core)
  Ok(base_plan)
}

///|
pub async fn complete_mooncode_draft_delivery(
  root : String,
  plan : MoonCodeDraftDeliveryPlan,
  moonclaw_output : Json,
) -> Result[MoonCodeDraftImportReceipt, String] {
  if plan.contract_version != mooncode_draft_delivery_contract_version() ||
    plan.already_imported ||
    plan.existing_receipt is Some(_) {
    return Err("invalid draft-delivery completion plan")
  }
  if plan.request.contract_version != mooncode_draft_delivery_contract_version() ||
    plan.request_digest != bookkeeper_payload_digest(plan.request.to_json()) ||
    plan.adapter_id != mooncode_draft_delivery_adapter_id() ||
    plan.adapter_version != mooncode_draft_delivery_adapter_version() ||
    plan.envelope != plan.request.envelope ||
    plan.request.expected_envelope_digest != plan.envelope.record_digest ||
    !reference_complete(plan.envelope) ||
    !reference_complete(plan.work_order) ||
    !@fsx.exists(plan.packet_path) {
    return Err("draft-delivery completion plan changed after preparation")
  }
  let packet = @json.parse(@fsx.read_file(plan.packet_path)) catch {
    _ => return Err("materialized MoonClaw packet is missing or corrupt")
  }
  if bookkeeper_payload_digest(packet) != plan.packet_digest {
    return Err("materialized MoonClaw packet digest changed")
  }
  let expected_claim = draft_delivery_claim_core(
    plan.request,
    plan.request_digest,
    plan.envelope,
    plan.work_order,
    plan.packet_path,
    plan.packet_digest,
  )
  if bookkeeper_payload_digest(expected_claim) != plan.claim_digest {
    return Err("draft-delivery completion plan no longer matches its claim")
  }
  guard moonclaw_output is Object(fields) else {
    return Err("MoonClaw draft import did not return JSON")
  }
  let proposal_id = match fields.get("proposal_id") {
    Some(String(value)) if !value.is_blank() => value
    _ => return Err("MoonClaw draft import omitted proposal_id")
  }
  if fields.get("status") != Some(Json::string("Draft")) ||
    fields.get("job_id") is Some(_) ||
    fields.get("workflow_id") is Some(_) ||
    fields.get("run_id") is Some(_) {
    return Err("MoonClaw import was not an unconfirmed, unexecuted draft")
  }
  let claim_path = draft_delivery_claim_path(root, plan.request)
  if !@fsx.exists(claim_path) {
    return Err("draft-delivery claim is missing")
  }
  let claim = @json.parse(@fsx.read_file(claim_path)) catch {
    _ => return Err("draft-delivery claim is corrupt")
  }
  if bookkeeper_payload_digest(claim) != plan.claim_digest {
    return Err("draft-delivery claim digest changed")
  }
  let mut receipt : MoonCodeDraftImportReceipt = {
    contract_version: mooncode_draft_delivery_contract_version(),
    receipt: {
      record_id: "mooncode-draft-import:" + plan.request.delivery_id,
      record_version: plan.request.delivery_version,
      record_digest: "pending",
    },
    request: plan.request,
    request_digest: plan.request_digest,
    adapter_id: plan.adapter_id,
    adapter_version: plan.adapter_version,
    envelope: plan.envelope,
    work_order: plan.work_order,
    packet_digest: plan.packet_digest,
    moonclaw_proposal_id: proposal_id,
    moonclaw_status: "Draft",
    moonclaw_output_digest: bookkeeper_payload_digest(moonclaw_output),
    confirmed: false,
    executed: false,
    external_effect_authorized: false,
    side_effects_applied: false,
  }
  receipt = {
    ..receipt,
    receipt: {
      ..receipt.receipt,
      record_digest: bookkeeper_payload_digest(
        draft_delivery_receipt_core(receipt),
      ),
    },
  }
  let receipt_path = draft_delivery_receipt_path(root, plan.request)
  if @fsx.exists(receipt_path) {
    let existing : MoonCodeDraftImportReceipt = @json.from_json(
      @json.parse(@fsx.read_file(receipt_path)),
    ) catch {
      _ => return Err("stored draft-import receipt is corrupt")
    }
    if existing == receipt && validate_mooncode_draft_import_receipt(existing) {
      return Ok(existing)
    }
    return Err("delivery identity already has a different receipt")
  }
  write_atomic_json(receipt_path, receipt.to_json())
  Ok(receipt)
}
