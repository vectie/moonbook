///|
fn metacognition_reflection(
  reflection_id : String,
  gaps : Array[BookkeeperGap],
  procedures : Array[BookkeeperProcedure],
  recorded_at : String,
) -> BookkeeperReflection {
  {
    contract_id: "moonbook.bookkeeper-reflection.v1",
    reflection_id,
    book_id: "metacognition-book",
    trigger: "test-observation",
    observations: ["A governed observation was recorded."],
    gaps,
    belief_updates: [],
    proposed_actions: if gaps.any(gap => gap.kind == "execution-gap") {
      [
        {
          declaration_id: "resolve-gap",
          kind: "research",
          title: "Resolve execution gap",
          statement: "Perform the governed next action.",
          executor_product: "moonwiki",
          requires: [],
          acceptance_criteria: ["the gap is resolved with evidence"],
          requested_authority: "observe",
        },
      ]
    } else {
      []
    },
    learned_procedures: procedures,
    confidence: 0.95,
    uncertainty: [],
    requested_authority: "cognitive-maintenance",
    recorded_at,
  }
}

///|
fn candidate_procedure(procedure_id : String) -> BookkeeperProcedure {
  {
    procedure_id,
    title: "Validate a bounded digital artifact",
    applicability: ["the artifact has declared positive and negative criteria"],
    steps: ["run native checks", "run positive and negative cases"],
    verification_criteria: ["all declared cases have exact receipts"],
    failure_modes: ["negative cases are omitted"],
    counterexamples: ["Reject reuse when negative cases are omitted."],
    invalidation_triggers: ["toolchain or acceptance criteria change"],
    evidence_refs: ["evidence/accepted-run.json"],
    status: "candidate",
  }
}

///|
async test "gap graph deduplicates stable gaps and records their resolution" {
  let root = "/tmp/moonbook-metacognition-gap-wbtest-" +
    @async.now().to_int().to_string()
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let gap = BookkeeperGap::{
    gap_id: "information-observation-1",
    kind: "information-gap",
    question: "Which evidence is missing?",
    required_by: ["terrain-model"],
    current_evidence: [],
    missing: "Traceable terrain evidence.",
    significance: "The model cannot be accepted without it.",
    resolution_criteria: ["a reviewed evidence envelope is attached"],
    status: "open",
  }
  let first = metacognition_reflection(
    "reflection-gap-1",
    [gap],
    [],
    "2026-07-12T14:00:00+08:00",
  )
  let snapshot = persist_metacognition(root, "terrain-model", first)
  assert_eq(snapshot.open_information_gaps, 1)
  let repeated = metacognition_reflection(
    "reflection-gap-2",
    [{ ..gap, gap_id: "information-observation-2" }],
    [],
    "2026-07-12T14:01:00+08:00",
  )
  ignore(persist_metacognition(root, "terrain-model", repeated))
  let graph : PersistentGapGraph = @json.from_json(
    @json.parse(@fsx.read_file(snapshot.gap_graph_path)),
  )
  assert_eq(graph.nodes.length(), 1)
  assert_eq(graph.nodes[0].last_reflection_id, "reflection-gap-2")
  let resolved = metacognition_reflection(
    "reflection-gap-3",
    [],
    [],
    "2026-07-12T14:02:00+08:00",
  )
  let final_snapshot = persist_metacognition(root, "terrain-model", resolved)
  assert_eq(final_snapshot.open_information_gaps, 0)
  let final_graph : PersistentGapGraph = @json.from_json(
    @json.parse(@fsx.read_file(snapshot.gap_graph_path)),
  )
  assert_eq(final_graph.nodes[0].status, "resolved")
  assert_eq(final_graph.nodes[0].resolution_ref, "reflection-gap-3")
}

