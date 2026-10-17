# Bring observed responses into a fixed practice workbook

MoonBook helps an agent learn from retained experience. The existing practice
workbook keeps exact lessons and tasks; this addition avoids retyping separately
recorded responses into each exercise. It imports observations only.

1. Open a reviewed teaching brief, write tasks, and start practice as usual.
2. Expand **Import recorded practice responses from CSV**. Copy the displayed
   template to a spreadsheet or CSV editor. Preserve the first six columns:
   `round,practice,record_id,record_version,record_digest,exercise`.
3. Fill `before,after,feedback,next_practice`. Keep exact response text. Quoted
   CSV fields may contain commas, newlines and doubled quotes. Export UTF-8 CSV.
4. Paste the CSV and click **Preview recorded responses CSV**. Open **Inspect
   and apply a CSV preview, or resume saved workbook JSON** to inspect the full
   replacement. Click **Replace local practice with this preview** to apply.
5. Review/edit observations in their normal controls. Save the workbook JSON
   before reloading. **Prepare practice … for correction** leads into the
   existing correction rehearsal and named-human review path.

You can import just selected rows. Rows match the current round, one-based
exercise position, exact lesson record/version/digest and the complete task.
Reordered, stale or duplicate identities are refused. A blank response cell
keeps the existing observation. A different nonblank existing response is never
overwritten by CSV; edit it explicitly in the workbook. Identical re-imports are
safe. Any row failure refuses the entire preview. Editing the workbook or intake
clears the preview through the existing reducer. Sealed rounds are unchanged.

The input limit is 1 MiB UTF-8, with at most one row per current exercise and
16384 characters per observation field. The decoded workbook must still satisfy
its existing bounds. No rows are truncated. Source labels and responses remain
operator-supplied; this does not run a model, establish response correctness,
accept an improvement, or authorize activation.

Focused tests: `scripts/practice-response-csv.test.mjs` exercises the exact
embedded parser; `main/lesson_practice_csv_wbtest.mbt` exercises compiled preview,
explicit application, cold JSON decode, fixed captures and actual view callbacks.
The full frontend still requires its separately qualified host/dependency and
browser path. Browser interaction, native collection fixture, real learning
efficacy and full release gates remain unqualified.
