# Later-task failure → narrower lesson proposal

MoonBook can now turn an operator-reported counterexample into an editable, review-pending scope revision without reconstructing the original guidance. This is a human-led learning workflow, not autonomous improvement.

## Use it

1. In Bookkeeper, select a saved lesson and open its version history. Select the current, named-human accepted version.
2. Open **Learn from a later-task failure · narrow lesson scope** and start a failure case.
3. Supply the exact later task ID/version/digest, an evidence reference, the observed failure, and actual task conditions. No external evidence is fetched; these are unverified operator statements.
4. Choose a distinguishing condition actually present in that task, and an unused lesson version.
5. Preview the complete new do-not-use conditions. Original required conditions and guidance remain unchanged.
6. Stage the narrowed revision. The normal revision editor now contains the original lesson plus the additional exclusion and a structured reason retaining the task, observation and evidence reference.
7. Inspect or edit that draft, then use **Save revision for review** and the existing named-human review controls. Staging does not save, accept, select or execute anything.

## What is new

The earlier rehearsal compares supplied before/after text, approach comparison chooses between reviewed lessons, and scope interview discovers applicability for a new task. This flow instead closes an adverse-use loop: a later failure inside the accepted scope becomes a concrete proposal to exclude that context, preserving the original lesson and its accepted history. It is connected to the existing version-history payload and host's predecessor/review checks.

## Bounded behavior

- A task outside the original required scope or already excluded cannot produce a narrowing proposal.
- Excluding a required condition with the same value would disable every applicable task, so it is refused.
- A condition not present in the supplied failure case cannot be excluded.
- Existing exclusions are preserved. Duplicate exclusion names require the ordinary revision editor because its broader meaning needs review.
- History changes, request changes, changing selected versions, or another revision draft invalidate staging. Edits require a new preview.
- All drafts are tab-local. Discarding deletes only the unsaved local failure case.
- Each field is limited to 8,192 characters, with at most 40 unique task conditions; oversized data is rejected, never silently truncated.
- Evidence references and observations are retained verbatim in the proposal reason with factual_review_complete=false and model_executed=false. The reference is not a verified linked outcome record.
- Passing scope checks does not establish factual accuracy, causality, effectiveness on remaining tasks, RSI, or new authority. Host review remains mandatory.

## Evidence and gaps

The focused runner executes the production JavaScript FFI planner directly with Node. Setting BOOK_MOON_CHECK=1 also checks the complete standalone Rabbita UI and runs compiled state/view integration and preserved scope/comparison/history tests with the pinned toolchain and cached exact dependency. It uses a private HOME/XDG and external target directory; no native build, provider, dependency update or browser is involved.

The default runner is cwd-independent: bash /absolute/r586/run-focused.sh [/absolute/source]. The compiled mode uses BOOK_MOON_CHECK=1 and optionally BOOK_TEST_ROOT=/absolute/path/under/r586. Reuse the existing focused-check directory for independent replay to avoid another build allocation. It recopies the chosen source, checks it, and runs tests; it does not rewrite the selected source. Formatting runs in that disposable check copy.

Real browser/layout/accessibility behavior, native host end-to-end persistence, live runtime/provider integration and release qualification remain unrun. Root workspace qualification remains blocked by unavailable MoonLeaf sources. No remote, Mac, release or production changes were made.
