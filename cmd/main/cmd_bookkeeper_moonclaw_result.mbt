///|
struct BookkeeperMoonClawResultCandidate {
  record_id : String
  record_version : String
  stage : String
  title : String
  summary : String
  owner_route : String
  recorded_at : Int
  links : Array[@bookkeeper.VersionedRecordReference]
  issue_refs : Array[String]
  next_action : String
  payload : Json
} derive(Debug, Eq, ToJson, FromJson)

///|
struct BookkeeperMoonClawResult {
  contract_version : String
  packet_id : String
  source_packet_digest : String
  source_snapshot_digest : String
  subject : @bookkeeper.VersionedRecordReference
  subject_stage : String
  evidence_refs : Array[@bookkeeper.VersionedEvidenceReference]
  producer : String
  model : String
  candidate : BookkeeperMoonClawResultCandidate
} derive(Debug, Eq, ToJson, FromJson)

///|
struct VerifiedBookkeeperMoonClawPacket {
  packet : BookkeeperMoonClawPacket
  request : BookkeeperMoonClawRequest
  source_snapshot : @bookkeeper_store.BookkeeperStoreSnapshot
  subject : @bookkeeper_store.DurableBookkeeperRecord
  source_snapshot_digest : String
  source_packet_digest : String
}

///|
fn result_allowed_key(key : String, allowed : ArrayView[String]) -> Bool {
  allowed.any(fn(value) { value == key })
}

///|
fn result_require_exact_keys(
  value : Json,
  allowed : ArrayView[String],
  label : String,
) -> Unit raise {
  guard value is Object(fields) else { fail("\{label} must be an object") }
  for key, _ in fields {
    if !result_allowed_key(key, allowed) {
      fail("\{label} contains unsupported field: \{key}")
    }
  }
}

