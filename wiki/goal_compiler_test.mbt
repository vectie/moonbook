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
    native_attestor_executable("/tmp/moonsuite", "moonrobo"),
    "/tmp/moonsuite/bin/moonrobo-flow-attestor",
  )
  assert_eq(
    native_attestor_executable("/tmp/moonsuite", "moonmoon"),
    "/tmp/moonsuite/bin/moonmoon-flow-attestor",
  )
}
