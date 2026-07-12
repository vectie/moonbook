///|
async test "MoonWiki attests traceable research and preserves gaps" {
  let workspace = "/tmp/moonbook-flow-attestor-research-test"
  write_json(scoped_path(workspace, "runtime/request.json"), {
    "request_id": "request-research",
    "book_id": "lunar-robot",
    "product_id": "moonwiki",
    "operation": "research-goal",
  })
  write_json(scoped_path(workspace, "runtime/result.json"), {
    "result_id": "result-research",
    "output_digest": "sha256:research",
  })
  write_json(scoped_path(workspace, "drafts/research.json"), {
    "contract_id": "moonwiki.evidence-bundle.v1",
    "product_id": "moonwiki",
    "sources": [
      {
        "source_id": "src-thermal",
        "title": "Lunar thermal environment",
        "locator": "https://example.invalid/thermal",
        "authority": "primary mission archive",
        "accessed_at": "2026-07-12T00:00:00Z",
      },
    ],
    "claims": [
      {
        "statement": "A polar traverse requires explicit thermal bounds.",
        "source_refs": ["src-thermal"],
        "confidence": 0.9,
      },
    ],
    "contradictions": [
      { "status": "unresolved", "statement": "Local illumination varies." },
    ],
    "limitations": ["No hardware calibration evidence is available."],
    "remaining_information_gaps": ["Calibrated actuator efficiency is unknown."],
    "query_lineage": ["goal -> thermal environment -> polar illumination"],
    "stopping_rationale": "The digital concept can proceed while calibration remains blocked.",
  })
  attest(
    workspace, "runtime/request.json", "runtime/result.json", "runtime/attestation.json",
    "moonbook-native-attestor-v1", "drafts/research.json", "outputs/research.json",
  )
  let text = read_json(scoped_path(workspace, "outputs/research.json")).stringify()
  assert_true(text.contains("\"claims_traceable\":true"))
  assert_true(text.contains("Calibrated actuator efficiency is unknown"))
  assert_true(text.contains("\"physical_readiness\":false"))
}

///|
async test "MoonBook attests ordered criteria and creates metacognitive reflections" {
  let workspace = "/tmp/moonbook-flow-attestor-audit-test"
  write_json(scoped_path(workspace, "runtime/request.json"), {
    "request_id": "request-audit",
    "book_id": "lunar-robot",
    "product_id": "moonbook",
    "operation": "audit-outcome",
    "acceptance_criteria": [
      "every original outcome criterion is decided in order", "open gaps and residual risks remain visible",
      "the final claim stays within product and constitutional ceilings",
    ],
  })
  write_json(scoped_path(workspace, "runtime/result.json"), {
    "result_id": "result-audit",
    "output_digest": "sha256:audit",
  })
  write_json(scoped_path(workspace, "drafts/audit.json"), {
    "contract_id": "moonbook.outcome-audit.v1",
    "product_id": "moonbook",
    "criterion_decisions": [
      {
        "criterion": "every original outcome criterion is decided in order",
        "decision": "accepted",
        "evidence_refs": ["outputs/simulate.json"],
        "blocker": "",
        "rationale": "All three immutable audit criteria are represented in order.",
      },
      {
        "criterion": "open gaps and residual risks remain visible",
        "decision": "accepted",
        "evidence_refs": ["outputs/research.json"],
        "blocker": "",
        "rationale": "Calibration and environment gaps remain explicit.",
      },
      {
        "criterion": "the final claim stays within product and constitutional ceilings",
        "decision": "accepted",
        "evidence_refs": ["outputs/simulate.json"],
        "blocker": "",
        "rationale": "The claim is limited to scenario-qualified evidence.",
      },
    ],
    "open_gaps": [
      {
        "kind": "information-gap",
        "question": "What calibrated thermal data is still required?",
        "resolution_criteria": "A traceable chamber-test receipt is linked.",
      },
      {
        "kind": "cognition-gap",
        "question": "How does thermal uncertainty change duty cycle?",
        "resolution_criteria": "The consequence map is independently reviewed.",
      },
      {
        "kind": "execution-gap",
        "question": "What physical validation remains prohibited?",
        "resolution_criteria": "A separately authorized hardware campaign exists.",
      },
    ],
    "residual_risks": ["The digital energy model is not hardware calibrated."],
    "final_claim": "The digital robot is scenario-qualified only.",
    "claim_ceiling": "scenario-qualified",
    "recorded_at": "2026-07-12T00:00:00Z",
  })
  attest(
    workspace, "runtime/request.json", "runtime/result.json", "runtime/attestation.json",
    "moonbook-native-attestor-v1", "drafts/audit.json", "outputs/audit.json",
  )
  let text = read_json(scoped_path(workspace, "outputs/audit.json")).stringify()
  assert_true(text.contains("\"metacognitive_reflections\""))
  assert_true(text.contains("\"scenario-qualified\""))
  assert_true(text.contains("\"execution-gap\""))
}
