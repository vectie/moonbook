# Exact task context for the existing lesson workspace

`OutcomeLessonTaskHandoff` is imported context, not a review or mutation. Pass a
Proj-produced value to `resolve_outcome_lesson_handoff` to read matching existing
sources. The same function backs the existing host's read-only lesson handoff
route. Callers must retain the exact serialized task/report snapshot strings;
reformatting them changes their digests.

The handler rejects incomplete references before reading or writing a journal:

```mbt check
///|
async test "public task handoff rejects incomplete references without journal admission" {
  let reference : @bookkeeper.VersionedRecordReference = {
    record_id: "task-example",
    record_version: "1",
    record_digest: "not-a-digest",
  }
  let handoff : @bookkeeper_store.OutcomeLessonTaskHandoff = {
    contract_version: "moonproj.book-lesson-handoff.v1",
    source_product: "moonproj",
    task: reference,
    report: reference,
    task_snapshot: "{}",
    report_snapshot: "{}",
    customer_acceptance: "not_asserted",
    cash: "not_asserted",
    authorizing: false,
  }
  let root = @fs.tmpdir(prefix="moonbook-public-task-handoff-")
  let (status, response) = @bookkeeper_store.outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/task-handoff",
    handoff.to_json(),
  )
  assert_eq(status, 422)
  assert_true(response is { "ok": false, .. })
  assert_true(
    @bookkeeper_store.replay_bookkeeper_store(root).records.is_empty(),
  )
}
```

For an admitted snapshot, the returned `handoff` is an exact typed echo. `sources`
contains only existing outcomes whose originating ProductOutcomeSubmission names
both exact task/report evidence references and whose assessment has a named-human
acceptance. Empty and multiple sources require explicit operator decisions.
No task handoff grants capability activation or establishes customer/cash facts.

The same readback now contains `saved_lessons`, a minimal read-only projection of
lessons whose immutable source chain matches one of those exact reviewed
assessments. Each `moonbook.saved-lesson-receipt.v1` entry identifies the persisted
lesson, its unique final review (or null for pending), and its current/historical
or legacy-unselected relation. `journal_sequence` identifies the observed replay
position. It is not a new receipt ledger or a cryptographic signature. Candidate
storage success cannot produce `retained`; the existing named-human review does.
The browser returns only a selected entry after an explicit operator action.
