///|
async test "typed primary stays first while dependency evidence extends the digest" {
  let root = "/tmp/moonbook-moonflow-input-artifacts-v1"
  @fsx.make_directory(root + "/inputs", recursive=true, exists_ok=true)
  @fsx.make_directory(root + "/evidence", recursive=true, exists_ok=true)
  @fsx.write_to_file(
    root + "/inputs/request.json",
    "{\"contract_id\":\"moonbook.wiki.requirements_prepare.v1\"}\n",
    create=0o600,
  )
  @fsx.write_to_file(
    root + "/evidence/brief.json",
    "{\"digest_bound\":true}\n",
    create=0o600,
  )
  let inputs = ["inputs/request.json", "evidence/brief.json"]
  assert_eq(
    primary_input_artifact(inputs, "requirements preparation"),
    "inputs/request.json",
  )
  let aggregate = artifact_set_digest(root, inputs)
  assert_true(aggregate.has_prefix("sha256:"))
  assert_eq(aggregate.length(), 71)
}
