///|
fn observation(
  evidence_refs? : Array[String] = ["terrain-edge-17"],
  measured_value? : Double = 24.0,
  limit_value? : Double = 15.0,
  outcome? : String = "blocked",
  next_action_present? : Bool = false,
) -> BookkeeperObservation {
  {
    observation_id: "selene-route-edge-17",
    book_id: "selene-crater-service-rover",
    subject: "candidate traverse",
    requirement_id: "maximum-traverse-slope",
    constraint_name: "maximum traverse slope",
    statement: "One candidate edge measures 24 degrees against a 15 degree maximum.",
    evidence_refs,
    comparison: "maximum",
    measured_value,
    limit_value,
    unit: "degree",
    outcome,
    next_action_present,
    validator_product: "moonmoon",
    applicability: [
      "a mission path has an explicit maximum edge-slope requirement",
    ],
    procedure_steps: [
      "preserve the failed global claim", "find a connected mission-specific alternative",
      "recompute every edge independently",
    ],
    verification_criteria: ["every candidate edge satisfies the declared limit"],
    failure_modes: ["copying a previous path without recomputation"],
    recorded_at: "2026-07-11T00:00:00Z",
  }
}

///|
test "Bookkeeper closes all three gaps without weakening the constraint" {
  let reflection = @wiki.reflect_on_observation(observation(evidence_refs=[]))
  assert_true(reflection.quality_issues().is_empty())
  assert_eq(reflection.requested_authority, "cognitive-maintenance")
  assert_true(reflection.gaps.any(gap => gap.kind == "information-gap"))
  assert_true(reflection.gaps.any(gap => gap.kind == "cognition-gap"))
  assert_true(reflection.gaps.any(gap => gap.kind == "execution-gap"))
  assert_true(
    reflection.proposed_actions.any(action => {
      action.statement.contains("without weakening its declared limit")
    }),
  )
  assert_true(
    reflection.proposed_actions.any(action => {
      action.executor_product == "moonmoon"
    }),
  )
}

///|
test "accepted observation produces a transferable procedure" {
  let reflection = @wiki.reflect_on_observation(
    observation(
      measured_value=11.0,
      outcome="accepted",
      next_action_present=true,
    ),
  )
  assert_true(reflection.gaps.is_empty())
  assert_eq(reflection.learned_procedures.length(), 1)
  let procedure = reflection.learned_procedures[0]
  assert_true(procedure.applicability[0].contains("explicit maximum"))
  assert_true(procedure.failure_modes[0].contains("without recomputation"))
}

///|
test "missing evidence does not create trusted procedural memory" {
  let reflection = @wiki.reflect_on_observation(
    observation(evidence_refs=[], measured_value=11.0, outcome="accepted"),
  )
  assert_true(reflection.gaps.any(gap => gap.kind == "information-gap"))
  assert_true(reflection.learned_procedures.is_empty())
  assert_eq(reflection.confidence, 0.55)
}

///|
async test "Bookkeeper proposal compiles with canonical authority and source digest" {
  let root = "/tmp/moonbook-bookkeeper-proposal-wbtest"
  @fsx.make_directory(root, recursive=true)
  let observation_path = root + "/observation.json"
  @fsx.write_to_file(
    observation_path,
    observation().to_json().stringify(indent=2),
  )
  let record = @wiki.reflect_bookkeeper_file(root, observation_path)
  let document = @wiki.decode_executable_document(
    @json.parse(@fsx.read_file(record.proposals_path)),
  )
  assert_true(document.quality_issues().is_empty())
  assert_true(@wiki.executable_source_digest_is_valid(document.source_digest))
  assert_eq(
    document.source_digest,
    @wiki.executable_sha256(
      @fsx.read_file(record.reflection_path).trim().to_owned(),
    ),
  )
  let graph = @wiki.compile_executable_document(document)
  assert_true(graph.stringify().contains("work-investigate-alternative"))
  assert_true(graph.stringify().contains("sandbox-execution"))
}

