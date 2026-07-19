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
    "web_provenance": [
      {
        "tool": "web_search",
        "arguments": { "query": "lunar thermal environment mission archive" },
        "succeeded": true,
        "event_digest": "sha256:search-event",
      },
      {
        "tool": "web_fetch",
        "arguments": { "url": "https://example.invalid/thermal" },
        "succeeded": true,
        "event_digest": "sha256:fetch-event",
      },
    ],
  })
  attest(
    workspace, "runtime/request.json", "runtime/result.json", "runtime/attestation.json",
    "moonbook-native-attestor-v1", "drafts/research.json", "outputs/research.json",
  )
  let text = read_json(scoped_path(workspace, "outputs/research.json")).stringify()
  assert_true(text.contains("\"claims_traceable\":true"))
  assert_true(text.contains("\"tool_provenance_verified\":true"))
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

///|
async test "MoonBook attests only an exact inert MoonCode draft receipt" {
  let workspace = "/tmp/moonbook-flow-attestor-mooncode-draft-test"
  let delivery_request : @bookkeeper_store.MoonCodeDraftDeliveryRequest = {
    contract_version: @bookkeeper_store.mooncode_draft_delivery_contract_version(),
    delivery_id: "delivery-one",
    delivery_version: "v1",
    envelope: {
      record_id: "envelope-one",
      record_version: "v1",
      record_digest: "sha256:envelope",
    },
    expected_envelope_digest: "sha256:envelope",
  }
  write_json(
    scoped_path(workspace, "inputs/delivery.json"),
    delivery_request.to_json(),
  )
  write_json(scoped_path(workspace, "runtime/request.json"), {
    "request_id": "request-delivery",
    "book_id": "bookkeeper",
    "product_id": "moonbook",
    "operation": "deliver-reviewed-mooncode-draft",
    "requested_authority": "workspace-mutation",
    "acceptance_criteria": ["the MoonClaw proposal remains Draft"],
    "input_contracts": [
      @bookkeeper_store.mooncode_draft_delivery_contract_version(),
    ],
    "output_contracts": [
      @bookkeeper_store.mooncode_draft_delivery_contract_version(),
    ],
    "input_artifacts": ["inputs/delivery.json"],
  })
  write_json(scoped_path(workspace, "runtime/result.json"), {
    "result_id": "result-delivery",
    "output_digest": "sha256:draft",
  })
  let mut receipt : @bookkeeper_store.MoonCodeDraftImportReceipt = {
    contract_version: @bookkeeper_store.mooncode_draft_delivery_contract_version(),
    receipt: {
      record_id: "mooncode-draft-import:delivery-one",
      record_version: "v1",
      record_digest: "pending",
    },
    request: delivery_request,
    request_digest: @bookkeeper_store.bookkeeper_payload_digest(
      delivery_request.to_json(),
    ),
    adapter_id: "moonbook-mooncode-draft-delivery",
    adapter_version: "v1",
    envelope: delivery_request.envelope,
    work_order: {
      record_id: "work-order-one",
      record_version: "v1",
      record_digest: "sha256:work-order",
    },
    packet_digest: "sha256:packet",
    moonclaw_proposal_id: "proposal-one",
    moonclaw_status: "Draft",
    moonclaw_output_digest: "sha256:moonclaw-output",
    confirmed: false,
    executed: false,
    external_effect_authorized: false,
    side_effects_applied: false,
  }
  let core : Json = {
    "contract_version": receipt.contract_version,
    "request": receipt.request.to_json(),
    "request_digest": receipt.request_digest,
    "adapter_id": receipt.adapter_id,
    "adapter_version": receipt.adapter_version,
    "envelope": receipt.envelope.to_json(),
    "work_order": receipt.work_order.to_json(),
    "packet_digest": receipt.packet_digest,
    "moonclaw_proposal_id": receipt.moonclaw_proposal_id,
    "moonclaw_status": receipt.moonclaw_status,
    "moonclaw_output_digest": receipt.moonclaw_output_digest,
    "confirmed": false,
    "executed": false,
    "external_effect_authorized": false,
    "side_effects_applied": false,
  }
  receipt = {
    ..receipt,
    receipt: {
      ..receipt.receipt,
      record_digest: @bookkeeper_store.bookkeeper_payload_digest(core),
    },
  }
  write_json(scoped_path(workspace, "drafts/delivery.json"), receipt.to_json())
  attest(
    workspace, "runtime/request.json", "runtime/result.json", "runtime/attestation.json",
    "moonbook-native-attestor-v1", "drafts/delivery.json", "outputs/delivery.json",
  )
  let final_output = read_json(scoped_path(workspace, "outputs/delivery.json"))
  assert_true(final_output == receipt.to_json())
  assert_true(
    read_json(scoped_path(workspace, "runtime/attestation.json"))
    .stringify()
    .contains("\"accepted\":true"),
  )
}
