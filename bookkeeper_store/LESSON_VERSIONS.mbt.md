# Reviewed lesson revisions and version choices

`outcome_lesson_history` returns original artifacts and every review, the exact
current selection receipt, and the accepted lesson reviews observed by a new
choice. Capture those returned references unchanged in `OutcomeLessonRevision`
or `OutcomeLessonSelection`. These save reviewable artifacts; the existing
`apply_governed_review` operation and installed named-human authority still own
the decision. A stale head or newly accepted lesson requires reloading history
and preparing a new choice, never overwriting an accepted record.

```mbt check
///|
async test "public version history has no inferred latest version" {
  let root = @fs.tmpdir(prefix="lesson-history-example-")
  let history = @bookkeeper_store.outcome_lesson_history(
    root, "source-checking",
  )
  assert_true(
    history
    is {
      "contract_version": "moonbook.outcome-lesson-history.v1",
      "lesson_id": "source-checking",
      "head": Null,
      "current": Null,
      "accepted_reviews": [],
      "versions": [],
      "selections": [],
      ..
    },
  )
}
```

Legacy `OutcomeLessonDraft` records and their wire format are unchanged. Before
an explicit version choice is accepted, all accepted matching legacy versions
remain retrievable. A unique legacy acceptance may be displayed as current;
multiple acceptances have no inferred ordering. After a reviewed revision or
choice establishes a head, only its selected accepted version is returned for
normal retrieval, with that version's original conditions and source chain.
Historical versions and decisions remain available through history.

Rollback is a new `OutcomeLessonSelection` pointing to an exact already accepted
version. It retains the current head and full accepted-review snapshot, needs its
own reason and named review, and changes no old artifact or decision. Selection
does not grant capability activation, customer acceptance, or external authority.
