///|
#cfg(target="js")
test "ordinary Bookkeeper journey exposes one next action and recovery" {
  let empty = bookkeeper_journey_step_for(
    false, false, false, "ingress", false, "",
  )
  assert_eq(empty.position, 1)
  assert_eq(empty.action, "replay")
  let selection = bookkeeper_journey_step_for(
    true, false, true, "ingress", false, "",
  )
  assert_eq(selection.action, "select")
  let blocked = bookkeeper_journey_step_for(
    true, true, false, "ingress", false, "",
  )
  assert_true(blocked.blocked)
  assert_eq(blocked.action, "install-authority")
  let prepare = bookkeeper_journey_step_for(
    true, true, true, "ingress", false, "",
  )
  assert_eq(prepare.action, "prepare-review")
  let submit = bookkeeper_journey_step_for(
    true, true, true, "review", false, "",
  )
  assert_eq(submit.action, "submit-review")
  let verify = bookkeeper_journey_step_for(
    true, true, true, "review", false, "Mutation accepted.",
  )
  assert_eq(verify.position, 4)
  assert_eq(verify.action, "replay")
}
