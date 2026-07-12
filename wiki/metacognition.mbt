///|
pub(all) struct PersistentGapNode {
  stable_key : String
  gap_id : String
  requirement_id : String
  kind : String
  question : String
  significance : String
  current_evidence : Array[String]
  resolution_criteria : Array[String]
  mut status : String
  first_reflection_id : String
  mut last_reflection_id : String
  mut resolution_ref : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PersistentGapGraph {
  contract_id : String
  book_id : String
  nodes : Array[PersistentGapNode]
  mut updated_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PersistentBelief {
  belief_id : String
  mut statement : String
  mut confidence : Double
  supporting_evidence : Array[String]
  contradicting_evidence : Array[String]
  consequence_links : Array[String]
  invalidation_triggers : Array[String]
  mut status : String
  mut last_update_id : String
  mut updated_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PersistentBeliefIndex {
  contract_id : String
  book_id : String
  beliefs : Array[PersistentBelief]
  mut updated_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ProcedureLearningRecord {
  stable_key : String
  procedure : BookkeeperProcedure
  successful_reflections : Array[String]
  review_refs : Array[String]
  mut status : String
  mut updated_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ProcedureLearningIndex {
  contract_id : String
  book_id : String
  procedures : Array[ProcedureLearningRecord]
  mut updated_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct MetacognitionSnapshot {
  contract_id : String
  gap_graph_path : String
  belief_index_path : String
  procedure_index_path : String
  open_information_gaps : Int
  open_cognition_gaps : Int
  open_execution_gaps : Int
  accepted_procedures : Int
  recorded_at : String
} derive(Debug, Eq, ToJson)

///|
fn metacognition_paths(root : String) -> (String, String, String) {
  (
    @pathx.join(root, "memory/gaps/graph.json"),
    @pathx.join(root, "memory/beliefs/index.json"),
    @pathx.join(root, "memory/procedures/index.json"),
  )
}

///|
async fn ensure_metacognition_dirs(root : String) -> Unit {
  for relative in ["memory/gaps", "memory/beliefs", "memory/procedures"] {
    @fsx.make_directory(
      @pathx.join(root, relative),
      recursive=true,
      exists_ok=true,
    )
  }
}

///|
fn gap_stable_key(requirement_id : String, kind : String) -> String {
  "\{requirement_id}::\{kind}"
}

///|
fn procedure_stable_key(procedure : BookkeeperProcedure) -> String {
  let applicability = procedure.applicability.map(value => value.to_lower())
  "\{procedure.title.to_lower()}::\{applicability.join("|")}"
}

///|
async fn load_gap_graph(
  path : String,
  book_id : String,
  recorded_at : String,
) -> PersistentGapGraph {
  if @fsx.exists(path) {
    @json.from_json(@json.parse(@fsx.read_file(path)))
  } else {
    {
      contract_id: "moonbook.gap-graph.v1",
      book_id,
      nodes: [],
      updated_at: recorded_at,
    }
  }
}

///|
async fn load_belief_index(
  path : String,
  book_id : String,
  recorded_at : String,
) -> PersistentBeliefIndex {
  if @fsx.exists(path) {
    @json.from_json(@json.parse(@fsx.read_file(path)))
  } else {
    {
      contract_id: "moonbook.belief-index.v1",
      book_id,
      beliefs: [],
      updated_at: recorded_at,
    }
  }
}

///|
async fn load_procedure_index(
  path : String,
  book_id : String,
  recorded_at : String,
) -> ProcedureLearningIndex {
  if @fsx.exists(path) {
    @json.from_json(@json.parse(@fsx.read_file(path)))
  } else {
    {
      contract_id: "moonbook.procedure-candidate.v1",
      book_id,
      procedures: [],
      updated_at: recorded_at,
    }
  }
}

///|
fn integrate_gaps(
  graph : PersistentGapGraph,
  requirement_id : String,
  reflection : BookkeeperReflection,
) -> Unit {
  let active_keys = reflection.gaps.map(gap => {
    gap_stable_key(requirement_id, gap.kind)
  })
  for node in graph.nodes {
    if node.requirement_id == requirement_id &&
      node.status == "open" &&
      !active_keys.contains(node.stable_key) {
      node.status = "resolved"
      node.last_reflection_id = reflection.reflection_id
      node.resolution_ref = reflection.reflection_id
    }
  }
  for gap in reflection.gaps {
    let stable_key = gap_stable_key(requirement_id, gap.kind)
    let mut found = false
    for node in graph.nodes {
      if node.stable_key == stable_key {
        node.status = gap.status
        node.last_reflection_id = reflection.reflection_id
        node.resolution_ref = ""
        found = true
      }
    }
    if !found {
      graph.nodes.push({
        stable_key,
        gap_id: gap.gap_id,
        requirement_id,
        kind: gap.kind,
        question: gap.question,
        significance: gap.significance,
        current_evidence: gap.current_evidence.copy(),
        resolution_criteria: gap.resolution_criteria.copy(),
        status: gap.status,
        first_reflection_id: reflection.reflection_id,
        last_reflection_id: reflection.reflection_id,
        resolution_ref: "",
      })
    }
  }
  graph.updated_at = reflection.recorded_at
}

///|
fn integrate_beliefs(
  index : PersistentBeliefIndex,
  reflection : BookkeeperReflection,
) -> Unit {
  for update in reflection.belief_updates {
    let mut found = false
    for belief in index.beliefs {
      if belief.belief_id == update.belief_id {
        belief.statement = update.statement
        belief.confidence = update.confidence
        belief.status = if update.change.contains("contradicted") {
          "contradicted"
        } else {
          "supported"
        }
        for evidence in update.evidence_refs {
          let destination = if belief.status == "contradicted" {
            belief.contradicting_evidence
          } else {
            belief.supporting_evidence
          }
          if !destination.contains(evidence) {
            destination.push(evidence)
          }
        }
        belief.last_update_id = update.update_id
        belief.updated_at = reflection.recorded_at
        found = true
      }
    }
    if !found {
      let contradicted = update.change.contains("contradicted")
      index.beliefs.push({
        belief_id: update.belief_id,
        statement: update.statement,
        confidence: update.confidence,
        supporting_evidence: if contradicted {
          []
        } else {
          update.evidence_refs.copy()
        },
        contradicting_evidence: if contradicted {
          update.evidence_refs.copy()
        } else {
          []
        },
        consequence_links: update.affected_refs.copy(),
        invalidation_triggers: [
          "supporting or contradicting evidence is superseded", "a linked requirement or consequence changes",
        ],
        status: if contradicted {
          "contradicted"
        } else {
          "supported"
        },
        last_update_id: update.update_id,
        updated_at: reflection.recorded_at,
      })
    }
  }
  index.updated_at = reflection.recorded_at
}

///|
fn integrate_procedures(
  index : ProcedureLearningIndex,
  reflection : BookkeeperReflection,
) -> Unit {
  for procedure in reflection.learned_procedures {
    let stable_key = procedure_stable_key(procedure)
    let mut found = false
    for record in index.procedures {
      if record.stable_key == stable_key {
        if !record.successful_reflections.contains(reflection.reflection_id) {
          record.successful_reflections.push(reflection.reflection_id)
        }
        if record.successful_reflections.length() >= 2 {
          record.status = "accepted"
        }
        record.updated_at = reflection.recorded_at
        found = true
      }
    }
    if !found {
      index.procedures.push({
        stable_key,
        procedure,
        successful_reflections: [reflection.reflection_id],
        review_refs: [],
        status: "candidate",
        updated_at: reflection.recorded_at,
      })
    }
  }
  index.updated_at = reflection.recorded_at
}

///|
pub async fn persist_metacognition(
  root : String,
  requirement_id : String,
  reflection : BookkeeperReflection,
) -> MetacognitionSnapshot {
  let normalized_root = @pathx.normalize(root)
  ensure_metacognition_dirs(normalized_root)
  let (gap_path, belief_path, procedure_path) = metacognition_paths(
    normalized_root,
  )
  let gap_graph = load_gap_graph(
    gap_path,
    reflection.book_id,
    reflection.recorded_at,
  )
  let beliefs = load_belief_index(
    belief_path,
    reflection.book_id,
    reflection.recorded_at,
  )
  let procedures = load_procedure_index(
    procedure_path,
    reflection.book_id,
    reflection.recorded_at,
  )
  integrate_gaps(gap_graph, requirement_id, reflection)
  integrate_beliefs(beliefs, reflection)
  integrate_procedures(procedures, reflection)
  @fsx.write_to_file(
    gap_path,
    gap_graph.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    belief_path,
    beliefs.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    procedure_path,
    procedures.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  {
    contract_id: "moonbook.metacognition-snapshot.v1",
    gap_graph_path: gap_path,
    belief_index_path: belief_path,
    procedure_index_path: procedure_path,
    open_information_gaps: gap_graph.nodes
    .filter(node => node.kind == "information-gap" && node.status == "open")
    .length(),
    open_cognition_gaps: gap_graph.nodes
    .filter(node => node.kind == "cognition-gap" && node.status == "open")
    .length(),
    open_execution_gaps: gap_graph.nodes
    .filter(node => node.kind == "execution-gap" && node.status == "open")
    .length(),
    accepted_procedures: procedures.procedures
    .filter(procedure => procedure.status == "accepted")
    .length(),
    recorded_at: reflection.recorded_at,
  }
}

///|
pub async fn metacognition_status_json(root : String) -> Json {
  let normalized_root = @pathx.normalize(root)
  let (gap_path, belief_path, procedure_path) = metacognition_paths(
    normalized_root,
  )
  if !@fsx.exists(gap_path) {
    return {
      "contract_id": "moonbook.metacognition-status.v1",
      "initialized": false,
      "root": normalized_root,
    }
  }
  let gap_graph : PersistentGapGraph = @json.from_json(
    @json.parse(@fsx.read_file(gap_path)),
  )
  let beliefs : PersistentBeliefIndex = @json.from_json(
    @json.parse(@fsx.read_file(belief_path)),
  )
  let procedures : ProcedureLearningIndex = @json.from_json(
    @json.parse(@fsx.read_file(procedure_path)),
  )
  {
    "contract_id": "moonbook.metacognition-status.v1",
    "initialized": true,
    "book_id": gap_graph.book_id,
    "gap_graph": gap_graph.to_json(),
    "beliefs": beliefs.to_json(),
    "procedures": procedures.to_json(),
  }
}
