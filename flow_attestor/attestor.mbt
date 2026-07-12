///|
fn object(value : Json, label : String) -> Map[String, Json] raise {
  match value {
    Object(fields) => fields
    _ => fail("MoonBook Flow attestor requires \{label} to be an object")
  }
}

///|
fn string_field(fields : Map[String, Json], name : String) -> String raise {
  match fields.get(name) {
    Some(String(value)) if !value.trim().is_empty() => value
    _ => fail("MoonBook Flow attestor requires \{name}")
  }
}

///|
fn strings_field(
  fields : Map[String, Json],
  name : String,
) -> Array[String] raise {
  match fields.get(name) {
    Some(Array(values)) =>
      values.map(value => {
        match value {
          String(text) if !text.trim().is_empty() => text
          _ => fail("MoonBook Flow attestor requires string values in \{name}")
        }
      })
    _ => fail("MoonBook Flow attestor requires \{name}")
  }
}

///|
fn array_field(fields : Map[String, Json], name : String) -> Array[Json] raise {
  match fields.get(name) {
    Some(Array(values)) if !values.is_empty() => values
    _ => fail("MoonBook Flow attestor requires non-empty \{name}")
  }
}

///|
fn safe_ref(reference : String) -> Bool {
  let value = reference.trim().replace(old="\\", new="/")
  !value.is_empty() &&
  !value.has_prefix("/") &&
  !value.split("/").any(part => part.is_empty() || part == "..")
}

///|
fn scoped_path(workspace : String, reference : String) -> String raise {
  if !safe_ref(reference) {
    fail("MoonBook Flow artifact must be workspace-relative")
  }
  @pathx.join(@pathx.normalize(workspace), reference)
}

///|
async fn read_json(path : String) -> Json {
  @json.parse(@fsx.read_file(path))
}

///|
async fn write_json(path : String, value : Json) -> Unit {
  @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true)
  @fsx.write_to_file(path, value.stringify(indent=2) + "\n", create=0o644)
}

///|
fn attest_web_provenance(
  draft_fields : Map[String, Json],
) -> (Array[Json], Array[String]) raise {
  let events = array_field(draft_fields, "web_provenance")
  let fetched_urls : Array[String] = []
  let mut searched = false
  for value in events {
    let entry = object(value, "web provenance entry")
    guard entry.get("succeeded") == Some(Json::boolean(true)) else { continue }
    let tool = string_field(entry, "tool")
    let arguments = match entry.get("arguments") {
      Some(Object(fields)) => fields
      _ => fail("MoonWiki web provenance requires tool arguments")
    }
    if tool == "web_search" {
      ignore(string_field(arguments, "query"))
      searched = true
    } else if tool == "web_fetch" {
      let url = string_field(arguments, "url")
      if !fetched_urls.contains(url) {
        fetched_urls.push(url)
      }
    }
    ignore(string_field(entry, "event_digest"))
  }
  if !searched || fetched_urls.is_empty() {
    fail(
      "MoonWiki research requires successful governed search and fetch provenance",
    )
  }
  (events, fetched_urls)
}

///|
fn attest_research(draft_fields : Map[String, Json]) -> Json raise {
  if string_field(draft_fields, "contract_id") != "moonwiki.evidence-bundle.v1" ||
    string_field(draft_fields, "product_id") != "moonwiki" {
    fail("MoonWiki evidence draft has the wrong identity")
  }
  let (web_provenance, fetched_urls) = attest_web_provenance(draft_fields)
  let sources = array_field(draft_fields, "sources")
  let source_ids : Array[String] = []
  for value in sources {
    let source = object(value, "source")
    let source_id = string_field(source, "source_id")
    if source_ids.contains(source_id) {
      fail("MoonWiki source identities must be unique")
    }
    source_ids.push(source_id)
    ignore(string_field(source, "title"))
    let locator = string_field(source, "locator")
    if !fetched_urls.contains(locator) {
      fail(
        "MoonWiki source locator lacks successful governed web_fetch provenance",
      )
    }
    ignore(string_field(source, "authority"))
    ignore(string_field(source, "accessed_at"))
  }
  let claims = array_field(draft_fields, "claims")
  for value in claims {
    let claim = object(value, "claim")
    ignore(string_field(claim, "statement"))
    let references = strings_field(claim, "source_refs")
    if references.is_empty() || references.any(id => !source_ids.contains(id)) {
      fail("MoonWiki claims require known source references")
    }
    let confidence = match claim.get("confidence") {
      Some(Number(value, ..)) => value
      _ => fail("MoonWiki claims require numeric confidence")
    }
    if confidence < 0.0 || confidence > 1.0 {
      fail("MoonWiki claim confidence must be between zero and one")
    }
  }
  let contradictions = array_field(draft_fields, "contradictions")
  let limitations = array_field(draft_fields, "limitations")
  let gaps = array_field(draft_fields, "remaining_information_gaps")
  let lineage = array_field(draft_fields, "query_lineage")
  ignore(string_field(draft_fields, "stopping_rationale"))
  (
    {
      "contract_id": "moonwiki.evidence-bundle.v1",
      "product_id": "moonwiki",
      "operation": "research-goal",
      "sources": sources.to_json(),
      "claims": claims.to_json(),
      "contradictions": contradictions.to_json(),
      "limitations": limitations.to_json(),
      "remaining_information_gaps": gaps.to_json(),
      "query_lineage": lineage.to_json(),
      "stopping_rationale": string_field(draft_fields, "stopping_rationale"),
      "web_provenance": web_provenance.to_json(),
      "research_quality": {
        "provenance_complete": true,
        "tool_provenance_verified": true,
        "claims_traceable": true,
        "contradictions_preserved": true,
        "information_gaps_preserved": true,
      },
      "claim_ceiling": "research-evidence",
      "physical_readiness": false,
    } : Json)
}

