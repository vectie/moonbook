# Product outcomes with retained sources

The Product outcomes panel accepts explicitly authored completed product work without requiring a MoonProj task. The existing task-bound outcome import still requires its exact accepted Proj task/report and is unchanged.

1. In the producing product, export an outcome package with its original source bytes and operator-authored interpretation
2. In Book → Product outcomes, import, inspect the interpretation, gap statements and original sources, then save for review
3. Open the exact deliverable in the existing Book review controls and select an active named reviewer. Prepare acceptance/rejection as usual, or use **Prepare revision request** / **Prepare escalation** beside this selected product outcome to defer acceptance. Check the reason, then choose **Save governed review**. Existing named-human authority is required; all four decisions keep their current meanings
4. Refresh the selected outcome. After deliverable acceptance, explicitly continue to the existing Three-Gap assessment review. Importing the same file never advances that gate
5. Download a freshly read disposition receipt and import it in the source product to reopen the original work. Rejected or deferred work retains all source bytes

The initial implemented producer is MoonMoon. Its submission is a completed deterministic digital simulation plus a user's interpretation. Simulator acceptance, artifact validity and the digital reviewer do not establish Book acceptance, physical performance, customer acceptance, cash or capability activation. The source dossier includes robot, terrain, input, replay and calibration assumptions. Book retains evidence and owns its decisions; it does not recompute the simulation or qualify those assumptions.

## Portable format

`moonbook.product-outcome-package.v1` carries `package_digest` (SHA-256 of UTF-8 bytes) and exact `payload_json`. The payload contains the unchanged existing `ProductOutcomeSubmission` and one retained text artifact for every exact evidence reference, with `reference`, `text` and `media_type`. Book verifies the outer bytes and every evidence digest before writing. The payload limit is 8 MiB; the browser file limit is 16 MiB to allow JSON string escaping.

The source package is stored as a non-activating `product.outcome_package` ingress envelope linked to the existing deliverable and result. No new acceptance stage or authority grant is created. Package or submission changes cannot replace a previously saved exact identity; the producer must export a distinct identity. Exact duplicate imports preserve records and review history. Read/list operations do not advance the journal. An interrupted intake is recoverable by retrying the original package.

`moonbook.product-outcome-readback.v1` contains the original package, exact progress and Book review receipts. It is a historical local observation, not a signed current-status assertion. Reopen Book and refresh before relying on current review state. Returning/importing this file performs no automatic transport, acceptance, activation or external action.

## Existing host and CLI

The general routes are `product-import`, `product-list`, `product-read`, and `product-continue` under `/api/bookkeeper/lessons/`. The host chooses the Book root. List takes an empty object; read/continue take `submission` containing the exact record reference. Import takes the package. The CLI crosses the same handler:

```text
moon run --target native cmd/outcome_lessons -- product-import <book-root> <package.json>
moon run --target native cmd/outcome_lessons -- product-list <book-root> <empty-object.json>
moon run --target native cmd/outcome_lessons -- product-read <book-root> <reference-request.json>
moon run --target native cmd/outcome_lessons -- product-continue <book-root> <reference-request.json>
```

CLI responses have the existing operation wrapper; its `result` is the portable readback that the UI downloads. There is no fixture-review command in production. Tests install reviewer authority only in isolated fixture stores.

## Verification scope

Targeted store tests, reducer/render tests and actual source-file/CLI crossings are cloud implementation checks. No live browser, installed app, Mac, external provider, hardware, customer transaction or production reviewer is exercised. MoonLib is unchanged: existing hashing, JSON and filesystem primitives suffice and no shared domain authority is introduced.
