# MoonBook responsibility and testability

MoonBook is the domain pack for durable book truth. Its Rabbita release also
contains the Bookkeeper operator journey; it does not create a second agent or
orchestration runtime.

| Responsibility | Owner | Primary evidence | Proportional verification |
| --- | --- | --- | --- |
| Book, wiki, source and accepted-knowledge state | `core/`, `wiki/` | rendered pages, source provenance and review records | targeted `moon test wiki` plus renderer fixture |
| Three-Gap records and named-human review | `bookkeeper/`, `bookkeeper_store/` | append-only journal, snapshot and UI projection | targeted Bookkeeper tests and replay comparison |
| Pack and MoonFlow boundary | `packhost/`, `flow_attestor/`, adapters | exact schema identities, digests, authority and receipts | adapter execute/reconcile tests |
| Ordinary operator journey | `ui/rabbita-book/main/` | visible Select → Authorize → Review → Verify states | focused Rabbita assertions and the UI-to-UI record |
| Agent execution | MoonClaw | MoonClaw journal and result receipt | excluded from MoonBook implementation tests |

The UI keeps evidence JSON, raw operations and diagnostics behind progressive
disclosure. Missing reviewer authority is a blocked state with a CLI recovery
instruction; the browser cannot install its own authority.

Authoritative references:

- [Product contract](PRODUCT_CONTRACT.md)
- [Executable-book boundary](EXECUTABLE_BOOK_BOUNDARY.md)
- [Bookkeeper closure](BOOKKEEPER_OUTCOME_CLOSURE.md)
- [UI-to-UI qualification](qualification/UI_TO_UI_USE_CASES.md)

For a UI-only second-iteration slice, run the Rabbita module check and focused
journey test once after the complete edit. The repository-wide native suite
remains a release gate.
