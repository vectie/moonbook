# Reuse remembered teaching examples in the next correction

A correction can preserve the behavior learned from earlier experience without
manually copying old examples. Open an accepted-current lesson's version history,
choose **Revise this lesson**, and inspect **Reuse this lesson's retained teaching
examples** in the existing contrasting-case workbench.

1. Inspect the remembered input, earlier successful output, exact literal checks,
   and retained lesson reference. Click **Reuse retained example** for each example
   worth preserving. The first example starts the workbench with a blank new
   adverse case; subsequent examples fill the same workbench.
2. Supply a fresh output under the proposed revised guidance for each remembered
   example. It starts blank. Its old input, baseline, name and checks are read-only;
   remove it explicitly if it is unsuitable, then author a separate manual case.
3. Add a distinct new adverse example and supply both outputs and checks. Edit
   guidance and rationale, compare, correct any regression, and compare again.
4. Stage the exact revision and use the ordinary **Save revision for review**
   action. The report carries each remembered example's exact source lesson,
   captured named-review receipts and source case identity. The current accepted
   lesson and original outputs are unchanged. Existing named-human acceptance is
   still required before the revised guidance becomes current.
5. After that version is accepted and reopened, its newly successful outputs can
   become remembered baselines for another correction. The prior record remains
   the source of the earlier case history; reports do not recursively copy it.

## Which experience can be reused

Only the exact currently accepted lesson being revised is eligible. The supported
sources are its `outcome_lesson.rehearsed.v1` single-example payload and a v2
revision containing the exact existing contrasting-case report format. The reader
checks the duplicated lesson, predecessor, guidance and report identities and
recomputes stored literal results. Ordinary manual revisions without that report
remain available for manual rehearsal, without invented examples. Historical or
unrelated lesson outputs are not presumed to be current-guidance baselines.

The workbench keeps its 2–6-case envelope. Up to five remembered examples leave
space for a new adverse case. Duplicate example inputs are refused. Legacy text
larger than the current 8,192-character input/output or 256-character fragment
limits, or fragments whose line-based representation would alter them, appear as
unavailable with an explanation; nothing is truncated. The original record remains
readable. All imported supported text, including whitespace and Unicode, is exact.

Remembered outputs, case labels and new outputs remain operator reports. Literal
matches cannot prove factual correctness, causation, generalization or that a
model actually ran. Reuse does not create a new review, authority, runtime action
or store schema. The source lesson's named review is attribution, not a fresh
verification of the new output.

## Interruptions and recovery

- Drafts stay in this tab. The ordinary successfully saved revision is durable in
  the existing Book journal; unsaved cases are lost on reload.
- Current lesson, head, accepted reviews, revision fields and owner identity are
  bound by the existing workbench. Changed history or detached callbacks cannot
  reuse an old control into another revision or a discarded/restarted rehearsal.
- Repeated reuse does not duplicate a case. Pending save suppresses changes.
  Editing a fresh output invalidates its preview; fresh comparison is required.
- An unavailable source or rejected input preserves the existing cases. Remove
  or discard is explicit. No accepted record is rewritten.

## Qualification

The focused runner supports Node-only production extraction/reducer tests, and
`BOOK_MOON_CHECK=1 BOOK_TEST_ROOT=/absolute/owned/r601/worker` adds a standalone
current-UI frozen JS check, controller/render/save-dispatch tests, actual compiled
rendered callbacks, interface generation and changed-file formatting checks.
Pass the exact source directory as its positional argument; the compiler workspace
is serialized and refreshed from that directory. It has a 35 MB compiler-target allowance (36 MB gross including its reused UI and
dependency view) and must
be reused for author/reviewer replay rather than duplicated.

These are local synthetic development checks. Native host mutation, actual named
user review, integrated sibling-workspace execution, a real browser, provider/model
execution and production release qualification are not claimed.
