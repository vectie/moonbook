///|
test "MoonWiki adapter stays inside evidence authority" {
  guard @moonbook.moonwiki_moonflow_adapter_capability_json()
    is Object(capability) else {
    fail("expected MoonWiki adapter capability")
  }
  assert_true(capability["protocol"] == Json::string("moonflow.adapter.v1"))
  assert_true(capability["product_id"] == Json::string("moonwiki"))
  assert_true(capability["supports_reconcile"] == Json::boolean(true))
  assert_true(
    capability["accepted_truth_requires_review"] == Json::boolean(true),
  )
  guard capability["operations"] is Array(operations) else {
    fail("expected MoonWiki operations")
  }
  assert_true(operations.contains(Json::string("track-freshness")))
  assert_true(operations.contains(Json::string("review-claims")))
  assert_false(operations.contains(Json::string("execute-experiment")))
  assert_false(operations.contains(Json::string("change-code")))
  guard capability["authority_classes"] is Array(authorities) else {
    fail("expected MoonWiki authorities")
  }
  assert_true(authorities.contains(Json::string("observe")))
  assert_false(authorities.contains(Json::string("sandbox-execution")))
  assert_false(authorities.contains(Json::string("external-effect")))
  assert_false(authorities.contains(Json::string("physical-effect")))
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
