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
  learning_key : @bookkeeper.VersionedRecordReference
  canonical_evidence_refs : Array[@bookkeeper.VersionedEvidenceReference]
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
  let learning_key = bookkeeper_moonclaw_learning_key(subject)
  let result_contract = result_required_json(
    metadata, "result_contract", "packet metadata",
  )
  if result_contract !=
    bookkeeper_moonclaw_result_contract(subject, learning_key) {
    fail("packet result contract is not the deterministic MoonBook contract")
  }
  let canonical_evidence_refs = result_evidence_references(
    result_required_json(metadata, "canonical_evidence_refs", "packet metadata"),
    "packet metadata.canonical_evidence_refs",
  )
  if canonical_evidence_refs !=
    bookkeeper_moonclaw_canonical_evidence([subject]) {
    fail("packet canonical evidence is not derived from its exact subject")
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
    result_contract,
    canonical_evidence_refs,
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
    learning_key,
    canonical_evidence_refs,
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
fn result_gap_class(value : String) -> @bookkeeper.ThreeGapClass raise {
  match value {
    "information_gap" => @bookkeeper.InformationGap
    "recognition_gap" => @bookkeeper.RecognitionGap
    "decisiveness_gap" => @bookkeeper.DecisivenessGap
    _ => fail("unsupported Three-Gap class in durable source finding")
  }
}

///|
fn result_exact_human_accept(
  snapshot : @bookkeeper_store.BookkeeperStoreSnapshot,
  record : @bookkeeper_store.DurableBookkeeperRecord,
) -> @bookkeeper_store.GovernedReviewReceipt raise {
  let mut accepted : @bookkeeper_store.GovernedReviewReceipt? = None
  for review in snapshot.reviews {
    if review.stage == @bookkeeper_store.ThreeGapFinding &&
      review.subject == record.record &&
      review.review_complete &&
      review.disposition == @bookkeeper.Accept &&
      review.reviewer_kind == @bookkeeper.Human {
      match accepted {
        None => accepted = Some(review)
        Some(_) => fail("source finding has ambiguous human Accept receipts")
      }
    }
  }
  match accepted {
    Some(review) => review
    None => fail("source finding lacks an exact named-human Accept receipt")
  }
}

///|
/// Rebuild the canonical reviewed value from the exact durable finding and its
/// named-human store receipt. This makes the core aggregation policy—not model
/// prose—the authority for every promotion threshold.
fn result_reviewed_finding(
  snapshot : @bookkeeper_store.BookkeeperStoreSnapshot,
  record : @bookkeeper_store.DurableBookkeeperRecord,
) -> @bookkeeper.ReviewedGapFinding raise {
  if record.stage != @bookkeeper_store.ThreeGapFinding {
    fail("capability source is not a Three-Gap finding")
  }
  guard record.payload is Object(fields) else {
    fail("durable Three-Gap finding payload must be an object")
  }
  if result_required_string(fields, "contract_version", "source finding") !=
    @bookkeeper.three_gap_contract_version() ||
    result_required_string(fields, "candidate_schema", "source finding") !=
    "three_gap_finding.v1" {
    fail("durable Three-Gap source uses an unsupported contract")
  }
  let subject = result_record_reference(
    result_required_json(fields, "subject", "source finding"),
    "source finding subject",
  )
  let learning_key = result_record_reference(
    result_required_json(fields, "learning_key", "source finding"),
    "source finding learning_key",
  )
  let gap_class_text = result_required_string(
    fields, "gap_class", "source finding",
  )
  let gap_class = result_gap_class(gap_class_text)
  let expected_transition = match gap_class {
    @bookkeeper.InformationGap => "unknown_to_known"
    @bookkeeper.RecognitionGap => "known_to_matters"
    @bookkeeper.DecisivenessGap => "matters_to_act"
  }
  if result_required_string(fields, "transition", "source finding") !=
    expected_transition {
    fail("durable Three-Gap transition does not match its gap class")
  }
  let severity = result_required_int(fields, "severity", "source finding")
  let owner_route = result_required_string(
    fields, "owner_route", "source finding",
  )
  let summary = result_required_string(fields, "summary", "source finding")
  let evidence_refs = result_evidence_references(
    result_required_json(fields, "evidence_refs", "source finding"),
    "source finding evidence_refs",
  )
  if owner_route != record.owner_route ||
    summary != record.summary ||
    evidence_refs != record.evidence_refs {
    fail("durable Three-Gap payload differs from its record envelope")
  }
  let finding = @bookkeeper.CanonicalGapFinding::new(
    finding=record.record,
    learning_key~,
    subject~,
    gap_class~,
    severity~,
    owner_route~,
    summary~,
    evidence_refs~,
  )
  let review = result_exact_human_accept(snapshot, record)
  let reviewer : @bookkeeper.ReviewerAuthority = {
    reviewer_id: review.reviewer.reviewer_id,
    authority_ref: review.reviewer.authority_ref,
    authorized: review.reviewer.authorized,
    evidence_refs: ReadOnlyArray::from_array(review.reviewer.evidence_refs),
  }
  let attestation = @bookkeeper.FindingReviewAuthorityAttestation::new(
    attestation=review.mutation,
    finding,
    receipt=review.receipt,
    reviewer_kind=@bookkeeper.Human,
    reviewer~,
    evidence_refs=review.evidence_refs,
    requested=@bookkeeper.Accept,
  )
  let decision = @bookkeeper.review_three_gap_finding(
    finding,
    receipt=review.receipt,
    reviewer~,
    requested=@bookkeeper.Accept,
    Some(attestation),
  )
  match decision.reviewed_finding {
    Some(reviewed) if decision.is_reviewed() => reviewed
    _ => fail("durable Three-Gap review cannot be reconstructed canonically")
  }
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
  let learning_key = result_record_reference(
    result_required_json(fields, "learning_key", label),
    "payload learning_key",
  )
  if learning_key != verified.learning_key {
    fail("Three-Gap payload learning_key must exactly copy the MoonBook packet")
  }
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
  snapshot : @bookkeeper_store.BookkeeperStoreSnapshot,
  source_records : ArrayView[@bookkeeper_store.DurableBookkeeperRecord],
) -> @bookkeeper.CapabilityProposal raise {
  let label = "capability proposal candidate payload"
  result_require_exact_keys(
    result.candidate.payload,
    [
      "contract_version", "candidate_schema", "proposal_id", "proposal_version",
      "subject", "capability_id", "capability_version", "change_digest", "summary",
      "owner_route", "evidence_refs", "source_finding_refs", "promotion_policy_ref",
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
  let capability_id = result_required_string(fields, "capability_id", label)
  let capability_version = result_required_string(
    fields, "capability_version", label,
  )
  let change_digest = result_required_string(fields, "change_digest", label)
  let promotion_policy_ref = result_record_reference(
    result_required_json(fields, "promotion_policy_ref", label),
    "payload promotion_policy_ref",
  )
  let policy = bookkeeper_capability_promotion_policy()
  if promotion_policy_ref != policy.policy {
    fail("capability proposal did not copy MoonBook's exact promotion policy")
  }
  let source_refs = result_record_references(
    result_required_json(fields, "source_finding_refs", label),
    "payload source_finding_refs",
  )
  if source_refs != result.candidate.links {
    fail("capability proposal source findings differ from candidate links")
  }
  result_validate_common_payload(fields, result, verified, label)
  let reviewed : Array[@bookkeeper.ReviewedGapFinding] = []
  for record in source_records {
    reviewed.push(result_reviewed_finding(snapshot, record))
  }
  let decision = @bookkeeper.aggregate_capability_proposal(
    policy,
    reviewed,
    proposal_id=result.candidate.record_id,
    proposal_version=result.candidate.record_version,
    capability_id~,
    capability_version~,
    owner_route=result.candidate.owner_route,
    proposal_digest=change_digest,
    summary=result.candidate.summary,
  )
  guard decision.proposal is Some(proposal) else {
    fail(
      "capability proposal does not satisfy MoonBook promotion policy: " +
      decision.non_promotion_reasons.to_json().stringify(),
    )
  }
  if !proposal.is_policy_promoted() ||
    proposal.source_finding_refs.to_json() != source_refs.to_json() {
    fail("capability proposal sources are not the canonical policy aggregation")
  }
  proposal
}

///|
fn result_canonical_capability_payload(
  result : BookkeeperMoonClawResult,
  verified : VerifiedBookkeeperMoonClawPacket,
  proposal : @bookkeeper.CapabilityProposal,
  evidence_refs : ArrayView[@bookkeeper.VersionedEvidenceReference],
) -> Json {
  {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "candidate_schema": "capability_proposal.v1",
    "proposal_id": proposal.proposal_id,
    "proposal_version": proposal.proposal_version,
    "subject": result.subject.to_json(),
    "capability_id": proposal.capability_id,
    "capability_version": proposal.capability_version,
    "change_digest": proposal.change_digest,
    "summary": proposal.summary,
    "owner_route": proposal.owner_route,
    "evidence_refs": evidence_refs.to_json(),
    "source_finding_refs": proposal.source_finding_refs.to_json(),
    "promotion_policy_ref": proposal.promotion_policy_ref.unwrap().to_json(),
    "aggregation_digest": proposal.aggregation_digest.unwrap(),
    "policy_promoted": true,
    "review_required": true,
    "self_application_allowed": false,
    "source_snapshot_digest": verified.source_snapshot_digest,
    "source_packet_digest": verified.source_packet_digest,
  }
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
  let mut canonical_capability : @bookkeeper.CapabilityProposal? = None
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
      canonical_capability = Some(
        result_validate_capability_payload(result, verified, current, records),
      )
      (@bookkeeper_store.CapabilityProposal, records)
    }
    _ => fail("unsupported Bookkeeper MoonClaw candidate stage")
  }
  let expected_evidence = match canonical_capability {
    Some(_) => bookkeeper_moonclaw_capability_evidence(source_records)
    None => bookkeeper_moonclaw_canonical_evidence(source_records)
  }
  if verified.subject.stage == OutcomeBinding &&
    expected_evidence != verified.canonical_evidence_refs {
    fail("MoonClaw source evidence differs from the packet canonical evidence")
  }
  if result.evidence_refs != expected_evidence {
    fail("MoonClaw result evidence is not the exact canonical source evidence")
  }
  let canonical_payload = match canonical_capability {
    Some(proposal) =>
      result_canonical_capability_payload(
        result, verified, proposal, expected_evidence,
      )
    None => result.candidate.payload
  }
  let payload_digest = @bookkeeper_store.bookkeeper_payload_digest(
    canonical_payload,
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
    payload: canonical_payload,
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
