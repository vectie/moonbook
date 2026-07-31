///|
/// Exact wire contract accepted by MoonBook's deterministic requirements
/// preparation capability.
pub fn requirements_prepare_contract_version() -> String {
  "moonbook.wiki.requirements_prepare.v1"
}

///|
/// Exact wire contract emitted as a review-pending MoonBook artifact.
pub fn requirements_packet_contract_version() -> String {
  "moonbook.wiki.requirements_packet.v1"
}

///|
/// One evidence-bound input statement. `kind` must be exactly `fact`,
/// `calculation`, `inference`, or `unresolved_question`.
pub(all) struct RequirementSourceStatement {
  statement_id : String
  kind : String
  text : String
  evidence_refs : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Product-owned request for deterministic MoonWiki requirements preparation.
/// This is data preparation only: it does not invoke an agent or accept truth.
pub(all) struct RequirementsPrepareRequest {
  contract_version : String
  request : @bookkeeper.VersionedRecordReference
  book_id : String
  goal : String
  owner_route : String
  recorded_at : Int
  evidence_refs : Array[@bookkeeper.VersionedEvidenceReference]
  statements : Array[RequirementSourceStatement]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A statement in one explicit epistemic section of the output packet.
pub(all) struct RequirementPacketStatement {
  statement_id : String
  text : String
  evidence_refs : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A deterministic requirements artifact awaiting named-human review.
///
/// `functionality` names MoonWiki as functionality inside MoonBook.
/// `agent_runtime` records the only permitted suite agent runtime if a later
/// reviewed workflow requests cognition. This operation does not invoke it.
pub(all) struct RequirementsPacket {
  contract_version : String
  packet : @bookkeeper.VersionedRecordReference
  request : @bookkeeper.VersionedRecordReference
  product_id : String
  functionality : String
  capability : String
  agent_runtime : String
  agent_execution_requested : Bool
  book_id : String
  goal : String
  owner_route : String
  recorded_at : Int
  review_status : String
  accepted_truth : Bool
  accepted_into_book : Bool
  requires_human_review : Bool
  facts : Array[RequirementPacketStatement]
  calculations : Array[RequirementPacketStatement]
  inferences : Array[RequirementPacketStatement]
  unresolved_questions : Array[RequirementPacketStatement]
  evidence_refs : Array[@bookkeeper.VersionedEvidenceReference]
  external_side_effects_applied : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Reconciliation result for an already persisted packet. Reconciliation never
/// upgrades the packet's pending review state or accepts it as book truth.
pub(all) struct RequirementsPacketReconciliation {
  contract_version : String
  request : @bookkeeper.VersionedRecordReference
  packet : @bookkeeper.VersionedRecordReference
  status : String
  exact_match : Bool
  review_status : String
  accepted_truth : Bool
  issues : Array[String]
} derive(Debug, Eq, ToJson)

///|
struct CanonicalRequirementStatement {
  statement_id : String
  kind : String
  text : String
  evidence_refs : Array[String]
} derive(Debug, Eq)

///|
fn requirements_record_complete(
  reference : @bookkeeper.VersionedRecordReference,
) -> Bool {
  !reference.record_id.is_blank() &&
  !reference.record_version.is_blank() &&
  !reference.record_digest.is_blank()
}

///|
fn requirements_evidence_compare(
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
fn canonical_requirements_evidence(
  evidence : ArrayView[@bookkeeper.VersionedEvidenceReference],
) -> Array[@bookkeeper.VersionedEvidenceReference] raise {
  let sorted : Array[@bookkeeper.VersionedEvidenceReference] = []
  for reference in evidence {
    if reference.reference_id.is_blank() ||
      reference.reference_version.is_blank() ||
      reference.digest.is_blank() ||
      reference.provenance_ref.is_blank() {
      fail("requirements preparation evidence references must be complete")
    }
    sorted.push(reference)
  }
  sorted.sort_by(requirements_evidence_compare)
  let unique : Array[@bookkeeper.VersionedEvidenceReference] = []
  for reference in sorted {
    match unique.last() {
      Some(previous) if previous.reference_id == reference.reference_id =>
        if previous != reference {
          fail(
            "requirements preparation has conflicting evidence identity " +
            reference.reference_id,
          )
        }
      _ => unique.push(reference)
    }
  }
  if unique.is_empty() {
    fail("requirements preparation requires evidence")
  }
  unique
}

///|
fn canonical_statement_evidence(
  references : ArrayView[String],
  evidence : Array[@bookkeeper.VersionedEvidenceReference],
  statement_id : String,
) -> Array[String] raise {
  let sorted : Array[String] = []
  for reference_id in references {
    if reference_id.is_blank() {
      fail(
        "requirements statement " +
        statement_id +
        " has a blank evidence reference",
      )
    }
    if !evidence.any(reference => reference.reference_id == reference_id) {
      fail(
        "requirements statement " +
        statement_id +
        " cites unknown evidence " +
        reference_id,
      )
    }
    sorted.push(reference_id)
  }
  sorted.sort()
  let unique : Array[String] = []
  for reference_id in sorted {
    if !unique.contains(reference_id) {
      unique.push(reference_id)
    }
  }
  if unique.is_empty() {
    fail(
      "requirements statement " + statement_id + " requires evidence references",
    )
  }
  unique
}

///|
fn canonical_requirements_statements(
  statements : ArrayView[RequirementSourceStatement],
  evidence : Array[@bookkeeper.VersionedEvidenceReference],
) -> Array[CanonicalRequirementStatement] raise {
  let normalized : Array[CanonicalRequirementStatement] = []
  for statement in statements {
    if statement.statement_id.is_blank() || statement.text.is_blank() {
      fail("requirements statements require an id and text")
    }
    if !["fact", "calculation", "inference", "unresolved_question"].contains(
        statement.kind,
      ) {
      fail(
        "requirements statement " +
        statement.statement_id +
        " has unsupported kind " +
        statement.kind,
      )
    }
    normalized.push({
      statement_id: statement.statement_id,
      kind: statement.kind,
      text: statement.text,
      evidence_refs: canonical_statement_evidence(
        statement.evidence_refs,
        evidence,
        statement.statement_id,
      ),
    })
  }
  normalized.sort_by(fn(left, right) {
    left.statement_id.compare(right.statement_id)
  })
  let unique : Array[CanonicalRequirementStatement] = []
  for statement in normalized {
    match unique.last() {
      Some(previous) if previous.statement_id == statement.statement_id =>
        if previous != statement {
          fail(
            "requirements preparation has conflicting statement identity " +
            statement.statement_id,
          )
        }
      _ => unique.push(statement)
    }
  }
  if unique.is_empty() {
    fail("requirements preparation requires at least one statement")
  }
  unique
}

///|
fn requirement_packet_statement(
  statement : CanonicalRequirementStatement,
) -> RequirementPacketStatement {
  {
    statement_id: statement.statement_id,
    text: statement.text,
    evidence_refs: statement.evidence_refs,
  }
}

///|
fn requirements_packet_digest_material(
  request : RequirementsPrepareRequest,
  facts : Array[RequirementPacketStatement],
  calculations : Array[RequirementPacketStatement],
  inferences : Array[RequirementPacketStatement],
  unresolved_questions : Array[RequirementPacketStatement],
  evidence_refs : Array[@bookkeeper.VersionedEvidenceReference],
) -> Json {
  {
    "contract_version": requirements_packet_contract_version(),
    "request": request.request.to_json(),
    "product_id": "moonbook",
    "functionality": "moonwiki",
    "capability": "moonbook/wiki.requirements.prepare@0.1.0",
    "agent_runtime": "moonclaw",
    "agent_execution_requested": false,
    "book_id": request.book_id,
    "goal": request.goal,
    "owner_route": request.owner_route,
    "recorded_at": request.recorded_at,
    "review_status": "pending",
    "accepted_truth": false,
    "accepted_into_book": false,
    "requires_human_review": true,
    "facts": facts.to_json(),
    "calculations": calculations.to_json(),
    "inferences": inferences.to_json(),
    "unresolved_questions": unresolved_questions.to_json(),
    "evidence_refs": evidence_refs.to_json(),
    "external_side_effects_applied": false,
  }
}

///|
/// Prepare a deterministic, epistemically separated requirements packet.
///
/// No language model participates in ranking or rewriting these statements.
/// The output is always pending review and cannot represent accepted book
/// truth.
pub fn prepare_requirements(
  request : RequirementsPrepareRequest,
) -> RequirementsPacket raise {
  if request.contract_version != requirements_prepare_contract_version() {
    fail("requirements preparation contract version is not canonical")
  }
  if !requirements_record_complete(request.request) {
    fail("requirements preparation request reference must be complete")
  }
  if request.book_id.is_blank() ||
    request.goal.is_blank() ||
    request.owner_route.is_blank() ||
    request.recorded_at < 0 {
    fail("requirements preparation requires book, goal, owner, and timestamp")
  }
  let evidence = canonical_requirements_evidence(request.evidence_refs)
  let statements = canonical_requirements_statements(
    request.statements,
    evidence,
  )
  let facts : Array[RequirementPacketStatement] = []
  let calculations : Array[RequirementPacketStatement] = []
  let inferences : Array[RequirementPacketStatement] = []
  let unresolved_questions : Array[RequirementPacketStatement] = []
  for statement in statements {
    let output = requirement_packet_statement(statement)
    match statement.kind {
      "fact" => facts.push(output)
      "calculation" => calculations.push(output)
      "inference" => inferences.push(output)
      "unresolved_question" => unresolved_questions.push(output)
      _ => fail("canonical requirements statement kind changed")
    }
  }
  let digest = executable_sha256(
    requirements_packet_digest_material(
      request, facts, calculations, inferences, unresolved_questions, evidence,
    ).stringify(),
  )
  {
    contract_version: requirements_packet_contract_version(),
    packet: {
      record_id: request.request.record_id + ".requirements-packet",
      record_version: request.request.record_version,
      record_digest: digest,
    },
    request: request.request,
    product_id: "moonbook",
    functionality: "moonwiki",
    capability: "moonbook/wiki.requirements.prepare@0.1.0",
    agent_runtime: "moonclaw",
    agent_execution_requested: false,
    book_id: request.book_id,
    goal: request.goal,
    owner_route: request.owner_route,
    recorded_at: request.recorded_at,
    review_status: "pending",
    accepted_truth: false,
    accepted_into_book: false,
    requires_human_review: true,
    facts,
    calculations,
    inferences,
    unresolved_questions,
    evidence_refs: evidence,
    external_side_effects_applied: false,
  }
}

///|
/// Recompute and compare an observed durable packet without mutating book truth.
pub fn reconcile_requirements_packet(
  request : RequirementsPrepareRequest,
  observed : RequirementsPacket,
) -> RequirementsPacketReconciliation raise {
  let expected = prepare_requirements(request)
  let issues : Array[String] = []
  if observed != expected {
    issues.push(
      "observed requirements packet differs from deterministic preparation",
    )
  }
  if observed.review_status != "pending" ||
    observed.accepted_truth ||
    observed.accepted_into_book {
    issues.push("requirements preparation cannot claim accepted book truth")
  }
  let exact_match = issues.is_empty()
  {
    contract_version: "moonbook.wiki.requirements_reconciliation.v1",
    request: expected.request,
    packet: observed.packet,
    status: if exact_match {
      "exact"
    } else {
      "mismatch"
    },
    exact_match,
    review_status: "pending",
    accepted_truth: false,
    issues,
  }
}
