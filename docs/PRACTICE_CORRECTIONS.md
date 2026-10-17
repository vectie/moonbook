# Turn observed practice into a correction case

The practice workbook now connects a selected observation to the existing
current-lesson revision rehearsal. You can carry the fixed exercise, first
response and source context into a correction without reconstructing them from
a downloaded report. This is local authoring, with ordinary named-human review
still required for any accepted lesson change.

## Complete journey

1. Open **Bookkeeper → Reviewed lessons → Agent teaching brief → Agent practice
   workbook**. Start or resume a workbook and record an observed first response,
   response after feedback, feedback and next practice.
2. Choose **Prepare practice N for correction** beside the intended observation.
   Give the case a name, deliberately choose **known-useful** or **adverse**, and
   author required/forbidden literal fragments. The exact prepared case and its
   complete captured lesson/source context are displayed before any transfer.
3. Choose **Open this practice lesson's history**. This uses the existing
   read-only lesson-history route and selects the captured exact version. An
   unrelated open unsaved revision must be finished or closed using the ordinary
   controls; the feature does not replace it. Recheck reviewed lessons if their
   current capture is unavailable or stale.
4. In that existing history, choose **Revise this accepted version**, then
   **Start contrasting-case rehearsal**. Its currently accepted version,
   source scope/reviews and captured guidance must match. If the workbook's
   lesson was superseded, it remains historical context; it is not relabeled
   automatically as an observation of newer guidance.
5. Return to the displayed prepared case and choose **Add first response as
   original-guidance case**. This explicitly attributes the supplied first
   response to the captured original guidance for this operator-reported
   rehearsal. It fills a pristine same-kind slot or appends within the existing
   six-case limit. Existing authored and retained examples are preserved.
6. In the ordinary rehearsal, the fixed input and first response are read-only.
   **Inspect observed practice source** retains the learner label, objective,
   exact lesson/scope/review/outcome references, exercise, both recorded responses,
   feedback and next-practice text. These remain unverified operator reports.
7. The revised-guidance output starts blank. Write revised guidance and its
   rationale, then supply an output explicitly attributed to that guidance.
   An after-feedback response is reference context; it is not automatically a
   result of guidance that did not exist when practice was recorded. Complete
   useful/adverse coverage, compare literal checks, and stage through the
   existing controls. Save the ordinary revision candidate and use the existing
   named-human review lane. No accepted record changes during this transfer.

## Preservation and recovery

- The workbook stays unchanged by preparation/import. Closing preparation removes
  only its local case labels/checks. Editing/replacing/discarding the workbook
  clears preparation rather than carrying observations to another exercise.
  Teaching-brief edits still cannot rewrite its fixed practice snapshot.
- The bridge has no separate saved artifact or authority contract. Once added,
  `practice_from` travels with that rehearsal case in its ordinary staged report.
  Explicit **Save correction on this browser** and cold resume also preserve it;
  the existing draft-size/current-history checks still apply. Save the separate
  workbook JSON if you need to keep the original practice session.
- The input and first response must fit the existing rehearsal's 8192 UTF-16
  character limit even though workbook fields can hold 16384. Larger observations
  are refused without truncation and stay in the workbook. Names, fragment counts,
  duplicate examples, six-case capacity and saved-draft limits are unchanged.
  A manual separate example remains the way to author a different/shorter task.
- Blank or inconsistent case labels/checks produce a visible error without
  replacing existing cases. Repeated imports of the same exercise are rejected.
  Revised output and authored name/checks remain editable; original observation
  fields retain their exact recorded strings, including whitespace and Unicode.
- Rendered controls bind workbook revision, host request, browser capture and
  exact rehearsal context/revision. Changed observations, a newer rehearsal,
  a refreshed or pending history, and detached controls cannot attach old input
  to different work. Failed/missing host reads preserve workbook preparation.
- Imported workbook labels and source references are not independent proof of
  a model run, factual correctness, efficacy or human review of the responses.
  Matching current host guidance does not authenticate the observations. No
  provider runs, grading, promotion, operational permission or sharing occurs.

## Development evidence

This supplies the missing practice-to-correction authoring step for
MOONBOOK-F03/R03, retaining F02/R02's source-linked experience context. R671's
workbook only directed the operator to manually reopen history and reconstruct
the correction. This uses the existing history/rehearsal/review controls and
does not close complete Three-Gap or outcome-linked-memory requirements.

Eleven focused compiled tests cover exact transfer, existing-case preservation,
current history/capture requirements, workbook/rehearsal-size differences,
stale rendered callbacks, read-only source fields, staged revision payload,
explicit saved-correction cold resume, and actual rendered controls. Eleven
workbook tests and 89 existing learning regressions also pass. Pinned JS
check/info/fmt and the real entrypoint build pass, with existing warnings.

The full UI aggregate retains its inherited missing native collection-wire
fixture failure at `book_collection_archive_wbtest.mbt:153`; no fixture was
invented. Real browser interaction, native host mutation/lifecycle, actual
named-human review, configured providers, learning efficacy, customer outcomes
and release qualification remain separate unrun/blocking gates.
