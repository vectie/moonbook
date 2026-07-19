///|
/// Describe the bounded MoonFlow operations owned by MoonWiki.
///
/// MoonWiki can observe sources and maintain evidence inside a workspace, but
/// it cannot schedule work, change code, execute experiments, or create an
/// external/physical effect.
pub fn moonwiki_moonflow_adapter_capability_json() -> Json {
  {
    "adapter_id": "moonwiki-v1",
    "product_id": "moonwiki",
    "protocol": "moonflow.adapter.v1",
    "operations": [
      "discover-sources", "ingest-evidence", "query-evidence", "review-claims", "track-freshness",
      "build-evidence-bundle", "reconcile-evidence",
    ],
    "authority_classes": [
      "observe", "cognitive-maintenance", "workspace-mutation",
    ],
    "supports_cancel": false,
    "supports_reconcile": true,
    "receipt_contracts": [
      "moonwiki.source-envelope.v1", "moonwiki.evidence-bundle.v1", "moonwiki.review-receipt.v1",
      "moonwiki.freshness-receipt.v1",
    ],
    "accepted_truth_requires_review": true,
    "code_changes_forbidden": true,
    "experiment_execution_forbidden": true,
  }
}

///|
/// Describe MoonBook's executable-document and reconciliation boundary.
/// MoonBook owns durable intent and reviewed cognition, while MoonFlow owns
/// scheduling and execution state.
pub fn moonbook_moonflow_adapter_capability_json() -> Json {
  {
    "adapter_id": "moonbook-v1",
    "product_id": "moonbook",
    "protocol": "moonflow.adapter.v1",
    "operations": [
      "compile-executable-declaration", "inspect-declaration-revision", "reconcile-flow-outcome",
      "reflect-on-outcome", "propose-memory-promotion", "record-acceptance-review",
      "deliver-reviewed-mooncode-draft",
    ],
    "authority_classes": [
      "observe", "cognitive-maintenance", "workspace-mutation",
    ],
    "supports_cancel": false,
    "supports_reconcile": true,
    "receipt_contracts": [
      "moonbook.executable-document.v1", "moonbook.bookkeeper-reflection.v1", "moonbook.acceptance-review.v1",
      "moonbook.bookkeeper.mooncode-draft-delivery.v1",
    ],
    "execution_state_owner": "moonflow",
    "accepted_truth_requires_review": true,
    "external_effect_forbidden": true,
    "mooncode_draft_delivery": {
      "adapter_id": "moonbook-mooncode-draft-delivery",
      "adapter_version": "v1",
      "agent_runtime": "moonclaw",
      "implementation_surface": "mooncode",
      "confirmation_allowed": false,
      "execution_allowed": false,
      "external_effect_allowed": false,
    },
  }
}

///|
/// Generic MoonFlow capability for the one product-owned mutation that turns
/// an exact reviewed Bookkeeper egress into an inert MoonClaw proposal draft.
pub fn moonbook_mooncode_draft_delivery_capability_json() -> Json {
  {
    "adapter_id": "moonbook-mooncode-draft-delivery",
    "product_id": "moonbook",
    "protocol": "moonflow.adapter.v1",
    "operations": ["deliver-reviewed-mooncode-draft"],
    "authority_classes": ["workspace-mutation"],
    "input_contracts": ["moonbook.bookkeeper.mooncode-draft-delivery.v1"],
    "output_contracts": ["moonbook.bookkeeper.mooncode-draft-delivery.v1"],
    "claim_ceiling": "digital-artifact",
    "healthy": true,
    "supports_cancel": false,
    "supports_reconcile": true,
    "agent_runtime": "moonclaw",
    "implementation_surface": "mooncode",
    "confirmation_allowed": false,
    "execution_allowed": false,
    "external_effect_allowed": false,
  }
}
