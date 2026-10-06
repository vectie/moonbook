///|
async test "wiki native status production command dispatch never initializes a workspace" {
  let root = @fs.tmpdir(prefix="moonbook-review-cli-readonly-")
  run_wiki_review([
    "native-status", root, "missing-work", "bad-request", "bad-payload", "result",
  ])
  assert_eq(@fsx.list_directory(root).length(), 0)
  run_wiki_review([
    "native-status",
    root + "/absent",
    "missing-work",
    "bad-request",
    "bad-payload",
    "result",
  ])
  assert_true(!@fsx.exists(root + "/absent"))
}
