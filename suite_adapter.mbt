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
    ],
    "authority_classes": [
      "observe", "cognitive-maintenance", "workspace-mutation",
    ],
    "supports_cancel": false,
    "supports_reconcile": true,
    "receipt_contracts": [
      "moonbook.executable-document.v1", "moonbook.bookkeeper-reflection.v1", "moonbook.acceptance-review.v1",
    ],
    "execution_state_owner": "moonflow",
    "accepted_truth_requires_review": true,
    "external_effect_forbidden": true,
  }
}
