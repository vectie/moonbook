///|
fn main raise {
  let args = @env.args()[1:]
  let output = match args {
    [] | ["declaration"] =>
      @moonbook.moonbook_moonflow_adapter_declaration_json()
    ["legacy-capabilities"] =>
      @moonbook.moonbook_moonflow_adapter_capability_json()
    ["health", checked_at, valid_until, evidence_ref, evidence_digest] =>
      @moonbook.moonbook_moonflow_adapter_health_json(
        checked_at~,
        valid_until~,
        evidence_ref~,
        evidence_digest~,
      )
    _ =>
      fail(
        "usage: moonbook_adapter [declaration | legacy-capabilities | health <checked-at> <valid-until> <evidence-ref> <sha256:digest>]",
      )
  }
  println(output.stringify(indent=2))
}
