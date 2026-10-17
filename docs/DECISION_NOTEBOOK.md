# Decision notebook from prior experiences

The Reviewed lessons section now has a planning notebook. It collects exact
reader snapshots from distinct prior lessons and separates them from your
application notes, proposed decision, and uncertainty. It never creates a task,
accepts a claim, changes the selected lesson version, or activates work.

## Complete user path

1. Open Bookkeeper's **Reviewed lessons** and browse or search. Each currently
   reviewed card has **Add experience to decision notebook**. Add another lesson
   from the same or a different search. Up to twelve exact captures are supported.
2. Write your decision question. For each experience, inspect required scope,
   do-not-use conditions, captured reviewer, outcome and assessment references.
   Mark its role **consider**, **tension**, or **context**, and write an application
   note explaining what it does and does not justify for this decision.
3. Move experiences up/down or remove them. Guidance and scope remain exact
   captured text. Conflicting lessons stay separate; their order is authored,
   and no majority vote or consensus is inferred.
4. Write the proposed decision and its reasoning, plus uncertainty, contradictions
   and the next check. These are your unreviewed planning judgments.
5. Choose **Reload all reviewed lessons to recheck captures**. This deliberately
   clears the search and runs the existing read-only browse endpoint. Exact
   matches, changed family/version, excluded guidance and absent/unknown captures
   are distinguished. No capture or note is overwritten by rechecking.
6. Choose **Download editable notebook JSON** before closing the tab. After reload,
   open that file as text and paste it under **Resume a downloaded notebook**.
   Preview the complete replacement; choose **Replace open notebook with this
   preview** explicitly. Download existing work first if you need both drafts.
7. Choose **Download offline decision notebook HTML** for a readable, printable
   standalone output. It requires a question and at least one experience. The
   output has local navigation, unchanged scopes and exact outcome/review
   references. It contains no active scripts or external resources.

## Boundaries and interruption behavior

- The current tab is not persistent storage. Only an explicitly downloaded JSON
  file restores the draft; HTML is for reading and printing.
- A file's captured reviewer and digest strings do not authenticate the file.
  Imported captures remain unverified until compared with host results. Even
  matching live results are current only at their last load, not indefinitely.
- The notebook stores a curated reader projection: guidance, scope, lesson and
  outcome/assessment/review references, reviewer and review summary. It does not
  export raw record payloads, authority grants, task handoffs or source bytes.
- Downloaded files may contain private notes and guidance. Share only with the
  intended readers. No file is transmitted to a third-party service by this UI.
- Drafts are bounded to 1 MiB UTF-8, twelve captures and 16,384 UTF-16 code units
  per authored field. Invalid, duplicate or unsupported archives preserve open
  work. Content is never silently truncated.
- Exact notebook revisions bind reorder/remove/edit/restore actions. Detached
  callbacks cannot edit a different row after reorder or replace newer work.
  Search request identity binds selection. Repeated selection is idempotent.
- Download failures retain all draft text. Browser download acceptance is not
  proof that the file was saved to disk; inspect browser downloads.

## Focused qualification

The compiled MoonBit JS tests exercise editing, multi-experience composition,
unchanged Bookkeeper records, exact cold restore, stale and malformed inputs,
mounted rendering, HTML escaping and production Blob bytes/cleanup. This does
not qualify live browser interactions, host authentication, accepted knowledge,
generalized model improvement, deployed service operation or customer outcomes.

PRD contribution: only the later-decision slice of MOONBOOK-R02. The notebook
exposes captured reviewed guidance and its applicability while preserving the
original outcome references. It does not qualify the complete commitment, task,
artifact or customer-identity intake path, nor missing/conflicting-receipt
closure. Timestamp producer-to-Town decoding (MOONBOOK-B03) and outcome
submit/close or reviewer promotion (MOONBOOK-B05) are not exercised here.

The full UI aggregate remains unqualified because native integration fixture
setup is missing: an unset `MOONBOOK_COLLECTION_WIRE` makes the fixture reader
return an empty string, causing the observed JSON EOF. The later archive test
also requires `MOONBOOK_ARCHIVE_EVIDENCE`. This reproduces on the mapped baseline
and is not evidence of a native runtime defect. Required broader gates remain
blocking until their real fixture prerequisites and executions are verified.
