# Retest a recorded task after reviewed guidance changes

The practice workbook can carry an exact historical exercise into a selected
current lesson version. Earlier practice and new practice retain their own
guidance, scope, reviews and responses. This explicit authoring step does not
run a learner, accept a correction, or infer improvement.

## Complete journey

1. Record a task and response in the existing agent practice workbook. Use the
   existing correction rehearsal and named-human review lane when guidance
   needs changing. Keep the workbook while reviewing the correction.
2. In **Agent teaching brief**, explicitly remove the old lesson selection and
   add the desired current reviewed version, then **Recheck all teaching
   lessons**. This does not rewrite the workbook's historical capture. A reviewed
   restore of an earlier version is also eligible; version names are not a clock.
3. In **Find a recorded practice experience**, search for the earlier exercise
   and choose **Preview this task with selected current guidance**. The original
   exact-snapshot reuse control remains available when guidance has not changed.
4. Inspect the historical exercise, the next task that will be replaced,
   and both complete curated guidance/scope/review captures. Check whether the
   new applicability and invalidation conditions make this a useful exercise.
   Matching the source family does not establish applicability or a predecessor
   relationship.
5. Choose **Replace next task with previewed historical task**. Only exact
   exercise text enters the selected current lesson's teaching brief. Existing
   observations, captured lessons, other tasks and accepted records are kept.
6. Use the ordinary **Seal this round and start the next** control. Its existing
   gates still require a recorded first response, a current brief and nonblank
   tasks. All new response/feedback fields start blank. Conduct practice
   separately with appropriate authorization and record the resulting response.
7. **Compare the same practice task across rounds** includes different
   version records of that exact source family. Each column retains its actual
   version, learner label, guidance and observations. Use the normal correction
   and named-human review lane for a further proposed change.

## Identity, interruptions and recovery

- Source matching requires the same lesson ID and exact outcome and assessment
  references. Records must either share the legacy record ID or each use the
  canonical `outcome-lesson:<lesson_id>@<record_version>` identity. The retest
  control requires distinct version labels and a target explicitly selected in
  the teaching brief that matches the latest successful host read. This is
  structural matching, not authentication of imported history or revision lineage.
- The complete old and new scopes are displayed without interpreting them as
  policies. The operator decides whether to proceed. Task preparation creates
  no authority, task-selection receipt or model execution.
- Preview is tab-local. Search, teaching or workbook edits, refreshed host data,
  unavailable/pending reads and detached callbacks invalidate it. Pending lesson
  submission blocks preparation and application. Repeated old clicks cannot
  overwrite a newer task. **Cancel retest preparation** changes neither brief
  nor workbook.
- Save the teaching brief before reload to keep an uncaptured next task. Once a
  round starts, normal workbook JSON retains both captures and observations.
  Resuming never restores an actionable retest preview. Existing 12-round,
  12-lesson and 1 MiB limits are unchanged.
- Same-task comparison requires exact task text, including Unicode and
  whitespace. Changed source references and unrelated record identities are
  not paired. Different learner labels and missing responses remain visible.
  Response differences do not imply a score, efficacy, factual verification,
  accepted knowledge or generalized learning.

## Development scope

This contributes to MOONBOOK-F02/R02's later reuse and F03/R03's correction loop,
preserving UC05/B05's named-human review boundary. Compiled production UI tests
exercise rendered preview/application, distinct version IDs, current-source
checks, stale controls, blank next rounds, exact preservation and cold resume.
The aggregate's inherited native collection-wire fixture gate, graphical browser,
provider execution, actual review, customer outcomes and learning efficacy remain
separate unrun or blocking gates. No authored PRD criterion or release status
changes.
