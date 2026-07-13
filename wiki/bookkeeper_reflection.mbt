///|
pub(all) struct BookkeeperObservation {
  observation_id : String
  book_id : String
  subject : String
  requirement_id : String
  constraint_name : String
  statement : String
  evidence_refs : Array[String]
  comparison : String
  measured_value : Double
  limit_value : Double
  unit : String
  outcome : String
  next_action_present : Bool
  validator_product : String
  applicability : Array[String]
  procedure_steps : Array[String]
  verification_criteria : Array[String]
  failure_modes : Array[String]
  recorded_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperGap {
  gap_id : String
  kind : String
  question : String
  required_by : Array[String]
  current_evidence : Array[String]
  missing : String
  significance : String
  resolution_criteria : Array[String]
  status : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperBeliefUpdate {
  update_id : String
  belief_id : String
  statement : String
  change : String
  evidence_refs : Array[String]
  confidence : Double
  affected_refs : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperAction {
  declaration_id : String
  kind : String
  title : String
  statement : String
  executor_product : String
  requires : Array[String]
  acceptance_criteria : Array[String]
  requested_authority : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperProcedure {
  procedure_id : String
  title : String
  applicability : Array[String]
  steps : Array[String]
  verification_criteria : Array[String]
  failure_modes : Array[String]
  counterexamples : Array[String]
  invalidation_triggers : Array[String]
  evidence_refs : Array[String]
  status : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperReflection {
  contract_id : String
  reflection_id : String
  book_id : String
  trigger : String
  observations : Array[String]
  gaps : Array[BookkeeperGap]
  belief_updates : Array[BookkeeperBeliefUpdate]
  proposed_actions : Array[BookkeeperAction]
  learned_procedures : Array[BookkeeperProcedure]
  confidence : Double
  uncertainty : Array[String]
  requested_authority : String
  recorded_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BookkeeperReflectionRecord {
  reflection_path : String
  episode_path : String
  proposals_path : String
  reflection : BookkeeperReflection
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SpatialReferenceStudy {
  study_id : String
  book_id : String
  subject : String
  requirement_id : String
  reference_refs : Array[String]
  observed_facts : Array[String]
  inferred_hypotheses : Array[String]
  unknowns : Array[String]
  blocking_unknowns : Array[String]
  scale_basis : String
  artifact_refs : Array[String]
  transform_refs : Array[String]
  applicability : Array[String]
  procedure_steps : Array[String]
  verification_criteria : Array[String]
  failure_modes : Array[String]
  recorded_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct SpatialReferenceRecord {
  study_path : String
  reflection_record : BookkeeperReflectionRecord
} derive(Debug, Eq, ToJson)

///|
fn bk_object(value : Json) -> Map[String, Json] raise {
  match value {
    Object(fields) => fields
    _ => fail("Bookkeeper observation must be a JSON object")
  }
}

///|
fn bk_string(fields : Map[String, Json], key : String) -> String raise {
  match fields.get(key) {
    Some(String(value)) if !value.trim().is_empty() => value
    _ => fail("Bookkeeper observation requires non-empty string field: \{key}")
  }
}

///|
fn bk_optional_string(
  fields : Map[String, Json],
  key : String,
  default : String,
) -> String {
  match fields.get(key) {
    Some(String(value)) => value
    _ => default
  }
}

///|
fn bk_double(fields : Map[String, Json], key : String) -> Double raise {
  match fields.get(key) {
    Some(Number(value, ..)) => value
    _ => fail("Bookkeeper observation requires number field: \{key}")
  }
}

///|
fn bk_bool(fields : Map[String, Json], key : String) -> Bool raise {
  match fields.get(key) {
    Some(True) => true
    Some(False) => false
    _ => fail("Bookkeeper observation requires boolean field: \{key}")
  }
}

///|
fn bk_strings(fields : Map[String, Json], key : String) -> Array[String] raise {
  match fields.get(key) {
    Some(Array(values)) => {
      let strings : Array[String] = []
      for value in values {
        match value {
          String(text) if !text.trim().is_empty() => strings.push(text)
          _ => fail("Bookkeeper field \{key} must contain non-empty strings")
        }
      }
      strings
    }
    _ => fail("Bookkeeper observation requires array field: \{key}")
  }
}

///|
fn safe_observation_id(id : String) -> String raise {
  if id.trim().is_empty() ||
    id.contains("/") ||
    id.contains("\\") ||
    id.contains("..") {
    fail("observation_id must be a safe relative identifier")
  }
  id
}

///|
pub fn decode_bookkeeper_observation(
  value : Json,
) -> BookkeeperObservation raise {
  let fields = bk_object(value)
  let comparison = bk_string(fields, "comparison")
  if comparison != "maximum" && comparison != "minimum" && comparison != "none" {
    fail("comparison must be maximum, minimum, or none")
  }
  {
    observation_id: safe_observation_id(bk_string(fields, "observation_id")),
    book_id: bk_string(fields, "book_id"),
    subject: bk_string(fields, "subject"),
    requirement_id: bk_string(fields, "requirement_id"),
    constraint_name: bk_string(fields, "constraint_name"),
    statement: bk_string(fields, "statement"),
    evidence_refs: bk_strings(fields, "evidence_refs"),
    comparison,
    measured_value: bk_double(fields, "measured_value"),
    limit_value: bk_double(fields, "limit_value"),
    unit: bk_optional_string(fields, "unit", ""),
    outcome: bk_string(fields, "outcome"),
    next_action_present: bk_bool(fields, "next_action_present"),
    validator_product: bk_string(fields, "validator_product"),
    applicability: bk_strings(fields, "applicability"),
    procedure_steps: bk_strings(fields, "procedure_steps"),
    verification_criteria: bk_strings(fields, "verification_criteria"),
    failure_modes: bk_strings(fields, "failure_modes"),
    recorded_at: bk_string(fields, "recorded_at"),
  }
}

///|
fn BookkeeperObservation::violates_constraint(
  self : BookkeeperObservation,
) -> Bool {
  match self.comparison {
    "maximum" => self.measured_value > self.limit_value
    "minimum" => self.measured_value < self.limit_value
    _ => false
  }
}

///|
fn evidence_action(observation : BookkeeperObservation) -> BookkeeperAction {
  {
    declaration_id: "research-evidence-\{observation.observation_id}",
    kind: "research",
    title: "Resolve evidence for \{observation.constraint_name}",
    statement: "Find traceable evidence required to evaluate \{observation.subject} against \{observation.constraint_name}.",
    executor_product: "moonwiki",
    requires: [],
    acceptance_criteria: [
      "the source is durable and provenance is recorded", "the evidence directly supports or challenges the requirement",
    ],
    requested_authority: "observe",
  }
}

///|
fn alternative_action(observation : BookkeeperObservation) -> BookkeeperAction {
  {
    declaration_id: "investigate-alternative-\{observation.observation_id}",
    kind: "research",
    title: "Find an alternative satisfying \{observation.constraint_name}",
    statement: "Find a feasible alternative for \{observation.subject} that satisfies the existing \{observation.constraint_name} constraint without weakening its declared limit.",
    executor_product: "moonwiki",
    requires: [],
    acceptance_criteria: [
      "the original failed claim remains recorded", "the declared constraint and limit are unchanged",
      "the alternative is supported by traceable evidence",
    ],
    requested_authority: "observe",
  }
}

///|
fn revalidation_action(observation : BookkeeperObservation) -> BookkeeperAction {
  let dependency = "investigate-alternative-\{observation.observation_id}"
  {
    declaration_id: "revalidate-\{observation.observation_id}",
    kind: "validation",
    title: "Revalidate \{observation.subject}",
    statement: "Independently re-evaluate the proposed alternative against the unchanged \{observation.constraint_name} requirement and all affected acceptance criteria.",
    executor_product: observation.validator_product,
    requires: [dependency],
    acceptance_criteria: observation.verification_criteria.copy(),
    requested_authority: "sandbox-execution",
  }
}

///|
pub fn reflect_on_observation(
  observation : BookkeeperObservation,
) -> BookkeeperReflection {
  let gaps : Array[BookkeeperGap] = []
  let updates : Array[BookkeeperBeliefUpdate] = []
  let actions : Array[BookkeeperAction] = []
  let procedures : Array[BookkeeperProcedure] = []
  let uncertainty : Array[String] = []
  if observation.evidence_refs.is_empty() {
    gaps.push({
      gap_id: "information-\{observation.observation_id}",
      kind: "information-gap",
      question: "What evidence is required to evaluate \{observation.constraint_name}?",
      required_by: [observation.requirement_id],
      current_evidence: [],
      missing: "Traceable evidence directly connecting the observation to the requirement.",
      significance: "The requirement cannot be accepted or rejected without durable evidence.",
      resolution_criteria: [
        "at least one durable source or experiment receipt is linked", "evidence relevance and limitations are reviewed",
      ],
      status: "open",
    })
    actions.push(evidence_action(observation))
    uncertainty.push(
      "constraint interpretation is provisional until evidence is linked",
    )
  }
  let violation = observation.violates_constraint()
  if violation {
    gaps.push({
      gap_id: "cognition-\{observation.observation_id}",
      kind: "cognition-gap",
      question: "What does the observed constraint violation change?",
      required_by: [observation.requirement_id],
      current_evidence: observation.evidence_refs.copy(),
      missing: "A reviewed consequence map covering affected claims, decisions, and validations.",
      significance: "The current \{observation.subject} claim does not satisfy \{observation.constraint_name}; dependent acceptance claims must remain blocked.",
      resolution_criteria: [
        "the failed claim remains explicit", "affected decisions and validations are identified",
        "the original constraint is not weakened to force success",
      ],
      status: "open",
    })
    updates.push({
      update_id: "belief-\{observation.observation_id}",
      belief_id: observation.requirement_id,
      statement: observation.statement,
      change: "contradicted-by-observation",
      evidence_refs: observation.evidence_refs.copy(),
      confidence: if observation.evidence_refs.is_empty() {
        0.55
      } else {
        0.95
      },
      affected_refs: [observation.subject, observation.requirement_id],
    })
    if !observation.next_action_present {
      gaps.push({
        gap_id: "execution-\{observation.observation_id}",
        kind: "execution-gap",
        question: "What governed action should follow the constraint violation?",
        required_by: [observation.requirement_id],
        current_evidence: observation.evidence_refs.copy(),
        missing: "An alternative-search and independent-revalidation path.",
        significance: "Without an explicit next action, the blocker may be forgotten or bypassed.",
        resolution_criteria: [
          "a feasible alternative is investigated", "the alternative is independently revalidated",
          "the failed original claim remains visible",
        ],
        status: "open",
      })
      actions.push(alternative_action(observation))
      actions.push(revalidation_action(observation))
    }
  }
  if observation.outcome == "accepted" &&
    !observation.applicability.is_empty() &&
    !observation.procedure_steps.is_empty() &&
    !observation.verification_criteria.is_empty() &&
    !observation.failure_modes.is_empty() &&
    !observation.evidence_refs.is_empty() {
    procedures.push({
      procedure_id: "procedure-\{observation.observation_id}",
      title: "Reuse the verified method for \{observation.constraint_name}",
      applicability: observation.applicability.copy(),
      steps: observation.procedure_steps.copy(),
      verification_criteria: observation.verification_criteria.copy(),
      failure_modes: observation.failure_modes.copy(),
      counterexamples: observation.failure_modes.map(failure => {
        "Reject reuse when \{failure}"
      }),
      invalidation_triggers: [
        "the applicability conditions no longer match", "supporting evidence is superseded or invalidated",
      ] +
      observation.failure_modes,
      evidence_refs: observation.evidence_refs.copy(),
      status: "candidate",
    })
  }
  {
    contract_id: "moonbook.bookkeeper-reflection.v1",
    reflection_id: "reflection-\{observation.observation_id}",
    book_id: observation.book_id,
    trigger: "experiment-observation",
    observations: [observation.statement],
    gaps,
    belief_updates: updates,
    proposed_actions: actions,
    learned_procedures: procedures,
    confidence: if observation.evidence_refs.is_empty() {
      0.55
    } else {
      0.95
    },
    uncertainty,
    requested_authority: "cognitive-maintenance",
    recorded_at: observation.recorded_at,
  }
}

///|
pub fn BookkeeperReflection::quality_issues(
  self : BookkeeperReflection,
) -> Array[String] {
  let issues : Array[String] = []
  if self.reflection_id.trim().is_empty() {
    issues.push("reflection_id is required")
  }
  if self.observations.is_empty() {
    issues.push("at least one observation is required")
  }
  if self.confidence < 0.0 || self.confidence > 1.0 {
    issues.push("confidence must be between 0 and 1")
  }
  if !executable_authority_is_canonical(self.requested_authority) {
    issues.push("reflection requested_authority is not canonical")
  }
  for action in self.proposed_actions {
    if !executable_authority_is_canonical(action.requested_authority) {
      issues.push(
        "proposed action requested_authority is not canonical: \{action.declaration_id}",
      )
    }
  }
  if self.gaps.any(gap => gap.kind == "execution-gap") &&
    self.proposed_actions.is_empty() {
    issues.push("execution gaps require proposed actions")
  }
  for procedure in self.learned_procedures {
    if procedure.applicability.is_empty() {
      issues.push("learned procedures require applicability conditions")
    }
    if procedure.verification_criteria.is_empty() {
      issues.push("learned procedures require verification criteria")
    }
    if procedure.failure_modes.is_empty() {
      issues.push("learned procedures require failure modes")
    }
    if procedure.counterexamples.is_empty() {
      issues.push(
        "learned procedures require counterfactual rejection boundaries",
      )
    }
    if procedure.invalidation_triggers.is_empty() {
      issues.push("learned procedures require invalidation triggers")
    }
  }
  issues
}

///|
async fn ensure_bookkeeper_learning_dirs(root : String) -> Unit {
  for
    relative in [
      "memory/episodes", "memory/reflections", "memory/beliefs", "memory/procedures",
      "flow/declarations", "flow/proposals", "research/spatial",
    ] {
    @fsx.make_directory(
      moonbook_wiki_path(root).join(moonbook_wiki_path(relative)).to_string(),
      recursive=true,
      exists_ok=true,
    )
  }
}

///|
fn spatial_reference_is_safe(reference : String) -> Bool {
  revision_artifact_ref_is_safe(reference) && !reference.trim().is_empty()
}

///|
fn SpatialReferenceStudy::quality_issues(
  self : SpatialReferenceStudy,
) -> Array[String] {
  let issues : Array[String] = []
  if self.study_id.trim().is_empty() ||
    self.study_id.contains("/") ||
    self.study_id.contains("\\") ||
    self.study_id.contains("..") {
    issues.push("study_id must be a safe relative identifier")
  }
  if self.book_id.trim().is_empty() ||
    self.subject.trim().is_empty() ||
    self.requirement_id.trim().is_empty() {
    issues.push("book_id, subject, and requirement_id are required")
  }
  if self.reference_refs.is_empty() {
    issues.push("at least one workspace-relative source reference is required")
  }
  if self.observed_facts.is_empty() {
    issues.push(
      "observed_facts must separate direct observations from inference",
    )
  }
  for blocking in self.blocking_unknowns {
    if !self.unknowns.contains(blocking) {
      issues.push("blocking_unknowns must also be declared in unknowns")
    }
  }
  if self.scale_basis != "measured" &&
    self.scale_basis != "declared" &&
    self.scale_basis != "inferred" &&
    self.scale_basis != "unknown" {
    issues.push("scale_basis must be measured, declared, inferred, or unknown")
  }
  if self.artifact_refs.is_empty() || self.transform_refs.is_empty() {
    issues.push("spatial studies require artifact and transform lineage")
  }
  for
    reference in self.reference_refs + self.artifact_refs + self.transform_refs {
    if !spatial_reference_is_safe(reference) {
      issues.push("all spatial lineage references must be workspace-relative")
    }
  }
  if self.applicability.is_empty() ||
    self.procedure_steps.is_empty() ||
    self.verification_criteria.is_empty() ||
    self.failure_modes.is_empty() {
    issues.push("reusable spatial studies require bounded procedure metadata")
  }
  issues
}

///|
pub async fn reflect_bookkeeper_file(
  root : String,
  observation_path : String,
) -> BookkeeperReflectionRecord {
  let source = @fsx.read_file(observation_path)
  let observation = decode_bookkeeper_observation(@json.parse(source))
  persist_bookkeeper_observation(root, observation)
}

///|
async fn persist_bookkeeper_observation(
  root : String,
  observation : BookkeeperObservation,
) -> BookkeeperReflectionRecord {
  let normalized_root = @pathx.normalize(root)
  ensure_bookkeeper_learning_dirs(normalized_root)
  let reflection = reflect_on_observation(observation)
  let issues = reflection.quality_issues()
  if !issues.is_empty() {
    fail("unqualified Bookkeeper reflection: \{issues.join("; ")}")
  }
  let reflection_path = moonbook_wiki_path(normalized_root)
    .join(
      moonbook_wiki_path("memory/reflections/\{reflection.reflection_id}.json"),
    )
    .to_string()
  let episode_path = moonbook_wiki_path(normalized_root)
    .join(
      moonbook_wiki_path("memory/episodes/\{observation.observation_id}.json"),
    )
    .to_string()
  let proposals_path = moonbook_wiki_path(normalized_root)
    .join(moonbook_wiki_path("flow/proposals/\{reflection.reflection_id}.json"))
    .to_string()
  @fsx.write_to_file(
    reflection_path,
    reflection.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    episode_path,
    observation.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  for update in reflection.belief_updates {
    let belief_path = moonbook_wiki_path(normalized_root)
      .join(moonbook_wiki_path("memory/beliefs/\{update.update_id}.json"))
      .to_string()
    @fsx.write_to_file(
      belief_path,
      update.to_json().stringify(indent=2) + "\n",
      create=0o644,
    )
  }
  for procedure in reflection.learned_procedures {
    let procedure_path = moonbook_wiki_path(normalized_root)
      .join(
        moonbook_wiki_path("memory/procedures/\{procedure.procedure_id}.json"),
      )
      .to_string()
    @fsx.write_to_file(
      procedure_path,
      procedure.to_json().stringify(indent=2) + "\n",
      create=0o644,
    )
  }
  ignore(
    persist_metacognition(
      normalized_root,
      observation.requirement_id,
      reflection,
    ),
  )
  let proposals_document : Json = {
    "contract_id": "moonsuite.executable-document.v1",
    "book_id": reflection.book_id,
    "revision": reflection.reflection_id,
    "declarations": reflection.proposed_actions.to_json(),
    "execution_bindings": executable_bindings_for_actions(
      reflection.proposed_actions,
      "memory/reflections/\{reflection.reflection_id}.json",
    ),
    "source_digest": executable_sha256(reflection.to_json().stringify(indent=2)),
    "source_reflection": reflection.reflection_id,
    "recorded_at": reflection.recorded_at,
  }
  @fsx.write_to_file(
    proposals_path,
    proposals_document.stringify(indent=2) + "\n",
    create=0o644,
  )
  { reflection_path, episode_path, proposals_path, reflection }
}

///|
pub async fn record_spatial_reference_file(
  root : String,
  study_file : String,
) -> SpatialReferenceRecord {
  let normalized_root = @pathx.normalize(root)
  ensure_bookkeeper_learning_dirs(normalized_root)
  let study : SpatialReferenceStudy = @json.from_json(
    @json.parse(@fsx.read_file(study_file)),
  )
  let issues = study.quality_issues()
  if !issues.is_empty() {
    let detail = issues.join("; ")
    fail("unqualified spatial reference study: \{detail}")
  }
  let study_path = @pathx.join(
    normalized_root,
    "research/spatial/\{study.study_id}.json",
  )
  let canonical_study = study.to_json().stringify(indent=2) + "\n"
  if @fsx.exists(study_path) {
    if @fsx.read_file(study_path) != canonical_study {
      fail("spatial study identity already exists with different content")
    }
    let reflection_id = "reflection-spatial-\{study.study_id}"
    let reflection_path = @pathx.join(
      normalized_root,
      "memory/reflections/\{reflection_id}.json",
    )
    let episode_path = @pathx.join(
      normalized_root,
      "memory/episodes/spatial-\{study.study_id}.json",
    )
    let proposals_path = @pathx.join(
      normalized_root,
      "flow/proposals/\{reflection_id}.json",
    )
    let reflection : BookkeeperReflection = @json.from_json(
      @json.parse(@fsx.read_file(reflection_path)),
    )
    return {
      study_path,
      reflection_record: {
        reflection_path,
        episode_path,
        proposals_path,
        reflection,
      },
    }
  }
  for
    reference in study.reference_refs +
    study.artifact_refs +
    study.transform_refs {
    if !@fsx.exists(@pathx.join(normalized_root, reference)) {
      fail("spatial lineage reference does not exist: \{reference}")
    }
  }
  let unresolved = !study.blocking_unknowns.is_empty() ||
    study.scale_basis == "unknown"
  let evidence_refs = if unresolved {
    []
  } else {
    study.reference_refs + study.artifact_refs + study.transform_refs
  }
  let observed = study.observed_facts.join(" | ")
  let inferred = study.inferred_hypotheses.join(" | ")
  let unknown = study.unknowns.join(" | ")
  let blocking = study.blocking_unknowns.join(" | ")
  let observation : BookkeeperObservation = {
    observation_id: "spatial-\{safe_observation_id(study.study_id)}",
    book_id: study.book_id,
    subject: study.subject,
    requirement_id: study.requirement_id,
    constraint_name: "traceable spatial interpretation",
    statement: "Observed: \{observed}; inferred: \{inferred}; unknown: \{unknown}; blocking unknown: \{blocking}; scale basis: \{study.scale_basis}",
    evidence_refs,
    comparison: "none",
    measured_value: 0.0,
    limit_value: 0.0,
    unit: "",
    outcome: if unresolved {
      "provisional"
    } else {
      "accepted"
    },
    next_action_present: !unresolved,
    validator_product: "moonmold",
    applicability: study.applicability,
    procedure_steps: study.procedure_steps,
    verification_criteria: study.verification_criteria,
    failure_modes: study.failure_modes,
    recorded_at: study.recorded_at,
  }
  let reflection_record = persist_bookkeeper_observation(
    normalized_root, observation,
  )
  @fsx.write_to_file(study_path, canonical_study, create=0o644)
  { study_path, reflection_record }
}

///|
pub async fn promote_bookkeeper_procedures(
  root : String,
  reflection_id : String,
  review_ref : String,
) -> Array[String] {
  let safe_id = safe_observation_id(reflection_id)
  let normalized_root = @pathx.normalize(root)
  ensure_bookkeeper_learning_dirs(normalized_root)
  if !revision_artifact_ref_is_safe(review_ref) {
    fail("procedure promotion review must be workspace-relative")
  }
  if !@fsx.exists(@pathx.join(normalized_root, review_ref)) {
    fail("procedure promotion requires an existing explicit review receipt")
  }
  let reflection_path = moonbook_wiki_path(normalized_root)
    .join(moonbook_wiki_path("memory/reflections/\{safe_id}.json"))
    .to_string()
  let reflection : BookkeeperReflection = @json.from_json(
    @json.parse(@fsx.read_file(reflection_path)),
  )
  if !reflection.gaps.is_empty() {
    fail("cannot promote procedure while reflection gaps remain open")
  }
  if reflection.confidence < 0.9 {
    fail("cannot promote a low-confidence procedure")
  }
  if reflection.learned_procedures.is_empty() {
    fail("reflection contains no learned procedure")
  }
  let paths : Array[String] = []
  let (_, _, procedure_index_path) = metacognition_paths(normalized_root)
  let procedure_index = load_procedure_index(
    procedure_index_path,
    reflection.book_id,
    reflection.recorded_at,
  )
  for candidate in reflection.learned_procedures {
    if candidate.evidence_refs.is_empty() ||
      candidate.verification_criteria.is_empty() ||
      candidate.failure_modes.is_empty() {
      fail(
        "procedure promotion requires evidence, verification, and failure modes",
      )
    }
    let procedure = { ..candidate, status: "accepted" }
    let stable_key = procedure_stable_key(candidate)
    let mut indexed = false
    for record in procedure_index.procedures {
      if record.stable_key == stable_key {
        if !record.review_refs.contains(review_ref) {
          record.review_refs.push(review_ref)
        }
        record.status = "accepted"
        record.updated_at = reflection.recorded_at
        indexed = true
      }
    }
    if !indexed {
      fail("procedure candidate is missing from the learning index")
    }
    let path = moonbook_wiki_path(normalized_root)
      .join(
        moonbook_wiki_path("memory/procedures/\{procedure.procedure_id}.json"),
      )
      .to_string()
    @fsx.write_to_file(
      path,
      procedure.to_json().stringify(indent=2) + "\n",
      create=0o644,
    )
    paths.push(path)
  }
  @fsx.write_to_file(
    procedure_index_path,
    procedure_index.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  paths
}
