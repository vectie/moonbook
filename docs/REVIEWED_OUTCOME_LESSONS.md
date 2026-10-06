# Reviewed outcome lessons

This bounded workflow connects an already reviewed Bookkeeper outcome to useful
guidance for a later task. It implements part of MOONBOOK-R02/R03 and preserves
the B05 review boundary. It does not qualify live customer outcomes or automatic
capability improvement.

## Existing stores and decisions

Lessons use the existing `.moonbook/bookkeeper` journal and existing governed
review operation. A lesson is a `DeliverableAcceptance` artifact whose payload
has `candidate_schema: outcome_lesson.v1`. There is no second memory database,
new reviewer authority, new review disposition, or automatic acceptance.

The draft binds the exact outcome, its Three-Gap assessment, and the assessment's
named-human acceptance. Its guidance and applicability become one immutable
reviewable artifact. The original outcome, source receipts, evidence and rejected
lesson versions are never rewritten. Each lesson version gets a distinct durable
record ID (`outcome-lesson:<lesson_id>@<lesson_version>`) to respect the existing
journal's unique identity convention. A changed draft with the same identity
cannot replace a saved artifact; an exact retry is idempotent.

These journal artifacts do not change or silently enter the portable agent
`memory/procedures` or `memory/beliefs` format. Existing Desk portable learning,
pack/import/upgrade, reflection heuristics and ingest-trust semantics are unchanged.

## Prepare, inspect and review

After `submit-product-outcome` / `close-product-outcome` has produced an outcome
and its assessment has an accepted named-human review, author a lesson JSON:

```json
{
  "contract_version": "moonbook.outcome-lesson.v1",
  "lesson_id": "source-contradiction-check",
  "lesson_version": "1",
  "title": "Resolve the decisive source contradiction",
  "guidance": "Preserve both exact quotations and test the decisive claim before the next vendor comparison.",
  "outcome": {"record_id": "<exact outcome id>", "record_version": "1", "record_digest": "<exact digest>"},
  "assessment": {"record_id": "<exact assessment id>", "record_version": "1", "record_digest": "<exact digest>"},
  "assessment_review": {"record_id": "<exact review id>", "record_version": "1", "record_digest": "<exact digest>"},
  "applicability": [
    {"key": "customer_id", "value": "customer-a"},
    {"key": "decision_kind", "value": "vendor-comparison"}
  ],
  "invalidation": [{"key": "evidence_state", "value": "superseded"}],
  "recorded_at": 200
}
```

The references and timestamp above are placeholders. Use the actual durable
references and a timestamp no earlier than the assessment's review.

```sh
moon run cmd/outcome_lessons -- prepare /path/to/book lesson.json
```

This returns the exact persisted candidate reference. Open the existing Bookkeeper
screen, select that artifact in the deliverable lane, and inspect the readable
guidance, required conditions, invalidation conditions and original references.
Use the existing named reviewer, **Prepare acceptance** / **Prepare rejection**,
review summary, and **Save governed review** controls. The existing `bookkeeper
review` CLI and generic record admission endpoint use the same journal rules.

The ordinary Bookkeeper screen also has **Make and reuse a lesson**. Select an
accepted Three-Gap assessment, choose **Use selected assessment**, and fill in
the title, guidance and **When to use this lesson** fields. Customer/audience
and decision-kind fields cover the common case; other named conditions,
invalidation rules and correction version remain available under the additional
conditions disclosure. **Save lesson for review** calls the same store operation
through the existing Book host. **Open saved lesson for review** selects its exact
durable reference after the current state has refreshed.

The form retains its chosen source and authored text through ordinary record
selection changes and request failures. It disables duplicate clicks while a
request is pending; an unchanged retry reuses the same immutable lesson identity.
Choosing the same source again does not allocate another identity. Browser reload
or leaving the page loses an unsaved lesson form; the form states this limit.

## Retrieve for another task

