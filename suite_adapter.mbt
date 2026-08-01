///|
/// Historical alias metadata for callers that once treated MoonWiki as a
/// product. MoonWiki is functionality inside MoonBook and this alias is
/// deliberately non-callable.
pub fn moonwiki_moonflow_adapter_capability_json() -> Json {
  {
    "contract_id": "moonsuite.capability-alias.v1",
    "legacy_product_id": "moonwiki",
    "canonical_product_id": "moonbook",
    "functionality": "moonwiki",
    "callable": false,
    "deprecated": true,
    "operations": [],
    "replacement_operation_ref": "moonbook/wiki.requirements.prepare@0.1.0",
    "reason": "MoonWiki is functionality inside MoonBook, never a product or agent runtime.",
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

///|
/// Installed MoonBook pack version used by MoonFlow capability truth.
pub fn moonbook_capability_pack_version() -> String {
  "0.1.0"
}

///|
/// Canonical product-owned operation replacing the aspirational canvas verb
/// `bookkeeper.close-loop`.
pub fn moonbook_outcome_closure_operation_id() -> String {
  "bookkeeper.outcome.close"
}

///|
pub fn moonbook_outcome_closure_operation_ref() -> String {
  "moonbook/" +
  moonbook_outcome_closure_operation_id() +
  "@" +
  moonbook_capability_pack_version()
}

///|
/// Canonical MoonDesk/MoonTown intake and replay alias for the exact
/// ProductOutcomeSubmission emitted by MoonClaw. It always enters MoonBook's
/// existing named-human gates.
pub fn moonbook_outcome_submission_operation_id() -> String {
  "bookkeeper.outcome.submit"
}

///|
pub fn moonbook_outcome_submission_operation_ref() -> String {
  "moonbook/" +
  moonbook_outcome_submission_operation_id() +
  "@" +
  moonbook_capability_pack_version()
}

///|
/// Product-owned operation for deterministic, review-pending MoonWiki
/// requirements preparation.
pub fn moonbook_requirements_prepare_operation_id() -> String {
  "wiki.requirements.prepare"
}

///|
pub fn moonbook_requirements_prepare_operation_ref() -> String {
  "moonbook/" +
  moonbook_requirements_prepare_operation_id() +
  "@" +
  moonbook_capability_pack_version()
}

///|
/// Host-binding declaration consumed by MoonFlow capability catalog
/// compilation. It deliberately contains no health claim.
pub fn moonbook_moonflow_adapter_declaration_json() -> Json {
  {
    "contract_id": "moonflow.adapter-declaration.v1",
    "adapter_id": "moonbook-pack-local-v1",
    "product_id": "moonbook",
    "pack_id": "moonbook",
    "pack_version": moonbook_capability_pack_version(),
    "protocol": "moonflow.adapter.v2",
    "operations": [
      {
        "operation_id": moonbook_outcome_closure_operation_id(),
        "claim_ceiling": "digital-artifact",
        "supports_cancel": false,
        "supports_reconcile": true,
      },
      {
        "operation_id": moonbook_outcome_submission_operation_id(),
        "claim_ceiling": "digital-artifact",
        "supports_cancel": false,
        "supports_reconcile": true,
      },
      {
        "operation_id": moonbook_requirements_prepare_operation_id(),
        "claim_ceiling": "digital-artifact",
        "supports_cancel": false,
        "supports_reconcile": true,
      },
    ],
  }
}

///|
fn valid_sha256_identity(value : String) -> Bool {
  value.length() == 71 &&
  value.has_prefix("sha256:") &&
  value[7:].all(fn(char) {
    (char >= '0' && char <= '9') || (char >= 'a' && char <= 'f')
  })
}

///|
/// Build a short-lived health attestation from host-verified evidence. A
/// repository checkout cannot truthfully publish a permanent healthy file, so
/// callers must supply the observation window and exact evidence identity.
pub fn moonbook_moonflow_adapter_health_json(
  checked_at~ : String,
  valid_until~ : String,
  evidence_ref~ : String,
  evidence_digest~ : String,
) -> Json raise {
  if checked_at.is_blank() ||
    valid_until.is_blank() ||
    checked_at >= valid_until ||
    evidence_ref.is_blank() ||
    !valid_sha256_identity(evidence_digest) {
    fail("MoonBook adapter health requires a valid window and SHA-256 evidence")
  }
  {
    "contract_id": "moonflow.adapter-health.v1",
    "adapter_id": "moonbook-pack-local-v1",
    "product_id": "moonbook",
    "pack_id": "moonbook",
    "pack_version": moonbook_capability_pack_version(),
    "protocol": "moonflow.adapter.v2",
    "status": "healthy",
    "checked_at": checked_at,
    "valid_until": valid_until,
    "operation_refs": [
      moonbook_outcome_closure_operation_ref(),
      moonbook_outcome_submission_operation_ref(),
      moonbook_requirements_prepare_operation_ref(),
    ],
    "evidence_ref": evidence_ref,
    "evidence_digest": evidence_digest,
  }
}
