# Import a bounded CSV teaching-case set

An operator who already has several observed examples can paste one dataset into
**Lesson version history → Revise this accepted version → Start contrasting-case
rehearsal → Import a CSV teaching-case set**. This removes per-field copying while
retaining the manual R597 rehearsal and R601 remembered-baseline workflows.

## Complete operator journey

1. Open a revision of the exact accepted-current lesson. Set the intended scope in
   the ordinary revision editor, then start or continue the local rehearsal.
2. Paste the complete bounded CSV text. Choose **Preview exact CSV cases**.
   Preview shows every parsed field as escaped JSON, so quotes, whitespace, CRLF
   and embedded line breaks remain inspectable. Semantic validation reports all
   bounded row/field errors; malformed syntax reports the rejecting location.
   No cases change during preview, including when the CSV is invalid.
3. Inspect the placement plan. **Import exact previewed cases** fills only wholly
   empty same-kind manual slots, then appends new cases with stable IDs. It never
   overwrites an authored field or a retained example. An invalid or over-capacity
   batch is rejected atomically; no valid-looking subset is imported.
4. Edit the imported cases normally. An empty revised-output field is allowed at
   intake so a later correction can supply a fresh output. Comparison still needs
   both outputs, a useful case and an adverse case. Rehearse the revised guidance,
   inspect original/revised literal-check differences, and correct regressions.
5. Compare, then **Stage exact guidance and operator-reported rationale**. Save the
   ordinary revision for named-human review using the existing revision contract.
   Accepted-current guidance and its review history remain unchanged by intake,
   comparison or staging. This intake adds no new acceptance or execution route.

## CSV contract

The header has exactly these seven case-sensitive fields in this exact order:

```csv
kind,name,input,original,revised,required,forbidden
```

- `kind`: exactly `useful` or `adverse`; these are operator labels.
- `name`: nonblank case name, at most 256 UTF-16 code units.
- `input`, `original`: nonblank exact example and observed original output, each
  at most 8192 UTF-16 code units.
- `revised`: exact supplied revised output, at most 8192 UTF-16 code units, or an
  empty field to author later. Whitespace-only text is rejected.
- `required`, `forbidden`: newline-separated literal fragments, each field at most
  5140 UTF-16 code units. Use 1–20 total fragments per case, at most 256 UTF-16 code
  units per fragment, with no empty lines or surrounding whitespace. Duplicates
  within a list and required fragments containing forbidden fragments are rejected.

Example (the adverse required field contains a quoted embedded newline):

```csv
kind,name,input,original,revised,required,forbidden
useful,Keep citation,Routine task,Source: correct,Source: correct,Source:,invented
adverse,State uncertainty,Ambiguous task,invented,Source: uncertainty,"Source:
uncertainty",invented
```

The parser supports one optional leading Unicode BOM, LF or CRLF record endings,
a final record without a newline, quoted commas and multiline text, and doubled
quotes (`""`) inside quoted fields. It preserves decoded fields exactly; it does
not normalize Unicode, trim values, synthesize checks, evaluate spreadsheet
formulas, or execute markup. Formula-looking text is ordinary text. Fields with
surrounding whitespace remain exact except fragment whitespace is rejected by
contract. Embedded CRLF remains CRLF; literal checks use the existing line-list
semantics. JSON display exposes the actual values without interpreting HTML.

Rejecting cases include unknown, reordered, duplicated, extra or spaced headers;
missing/extra fields; bare CR; unsupported ASCII controls (TAB is allowed); quotes
inside unquoted fields; text after a closing quote; and unterminated quotations.
Extra blank records are rejected instead of silently skipped. Inputs duplicated
within the CSV or existing rehearsal are rejected under the same trimmed-input
identity used by comparison. One terminal newline is permitted.

## Bounds, interruption and recovery

The complete pasted string is limited to 131072 UTF-8 bytes, including a leading
BOM, with well-formed Unicode. There are 1–6 data records and at most six total
rehearsal cases after import. Limits reject whole inputs, never truncate. An
oversized/invalid-Unicode edit retains the prior CSV text and all cases, but clears
its preview and sets a visible error: a fresh valid paste is required before
preview or import. An already-rendered old Import callback cannot remain armed.

Any case/guidance/rationale/CSV edit, add/remove/reuse, comparison, staging or CSV
clear removes the prior CSV preview. Refreshing history starts a new request
generation: even if that request fails and history is unchanged, the previous
CSV preview cannot import until the operator previews again. Pending requests,
stale history/scope/review bindings, old draft revisions and discarded/restarted
rehearsal epochs all block detached callbacks. Import reparses the complete text
and verifies the exact preview and placement again before a single atomic change.

**Clear CSV intake** clears only the CSV text and preview, keeping cases and
revision text. **Discard local rehearsal** retains ordinary revision fields,
including already-staged text, as before. The CSV and rehearsal are tab-local;
a browser reload or closed tab loses unsaved local work. No file bytes are loaded
or uploaded by this paste-only intake, so it cannot attest that a copied CSV is
identical to a source file or detect text omitted before the paste.

## Evidence and qualification boundary

Imported examples, outputs and labels are operator-reported test observations.
Literal checks do not establish a model run, factual review, generalized learning,
customer outcome, or permission. Existing staging retains false
`model_executed`, `factual_review_complete`, and `activation_authorized` flags.
Remembered accepted-current baselines remain immutable and attributed; importing
new data never grants it retained-case status or new authority.

This is a bounded authoring contribution toward MOONBOOK-UC05, MOONBOOK-F02/F03
and MOONBOOK-R02/R03, not a qualification of all learning, native journal review,
multi-user collaboration, providers or production deployment. Focused tests cover
the production embedded-JS parser/reducer, compiled MoonBit controller/render/save
path, and actual compiled rendered input/click callbacks without a live browser.

The full standalone UI test invocation is a separate, broader gate: its existing
portable collection test needs `MOONBOOK_COLLECTION_WIRE` from native HTTP fixture
execution and `MOONBOOK_ARCHIVE_EVIDENCE` for output. Without that fixture, both the
unchanged f7d28e4 baseline and this change abort while parsing an empty native wire
at `book_collection_archive_wbtest.mbt:153`. The focused JS/UI checks do not claim
this broad gate, native host mutation or real named-human review passed. No native
fixture is fabricated and no native build is performed for this intake.