///|
async test "reviewed high-confidence procedure promotion becomes durable memory" {
  let root = "/tmp/moonbook-bookkeeper-promotion-wbtest"
  @fsx.make_directory(root, recursive=true)
  let observation_path = root + "/observation.json"
  @fsx.write_to_file(
    observation_path,
    observation(
      measured_value=11.0,
      outcome="accepted",
      next_action_present=true,
    )
    .to_json()
    .stringify(indent=2),
  )
  let record = @wiki.reflect_bookkeeper_file(root, observation_path)
  let review_ref = "reviews/procedure-promotion.json"
  @fsx.make_directory(root + "/reviews", recursive=true, exists_ok=true)
  @fsx.write_to_file(
    root + "/" + review_ref,
    "{\"decision\":\"accepted\",\"reviewer\":\"human\"}",
    create=0o644,
  )
  let paths = @wiki.promote_bookkeeper_procedures(
    root,
    record.reflection.reflection_id,
    review_ref,
  )
  assert_eq(paths.length(), 1)
  assert_true(@fsx.read_file(paths[0]).contains("\"status\": \"accepted\""))
}

///|
fn spatial_study(unknowns? : Array[String] = []) -> @wiki.SpatialReferenceStudy {
  {
    study_id: if unknowns.is_empty() {
      "habitat-complete"
    } else {
      "habitat-provisional"
    },
    book_id: "lunar-habitat-book",
    subject: "reference-derived habitat shell",
    requirement_id: "habitat-spatial-lineage",
    reference_refs: ["inputs/reference.png"],
    observed_facts: ["the source image shows a rectangular central volume"],
    inferred_hypotheses: ["the visible wings may be service volumes"],
    unknowns,
    blocking_unknowns: unknowns,
    scale_basis: if unknowns.is_empty() {
      "declared"
    } else {
      "unknown"
    },
    artifact_refs: ["artifacts/habitat.glb"],
    transform_refs: ["artifacts/habitat-transform.json"],
    applicability: ["a user supplies a workspace-local visual reference"],
    procedure_steps: [
      "separate observed geometry from inferred geometry", "declare the scale basis",
      "preserve transform lineage for each derived representation",
    ],
    verification_criteria: [
      "all source and output references resolve inside the MoonBook",
    ],
    failure_modes: ["treating an inferred dimension as a measured fact"],
    recorded_at: "2026-07-13T00:00:00Z",
  }
}

///|
async test "complete spatial reference study becomes candidate procedural memory" {
  let root = "/tmp/moonbook-spatial-complete-wbtest"
  @fsx.make_directory(root + "/inputs", recursive=true, exists_ok=true)
  @fsx.make_directory(root + "/artifacts", recursive=true, exists_ok=true)
  @fsx.write_to_file(root + "/inputs/reference.png", "fixture")
  @fsx.write_to_file(root + "/artifacts/habitat.glb", "fixture")
  @fsx.write_to_file(root + "/artifacts/habitat-transform.json", "{}")
  let study_path = root + "/study.json"
  @fsx.write_to_file(study_path, spatial_study().to_json().stringify(indent=2))
  let record = @wiki.record_spatial_reference_file(root, study_path)
  assert_true(@fsx.exists(record.study_path))
  assert_true(record.reflection_record.reflection.gaps.is_empty())
  assert_eq(record.reflection_record.reflection.learned_procedures.length(), 1)
  let repeated = @wiki.record_spatial_reference_file(root, study_path)
  assert_eq(repeated.study_path, record.study_path)
  assert_true(
    repeated.reflection_record.reflection == record.reflection_record.reflection,
  )
}

///|
async test "unknown spatial scale remains an information gap and cannot become habit" {
  let root = "/tmp/moonbook-spatial-provisional-wbtest"
  @fsx.make_directory(root + "/inputs", recursive=true, exists_ok=true)
  @fsx.make_directory(root + "/artifacts", recursive=true, exists_ok=true)
  @fsx.write_to_file(root + "/inputs/reference.png", "fixture")
  @fsx.write_to_file(root + "/artifacts/habitat.glb", "fixture")
  @fsx.write_to_file(root + "/artifacts/habitat-transform.json", "{}")
  let study_path = root + "/study.json"
  @fsx.write_to_file(
    study_path,
    spatial_study(unknowns=["no reliable real-world dimension is visible"])
    .to_json()
    .stringify(indent=2),
  )
  let record = @wiki.record_spatial_reference_file(root, study_path)
  assert_true(
    record.reflection_record.reflection.gaps.any(gap => {
      gap.kind == "information-gap"
    }),
  )
  assert_true(record.reflection_record.reflection.learned_procedures.is_empty())
}
