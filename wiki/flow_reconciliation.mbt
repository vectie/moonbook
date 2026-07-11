///|
pub(all) struct FlowOutcomeObservation {
  observation_id : String
  run_id : String
  book_id : String
  declaration_revision : String
  source_digest : String
  source_projection_digest : String
  work_item_id : String
  declaration_id : String
  product_id : String
  requested_authority : String
  acceptance_criteria : Array[String]
  status : String
  attempt_id : String
  request_id : String
  result_id : String
  input_digest : String
  output_digest : String
  artifact_refs : Array[String]
  blocker : String
  error_kind : String
  recorded_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
fn flow_int(fields : Map[String, Json], key : String) -> Int raise {
  match fields.get(key) {
    Some(Number(value, ..)) => value.to_int()
    _ => fail("MoonFlow projection requires integer field: \{key}")
  }
}

///|
fn flow_projection_item(
  fields : Map[String, Json],
  work_item_id : String,
) -> Map[String, Json] raise {
  guard fields.get("items") is Some(Array(items)) else {
    fail("MoonFlow projection requires items array")
  }
  for item_value in items {
    let item = bk_object(item_value)
    if bk_string(item, "work_item_id") == work_item_id {
      return item
    }
  }
  fail("MoonFlow projection does not contain work item: \{work_item_id}")
}

///|
pub fn decode_flow_outcome_observation(
  projection : Json,
  work_item_id : String,
  recorded_at : String,
) -> FlowOutcomeObservation raise {
  let fields = bk_object(projection)
  let protocol = bk_string(fields, "protocol")
  if protocol != "moonflow.run-projection.v2" {
    fail("unsupported MoonFlow projection: \{protocol}")
  }
  let safe_work_item_id = safe_observation_id(work_item_id)
  let item = flow_projection_item(fields, safe_work_item_id)
  let run_id = safe_observation_id(bk_string(fields, "run_id"))
  let result_id = bk_optional_string(item, "result_id", "")
  let attempt_id = bk_optional_string(item, "active_attempt_id", "")
  let sequence = flow_int(fields, "last_sequence")
  {
    observation_id: safe_observation_id(
      "flow-\{run_id}-\{safe_work_item_id}-\{sequence}",
    ),
    run_id,
    book_id: bk_string(fields, "book_id"),
    declaration_revision: safe_observation_id(
      bk_string(fields, "declaration_revision"),
    ),
    source_digest: bk_string(fields, "source_digest"),
    source_projection_digest: executable_sha256(projection.stringify(indent=2)),
    work_item_id: safe_work_item_id,
    declaration_id: safe_observation_id(bk_string(item, "declaration_id")),
    product_id: bk_string(item, "product_id"),
    requested_authority: bk_string(item, "requested_authority"),
    acceptance_criteria: bk_strings(item, "acceptance_criteria"),
    status: bk_string(item, "status"),
    attempt_id,
    request_id: bk_optional_string(item, "request_id", ""),
    result_id,
    input_digest: bk_optional_string(item, "input_digest", ""),
    output_digest: bk_optional_string(item, "output_digest", ""),
    artifact_refs: bk_strings(item, "artifacts"),
    blocker: bk_optional_string(item, "blocker", ""),
    error_kind: bk_optional_string(item, "error_kind", ""),
    recorded_at,
  }
}

///|
pub fn FlowOutcomeObservation::quality_issues(
  self : FlowOutcomeObservation,
) -> Array[String] {
  let issues : Array[String] = []
  if !executable_source_digest_is_valid(self.source_digest) {
    issues.push("flow source_digest is invalid")
  }
  if !executable_source_digest_is_valid(self.source_projection_digest) {
    issues.push("source projection digest is invalid")
  }
  if !executable_authority_is_canonical(self.requested_authority) {
    issues.push("flow requested_authority is not canonical")
  }
  if self.acceptance_criteria.is_empty() {
    issues.push("flow acceptance criteria are required")
  }
  if !["review", "accepted", "blocked", "failed", "cancelled", "superseded"].contains(
      self.status,
    ) {
    issues.push("flow outcome is not ready for reconciliation: \{self.status}")
  }
  if (self.status == "review" || self.status == "accepted") &&
    self.output_digest.trim().is_empty() {
    issues.push("reviewed or accepted flow outcome requires output_digest")
  }
  if self.status == "failed" &&
    self.error_kind.trim().is_empty() &&
    self.blocker.trim().is_empty() {
    issues.push("failed flow outcome requires an error or blocker")
  }
  issues
}

///|
fn flow_recovery_action(
  observation : FlowOutcomeObservation,
) -> BookkeeperAction {
  {
    declaration_id: "recover-\{observation.declaration_id}-\{observation.attempt_id}",
    kind: "validation",
    title: "Diagnose and recover \{observation.declaration_id}",
    statement: "Diagnose the recorded \{observation.status} outcome, preserve its negative evidence, and propose a bounded retry only after the blocker is resolved.",
    executor_product: observation.product_id,
    requires: [],
    acceptance_criteria: [
      "the original failed or blocked outcome remains recorded", "the diagnosed cause is linked to evidence",
      "the original acceptance criteria remain unchanged",
    ] +
    observation.acceptance_criteria,
    requested_authority: observation.requested_authority,
  }
}

///|
pub fn reflect_on_flow_outcome(
  observation : FlowOutcomeObservation,
) -> BookkeeperReflection raise {
  let issues = observation.quality_issues()
  if !issues.is_empty() {
    fail("unqualified MoonFlow observation: \{issues.join("; ")}")
  }
  let gaps : Array[BookkeeperGap] = []
  let actions : Array[BookkeeperAction] = []
  let uncertainty : Array[String] = []
  match observation.status {
    "review" => {
      gaps.push({
        gap_id: "cognition-\{observation.observation_id}",
        kind: "cognition-gap",
        question: "Do the returned artifacts satisfy the declared acceptance criteria?",
        required_by: [observation.declaration_id],
        current_evidence: observation.artifact_refs.copy(),
        missing: "An explicit acceptance review linked to every declared criterion.",
        significance: "Adapter success proves execution completed, not that the MoonBook declaration is acceptable.",
        resolution_criteria: observation.acceptance_criteria.copy(),
        status: "open",
      })
      uncertainty.push("acceptance remains pending explicit review")
    }
    "failed" | "blocked" => {
      gaps.push({
        gap_id: "execution-\{observation.observation_id}",
        kind: "execution-gap",
        question: "What bounded recovery should follow this \{observation.status} outcome?",
        required_by: [observation.declaration_id],
        current_evidence: observation.artifact_refs.copy(),
        missing: "A diagnosed cause and governed recovery path.",
        significance: "The declared work remains incomplete and its blocker must not be optimized away.",
        resolution_criteria: [
          "the blocker or error is diagnosed", "negative evidence remains linked",
          "any retry preserves the original acceptance criteria",
        ],
        status: "open",
      })
      actions.push(flow_recovery_action(observation))
    }
    "cancelled" | "superseded" =>
      uncertainty.push(
        "the work ended without acceptance and requires no automatic retry",
      )
    _ => ()
  }
  {
    contract_id: "moonbook.bookkeeper-reflection.v1",
    reflection_id: "reflection-\{observation.observation_id}",
    book_id: observation.book_id,
    trigger: "moonflow-outcome",
    observations: [
      "MoonFlow \{observation.work_item_id} reached \{observation.status} with result \{observation.result_id}.",
    ],
    gaps,
    belief_updates: [],
    proposed_actions: actions,
    learned_procedures: [],
    confidence: if observation.status == "accepted" {
      0.98
    } else {
      0.9
    },
    uncertainty,
    requested_authority: "cognitive-maintenance",
    recorded_at: observation.recorded_at,
  }
}

///|
pub async fn reconcile_flow_projection_file(
  root : String,
  projection_path : String,
  work_item_id : String,
  recorded_at : String,
) -> BookkeeperReflectionRecord {
  let normalized_root = @pathx.normalize(root)
  ensure_bookkeeper_learning_dirs(normalized_root)
  let projection = @json.parse(@fsx.read_file(projection_path))
  let observation = decode_flow_outcome_observation(
    projection, work_item_id, recorded_at,
  )
  let reflection = reflect_on_flow_outcome(observation)
  let reflection_issues = reflection.quality_issues()
  if !reflection_issues.is_empty() {
    fail("unqualified MoonFlow reflection: \{reflection_issues.join("; ")}")
  }
  let episode_path = moonbook_wiki_path(normalized_root)
    .join(
      moonbook_wiki_path("memory/episodes/\{observation.observation_id}.json"),
    )
    .to_string()
  let reflection_path = moonbook_wiki_path(normalized_root)
    .join(
      moonbook_wiki_path("memory/reflections/\{reflection.reflection_id}.json"),
    )
    .to_string()
  @fsx.write_to_file(
    episode_path,
    observation.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    reflection_path,
    reflection.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  let mut proposals_path = ""
  if !reflection.proposed_actions.is_empty() {
    proposals_path = moonbook_wiki_path(normalized_root)
      .join(
        moonbook_wiki_path("flow/proposals/\{reflection.reflection_id}.json"),
      )
      .to_string()
    let proposal : Json = {
      "contract_id": "moonsuite.executable-document.v1",
      "book_id": reflection.book_id,
      "revision": reflection.reflection_id,
      "declarations": reflection.proposed_actions.to_json(),
      "source_digest": executable_sha256(
        reflection.to_json().stringify(indent=2),
      ),
      "source_reflection": reflection.reflection_id,
      "recorded_at": reflection.recorded_at,
    }
    @fsx.write_to_file(
      proposals_path,
      proposal.stringify(indent=2) + "\n",
      create=0o644,
    )
  }
  { reflection_path, episode_path, proposals_path, reflection }
}
