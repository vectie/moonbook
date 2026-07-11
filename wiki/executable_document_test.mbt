///|
fn executable_document() -> ExecutableDocument {
  {
    contract_id: "moonsuite.executable-document.v1",
    book_id: "selene-crater-service-rover",
    revision: "r1",
    declarations: [
      {
        declaration_id: "research-terrain",
        kind: "research",
        title: "Research terrain",
        statement: "Collect traceable terrain evidence.",
        executor_product: "moonwiki",
        requires: [],
        acceptance_criteria: ["source digest is recorded"],
        requested_authority: "observe",
      },
      {
        declaration_id: "validate-route",
        kind: "validation",
        title: "Validate route",
        statement: "Independently compute every candidate edge.",
        executor_product: "moonmoon",
        requires: ["research-terrain"],
        acceptance_criteria: ["every edge satisfies the declared slope limit"],
        requested_authority: "sandbox-execution",
      },
    ],
    source_digest: "sha256:selene-r1",
    recorded_at: "2026-07-11T00:00:00Z",
  }
}

///|
test "executable document compiles deterministically" {
  let first = @wiki.compile_executable_document(executable_document())
  let second = @wiki.compile_executable_document(executable_document())
  assert_true(first == second)
  let text = first.stringify()
  assert_true(text.contains("flow-selene-crater-service-rover-r1"))
  assert_true(text.contains("work-research-terrain"))
  assert_true(text.contains("work-validate-route"))
}

///|
test "executable document rejects dependency leakage" {
  let document = executable_document()
  document.declarations[1].requires.push("unstated-secret-step")
  let issues = document.quality_issues()
  assert_true(
    issues.contains(
      "unknown declaration dependency unstated-secret-step for validate-route",
    ),
  )
}

///|
test "executable document rejects cycles" {
  let document = executable_document()
  document.declarations[0].requires.push("validate-route")
  assert_true(
    document
    .quality_issues()
    .contains("executable declarations contain a dependency cycle"),
  )
}
