///|
pub(all) enum GoalIntentClass {
  ResearchOutcome
  SoftwareArtifact
  PhysicalSystemDigitalTwin
  GeneralDigitalArtifact
} derive(Debug, Eq)

///|
pub fn GoalIntentClass::id(self : GoalIntentClass) -> String {
  match self {
    ResearchOutcome => "research-outcome"
    SoftwareArtifact => "software-artifact"
    PhysicalSystemDigitalTwin => "physical-system-digital-twin"
    GeneralDigitalArtifact => "general-digital-artifact"
  }
}

///|
pub(all) struct GoalCompileRecord {
  contract_id : String
  goal_path : String
  assumptions_path : String
  declaration_path : String
  graph_path : String
  intent_class : String
  graph : Json
} derive(Debug, Eq, ToJson)

///|
pub(all) struct GoalRuntimeRecord {
  contract_id : String
  capabilities_path : String
  manifest_path : String
  review_policy_path : String
  envelope_request_path : String
  expected_artifacts : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub fn classify_goal_intent(goal : String) -> GoalIntentClass {
  let text = goal.to_lower()
  let physical = [
    "robot", "rover", "hardware", "machine", "vehicle", "device", "mechanism", "physical system",
    "manufacture", "fabricate",
  ].any(term => text.contains(term))
  let software = [
    "software", "code", "library", "compiler", "service", "api", "application", "website",
    "program", "repository",
  ].any(term => text.contains(term))
  let research = [
    "research", "investigate", "study", "compare", "explain", "evidence", "literature",
    "survey",
  ].any(term => text.contains(term))
  if physical {
    PhysicalSystemDigitalTwin
  } else if software {
    SoftwareArtifact
  } else if research {
    ResearchOutcome
  } else {
    GeneralDigitalArtifact
  }
}

///|
fn goal_action(
  declaration_id : String,
  kind : String,
  title : String,
  statement : String,
  executor_product : String,
  requires : Array[String],
  acceptance_criteria : Array[String],
  requested_authority : String,
) -> BookkeeperAction {
  {
    declaration_id,
    kind,
    title,
    statement,
    executor_product,
    requires,
    acceptance_criteria,
    requested_authority,
  }
}

///|
fn goal_binding(
  declaration_id : String,
  operation : String,
  input_contracts : Array[String],
  output_contracts : Array[String],
  required_claim : String,
  input_artifacts : Array[String],
  timeout_ms : Int,
) -> ExecutableExecutionBinding {
  {
    declaration_id,
    operation,
    input_contracts,
    output_contracts,
    required_claim,
    input_artifacts,
    timeout_ms,
  }
}

///|
pub fn compile_goal_document(
  book_id : String,
  revision : String,
  goal : String,
  goal_ref : String,
  recorded_at : String,
) -> ExecutableDocument {
  let intent = classify_goal_intent(goal)
  let actions : Array[BookkeeperAction] = [
    goal_action(
      "research",
      "research-goal",
      "Resolve goal information gaps",
      "Collect primary evidence, alternatives, contradictions, limitations, and stopping rationale for the approved goal without changing it.",
      "moonwiki",
      [],
      [
        "primary or authoritative evidence is traceable", "material contradictions and limitations are explicit",
        "remaining information gaps are qualified or blocked",
      ],
      "observe",
    ),
  ]
  let bindings : Array[ExecutableExecutionBinding] = [
    goal_binding(
      "research",
      "research-goal",
      ["moonsuite.goal.v1"],
      ["moonwiki.evidence-bundle.v1"],
      "research-evidence",
      [goal_ref],
      600000,
    ),
  ]
  let mut terminal_contract = "moonwiki.evidence-bundle.v1"
  match intent {
    ResearchOutcome => {
      actions.push(
        goal_action(
          "critique",
          "deliberate-evidence",
          "Critique the evidence and competing explanations",
          "Produce a plural critique that preserves dissent and identifies unsupported conclusions.",
          "moontown",
          ["research"],
          [
            "at least one competing explanation is evaluated", "dissent and uncertainty remain traceable",
          ],
          "cognitive-maintenance",
        ),
      )
      bindings.push(
        goal_binding(
          "critique",
          "deliberate-evidence",
          ["moonwiki.evidence-bundle.v1"],
          ["moontown.deliberation.v1"],
          "accepted-knowledge",
          [goal_ref],
          300000,
        ),
      )
      terminal_contract = "moontown.deliberation.v1"
    }
    SoftwareArtifact => {
      actions.push(
        goal_action(
          "design",
          "deliberate-design",
          "Choose a bounded software design",
          "Compare implementable approaches and retain reasons, dissent, risks, and acceptance ownership.",
          "moontown",
          ["research"],
          [
            "alternatives are compared against the original outcome", "the selected approach keeps owner boundaries and risks explicit",
          ],
          "cognitive-maintenance",
        ),
      )
      actions.push(
        goal_action(
          "implement",
          "implement-software",
          "Implement the governed software artifact",
          "Create the smallest general implementation that satisfies the approved design and preserve all trial evidence.",
          "moonclaw",
          ["design"],
          [
            "the software builds or checks successfully", "tests cover the declared positive and negative behavior",
            "no acceptance criterion was weakened during trials",
          ],
          "workspace-mutation",
        ),
      )
      bindings.push(
        goal_binding(
          "design",
          "deliberate-design",
          ["moonwiki.evidence-bundle.v1"],
          ["moontown.deliberation.v1"],
          "accepted-knowledge",
          [goal_ref],
          300000,
        ),
      )
      bindings.push(
        goal_binding(
          "implement",
          "implement-software",
          ["moontown.deliberation.v1"],
          ["moonclaw.software-result.v1"],
          "digital-artifact",
          [goal_ref],
          900000,
        ),
      )
      terminal_contract = "moonclaw.software-result.v1"
    }
    PhysicalSystemDigitalTwin => {
      actions.push(
        goal_action(
          "concept",
          "deliberate-concept",
          "Select a digital physical-system concept",
          "Compare feasible concepts against lunar or declared environment constraints while preserving dissent and unresolved assumptions.",
          "moontown",
          ["research"],
          [
            "multiple concepts are compared against explicit criteria", "the recommendation preserves dissent and unresolved assumptions",
          ],
          "cognitive-maintenance",
        ),
      )
      actions.push(
        goal_action(
          "helper-tools",
          "implement-helper-tools",
          "Build bounded executable helper logic",
          "Implement the smallest concept-specific calculations or decision gates as a native-validated safe helper DSL with positive and negative vectors.",
          "moonclaw",
          ["concept"],
          [
            "helper logic passes native wrapper-owned checks", "positive and negative vectors are executed rather than asserted",
            "the helper remains digital and preserves every original criterion",
          ],
          "workspace-mutation",
        ),
      )
      actions.push(
        goal_action(
          "digital-build",
          "build-digital-robot",
          "Build the governed digital system model",
          "Produce a traceable digital design and sandboxed model; do not claim physical construction or readiness.",
          "moonrobo",
          ["concept", "helper-tools"],
          [
            "the digital design traces requirements to components", "hazards, margins, and unsupported physical assumptions are explicit",
            "the artifact claims digital design only",
          ],
          "workspace-mutation",
        ),
      )
      actions.push(
        goal_action(
          "validate",
          "validate-requirements",
          "Validate the digital design and negative cases",
          "Run independent structural, constraint, and resilience validation against the original criteria.",
          "moonrobo",
          ["digital-build"],
          [
            "all declared constraints have evidence or an explicit blocker", "negative and degraded cases are exercised",
            "failures cannot be hidden by aggregate scores",
          ],
          "sandbox-execution",
        ),
      )
      actions.push(
        goal_action(
          "simulate",
          "simulate-mission",
          "Run bounded digital environment scenarios",
          "Simulate nominal and adverse scenarios with uncertainty; stop below physical-readiness claims.",
          "moonmoon",
          ["validate"],
          [
            "nominal and adverse scenarios are reproducible", "uncertainty and model limitations are explicit",
            "claims do not exceed scenario-qualified evidence",
          ],
          "sandbox-execution",
        ),
      )
      bindings.push(
        goal_binding(
          "concept",
          "deliberate-concept",
          ["moonwiki.evidence-bundle.v1"],
          ["moontown.deliberation.v1"],
          "accepted-knowledge",
          [goal_ref],
          300000,
        ),
      )
      bindings.push(
        goal_binding(
          "helper-tools",
          "implement-helper-tools",
          ["moontown.deliberation.v1"],
          ["moonclaw.software-result.v1"],
          "digital-artifact",
          [goal_ref],
          900000,
        ),
      )
      bindings.push(
        goal_binding(
          "digital-build",
          "build-digital-robot",
          ["moontown.deliberation.v1", "moonclaw.software-result.v1"],
          ["moonrobo.digital-design.v1"],
          "digital-artifact",
          [goal_ref],
          900000,
        ),
      )
      bindings.push(
        goal_binding(
          "validate",
          "validate-requirements",
          ["moonrobo.digital-design.v1"],
          ["moonrobo.validation-evidence.v1"],
          "simulation-evidence",
          [goal_ref],
          900000,
        ),
      )
      terminal_contract = "moonmoon.scenario-evidence.v1"
      bindings.push(
        goal_binding(
          "simulate",
          "simulate-mission",
          ["moonrobo.validation-evidence.v1"],
          ["moonmoon.scenario-evidence.v1"],
          "scenario-qualified",
          [goal_ref],
          900000,
        ),
      )
    }
    GeneralDigitalArtifact => {
      actions.push(
        goal_action(
          "deliberate",
          "deliberate-outcome",
          "Clarify alternatives and execution boundaries",
          "Compare interpretations and methods without expanding the approved goal or authority.",
          "moontown",
          ["research"],
          [
            "desired outcomes are separated from proposed methods", "material ambiguity is resolved or explicitly blocked",
          ],
          "cognitive-maintenance",
        ),
      )
      bindings.push(
        goal_binding(
          "deliberate",
          "deliberate-outcome",
          ["moonwiki.evidence-bundle.v1"],
          ["moontown.deliberation.v1"],
          "accepted-knowledge",
          [goal_ref],
          300000,
        ),
      )
      terminal_contract = "moontown.deliberation.v1"
    }
  }
  let terminal = actions[actions.length() - 1].declaration_id
  actions.push(
    goal_action(
      "audit",
      "audit-outcome",
      "Audit the outcome against the original goal",
      "Reconcile evidence, gaps, decisions, procedures, and claim ceilings into a durable outcome report.",
      "moonbook",
      [terminal],
      [
        "every original outcome criterion is decided in order", "open gaps and residual risks remain visible",
        "the final claim stays within product and constitutional ceilings",
      ],
      "cognitive-maintenance",
    ),
  )
  bindings.push(
    goal_binding(
      "audit",
      "audit-outcome",
      [terminal_contract],
      ["moonbook.outcome-audit.v1"],
      "accepted-knowledge",
      [goal_ref],
      300000,
    ),
  )
  {
    contract_id: "moonsuite.executable-document.v1",
    book_id,
    revision,
    declarations: actions,
    execution_bindings: bindings,
    source_digest: executable_sha256(goal),
    recorded_at,
  }
}

///|
pub async fn compile_goal_file(
  workspace : String,
  book_id : String,
  goal_file : String,
  revision : String,
  recorded_at : String,
) -> GoalCompileRecord {
  let safe_book_id = safe_observation_id(book_id)
  let safe_revision = safe_observation_id(revision)
  let normalized_workspace = @pathx.normalize(workspace)
  let book_root = moonbook_wiki_path(normalized_workspace)
    .join(moonbook_wiki_path("books/\{safe_book_id}"))
    .to_string()
  ensure_bookkeeper_learning_dirs(book_root)
  let goal = @fsx.read_file(goal_file).trim().to_owned()
  if goal.is_empty() {
    fail("approved goal cannot be empty")
  }
  let goal_dir = moonbook_wiki_path(book_root)
    .join(moonbook_wiki_path("flow/goals"))
    .to_string()
  @fsx.make_directory(goal_dir, recursive=true, exists_ok=true)
  let goal_path = goal_dir + "/" + safe_revision + ".txt"
  @fsx.write_to_file(goal_path, goal + "\n", create=0o644)
  let goal_ref = "books/\{safe_book_id}/flow/goals/\{safe_revision}.txt"
  let intent = classify_goal_intent(goal)
  let document = compile_goal_document(
    safe_book_id, safe_revision, goal, goal_ref, recorded_at,
  )
  let graph = compile_executable_document(document)
  let declaration_path = book_root +
    "/flow/declarations/" +
    safe_revision +
    ".json"
  let graph_path = book_root + "/flow/draft-work-graph.json"
  let assumptions_path = book_root + "/flow/goal-compilation.json"
  @fsx.write_to_file(
    declaration_path,
    document.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(graph_path, graph.stringify(indent=2) + "\n", create=0o644)
  @fsx.write_to_file(
    assumptions_path,
    (
      {
        "contract_id": "moonbook.goal-compilation.v1",
        "book_id": safe_book_id,
        "revision": safe_revision,
        "goal_ref": goal_ref,
        "intent_class": intent.id(),
        "authority_inference": "none",
        "physical_boundary": "digital evidence only; physical construction, readiness, launch, and deployment remain prohibited",
        "uncertainty": [
          "intent classification is conservative and must be revised if it materially changes the desired outcome",
        ],
        "recorded_at": recorded_at,
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  {
    contract_id: "moonbook.goal-compile-record.v1",
    goal_path,
    assumptions_path,
    declaration_path,
    graph_path,
    intent_class: intent.id(),
    graph,
  }
}

///|
fn goal_capability_json(
  action : BookkeeperAction,
  binding : ExecutableExecutionBinding,
) -> Json {
  (
    {
      "adapter_id": "\{action.executor_product}-\{binding.operation}-v1",
      "product_id": action.executor_product,
      "protocol": "moonflow.adapter.v1",
      "operations": [binding.operation],
      "authority_classes": [action.requested_authority],
      "input_contracts": binding.input_contracts.to_json(),
      "output_contracts": binding.output_contracts.to_json(),
      "claim_ceiling": binding.required_claim,
      "healthy": true,
      "supports_cancel": true,
      "supports_reconcile": true,
    } : Json)
}

///|
fn goal_driver_json(
  action : BookkeeperAction,
  binding : ExecutableExecutionBinding,
  output_ref : String,
  draft_ref : String,
  worker_executable : String,
  attestor_executable : String,
  model : String,
) -> Json {
  (
    {
      "adapter_id": "\{action.executor_product}-\{binding.operation}-v1",
      "executable": worker_executable,
      "arguments": [
        "flow-adapter", "execute", "--workspace", "{workspace}", "--request", "{request}",
        "--result", "{result}", "--model", model, "--artifact", draft_ref, "--max-trials",
        "3",
      ],
      "draft_output_artifacts": [draft_ref],
      "expected_output_artifacts": [output_ref],
      "attestor_id": "contract-attestor-\{action.executor_product}-v1",
      "attestor_executable": attestor_executable,
      "attestor_arguments": [
        "flow-adapter",
        "attest",
        "--workspace",
        "{workspace}",
        "--request",
        "{request}",
        "--result",
        "{result}",
        "--attestation",
        "{attestation}",
        "--attestor-id",
        "contract-attestor-\{action.executor_product}-v1",
        "--draft",
        "{draft}",
        "--final",
        "{final}",
      ],
      "reviewer_id": "independent-reviewer-\{action.executor_product}-\{binding.operation}",
      "reviewer_executable": worker_executable,
      "reviewer_arguments": [
        "flow-adapter", "review", "--workspace", "{workspace}", "--review-packet",
        "{review}", "--model", model,
      ],
      "review_authority_id": "moonflow-independent-criterion-policy-v1",
      "budget_request": {
        "model_tokens": 50000,
        "tool_calls": 30,
        "storage_bytes": 10485760,
        "attempts": 3,
        "concurrency": 1,
      },
    } : Json)
}

///|
pub fn native_attestor_executable(
  workspace : String,
  product_id : String,
) -> String raise {
  let binary = match product_id {
    "moonwiki" | "moonbook" => "moonbook-flow-attestor"
    "moonclaw" => "moonclaw"
    "moontown" => "moontown-flow-attestor"
    "moonrobo" => "moonrobo-flow-attestor"
    "moonmoon" => "moonmoon-flow-attestor"
    _ => fail("no product-native Flow attestor is registered for \{product_id}")
  }
  @pathx.normalize(workspace) + "/bin/" + binary
}

///|
pub fn goal_artifact_prefixes(book_id : String) -> Array[String] raise {
  let base = "books/" + safe_observation_id(book_id) + "/flow/"
  [base + "drafts", base + "outputs"]
}

///|
pub async fn prepare_goal_unattended_runtime(
  workspace : String,
  book_id : String,
  revision : String,
  gate_executable : String,
  worker_executable : String,
  observer_executable : String,
  model : String,
) -> GoalRuntimeRecord {
  if gate_executable.trim().is_empty() ||
    worker_executable.trim().is_empty() ||
    observer_executable.trim().is_empty() ||
    model.trim().is_empty() {
    fail(
      "unattended runtime requires explicit gate, worker, observer, and model",
    )
  }
  let safe_book_id = safe_observation_id(book_id)
  let safe_revision = safe_observation_id(revision)
  let root = @pathx.normalize(workspace)
  let book_root = root + "/books/" + safe_book_id
  let declaration_path = book_root +
    "/flow/declarations/" +
    safe_revision +
    ".json"
  let document = decode_executable_document(
    @json.parse(@fsx.read_file(declaration_path)),
  )
  let capabilities : Array[Json] = []
  let drivers : Array[Json] = []
  let expected_artifacts : Array[String] = []
  for action in document.declarations {
    guard document.binding_for(action.declaration_id) is Some(binding) else {
      fail("goal runtime lost execution binding: \{action.declaration_id}")
    }
    let output_ref = "books/" +
      safe_book_id +
      "/flow/outputs/" +
      action.declaration_id +
      ".json"
    let draft_ref = "books/" +
      safe_book_id +
      "/flow/drafts/" +
      action.declaration_id +
      ".json"
    let attestor_executable = native_attestor_executable(
      workspace,
      action.executor_product,
    )
    if !@suite_fsx.exists_as_file(attestor_executable) {
      fail(
        "missing product-native Flow attestor: \{attestor_executable}; install the Moon Suite runtime before preparing unattended work",
      )
    }
    capabilities.push(goal_capability_json(action, binding))
    drivers.push(
      goal_driver_json(
        action, binding, output_ref, draft_ref, worker_executable, attestor_executable,
        model,
      ),
    )
    expected_artifacts.push(output_ref)
  }
  let runtime_root = book_root + "/flow/runtime"
  @fsx.make_directory(runtime_root, recursive=true, exists_ok=true)
  let capabilities_path = runtime_root + "/capabilities.json"
  let manifest_path = runtime_root + "/unattended-manifest.json"
  let review_policy_path = runtime_root + "/review-policy.json"
  let envelope_request_path = runtime_root + "/autonomy-request.json"
  let usage_path = runtime_root + "/usage.json"
  @fsx.write_to_file(
    capabilities_path,
    Json::array(capabilities).stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    usage_path,
    (
      {
        "model_tokens": 0,
        "tool_calls": 0,
        "storage_bytes": 0,
        "attempts": 0,
        "concurrency": 0,
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let grant_products : Array[String] = []
  let grants : Array[Json] = []
  for action in document.declarations {
    if grant_products.contains(action.executor_product) {
      continue
    }
    grant_products.push(action.executor_product)
    let operations : Array[String] = []
    let mut authority = @pipeline.AuthorityClass::Observe
    let mut claim = @pipeline.ClaimClass::Observation
    for candidate in document.declarations {
      if candidate.executor_product == action.executor_product {
        guard document.binding_for(candidate.declaration_id) is Some(binding) else {
          continue
        }
        if !operations.contains(binding.operation) {
          operations.push(binding.operation)
        }
        let requested = @pipeline.authority_class_from_id(
          candidate.requested_authority,
        )
        if !authority.allows(requested) {
          authority = requested
        }
        let required = @pipeline.claim_class_from_id(binding.required_claim)
        if !claim.allows(required) {
          claim = required
        }
      }
    }
    grants.push(
      (
        {
          "product_id": action.executor_product,
          "operations": operations.to_json(),
          "authority_ceiling": authority.id(),
          "claim_ceiling": claim.id(),
          "artifact_prefixes": goal_artifact_prefixes(safe_book_id).to_json(),
        } : Json),
    )
  }
  @fsx.write_to_file(
    envelope_request_path,
    (
      {
        "contract_id": "moonbook.autonomy-request.v1",
        "goal_ref": "books/" +
        safe_book_id +
        "/flow/goals/" +
        safe_revision +
        ".txt",
        "source_digest": document.source_digest,
        "mode": "unattended-digital",
        "grants": Json::array(grants),
        "budget": {
          "model_tokens": document.declarations.length() * 50000,
          "tool_calls": document.declarations.length() * 30,
          "storage_bytes": document.declarations.length() * 10485760,
          "attempts": document.declarations.length() * 3,
          "concurrency": 1,
        },
        "external_effects_allowed": false,
        "physical_effects_allowed": false,
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    manifest_path,
    (
      {
        "contract_id": "moonflow.unattended-manifest.v3",
        "gate_executable": gate_executable,
        "gate_arguments": ["suite", "autonomy-check"],
        "max_cycles": document.declarations.length() * 4 + 4,
        "drivers": Json::array(drivers),
        "observer_executable": observer_executable,
        "observer_arguments": [
          "bookkeeper", "reconcile-run", "{workspace}/books/{book_id}", "{projection}",
          "{recorded_at}",
        ],
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    review_policy_path,
    (
      {
        "contract_id": "moonbook.review-policy.v1",
        "reviewer_independence": "required",
        "criterion_order": "immutable",
        "evidence_identity": "digest-verified",
        "self_review": "prohibited",
        "unsupported_claim": "reduce-or-reject",
        "physical_readiness": "prohibited",
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  {
    contract_id: "moonbook.goal-runtime-record.v1",
    capabilities_path,
    manifest_path,
    review_policy_path,
    envelope_request_path,
    expected_artifacts,
  }
}
