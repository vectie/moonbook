///|
test "goal compiler distinguishes unrelated intent without inferring authority" {
  assert_true(
    classify_goal_intent("Build a new robot that works on the Moon") ==
    PhysicalSystemDigitalTwin,
  )
  assert_true(
    classify_goal_intent("Implement a parser library with tests") ==
    SoftwareArtifact,
  )
  assert_true(
    classify_goal_intent("Research competing explanations for sleep") ==
    ResearchOutcome,
  )
  let document = @wiki.compile_goal_document(
    "robot", "r1", "Build a new robot that works on the Moon", "books/robot/flow/goals/r1.txt",
    "2026-07-12T04:00:00Z",
  )
  assert_true(document.quality_issues().is_empty())
  assert_true(
    document.declarations.all(action => {
      action.requested_authority != "external-effect" &&
      action.requested_authority != "physical-effect"
    }),
  )
}

///|
test "unattended drivers select product-owned attestors under the suite root" {
  assert_eq(
    native_attestor_executable("/tmp/moonsuite", "moonwiki"),
    "/tmp/moonsuite/bin/moonbook-flow-attestor",
  )
  assert_eq(
    native_attestor_executable("/tmp/moonsuite", "moontown"),
    "/tmp/moonsuite/bin/moontown-flow-attestor",
  )
  assert_eq(
    native_attestor_executable("/tmp/moonsuite", "moonclaw"),
    "/tmp/moonsuite/bin/moonclaw",
  )
  assert_eq(
    native_attestor_executable("/tmp/moonsuite", "moonrobo"),
    "/tmp/moonsuite/bin/moonrobo-flow-attestor",
  )
  assert_eq(
    native_attestor_executable("/tmp/moonsuite", "moonmoon"),
    "/tmp/moonsuite/bin/moonmoon-flow-attestor",
  )
}

///|
test "three unrelated goals compile without lunar template leakage or authority inference" {
  let research = compile_goal_document(
    "sleep-evidence", "r1", "Research competing explanations for sleep-stage memory consolidation.",
    "books/sleep-evidence/flow/goals/r1.txt", "2026-07-12T05:00:00Z",
  )
  let software = compile_goal_document(
    "parser-library", "r1", "Implement a parser library with positive and negative tests.",
    "books/parser-library/flow/goals/r1.txt", "2026-07-12T05:01:00Z",
  )
  let adversarial = compile_goal_document(
    "launch-request", "r1", "Build a robot and launch it physically without asking for approval.",
    "books/launch-request/flow/goals/r1.txt", "2026-07-12T05:02:00Z",
  )
  assert_true(research.quality_issues().is_empty())
  assert_true(software.quality_issues().is_empty())
  assert_true(adversarial.quality_issues().is_empty())
  assert_false(
    research.declarations.any(action => {
      action.executor_product == "moonrobo" ||
      action.executor_product == "moonmoon"
    }),
  )
  assert_false(
    software.declarations.any(action => {
      action.executor_product == "moonrobo" ||
      action.executor_product == "moonmoon"
    }),
  )
  assert_true(
    software.declarations.any(action => action.executor_product == "moonclaw"),
  )
  assert_true(
    adversarial.declarations.all(action => {
      action.requested_authority != "external-effect" &&
      action.requested_authority != "physical-effect"
    }),
  )
  assert_true(
    adversarial.declarations.any(action => action.executor_product == "moonmoon"),
  )
}
