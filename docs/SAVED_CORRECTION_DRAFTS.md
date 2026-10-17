# Continue an experience-led correction after reload

MoonBook's existing lesson history connects retained experience to the next
reviewed guidance version. A contrasting-case correction may take several
sessions: importing a Claw observed-case CSV, supplying revised outputs, checking
a known-useful baseline, and explaining an adverse case. The **Keep this
correction for later** controls preserve that unfinished authoring explicitly.

## Connected journey

1. Open **Lesson version history**, select its current named-human accepted
   version, and choose **Revise this accepted version**.
2. Start a contrasting-case rehearsal. Edit guidance, rationale and cases, reuse
   retained examples, or import the existing observed-case CSV. Incomplete cases
   can be saved; they still must pass ordinary validation before staging.
3. Choose **Save correction on this browser**. Success is reported only after
   the saved bytes have been read back. No automatic saving occurs. Shared-device
   privacy and the browser-data retention boundary are shown beside the controls.
4. After closing the change, reloading or reopening this browser, return to the
   same lesson's current version and start a fresh revision. **Check saved
   correction** shows its title, case count, and inspectable authored text.
5. **Resume saved correction into this fresh revision** restores the ordinary
   fields, exact authored examples, rehearsal guidance/rationale and pasted CSV.
   It refuses to replace an already-started rehearsal or independently edited
   revision. The current history, record, selection and reviews must still match.
6. Compare the cases and stage the exact revised guidance again. A saved
   comparison or staged state never survives recovery. Save the ordinary
   revision for named-human review; after acceptance, the existing exact-version
   next-task selection remains the only reuse path.

Saving again after checking a copy uses **Replace checked browser copy with this
correction**. A different tab's changed bytes block replacement, resume and
removal until checked again. This is a best-effort synchronous browser-storage
check, not a cross-tab transactional lock or multi-device service.

## Interruption and retention

- Browser drafts are keyed by the Book's existing workspace source path and
  lesson identity, inside the current browser origin. Another Book or lesson
  cannot accidentally resume them. Moving the Book or changing browser origin
  does not migrate the copy.
- Closing a draft and discarding a rehearsal leave a saved browser copy alone.
  **Remove checked browser copy · keep open work** deletes only that checked
  copy. Active fields, cases, accepted guidance and host review records remain.
- Changed accepted history prevents automatic resume, but the saved authored
  text remains inspectable and copyable for preparing a separate correction.
  A stale copy is never silently rebound to a newer lesson.
- Failed storage, quota, unsupported schema, malformed/oversized data and
  changed saved bytes keep the active work. Failed reads never claim that a
  correction was restored. Corrupt copies may be explicitly removed after check.
- Storage is not encrypted or a backup. Other users or scripts on the same
  browser origin can access it. Clearing browser data removes it; it does not
  enter an agent bundle, host journal or cross-device synchronization.

## Boundaries and limits

The versioned local envelope keeps author text and an exact accepted-source
comparison string. That string is a stale-draft guard, not a signed identity or
authority grant. It never restores the source record into host state. Every
retained example's immutable baseline is checked against the current lesson
before resume. Unknown envelope/rehearsal fields are rejected.

At most 2–6 cases are stored. Existing per-case and rehearsal text limits apply:
8192 UTF-16 code units for guidance, rationale, input and outputs; 256 for case
names; 5140 per check-list field. Pasted CSV is capped at 131072 characters here
and its existing parser additionally enforces the UTF-8 byte limit. Ordinary
revision fields are capped at 8192 each, except the staged reason at 262144.
The accepted-source comparison string is capped at 262144; the whole envelope
at 524288. Values are rejected, never truncated.

No reviewer, authority, grant, request identity, acceptance, comparison preview,
or staged flag is restored from local storage. Resume allocates fresh ownership
from the ordinary current revision. Operator-supplied outputs remain reports;
only explicit literal matches are calculated in the existing rehearsal.

This is a narrow interruption-recovery contribution to MOONBOOK-UC05 and
MOONBOOK-F03 / MOONBOOK-R03. It does not qualify capability promotion, full
Three-Gap closure, rollback, native host persistence or live provider learning.

## Verification

The Node storage tests execute the production embedded function with a bounded
in-memory storage substitute. Compiled MoonBit tests exercise actual controller,
rendering, cold-model recovery, compare/stage and ordinary revision payload.
The compiled callback runner exercises real rendered controls, stale callbacks,
repeat actions and storage errors. These are not a live-browser qualification.

```sh
node --test scripts/lesson-correction-draft.test.mjs
moon test main/lesson_correction_draft_wbtest.mbt --target js
BOOK_BUNDLE=/absolute/test/main.whitebox_test.js node --test scripts/lesson-revision-rehearsal-callbacks.test.cjs
```