///|
fn audit_reflection(
  book_id : String,
  index : Int,
  criterion : String,
  decision : String,
  evidence_refs : Array[String],
  rationale : String,
  recorded_at : String,
) -> Json {
  let observation : @wiki.BookkeeperObservation = {
    observation_id: "audit-criterion-\{index}",
    book_id,
    subject: "unattended outcome",
    requirement_id: "criterion-\{index}",
    constraint_name: criterion,
    statement: rationale,
    evidence_refs,
    comparison: "none",
    measured_value: 0.0,
    limit_value: 0.0,
    unit: "",
    outcome: decision,
    next_action_present: decision == "accepted",
    validator_product: "moonbook",
    applicability: ["the goal and immutable criterion are unchanged"],
    procedure_steps: ["replay the accepted product evidence chain"],
    verification_criteria: [criterion],
    failure_modes: ["the evidence digest or criterion changes"],
    recorded_at,
  }
  @wiki.reflect_on_observation(observation).to_json()
}

///|
fn attest_audit(
  request_fields : Map[String, Json],
  draft_fields : Map[String, Json],
) -> Json raise {
  if string_field(draft_fields, "contract_id") != "moonbook.outcome-audit.v1" ||
    string_field(draft_fields, "product_id") != "moonbook" {
    fail("MoonBook outcome audit draft has the wrong identity")
  }
  let criteria = strings_field(request_fields, "acceptance_criteria")
  let decisions = array_field(draft_fields, "criterion_decisions")
  if decisions.length() != criteria.length() {
    fail("MoonBook audit must decide every criterion exactly once")
  }
  let reflections : Array[Json] = []
  let recorded_at = string_field(draft_fields, "recorded_at")
  let book_id = string_field(request_fields, "book_id")
  for index, value in decisions {
    let decision = object(value, "criterion decision")
    if string_field(decision, "criterion") != criteria[index] {
      fail("MoonBook audit criteria must preserve immutable order")
    }
    let outcome = string_field(decision, "decision")
    if !["accepted", "blocked", "rejected"].contains(outcome) {
      fail("MoonBook audit decision must be accepted, blocked, or rejected")
    }
    let evidence_refs = strings_field(decision, "evidence_refs")
    let blocker = match decision.get("blocker") {
      Some(String(value)) => value
      _ => ""
    }
    if evidence_refs.is_empty() && blocker.trim().is_empty() {
      fail("MoonBook audit decisions require evidence or an explicit blocker")
    }
    reflections.push(
      audit_reflection(
        book_id,
        index,
        criteria[index],
        outcome,
        evidence_refs,
        string_field(decision, "rationale"),
        recorded_at,
      ),
    )
  }
  let open_gaps = array_field(draft_fields, "open_gaps")
  for value in open_gaps {
    let gap = object(value, "open gap")
    if !["information-gap", "cognition-gap", "execution-gap"].contains(
        string_field(gap, "kind"),
      ) {
      fail("MoonBook open gaps must use a metacognitive gap class")
    }
    ignore(string_field(gap, "question"))
    ignore(string_field(gap, "resolution_criteria"))
  }
  let residual_risks = array_field(draft_fields, "residual_risks")
  let final_claim = string_field(draft_fields, "final_claim")
  let claim_ceiling = string_field(draft_fields, "claim_ceiling")
  if ![
      "observation", "research-evidence", "accepted-knowledge", "digital-artifact",
      "simulation-evidence", "scenario-qualified",
    ].contains(claim_ceiling) {
    fail("MoonBook final claim ceiling is not constitutionally bounded")
  }
  (
    {
      "contract_id": "moonbook.outcome-audit.v1",
      "product_id": "moonbook",
      "operation": "audit-outcome",
      "criterion_decisions": decisions.to_json(),
      "open_gaps": open_gaps.to_json(),
      "residual_risks": residual_risks.to_json(),
      "metacognitive_reflections": reflections.to_json(),
      "final_claim": final_claim,
      "claim_ceiling": claim_ceiling,
      "physical_readiness": false,
      "recorded_at": recorded_at,
    } : Json)
}

///|
pub async fn attest(
  workspace : String,
  request_ref : String,
  result_ref : String,
  attestation_ref : String,
  attestor_id : String,
  draft_ref : String,
  final_ref : String,
) -> Unit {
  let request = read_json(scoped_path(workspace, request_ref))
  let request_fields = object(request, "request")
  let result = read_json(scoped_path(workspace, result_ref))
  let result_fields = object(result, "draft result")
  let draft = read_json(scoped_path(workspace, draft_ref))
  let draft_fields = object(draft, "product draft")
  let product_id = string_field(request_fields, "product_id")
  let operation = string_field(request_fields, "operation")
  let final_artifact = match (product_id, operation) {
    ("moonwiki", "research-goal") => attest_research(draft_fields)
    ("moonbook", "audit-outcome") => attest_audit(request_fields, draft_fields)
    _ => fail("MoonBook attestor does not own this product operation")
  }
  write_json(scoped_path(workspace, final_ref), final_artifact)
  write_json(scoped_path(workspace, attestation_ref), {
    "contract_id": "moonflow.product-attestation.v1",
    "attestor_id": attestor_id,
    "product_id": product_id,
    "request_id": string_field(request_fields, "request_id"),
    "result_id": string_field(result_fields, "result_id"),
    "output_digest": string_field(result_fields, "output_digest"),
    "accepted": true,
    "native_final_artifact": final_ref,
    "operation": operation,
  })
}
