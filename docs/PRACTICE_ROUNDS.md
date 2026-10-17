# Continue practice without overwriting experience

Open **Bookkeeper → Reviewed lessons → Agent teaching brief → Agent practice
workbook**. A workbook can now retain up to twelve explicit practice rounds.
Each round fixes its learner label, teaching objective, exact lesson versions,
scope, reviews, historical examples, tasks and operator-entered observations.

## A complete journey

1. Recheck the teaching brief and write a task for each selected lesson. Choose
   **Start practice from this teaching brief**. Conduct the practice separately
   with appropriate authorization. Record first responses, optional responses
   after feedback, observed differences and a proposed next practice.
2. Prepare the next tasks in the teaching brief above. Retry the same tasks or
   use different tasks; after guidance changes, remove/re-add the current lesson
   capture through the existing teaching-brief controls and recheck it. Changing
   the brief never rewrites the open round's fixed tasks or guidance.
3. Inspect **Next round's exact teaching brief**. Choose **Seal this round and
   start the next**. At least one first response must be recorded, every next
   task must be nonblank, and the next brief must match the currently loaded
   reviewed lessons. The old round becomes read-only in Book. A blank new round
   captures the inspected brief. Unrecorded rows remain unrecorded in history.
4. Record the next experience. The **Practice round progression** shows each
   round's objective, captured learner label and entry counts. Expand an earlier
   round to read its exact task, responses, feedback, proposed next exercise and
   lesson snapshot. Editing the current learner label or observations, or
   reordering the teaching brief, cannot relabel earlier evidence.
5. Save **editable practice-workbook JSON** before reload. To resume, paste the
   complete JSON, preview it and explicitly replace the local workbook. All
   rounds return, including gaps and exact Unicode text. The teaching brief is
   separate; after a cold resume, prepare/recheck that brief before continuing.
   **Download practice report Markdown** exports all rounds in readable order.
6. To propose a correction, choose **Prepare round N practice M for correction**
   beside the particular sealed observation, or the existing current-practice
   control. Inspect the selected round in the correction panel. Open the exact
   lesson's history, revise its current accepted version, start the ordinary
   contrasting-case rehearsal, name the case and checks, then explicitly add it.
   The selected round's task and first response become the original-guidance
   case. Round number, learner label, feedback and after-feedback response stay
   attached as operator-reported source context. Revised-guidance output starts
   blank and must be supplied separately.
7. Continue through the existing comparison, staging and named-human review
   lane. A stale, changed or unavailable captured lesson cannot automatically
   enter a current revision. Keep the historical round readable and use the
   normal current-guidance workflow rather than relabeling old observations.

## Portable format and recovery

New saves use `moonbook.agent-practice-workbook.v2`. The current round retains
the original top-level `learner`, `teaching` and `observations` shape; sealed
rounds are an ordered `previous_rounds` array containing those same three
fields. This is not chronological execution evidence: order records explicit
next-round actions, and imported files remain unverified operator reports.

Exact v1 files are accepted as a single current round and saved as v2 without
dropping fields. A v1 file carrying subsequent rounds or unknown fields is
rejected. Old Book versions that support only v1 cannot open v2 workbooks.
Each round keeps the inherited 12-lesson limit, 256-character learner-label
limit and 16384-character observation-field limit. The whole file remains
bounded to 1 MiB UTF-8. Oversized/malformed round data is rejected with the
existing workbook kept; no truncation or implicit replacement occurs.

Starting a new round clears stale replacement previews and correction
preparations. Callbacks from earlier rendered controls cannot overwrite new
observations or attach a different round. Save before discarding the workbook;
there is no automatic disk persistence or undo for sealing. A sealed snapshot
is read-only in this UI, not a tamper-proof receipt; editing an exported file
does not create trusted evidence. Exports can contain private tasks and
responses, so inspect them before sharing.

## What this establishes

This closes the authoring gap between one mutable before/after exercise pair
and repeated, inspectable practice. It supports MOONBOOK-R02 outcome reuse and
R03 correction review without claiming those PRD gates are complete. Counts
mean recorded entries only. No model/provider call, automatic score,
generalization claim, accepted lesson, deployment, permission expansion or
customer outcome results from creating a round.

The synthetic three-round example goes from an invented export completion time
to separating a start window from a finish time, then making an omitted
timezone explicit. Missing second-lesson responses remain visible. These are
authored example responses, not measured learner improvement.

## Development evidence

R699 exercises the compiled production controller, actual rendered controls,
and production Blob download path: nine focused tests pass, including sealed
snapshot preservation, v1 migration, v2 cold resume, exact round correction
selection and multiround export bytes. Eleven prior workbook tests, eleven
correction tests and 89 learning regressions also pass. JS `moon check`,
entrypoint build, `moon info` and `moon fmt` pass on the pinned toolchain with
the retained Rabbita dependency graph; public interfaces are unchanged.

The aggregate UI run remains blocked by the inherited absent native
collection-wire fixture. No native fixture, provider response or runtime
receipt was fabricated. Real browser interaction, native host changes,
cross-machine compatibility and real named-human review were not qualified.
