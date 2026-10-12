///|
async test "public lesson browser starts empty without a target task or filesystem mutation" {
  let root = @fs.tmpdir(prefix="moonbook-public-browser-")
  let query : @bookkeeper_store.OutcomeLessonBrowseQuery = {
    contract_version: "moonbook.outcome-lesson-browse-query.v1",
    text: "",
  }
  assert_true(
    @bookkeeper_store.browse_outcome_lessons(root, query)
    is {
      "contract_version": "moonbook.outcome-lesson-browser.v1",
      "lessons": [],
      "exclusions": [],
      "activation_authorized": false,
      "external_side_effects_applied": false,
      ..
    },
  )
  assert_false(@fs.exists(root + "/.moonbook"))
}