///|
async test "procedure remains candidate after one success and promotes after two" {
  let root = "/tmp/moonbook-metacognition-procedure-wbtest-" +
    @async.now().to_int().to_string()
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let first = persist_metacognition(
    root,
    "artifact-validation",
    metacognition_reflection(
      "reflection-success-1",
      [],
      [candidate_procedure("procedure-run-1")],
      "2026-07-12T14:10:00+08:00",
    ),
  )
  assert_eq(first.accepted_procedures, 0)
  let second = persist_metacognition(
    root,
    "artifact-validation",
    metacognition_reflection(
      "reflection-success-2",
      [],
      [
        {
          ..candidate_procedure("procedure-run-2"),
          applicability: [
            "the artifact has declared positive and negative criteria", "declaration revision r2",
            "input digest sha256:bbbbbbbb",
          ],
          steps: [
            "run native checks", "Retain result result-run-2 and output digest sha256:cccccccc.",
            "run positive and negative cases",
          ],
          evidence_refs: ["evidence/accepted-run-2.json"],
        },
      ],
      "2026-07-12T14:11:00+08:00",
    ),
  )
  assert_eq(second.accepted_procedures, 1)
  let index : ProcedureLearningIndex = @json.from_json(
    @json.parse(@fsx.read_file(second.procedure_index_path)),
  )
  assert_eq(index.procedures.length(), 1)
  assert_eq(index.procedures[0].successful_reflections.length(), 2)
  assert_eq(index.procedures[0].status, "accepted")
  assert_true(
    index.procedures[0].procedure.evidence_refs.contains(
      "evidence/accepted-run-2.json",
    ),
  )
  assert_true(!index.procedures[0].procedure.invalidation_triggers.is_empty())
}

///|
async test "belief index separates contradiction evidence and records invalidation" {
  let root = "/tmp/moonbook-metacognition-belief-wbtest-" +
    @async.now().to_int().to_string()
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let reflection = {
    ..metacognition_reflection(
      "reflection-belief-1",
      [],
      [],
      "2026-07-12T14:20:00+08:00",
    ),
    belief_updates: [
      {
        update_id: "update-power-margin-1",
        belief_id: "power-margin-is-sufficient",
        statement: "The current power margin is not sufficient under the observed load.",
        change: "contradicted-by-observation",
        evidence_refs: ["evidence/power-load-1.json"],
        confidence: 0.93,
        affected_refs: ["mission-duration", "safe-return"],
      },
    ],
  }
  let snapshot = persist_metacognition(root, "power-margin", reflection)
  let index : PersistentBeliefIndex = @json.from_json(
    @json.parse(@fsx.read_file(snapshot.belief_index_path)),
  )
  assert_eq(index.beliefs.length(), 1)
  assert_eq(index.beliefs[0].status, "contradicted")
  assert_true(
    index.beliefs[0].contradicting_evidence.contains(
      "evidence/power-load-1.json",
    ),
  )
  assert_true(index.beliefs[0].consequence_links.contains("safe-return"))
  assert_true(!index.beliefs[0].invalidation_triggers.is_empty())
}

///|
test "accepted procedures transfer structurally and changed criteria prevent reuse" {
  let procedure = candidate_procedure("procedure-source-domain")
  let index : ProcedureLearningIndex = {
    contract_id: "moonbook.procedure-candidate.v1",
    book_id: "source-domain",
    procedures: [
      {
        stable_key: "structural-digital-validation",
        procedure,
        successful_reflections: ["success-a", "success-b"],
        review_refs: [],
        status: "accepted",
        updated_at: "2026-07-12T14:30:00+08:00",
      },
    ],
    updated_at: "2026-07-12T14:30:00+08:00",
  }
  let transferred = retrieve_applicable_procedures(
    index,
    [
      "A software package has positive and negative acceptance criteria.", "Run native checks and retain exact case receipts.",
    ],
    [],
  ).stringify()
  assert_true(transferred.contains("\"status\":\"applicable-candidate\""))
  let invalidated = retrieve_applicable_procedures(
    index,
    ["A different robot model has positive and negative acceptance criteria."],
    ["The acceptance criteria change for this run."],
  ).stringify()
  assert_true(invalidated.contains("invalidation signal matched"))
  assert_false(invalidated.contains("\"status\":\"applicable-candidate\""))
}
