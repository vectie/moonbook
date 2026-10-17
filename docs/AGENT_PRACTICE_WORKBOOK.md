# Record an agent practice session

The teaching brief prepares a learning sequence. The practice workbook now lets
an operator bring observed responses, feedback and a next exercise back beside
that exact sequence. Open **Bookkeeper → Reviewed lessons → Agent teaching
brief → Agent practice workbook**.

For subsequent attempts, use [Practice rounds](PRACTICE_ROUNDS.md). Seal the
current round and start another from the rechecked brief, preserving earlier
tasks, learner labels and observations instead of overwriting the first pair.

## Complete journey

1. Select reviewed lessons, author an objective and a fresh task for every
   selected lesson, and recheck all teaching lessons. Choose **Start practice
   from this teaching brief**. Starting requires the exact current capture;
   it does not run a learner or send anything to a provider.
2. Enter an optional learner/session label. Conduct practice separately under
   the appropriate authorization, then paste each first response and response
   after feedback. Describe the observed difference and the next practice or
   proposed correction. Empty fields explicitly mean unrecorded. There is no
   automatic score, pass/fail grade or inference of improvement.
3. Inspect the fixed lesson/task snapshot. It includes exact scope, review and
   source references plus the historical teaching examples captured by the
   teaching brief. Reordering, rewriting or removing lessons in the open brief
   never moves observations to a different exercise. A changed/missing host
   lesson shows a historical-capture warning and retains the observations.
4. **Save editable practice-workbook JSON** before reload. This is separate from
   the teaching-brief JSON, which does not include practice. To resume, paste
   the complete workbook, preview all fields, then explicitly replace the local
   practice session. Imported captures and learner responses remain unverified
   operator reports, even if their lesson fields match the current host.
5. **Download practice report Markdown** creates a readable review packet with
   the exact captured tasks, lesson context, both responses, feedback and next
   practice. Historical report export is allowed without a current host match;
   it makes no claim that guidance is still current at export. JSON is the
   editable exact field representation. Check browser downloads before leaving.
6. For a useful correction, open that lesson's current version history and use
   the existing revision, contrasting-case rehearsal and named-human review
   workflow. This report neither stages a revision nor accepts one. A before/
   after difference is not proof of learning, generalization or factual accuracy.

For an integrated transfer without reconstructing the task and observations,
choose **Prepare practice N for correction**. The [practice correction workflow](PRACTICE_CORRECTIONS.md)
opens matching history and explicitly adds an observed case to its existing
revision rehearsal. Revised-guidance output starts blank; exact feedback and
the after-feedback response remain visible source context.

Save before **Discard local practice workbook**, which removes only the current
tab's session. A second session cannot overwrite the first via Start; discard
or explicit previewed replacement is required. Close/reload loses unsaved work.

## Portable contract and bounds

`moonbook.agent-practice-workbook.v2` contains the current learner label, an exact
`moonbook.agent-teaching-brief.v1` snapshot and one observation row per captured
exercise, plus up to eleven sealed previous rounds with their own exact
captures. Existing v1 files import as one current round and save as v2. The
objective and every exercise must be nonblank. The inherited
12-lesson and snapshot constraints apply. Learner label: 256 UTF-16 code units;
each response, feedback and next-practice field: 16384 code units. Complete
JSON/imports/downloads: 1 MiB UTF-8. Unknown fields/schemas, unmatched Unicode
surrogates, missing/extra rows and over-limit content are rejected without
truncation. This is an editable report, not signed provenance or an authenticated
runtime receipt. No credentials, raw record payloads or authority grants are
added by capture; authored responses and retained guidance can still be private.

Invalid intake clears its replacement preview and keeps current observations.
New edits invalidate older rendered callbacks, replacement previews and stale
download-result messages. Failed downloads preserve the complete session and
clean up temporary links/Blob URLs. Markdown fences exceed authored backtick
runs, retaining markup as literal text. The app's displayed values use escaped
text rather than executing response HTML.

## Development evidence

R671 executes the compiled production controller, rendering and download path
with synthetic current lessons and operator observations. Eleven focused tests,
89 existing learning regressions, JS checking and the real JS entrypoint build
pass. Final `moon info` and `moon fmt` ran with the pinned toolchain and retained
Rabbita 0.12.4 graph. The full UI aggregate still fails at the inherited missing
native collection-wire fixture (`book_collection_archive_wbtest.mbt:153`); its
native evidence destination is also a prerequisite. No fixture was fabricated.

This is a bounded authoring/output contribution toward outcome-linked memory
and founder correction review (MOONBOOK-F02/F03), not closure of those PRD gates.
Real browser interaction, native host mutation/lifecycle, real named-human
review, providers, learner efficacy, customer outcomes and release qualification
remain blocking/unrun where required. Chromium was not retried.