The query records the caller-supplied exact target task identity and useful named
context. It is not an attestation that MoonProj accepted or executed that task.
For a Proj brief, retain the existing task_id/project_id and exact command/run/
session/report references as source evidence; `source_context.reference` and
`source_context.problem` remain the originating brief's source and problem.

```json
{
  "contract_version": "moonbook.outcome-lesson-query.v1",
  "target_task": {"record_id": "<exact later task id>", "record_version": "1", "record_digest": "<exact task digest>"},
  "conditions": [
    {"key": "customer_id", "value": "customer-a"},
    {"key": "decision_kind", "value": "vendor-comparison"},
    {"key": "evidence_state", "value": "current"}
  ]
}
```

```sh
moon run cmd/outcome_lessons -- retrieve /path/to/book query.json
```

In the same GUI, **Find useful lessons for the next task** accepts the next task
ID, its exact version/digest and named context. It calls the same scoped retrieval
operation and shows readable guidance, scope, reviewer and original evidence
references. It shows an explicit empty state when nothing matches. Editing the
next task or its conditions clears the previous result, and late responses for
another request cannot replace current context. The manual fields remain. For an
accepted Proj task, **Prepare lesson** now supplies a direct user-selected Book
handoff or an exported file. **Receive task from Proj** / **Import Proj task
handoff file** validates and displays the exact typed binding. **Use task for
lesson retrieval** fills its ID/version/digest and actual project condition;
other conditions remain an explicit human choice.

The same read-only receiver resolves existing moonproj ProductOutcomeSubmission
outcomes only when both exact captured task and report reference triples occur
in the submission and outcome evidence. A reviewed source can be explicitly
selected to start a lesson in this same UI. Missing or unreviewed chains stay
visible prerequisites; no submission, outcome or assessment is synthesized from
task acceptance. Old outcomes lacking those exact refs retain manual selection.
Handoff hashes identify captured projection bytes, not independent authentication
or new Book authority. A direct sender receives only its original binding and a
matching-state label, without Book's private source/review text.

Every required key/value must match exactly. Missing conditions, another customer,
a different decision kind, or any matching invalidation condition excludes the
lesson and reports why. Additional target conditions do not widen the lesson's
original scope. The keys are author-chosen domain context, not a new global
customer policy; the reviewer must check that they accurately bound the guidance.

Only the exact human-accepted lesson is returned. Candidate/rejected lessons are
reported as exclusions. Ambiguous final reviews or broken journal/source linkage
return an error instead of guessing. Retrieval includes the full original lesson,
lesson review, outcome, assessment and assessment review. It performs no write,
does not infer customer/cash acceptance, and never activates a capability. A scope
match still requires the consumer to judge applicability to the actual task.

## Revise a method, choose a version, or roll back

Select a lesson and open its version history. The ordinary history workspace
retains every version and named review, including pending, deferred and rejected
updates. **Revise this lesson** captures the selected accepted predecessor, the
current selection receipt, and the exact accepted-review history. Compare the
old guidance and conditions, enter a new version and explain the change, then
save the revision for the existing named-human review. Saving does not select
or accept the revision. Acceptance makes it current; rejection or deferral leaves
the previous guidance in use.

**Restore this version** (or choosing an existing accepted version) saves a
separate immutable selection proposal with a reason. Its existing named-human
review decides whether to use that exact version again. It does not rewrite the
old lesson, repeat its acceptance, erase the intervening decisions, or activate
a capability. Inspect the selected original guidance and conditions before
reviewing the choice.

Both changes bind the exact current head and observed accepted reviews. Another
accepted revision, rollback, or newly accepted legacy lesson makes an outstanding
choice stale. Reload history and prepare a new choice; changing a version's
content or retrying against a newer head cannot silently replace accepted
knowledge. Exact unchanged retries remain idempotent. Journal replay reconstructs
the selection without trusting a mutable projection or a lexical latest version.

Legacy v1 artifacts and ordinary manual authoring remain compatible. Before an
explicit revision/choice is accepted, every accepted matching legacy version
remains retrievable. A single accepted version can be displayed as current;
multiple versions show no selected current version. History remains readable and
an explicit reviewed choice establishes which version subsequent retrieval uses.
Afterward, historical versions are retained and shown as excluded from normal
retrieval rather than silently deleted. The selected version's original scope
and invalidation conditions always apply, including after rollback.

