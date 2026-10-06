///|
async test "public lesson query starts empty" {
  let root = @fs.tmpdir(prefix="moonbook-public-lesson-")
  let query : @bookkeeper_store.OutcomeLessonQuery = {
    contract_version: "moonbook.outcome-lesson-query.v1",
    target_task: {
      record_id: "next-task",
      record_version: "1",
      record_digest: "sha256:" + "c".repeat(64),
    },
    conditions: [{ key: "decision_kind", value: "vendor-comparison", }],
  }
  assert_true(
    @bookkeeper_store.retrieve_outcome_lessons(root, query)
    is { "matches": [], "activation_authorized": false, .. },
  )
}