///|
fn result_required_json(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Json raise {
  match fields.get(key) {
    Some(value) => value
    None => fail("\{label} is missing \{key}")
  }
}

///|
fn result_required_string(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> String raise {
  match fields.get(key) {
    Some(String(value)) if !value.is_blank() => value
    _ => fail("\{label}.\{key} must be a non-blank string")
  }
}

///|
fn result_required_bool(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Bool raise {
  match fields.get(key) {
    Some(True) => true
    Some(False) => false
    _ => fail("\{label}.\{key} must be boolean")
  }
}

///|
fn result_required_int(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Int raise {
  match fields.get(key) {
    Some(Number(value, ..)) => value.to_int()
    _ => fail("\{label}.\{key} must be an integer")
  }
}

///|
fn result_record_reference(
  value : Json,
  label : String,
) -> @bookkeeper.VersionedRecordReference raise {
  result_require_exact_keys(
    value,
    ["record_id", "record_version", "record_digest"],
    label,
  )
  let reference : @bookkeeper.VersionedRecordReference = @json.from_json(value)
  if reference.record_id.is_blank() ||
    reference.record_version.is_blank() ||
    reference.record_digest.is_blank() {
    fail("\{label} must be a complete versioned record reference")
  }
  reference
}

///|
fn result_evidence_references(
  value : Json,
  label : String,
) -> Array[@bookkeeper.VersionedEvidenceReference] raise {
  guard value is Array(items) else { fail("\{label} must be an array") }
  let references : Array[@bookkeeper.VersionedEvidenceReference] = []
  for item in items {
    result_require_exact_keys(
      item,
      ["reference_id", "reference_version", "digest", "provenance_ref"],
      label,
    )
    let reference : @bookkeeper.VersionedEvidenceReference = @json.from_json(
      item,
    )
    if reference.reference_id.is_blank() ||
      reference.reference_version.is_blank() ||
      reference.digest.is_blank() ||
      reference.provenance_ref.is_blank() {
      fail("\{label} contains an incomplete evidence reference")
    }
    references.push(reference)
  }
  if references.is_empty() {
    fail("\{label} must not be empty")
  }
  references
}

///|
fn result_record_references(
  value : Json,
  label : String,
) -> Array[@bookkeeper.VersionedRecordReference] raise {
  guard value is Array(items) else { fail("\{label} must be an array") }
  let references : Array[@bookkeeper.VersionedRecordReference] = []
  for item in items {
    references.push(result_record_reference(item, label))
  }
  references
}

///|
fn bookkeeper_moonclaw_fenced_result(content : String) -> Json raise {
  let sections : Array[String] = []
  for section in content.split("```") {
    sections.push(section.to_owned())
  }
  if sections.length() != 3 {
    fail(
      "MoonClaw step result content must contain exactly one fenced JSON object",
    )
  }
  let fenced = sections[1]
  guard fenced.find("\n") is Some(first_line_end) else {
    fail("MoonClaw step result JSON fence is malformed")
  }
  let language = fenced[:first_line_end].trim().to_owned()
  if language != "json" {
    fail("MoonClaw step result fence must use the json language tag")
  }
  let body = fenced[first_line_end + 1:].trim().to_owned()
  if body.is_blank() {
    fail("MoonClaw step result JSON fence is empty")
  }
  let value = @json.parse(body)
  guard value is Object(_) else {
    fail("MoonClaw step result fence must contain one JSON object")
  }
  value
}

///|
fn unwrap_bookkeeper_moonclaw_result(value : Json) -> Json raise {
  guard value is Object(fields) else {
    fail("Bookkeeper MoonClaw result must be an object")
  }
  let step_id = fields.get("step_id")
  let result_decision = fields.get("result_decision")
  let content = fields.get("content")
  match (step_id, result_decision, content) {
    (None, None, None) => value
    (Some(String(step)), Some(String(decision)), Some(String(body))) => {
      if step.is_blank() || decision.is_blank() {
        fail("MoonClaw step result wrapper identity is incomplete")
      }
      bookkeeper_moonclaw_fenced_result(body)
    }
    _ => fail("MoonClaw step result wrapper is incomplete or ambiguous")
  }
}

///|
fn decode_bookkeeper_moonclaw_result_input(
  value : Json,
) -> BookkeeperMoonClawResult raise {
  decode_bookkeeper_moonclaw_result(unwrap_bookkeeper_moonclaw_result(value))
}

///|
fn decode_bookkeeper_moonclaw_result(
  value : Json,
) -> BookkeeperMoonClawResult raise {
  result_require_exact_keys(
    value,
    [
      "contract_version", "packet_id", "source_packet_digest", "source_snapshot_digest",
      "subject", "subject_stage", "evidence_refs", "producer", "model", "candidate",
    ],
    "Bookkeeper MoonClaw result",
  )
  guard value is Object(fields) else { fail("result must be an object") }
  let candidate_json = result_required_json(
    fields, "candidate", "Bookkeeper MoonClaw result",
  )
  result_require_exact_keys(
    candidate_json,
    [
      "record_id", "record_version", "stage", "title", "summary", "owner_route",
      "recorded_at", "links", "issue_refs", "next_action", "payload",
    ],
    "Bookkeeper MoonClaw candidate",
  )
  let decoded : BookkeeperMoonClawResult = @json.from_json(value)
  ignore(result_record_reference(decoded.subject.to_json(), "result subject"))
  ignore(
    result_evidence_references(
      decoded.evidence_refs.to_json(),
      "result evidence_refs",
    ),
  )
  bookkeeper_moonclaw_safe_id(
    decoded.candidate.record_id,
    "candidate record_id",
  )
  bookkeeper_moonclaw_safe_id(
    decoded.candidate.record_version,
    "candidate record_version",
  )
  if decoded.candidate.title.is_blank() ||
    decoded.candidate.summary.is_blank() ||
    decoded.candidate.owner_route.is_blank() ||
    decoded.candidate.next_action.is_blank() ||
    decoded.candidate.recorded_at <= 0 {
    fail("Bookkeeper MoonClaw candidate metadata is incomplete")
  }
  for issue in decoded.candidate.issue_refs {
    if issue.is_blank() {
      fail("Bookkeeper MoonClaw candidate issue_refs cannot contain blanks")
    }
  }
  decoded
}

///|
fn packet_metadata_object(
  packet : BookkeeperMoonClawPacket,
) -> Map[String, Json] raise {
  guard packet.metadata is Object(fields) else {
    fail("Bookkeeper MoonClaw packet metadata must be an object")
  }
  fields
}

///|
fn verify_bookkeeper_moonclaw_packet(
  packet_json : Json,
) -> VerifiedBookkeeperMoonClawPacket raise {
  result_require_exact_keys(
    packet_json,
    [
      "packet_id", "title", "summary", "request_text", "profile", "output_contract",
      "source_path", "context_pages", "related_pages", "skill_paths", "notes", "tags",
      "metadata",
    ],
    "Bookkeeper MoonClaw packet",
  )
  let packet : BookkeeperMoonClawPacket = @json.from_json(packet_json)
  if packet.profile != "bookkeeper_three_gap_controller" ||
    packet.output_contract != bookkeeper_moonclaw_result_contract_version() {
    fail("packet does not target the canonical Bookkeeper MoonClaw profile")
  }
  let metadata = packet_metadata_object(packet)
  let request_json = result_required_json(
    metadata, "request", "packet metadata",
  )
  let request : BookkeeperMoonClawRequest = @json.from_json(request_json)
  let source_snapshot_json = result_required_json(
    metadata, "source_snapshot", "packet metadata",
  )
  let source_snapshot : @bookkeeper_store.BookkeeperStoreSnapshot = @json.from_json(
    source_snapshot_json,
  )
  let source_snapshot_digest = result_required_string(
    metadata, "source_snapshot_digest", "packet metadata",
  )
  if source_snapshot_digest !=
    @bookkeeper_store.bookkeeper_payload_digest(source_snapshot.to_json()) {
    fail("packet source snapshot digest does not match embedded snapshot")
  }
  let subject_json = result_required_json(
    metadata, "subject_record", "packet metadata",
  )
  let subject : @bookkeeper_store.DurableBookkeeperRecord = @json.from_json(
    subject_json,
  )
  let exact_subject = bookkeeper_moonclaw_subject_record(
    source_snapshot, request,
  )
  if subject != exact_subject {
    fail("packet subject record does not exactly match embedded snapshot")
  }
  if result_required_string(metadata, "subject_stage", "packet metadata") !=
    subject.stage.id() {
    fail("packet subject stage does not match subject record")
  }
  if result_required_string(metadata, "model", "packet metadata") !=
    "gpt-5.6-sol" ||
    result_required_string(metadata, "agent_runtime", "packet metadata") !=
    "moonclaw" ||
    result_required_string(metadata, "durable_owner", "packet metadata") !=
    "moonbook" ||
    !result_required_bool(metadata, "human_review_required", "packet metadata") ||
    result_required_bool(metadata, "side_effects_allowed", "packet metadata") {
    fail("packet runtime, ownership, or governance metadata is invalid")
  }
  let source_packet_digest = result_required_string(
    metadata, "source_packet_digest", "packet metadata",
  )
  let expected_packet_digest = bookkeeper_moonclaw_packet_binding_digest(
    packet.packet_id,
    request,
    subject,
    source_snapshot_digest,
  )
  if source_packet_digest != expected_packet_digest {
    fail("packet binding digest is invalid")
  }
  {
    packet,
    request,
    source_snapshot,
    subject,
    source_snapshot_digest,
    source_packet_digest,
  }
}

///|
fn result_find_record(
  snapshot : @bookkeeper_store.BookkeeperStoreSnapshot,
  reference : @bookkeeper.VersionedRecordReference,
) -> @bookkeeper_store.DurableBookkeeperRecord raise {
  for record in snapshot.records {
    if record.record == reference {
      return record
    }
  }
  fail(
    "missing exact source record \{reference.record_id}@\{reference.record_version}",
  )
}

///|
fn result_has_human_accept(
  snapshot : @bookkeeper_store.BookkeeperStoreSnapshot,
  record : @bookkeeper_store.DurableBookkeeperRecord,
) -> Bool {
  snapshot.reviews.any(fn(review) {
    review.stage == record.stage &&
    review.subject == record.record &&
    review.review_complete &&
    review.disposition == Accept &&
    review.reviewer_kind == Human
  })
}

///|
fn result_evidence_compare(
  left : @bookkeeper.VersionedEvidenceReference,
  right : @bookkeeper.VersionedEvidenceReference,
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
fn result_canonical_evidence(
  records : ArrayView[@bookkeeper_store.DurableBookkeeperRecord],
) -> Array[@bookkeeper.VersionedEvidenceReference] raise {
  let evidence : Array[@bookkeeper.VersionedEvidenceReference] = []
  for record in records {
    for reference in record.evidence_refs {
      evidence.push(reference)
    }
  }
  evidence.sort_by(result_evidence_compare)
  let unique : Array[@bookkeeper.VersionedEvidenceReference] = []
  for reference in evidence {
    match unique.last() {
      Some(previous) if previous.reference_id == reference.reference_id &&
        previous.reference_version == reference.reference_version =>
        if previous != reference {
          fail("conflicting exact evidence identity in source findings")
        }
      _ => unique.push(reference)
    }
  }
  unique
}

///|
fn result_validate_common_payload(
  fields : Map[String, Json],
  result : BookkeeperMoonClawResult,
  verified : VerifiedBookkeeperMoonClawPacket,
  label : String,
) -> Unit raise {
  if result_required_string(fields, "summary", label) !=
    result.candidate.summary ||
    result_required_string(fields, "owner_route", label) !=
    result.candidate.owner_route {
    fail("\{label} summary or owner route does not match candidate")
  }
  if result_required_string(fields, "source_snapshot_digest", label) !=
    verified.source_snapshot_digest ||
    result_required_string(fields, "source_packet_digest", label) !=
    verified.source_packet_digest {
    fail("\{label} source bindings do not match packet")
  }
  let evidence = result_evidence_references(
    result_required_json(fields, "evidence_refs", label),
    "\{label}.evidence_refs",
  )
  if evidence != result.evidence_refs {
    fail("\{label} evidence does not match result evidence")
  }
}

///|
fn result_validate_gap_payload(
  result : BookkeeperMoonClawResult,
  verified : VerifiedBookkeeperMoonClawPacket,
) -> Unit raise {
  let label = "Three-Gap candidate payload"
  result_require_exact_keys(
    result.candidate.payload,
    [
      "contract_version", "candidate_schema", "subject", "learning_key", "gap_class",
      "transition", "severity", "owner_route", "summary", "evidence_refs", "source_snapshot_digest",
      "source_packet_digest",
    ],
    label,
  )
  guard result.candidate.payload is Object(fields) else {
    fail("\{label} must be an object")
  }
  if result_required_string(fields, "contract_version", label) !=
    @bookkeeper.three_gap_contract_version() ||
    result_required_string(fields, "candidate_schema", label) !=
    "three_gap_finding.v1" {
    fail("invalid Three-Gap candidate payload contract")
  }
  let subject = result_record_reference(
    result_required_json(fields, "subject", label),
    "payload subject",
  )
  if subject != result.subject {
    fail("Three-Gap payload subject does not match result subject")
  }
  ignore(
    result_record_reference(
      result_required_json(fields, "learning_key", label),
      "payload learning_key",
    ),
  )
  let gap_class = result_required_string(fields, "gap_class", label)
  let transition = result_required_string(fields, "transition", label)
  let expected_transition = match gap_class {
    "information_gap" => "unknown_to_known"
    "recognition_gap" => "known_to_matters"
    "decisiveness_gap" => "matters_to_act"
    _ => fail("unsupported Three-Gap class")
  }
  if transition != expected_transition {
    fail("Three-Gap transition does not match gap class")
  }
  let severity = result_required_int(fields, "severity", label)
  if severity < 1 || severity > 5 {
    fail("Three-Gap severity must be between 1 and 5")
  }
  result_validate_common_payload(fields, result, verified, label)
}

///|
fn result_validate_capability_payload(
  result : BookkeeperMoonClawResult,
  verified : VerifiedBookkeeperMoonClawPacket,
) -> Unit raise {
  let label = "capability proposal candidate payload"
  result_require_exact_keys(
    result.candidate.payload,
    [
      "contract_version", "candidate_schema", "proposal_id", "proposal_version",
      "subject", "capability_id", "capability_version", "change_digest", "summary",
      "owner_route", "evidence_refs", "source_finding_refs", "promotion_policy_ref",
      "aggregation_digest", "policy_promoted", "review_required", "self_application_allowed",
      "source_snapshot_digest", "source_packet_digest",
    ],
    label,
  )
  guard result.candidate.payload is Object(fields) else {
    fail("\{label} must be an object")
  }
  if result_required_string(fields, "contract_version", label) !=
    @bookkeeper.bookkeeper_contract_version() ||
    result_required_string(fields, "candidate_schema", label) !=
    "capability_proposal.v1" ||
    result_required_string(fields, "proposal_id", label) !=
    result.candidate.record_id ||
    result_required_string(fields, "proposal_version", label) !=
    result.candidate.record_version {
    fail("invalid capability proposal candidate payload identity or contract")
  }
  let subject = result_record_reference(
    result_required_json(fields, "subject", label),
    "payload subject",
  )
  if subject != result.subject {
    fail("capability proposal payload subject does not match result")
  }
  for
    key in [
      "capability_id", "capability_version", "change_digest", "aggregation_digest",
    ] {
    ignore(result_required_string(fields, key, label))
  }
  ignore(
    result_record_reference(
      result_required_json(fields, "promotion_policy_ref", label),
      "payload promotion_policy_ref",
    ),
  )
  let source_refs = result_record_references(
    result_required_json(fields, "source_finding_refs", label),
    "payload source_finding_refs",
  )
  if source_refs != result.candidate.links ||
    !result_required_bool(fields, "policy_promoted", label) ||
    !result_required_bool(fields, "review_required", label) ||
    result_required_bool(fields, "self_application_allowed", label) {
    fail("capability proposal promotion or review invariants are invalid")
  }
  result_validate_common_payload(fields, result, verified, label)
}

///|
fn materialize_bookkeeper_moonclaw_record(
  verified : VerifiedBookkeeperMoonClawPacket,
  current : @bookkeeper_store.BookkeeperStoreSnapshot,
  result : BookkeeperMoonClawResult,
) -> @bookkeeper_store.DurableBookkeeperRecord raise {
  if result.contract_version != bookkeeper_moonclaw_result_contract_version() ||
    result.packet_id != verified.packet.packet_id ||
    result.source_packet_digest != verified.source_packet_digest ||
    result.source_snapshot_digest != verified.source_snapshot_digest ||
    result.subject != verified.request.subject ||
    result.subject_stage != verified.subject.stage.id() ||
    result.producer != "moonclaw" ||
    result.model != "gpt-5.6-sol" {
    fail("MoonClaw result does not exactly bind the source packet")
  }
  if !current.replay_issues.is_empty() {
    fail("current Bookkeeper journal has replay issues")
  }
  let current_subject = result_find_record(current, result.subject)
  if current_subject != verified.subject {
    fail("current Bookkeeper subject differs from source packet subject")
  }
  let (stage, source_records) = match result.candidate.stage {
    "three_gap_finding" => {
      if verified.subject.stage != OutcomeBinding ||
        result.candidate.links != [result.subject] {
        fail("Three-Gap candidate requires exactly its outcome subject link")
      }
      result_validate_gap_payload(result, verified)
      (@bookkeeper_store.ThreeGapFinding, [verified.subject])
    }
    "capability_proposal" => {
      if verified.subject.stage != ThreeGapFinding ||
        result.candidate.links.length() < 2 ||
        !result.candidate.links.contains(result.subject) {
        fail(
          "capability proposal requires at least two linked reviewed findings including the packet subject",
        )
      }
      let records : Array[@bookkeeper_store.DurableBookkeeperRecord] = []
      for link in result.candidate.links {
        let source_record = result_find_record(verified.source_snapshot, link)
        let current_record = result_find_record(current, link)
        if source_record != current_record ||
          source_record.stage != ThreeGapFinding ||
          !result_has_human_accept(verified.source_snapshot, source_record) ||
          !result_has_human_accept(current, current_record) {
          fail(
            "capability proposal source finding is not an exact named-human accepted record",
          )
        }
        records.push(source_record)
      }
      result_validate_capability_payload(result, verified)
      (@bookkeeper_store.CapabilityProposal, records)
    }
    _ => fail("unsupported Bookkeeper MoonClaw candidate stage")
  }
  let expected_evidence = result_canonical_evidence(source_records)
  if result.evidence_refs != expected_evidence {
    fail("MoonClaw result evidence is not the exact canonical source evidence")
  }
  let payload_digest = @bookkeeper_store.bookkeeper_payload_digest(
    result.candidate.payload,
  )
  {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    record: {
      record_id: result.candidate.record_id,
      record_version: result.candidate.record_version,
      record_digest: payload_digest,
    },
    stage,
    subject: Some(result.subject),
    links: result.candidate.links,
    title: result.candidate.title,
    summary: result.candidate.summary,
    owner_route: result.candidate.owner_route,
    status: if result.candidate.issue_refs.is_empty() {
      "awaiting human review"
    } else {
      "blocked"
    },
    evidence_refs: result.evidence_refs,
    issue_refs: result.candidate.issue_refs,
    requires_human_review: true,
    next_action: result.candidate.next_action,
    source_product: "moonclaw",
    recorded_at: result.candidate.recorded_at,
    payload: result.candidate.payload,
    side_effects_applied: false,
  }
}

///|
async fn ingest_bookkeeper_moonclaw_result(
  root : String,
  packet_path : String,
  result_json : Json,
) -> @bookkeeper_store.BookkeeperMutationResult {
  let packet_json = @json.parse(@fsx.read_file(packet_path))
  let verified = verify_bookkeeper_moonclaw_packet(packet_json)
  let result = decode_bookkeeper_moonclaw_result_input(result_json)
  let current = @bookkeeper_store.replay_bookkeeper_store(root)
  let record = materialize_bookkeeper_moonclaw_record(verified, current, result)
  @bookkeeper_store.persist_bookkeeper_record(root, record)
}

///|
async fn run_bookkeeper_moonclaw_ingest_result(
  root : String,
  packet_path : String,
  result_path : String,
) -> Unit {
  let resolved_packet = resolve_keeper_packet_path(root, packet_path)
  let resolved_result = resolve_keeper_packet_path(root, result_path)
  let result = ingest_bookkeeper_moonclaw_result(
    root,
    resolved_packet,
    @json.parse(@fsx.read_file(resolved_result)),
  ) catch {
    error => {
      println("moonbook bookkeeper moonclaw ingest-result failed: \{error}")
      return
    }
  }
  print_json(result)
}
