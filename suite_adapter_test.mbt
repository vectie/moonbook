///|
test "MoonWiki legacy product alias is deprecated and non-callable" {
  guard @moonbook.moonwiki_moonflow_adapter_capability_json()
    is Object(capability) else {
    fail("expected MoonWiki compatibility metadata")
  }
  assert_true(capability["legacy_product_id"] == Json::string("moonwiki"))
  assert_true(capability["canonical_product_id"] == Json::string("moonbook"))
  assert_true(capability["functionality"] == Json::string("moonwiki"))
  assert_true(capability["callable"] == Json::boolean(false))
  assert_true(capability["deprecated"] == Json::boolean(true))
  assert_true(capability["operations"] == ([] : Array[Json]).to_json())
  guard capability.get("product_id") is None else {
    fail("deprecated MoonWiki alias must not advertise a live product_id")
  }
  assert_true(
    capability["replacement_operation_ref"] ==
    Json::string("moonbook/wiki.requirements.prepare@0.1.0"),
  )
}

///|
test "MoonBook reconciles execution without becoming the scheduler" {
  guard @moonbook.moonbook_moonflow_adapter_capability_json()
    is Object(capability) else {
    fail("expected MoonBook adapter capability")
  }
  assert_true(capability["product_id"] == Json::string("moonbook"))
  assert_true(capability["execution_state_owner"] == Json::string("moonflow"))
  assert_true(capability["supports_reconcile"] == Json::boolean(true))
  guard capability["operations"] is Array(operations) else {
    fail("expected MoonBook operations")
  }
  assert_true(operations.contains(Json::string("reconcile-flow-outcome")))
  assert_false(operations.contains(Json::string("schedule-work")))
  guard capability["authority_classes"] is Array(authorities) else {
    fail("expected MoonBook authorities")
  }
  assert_false(authorities.contains(Json::string("sandbox-execution")))
  assert_false(authorities.contains(Json::string("external-effect")))
}

///|
test "MoonCode draft delivery capability is generic and cannot execute" {
  guard @moonbook.moonbook_mooncode_draft_delivery_capability_json()
    is Object(capability) else {
    fail("expected MoonCode draft delivery capability")
  }
  assert_true(
    capability["adapter_id"] == Json::string("moonbook-mooncode-draft-delivery"),
  )
  assert_true(
    capability["operations"] == ["deliver-reviewed-mooncode-draft"].to_json(),
  )
  assert_true(
    capability["authority_classes"] == ["workspace-mutation"].to_json(),
  )
  assert_true(capability["claim_ceiling"] == Json::string("digital-artifact"))
  assert_true(capability["supports_reconcile"] == Json::boolean(true))
  assert_true(capability["confirmation_allowed"] == Json::boolean(false))
  assert_true(capability["execution_allowed"] == Json::boolean(false))
  assert_true(capability["external_effect_allowed"] == Json::boolean(false))
}

///|
test "MoonBook publishes exact MoonFlow v2 product-owned capability truth" {
  guard @moonbook.moonbook_moonflow_adapter_declaration_json()
    is Object(declaration) else {
    fail("expected MoonBook adapter declaration")
  }
  assert_true(
    declaration["contract_id"] ==
    Json::string("moonflow.adapter-declaration.v1"),
  )
  assert_true(declaration["protocol"] == Json::string("moonflow.adapter.v2"))
  assert_true(declaration["product_id"] == Json::string("moonbook"))
  guard declaration["operations"]
    is [Object(outcome), Object(submission), Object(requirements)] else {
    fail("expected three exact MoonBook operation declarations")
  }
  assert_true(
    outcome["operation_id"] == Json::string("bookkeeper.outcome.close"),
  )
  assert_true(outcome["supports_reconcile"] == Json::boolean(true))
  assert_true(outcome["supports_cancel"] == Json::boolean(false))
  assert_true(
    submission["operation_id"] ==
    Json::string("bookkeeper.outcome.submit"),
  )
  assert_true(submission["supports_reconcile"] == Json::boolean(true))
  assert_true(submission["supports_cancel"] == Json::boolean(false))
  assert_true(
    requirements["operation_id"] == Json::string("wiki.requirements.prepare"),
  )
  assert_true(requirements["supports_reconcile"] == Json::boolean(true))
  assert_true(requirements["supports_cancel"] == Json::boolean(false))
  assert_true(
    @moonbook.moonbook_outcome_closure_operation_ref() ==
    "moonbook/bookkeeper.outcome.close@0.1.0",
  )
  assert_true(
    @moonbook.moonbook_outcome_submission_operation_ref() ==
    "moonbook/bookkeeper.outcome.submit@0.1.0",
  )
  assert_true(
    @moonbook.moonbook_requirements_prepare_operation_ref() ==
    "moonbook/wiki.requirements.prepare@0.1.0",
  )
}

///|
test "MoonBook health attestation is evidence-bound and expiring" {
  let digest = "sha256:" + "a".repeat(64)
  guard @moonbook.moonbook_moonflow_adapter_health_json(
      checked_at="2026-07-31T00:00:00Z",
      valid_until="2026-07-31T00:05:00Z",
      evidence_ref="health/moonbook-outcome-close.json",
      evidence_digest=digest,
    )
    is Object(health) else {
    fail("expected MoonBook adapter health")
  }
  assert_true(
    health["contract_id"] == Json::string("moonflow.adapter-health.v1"),
  )
  assert_true(health["status"] == Json::string("healthy"))
  assert_true(
    health["operation_refs"] ==
    [
      "moonbook/bookkeeper.outcome.close@0.1.0",
      "moonbook/bookkeeper.outcome.submit@0.1.0",
      "moonbook/wiki.requirements.prepare@0.1.0",
    ].to_json(),
  )
  try
    @moonbook.moonbook_moonflow_adapter_health_json(
      checked_at="2026-07-31T00:05:00Z",
      valid_until="2026-07-31T00:00:00Z",
      evidence_ref="health/moonbook-outcome-close.json",
      evidence_digest=digest,
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("non-expiring health evidence must fail closed")
  }
}
