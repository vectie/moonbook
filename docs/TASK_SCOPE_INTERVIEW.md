# Task scope interview

MoonBook can now use current reviewed experience to help an operator identify
which task conditions matter before retrieving guidance. This closes the gap
between free-text lesson browsing and exact scoped retrieval.

## Journey

1. Browse or search reviewed lessons in the existing Bookkeeper console. A
   search narrows the interview to those results; an empty search considers all
   currently returned reviewed lessons.
2. Enter the later task's exact ID, version and digest, or receive its existing
   Proj handoff. Existing task conditions remain authoritative inputs.
3. In **Which past lessons fit this task?**, inspect the observed condition
   values. Click **This task has key=value** only when that statement is true.
   This stages an answer; it does not infer task facts from a past lesson.
4. Watch the candidate explanations distinguish missing scope, contradictions,
   matching invalidations, and required scope that matches while invalidation
   conditions remain unknown. Ambiguous values stay separate explicit choices.
5. Remove individual answers or discard the whole staged interview. These
   controls leave the task query and authored lesson unchanged.
6. Choose **Apply my answers and find lessons**. The explicit answers are added
   to the existing query, and the ordinary exact host retrieval runs. Select a
   returned lesson through the existing named-review, destination-confirmation
   and exact-current-version handoff path. Applying answers alone cannot attach
   guidance, start work, accept knowledge or change permissions.

## Recovery and boundaries

- Questions come only from current reviewed browse results, never excluded
  historical or rejected records. Existing conditions are not overwritten.
- Unknown conditions remain unknown; a missing do-not-use answer is explicitly
  shown as needing checking, not proof of safety or applicability.
- Other truthful values may be typed in the ordinary task-condition controls.
  If an interview is already staged, discard it before editing those controls.
- Task edits, query edits, a browser reload, lesson-byte/review-selection changes
  and new handoffs invalidate staged answers. Discard and start again instead of
  silently rebasing an answer onto new context.
- Repeated/stale controls and pending requests cannot append duplicate answers
  or apply a stale draft. Applying preserves the authored lesson and rehearsal.
- The interview is tab-local, with no storage or model execution. Closing the
  page loses unapplied answers. Source truth remains on the Book host, which
  rechecks currentness during retrieval and selection.
- This does not prove general applicability, customer outcomes, self-improvement
  or integrated runtime qualification. Conditions are exact strings; there is no
  semantic inference or automatic conflict resolution.

## Verification

From any directory run the delivery's `r580/run-focused.sh`. It checks the
unchanged standalone current UI module with the pinned MoonBit toolchain and
exact approved Rabbita dependency, runs eight interview tests plus related
browser/controller/selection regressions, and runs the existing production-JS
comparison and rehearsal tests. Root workspace/native/integrated browser/provider
qualification remains unrun; the absent MoonLeaf workspace is not substituted.
