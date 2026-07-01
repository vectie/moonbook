# Executable Book Boundary

Last checked: 2026-06-18.

MoonBook is the durable executable book. It owns the filesystem truth that both
human-language and executable/code-language editing operate on.

## Standalone Project Rule

MoonBook must run as its own checkout. It may persist artifacts produced by external runtimes, but it must not require adjacent MoonClaw, Moontown, or Moondesk source checkouts to build, test, serve, or edit books. Cross-project integration should use configured paths, published packages, or runtime protocols.

## Product Model

```text
MoonBook = executable book
MoonWiki = human-language book editing
MoonCode = executable/code-language book editing
MoonClaw = bounded execution engine
Moontown = coordination network for books
Bookkeeper = acceptance gate
```

MoonBook should not become an agent runtime. It stores accepted knowledge,
accepted code, sources, evidence, review receipts, generated sites, package
manifests, and durable outputs.

## Durable Layout

A mature executable book can contain both prose and executable behavior:

```text
<book>/
  book.json
  raw/
    inbox/
    bootstrap/
    extracted/
    analysis-runs/
  wiki/
    index.md
    sources/
    methods/
    reviews/
    history/
  skills/
  schemas/
  tools/
  apps/
  portable/app-tool/
  site/generated/
  .moonsuite/products/mooncode/sessions/
```

MoonBook already strongly owns the Wiki side: `wiki init`, `wiki ingest`,
`wiki query`, `wiki review`, `wiki lint`, `raw/bootstrap`, seeded skills,
standing-watch decisions, and review queues.

The next documentation and template hardening is to make the Code side equally
first-class: book-owned `tools/`, `apps/`, package manifests, test evidence,
MoonCode review receipts, and executable artifact promotion should be described
as normal MoonBook surfaces, not only as Moondesk or MoonClaw side effects.

## Boundary Rules

- MoonBook owns durable truth and accepted artifacts.
- MoonClaw may stage raw results, code diffs, package proof, and runtime events.
- Bookkeeper/user review decides what is accepted.
- Moontown schedules and coordinates book work, but does not own topic memory.
- Moondesk projects and edits the book, but should not own book semantics.

## Portable Event Contract

MoonBook publishes meaningful book changes with a project-local JSON contract
named `moonbook.executable_event.v1`. This is not a shared source dependency:
other projects may mirror the same JSON fields, but MoonBook remains runnable as
its own checkout.

Core fields:

```json
{
  "protocol": "moonbook.executable_event.v1",
  "id": "book-event-<book-id>-<evidence-or-result-id>",
  "source": "moonbook",
  "book_id": "<book-id>",
  "result_id": "<result-id>",
  "run_id": "<optional-runtime-run-id>",
  "event_type": "knowledge_accepted | review_required",
  "accepted": true,
  "requires_review": false,
  "notify_town": true,
  "summary": "<operator-readable summary>",
  "artifacts": ["wiki/...", "tools/...", "apps/..."],
  "evidence_id": "<optional-evidence-id>",
  "review_path": "<optional-review-page>",
  "lifecycle_proof": {
    "contract_id": "mooncode-executable-book-lifecycle.v1",
    "owner": "moonclaw",
    "session_id": "<runtime-session-id>",
    "book_root": "<book-root>",
    "ready": false,
    "status": "blocked",
    "completed_step_count": 7,
    "step_count": 9,
    "blocked_step_count": 2,
    "first_blocker_id": "package_output",
    "first_blocker_label": "Package output",
    "first_blocker_evidence": "package results 0, package events 0"
  }
}
```

`run_id`, `evidence_id`, `review_path`, and `lifecycle_proof` are optional and
may be omitted when absent.

MoonCode producers include their native `command_id` and `result_id` on the
surrounding envelope or executable event when available. The nested
`BookResult` uses `result_id` directly; MoonCode result persistence is not
adapted through generic MoonClaw task identity.

If a MoonCode/MoonClaw envelope includes `executable_book_lifecycle`, MoonBook
persists it as `lifecycle_proof` on the executable event. The proof is book-owned
evidence after persistence: consumers must read it from
`.moonbook/events/latest.json` or the CLI persist response, not from transient
runtime sidecars. Lifecycle proof does not by itself accept knowledge; the event
still uses `knowledge_accepted` or `review_required` to express Bookkeeper state.

`knowledge_accepted` means the book changed without requiring another
Bookkeeper pass. `review_required` means MoonBook stored durable artifacts, but
the result must not be treated as accepted knowledge or executable code until
review accepts it.

Every `wiki extension persist` writes the event as book-owned evidence:

```text
<book>/.moonbook/events/<event-id>.json
<book>/.moonbook/events/latest.json
```

The CLI persist response includes `executable_event_path`,
`latest_executable_event_path`, and `executable_event`. Downstream projects
should consume that returned event instead of reconstructing accepted/review
state from pages, logs, or sidecar hints.

## Native Knowledge Bundle

MoonBook also publishes a compact product contract named
`moonbook.knowledge_bundle.v1`. This is the stable read model for Moondesk,
Moontown, MoonClaw clients, and future suite tools when they need current book
state without scraping markdown or rendered HTML.

The bundle contains:

- current summary and health
- typed durable page records
- source quality and review status
- outbound links
- a graph of durable page relationships
- the executable event protocol id used for result notifications

`moonbook wiki bundle [root]` writes the standalone package under
`book/knowledge/`. Build/serve projection also writes
`book/site/generated/knowledge-bundle.json` and `graph.json`.

This is a MoonBook-native feature. The value is a clear, small, inspectable
contract that preserves MoonBook's richer executable-book semantics.

## Native Book State Snapshot

MoonBook also publishes `moonbook.book_state.v1`, a higher-level state snapshot
for consumers that need one file instead of multiple probes.

`moonbook wiki extension state [root]` returns the snapshot as JSON for runtime
consumers. `moonbook wiki state [root]` writes `.moonbook/state.json` for human
or file-based inspection. Build/serve projection also writes
`book/site/generated/book-state.json`.

The snapshot contains:

- catalog identity
- current summary and health
- the embedded `moonbook.knowledge_bundle.v1`
- the latest executable-book event when present
- canonical paths for the review queue, generated graph, generated bundle, and
  latest event

Suite tools should prefer this snapshot for dashboards and routing decisions,
then drill into the knowledge bundle only when they need page-level records or
graph edges. They should not scrape `wiki/SUMMARY.md`, generated site files,
review pages, and event files independently when the snapshot is available.
