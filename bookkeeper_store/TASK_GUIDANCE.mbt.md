# Reviewed guidance for a later formal task

The read-only `guidance-query` and `guidance-select` host routes are separate
from the accepted-outcome handoff and saved-lesson receipt contracts. Neither
route appends journal events, accepts a review, activates a capability, creates
a runner, or changes source evidence.

`resolve_task_guidance_query` accepts `moonproj.book-guidance-query.v1` with an
exact `target_task` reference and its captured `task_snapshot` string. That
snapshot contains only `task_id`, `project_id`, `product_id`, and `revision`.
The reference digest identifies its exact UTF-8 bytes. This is captured query
context, not proof of task acceptance or independent verification of Proj.

Known conditions are `project_id` and, when the task has a suite catalog tag,
`suite_product_id`. The latter is derived from the task's `product_id` field;
it must not be confused with the outcome's `source_product` or a customer's
business `product_id`. Customer, decision, and other unknown conditions require
explicit founder input. Topic similarity never expands applicability.

```mbt check
///|
test "public guidance projection rejects unsupported input" {
  try @bookkeeper_store.resolve_task_guidance_query({}) catch {
    _ => ()
  } noraise {
    _ => fail("Unsupported guidance input must not be accepted")
  }
}
```

`select_task_guidance` takes only `handoff`, the existing
`moonbook.outcome-lesson-query.v1` query, and the exact `lesson` reference. It
replays one journal snapshot and uses the same retrieval logic as ordinary
lesson lookup. Pending/rejected lessons, accepted historical versions replaced
by a reviewed current choice, missing applicability, and any invalidation
match are excluded. Legacy accepted lessons without a reviewed current-version
choice retain the existing `legacy_unselected` behavior.

The result is `moonbook.task-guidance-selection.v1`, containing only the
handoff/query, selected title/guidance/scope, exact source/review references,
named reviewer, observed journal position, currentness, and non-authorizing
flags. It does not contain raw outcome/assessment bodies, evidence arrays,
workspace memory, capabilities, or credentials. The browser adds its actual
`book_origin` and readback `observed_at`. Export-specific size limits reject
excess content without truncation; ordinary lookup remains unchanged.

The incoming browser origin is only a suggested destination. Before sharing,
the founder explicitly confirms the displayed origin and exact target task,
then chooses one lesson at a control naming that destination. The transport
binds the opener window, origin, nonce, handoff, and exact acknowledgement.
Receive/reopen/cancel invalidates that choice. Guidance is tab-local and does
not enter URLs or generic draft/file exports.

The selection remains an advisory observation. Proj independently compares
the canonical task snapshot before the first Start and freezes the selected
advice in its existing execution reservation. Retries use that captured
request. Captured prompt text is not proof that a model followed it, customer
acceptance, capability authorization, or measured learning.
