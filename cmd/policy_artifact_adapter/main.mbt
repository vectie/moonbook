///|
async fn main {
  let args = @env.args()[1:]
  let result = match args {
    ["capability"] => @policy_artifact_store.capability()
    ["read", root] => @policy_artifact_store.read_journal(root).to_json()
    ["append-local-fixture", root, input] => {
      let batch : @policy_artifact_store.ArtifactBatch = @json.from_json(
        @json.parse(@fs.read_file(input).text()),
      )
      @policy_artifact_store.append_batch(root, batch).to_json()
    }
    _ =>
      fail(
        "usage: policy_artifact_adapter capability | read ROOT | append-local-fixture ROOT REQUEST.json",
      )
  }
  println(result.stringify())
}
