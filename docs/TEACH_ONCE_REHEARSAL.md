# Teach once: rehearse a correction, review it, select its exact version

This is a bounded advisory-learning workflow in the existing Bookkeeper lesson
workspace. A person supplies a reusable correction and a fixed completed example.
MoonBook compares the two supplied outputs on explicit literal checks, retains the
example with the candidate, and makes the exact accepted guidance version
selectable for a later task. It does not run a model, infer a procedure, prove
factual correctness or demonstrate generalization from one example.

## User path

1. Open the completed task's existing Book outcome/lesson handoff, or select its
   Three-Gap assessment in Bookkeeper. Complete the existing named-human source
   assessment review. In **Make and reuse a lesson**, choose **Use selected
   assessment** (or the exact reviewed handoff source).
2. Write **What should we do next time?** as concrete procedural guidance. Supply
   the applicability conditions and any invalidation conditions. The conditions
   are checked exactly; topic similarity does not broaden them.
3. Open **Teach once · rehearse this correction**. Paste the fixed example input,
   original output and your corrected output for that same input. Add 1–20
   case-sensitive required text fragments, one per line. Line-end whitespace is
   trimmed in the form; the retained outputs are not rewritten. Click **Try
   correction on the same example**. The preview displays every before/after
   check. All corrected-output checks must pass and at least one original-output
   check must fail to save a rehearsal-backed proposal.
4. Click **Save rehearsal-backed lesson for review**. The host independently
   recomputes the checks and validates the exact outcome/assessment/review source
   chain. The existing immutable journal admits a candidate, not an acceptance.
   Open it using **Open saved lesson for review**. Inspect the guidance, scope and
   **Review the same-example rehearsal · supplied outputs** disclosure, then use
   the existing named-human review controls. Rejected candidates remain history.
5. For the next formal task, use Proj's existing Book guidance action before
   **Start**. Book receives the exact task revision and project/product conditions.
   Add any truthful conditions that only the creator knows, then **Find useful
   lessons**. Confirm the displayed Proj destination and task and choose the
   accepted version using the existing **Use this guidance for …** control.
6. Return to Proj and **Start**. The existing native task path validates the task
   snapshot, captures the exact Book selection in its execution reservation and
   quotes the selected guidance as advisory input in the execution prompt. The
   captured receipt is evidence of supplied input, not evidence that a model
   followed it or that a customer accepted the result. The trial example and its
   raw outputs are not added to the guidance-selection wire.
7. To change guidance later, open its existing version history and prepare a
   reviewed revision. Acceptance chooses the new version; new selections of the
   old version fail. To roll back, choose an already accepted earlier version
   with **Choose or restore this accepted version as current**, give a reason,
   and complete its named-human review. A later Start can select that restored
   version. An existing run retains its originally captured input.

If several accepted legacy versions have no reviewed current selection, choose
one explicitly using version history before treating any as the current version.
The rehearsal does not introduce a second version ordering or a new review lane.

## Failure and interruption behavior

- Editing guidance, scope or rehearsal fields invalidates the preview. A changed
  source binding also prevents saving until the rehearsal is repeated.
- Repeated Save uses the same exact candidate identity and bytes. An interrupted
  request leaves the draft and preview intact; retry is idempotent. Conflicting
  bytes at that identity are rejected. Use a new version or a new lesson rather
  than overwriting one already saved.
- While Save is pending, edits, Clear and repeat submission do not race it.
- **Clear rehearsal and keep lesson draft** removes only the unsaved example and
  checks. Ordinary lesson saving stays available without a rehearsal; it cannot
  silently discard nonempty rehearsal fields.
- No candidate is selected for a run before named-human acceptance. Wrong scope,
  invalidation matches and superseded versions remain excluded by ordinary
  retrieval/selection. Changed task snapshots still fail Proj's existing Start
  validation.
- Form state is tab-local and does not survive reload. A successful save is
  durable in the journal. Neither a local preview nor an HTTP error is described
  as a durable saved lesson.

## Contract and ownership

POST `/api/bookkeeper/lessons/prepare-rehearsal` takes:

- `contract_version`: `moonbook.outcome-lesson-rehearsal.v1`
- `lesson`: the unchanged `moonbook.outcome-lesson.v1` draft
- `example_input`, `baseline_output`, `corrected_output`: exact supplied strings
- `required_text`: 1–20 unique, nonblank text fragments

Each example/output is limited to 16,384 UTF-16 code units and each check to 512.
Over-limit values are rejected rather than truncated. A passing candidate uses
`candidate_schema: outcome_lesson.rehearsed.v1` in the existing
`DeliverableAcceptance` stage. Its payload contains the exact normal draft,
complete rehearsal and server-computed result. Its digest therefore binds all
three. Ordinary record admission and journal replay recompute the same expected
record; a forged pass or mismatched duplicated lesson cannot be admitted.

The normal `moonbook.task-guidance-selection.v1` wire is unchanged. The selected
lesson reference's digest binds the retained rehearsal without exporting it.
Currentness, history, source evidence, named reviewers and rollback all use the
existing outcome-lesson facilities. New lesson revisions do not inherit a claim
that changed guidance passed the original rehearsal.

This single-example workflow does not create a `CapabilityVersionReceipt`,
activate a skill/tool, relax Three-Gap's repeated-reviewed-finding requirement,
or replace `decide_capability_adoption`. The portable-agent bundle contract and
Desk's accepted-memory bridge are unchanged. No automatic bundle publication,
runtime hydration, deployment or external authority follows from acceptance.

CLI through the same handler:

```sh
moon run cmd/outcome_lessons -- prepare-rehearsal <book-root> <request.json>
```

## Verification

```sh
node --test scripts/lesson-rehearsal.test.mjs
moon test bookkeeper_store/outcome_lesson_rehearsal_wbtest.mbt --target native
(cd ui/rabbita-book && moon test main/lesson_rehearsal_wbtest.mbt --target js)
```

The Node runner executes the production embedded preview function verbatim. It
covers literal deltas, no-gain/regression cases, Unicode/inert markup, malformed
and oversized data, replay and forged pass claims. It is not a substitute for
native journal or compiled Rabbita testing.

The native fixture covers reviewed source → preview → candidate → pending
selection rejection → named review → exact next-task selection → reviewed
revision → stale-version rejection → reviewed rollback. Its authority grants and
outcomes are explicitly synthetic. UI fixtures cover edits, source changes,
cancel, duplicate clicks, interrupted saves and reachable controls.

Cloud author qualification: Node preview tests and official `moonfmt` parsing
passed. Native/UI tests and `moon info`/`moon fmt` were blocked before compilation
by the integrated workspace's absent `../moonleaf` member. No dependency was
restored or substituted. Browser startup is unavailable under the retained
restriction, and no MoonProj/database/MoonClaw/MoonFlow service was exercised.
This is source-level integration with an executable local preview, not a claim
of end-to-end production learning or release acceptance.