The existing host routes add `history`, `revise`, and `select` under
`/api/bookkeeper/lessons/`. Their exact request structures are
`OutcomeLessonRevision` and `OutcomeLessonSelection`; history requires a
`lesson_id`. The thin CLI uses the same store operations:

```sh
moon run cmd/outcome_lessons -- history /path/to/book source-contradiction-check
moon run cmd/outcome_lessons -- revise /path/to/book revision.json
moon run cmd/outcome_lessons -- select /path/to/book selection.json
```

The history response supplies `head` and `accepted_reviews` to capture unchanged
in the choice. New revision artifacts use `outcome_lesson.v2`; selection artifacts
use `outcome_lesson_selection.v1`. The original `OutcomeLessonDraft` wire is
unchanged. Browser drafts remain tab-local; saved artifacts, choices, and reviews
can be recovered from the existing journal after restart.

## Return a saved lesson's status to Proj

If a received task has no reviewed assessment yet, use the ordered outcome-review
panel first. Import and inspect an already-complete outcome file, or open an exact
saved submission. Review its deliverable with the existing named-human controls,
then explicitly continue it to assessment review. After that review is accepted,
refresh the task readback and start a lesson from the available assessment. The
original source and review remain inspectable. Existing unsaved lesson and review
drafts are retained; opening another review is an explicit choice.

This is an intake/resume UI for the [existing outcome contract](BOOKKEEPER_OUTCOME_CLOSURE.md).
It does not derive customer outcomes from internal task acceptance or supply
missing evidence. A failed import keeps the current task and draft. Existing
rejected submissions remain visible with their stage, without producing a lesson.

After receiving/importing the exact Proj task handoff, use **Refresh saved lesson
status** to read matching persisted lessons. Select a version, inspect it in
Book, then choose **Return selected lesson status to Proj** or **Download selected
lesson receipt**. Both actions reread the Book journal first. They do not save,
accept, reject, select a current version, or change any company record.

The returned receipt contains only the title, exact task/report and source-chain
references, lesson version, final reviewer reference/name and review state,
current-version references, and observation metadata. Full guidance and scope
stay in Book. A saved candidate is `pending`; a unique completed named-human
Accept is `retained`; a unique Reject is `rejected`. Ambiguous final decisions or
journal replay issues fail the readback. Accepted historical versions remain
historical. Multiple accepted legacy versions with no reviewed choice remain
`legacy_unselected`, without new authorization or an inferred latest version.

The initial Proj handoff acknowledgment remains minimal. Lesson status is sent
only after the explicit selected-lesson action, using the same exact origin,
opener/child window and nonce binding. Book reports successful return only after
Proj acknowledges the same serialized receipt. The source handshake has a
120-second window; following acknowledgment, Proj accepts one explicit receipt
for up to ten minutes. If the window closes or the connection expires, reconnect
from Proj or use the JSON file fallback. Saved lessons and reviews remain in the
journal. Restarting either UI requires a new handoff/refresh or file import, not
manually copying lesson identifiers.

Proj labels file imports as historical observations. Reopening the same Book
passes the selected exact lesson reference through the message channel and asks
for a new readback; private content and record references are not placed in the
URL. Hashes bind captured bytes and are not signatures. These receipts do not
prove customer acceptance, cash, or authority to activate anything.

## Evidence scope

Native filesystem and socket-free existing-host handler fixtures exercise submission, source review, candidate
persistence, explicit lesson acceptance/rejection, replay, revised versions,
retrieval and original-record equality. UI SSR tests exercise readable review
content, author/retrieval controls, draft retention, duplicate clicks, late
responses, exact-query response decoding, empty results and escaping. CLI fixtures use locally generated synthetic outcomes.
These are local implementation checks, not live provider, customer, cross-machine,
browser-pixel or end-to-end company execution acceptance.
