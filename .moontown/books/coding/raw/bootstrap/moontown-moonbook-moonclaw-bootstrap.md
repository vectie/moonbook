# Bootstrap Packet: Moontown, MoonBook, and MoonClaw

## Scope

Bounded fan-out gather across three local repos for coding-book bootstrap.

- lane 1: repo-doc discovery
- lane 2: implementation evidence
- lane 3: architecture and topology notes
- lane 4: cross-project linkage

## Lane 1: Repo-doc discovery

### Sources inspected

- `/Users/kq/Workspace/moontown/README.md`
- `/Users/kq/Workspace/moonbook/README.md`
- `/Users/kq/Workspace/moonclaw/README.md`
- `/Users/kq/Workspace/moontown/moon.mod.json`
- `/Users/kq/Workspace/moonbook/moon.mod.json`
- `/Users/kq/Workspace/moonclaw/moon.mod.json`

### Evidence

- `moontown` presents itself as a town-level orchestration layer above multiple `moonbook` domains and multiple `moonclaw` runtimes.
- `moonbook` presents itself as a MoonBit rewrite of `mdBook` extended into a persistent wiki-maintainer workspace with raw-first bootstrap under `raw/bootstrap/`.
- `moonclaw` presents itself as an agent runtime with gateway, jobs, memory, run workspaces, and external proposal packet import.
- The module manifests identify distinct packages: `vectie/moontown`, `vectie/moonbook`, and `vectie/moonclaw`.

### Candidate durable source pages

- `wiki/sources/moontown-repo-overview.md`
- `wiki/sources/moonbook-repo-overview.md`
- `wiki/sources/moonclaw-repo-overview.md`

### Lane blocker

- None. README-level sources are substantive enough for durable source pages.

## Lane 2: Implementation evidence

### Sources inspected

- `/Users/kq/Workspace/moontown/cmd/main/main.mbt`
- `/Users/kq/Workspace/moontown/roles/mayor.mbt`
- `/Users/kq/Workspace/moontown/adapters/moonbook/client.mbt`
- `/Users/kq/Workspace/moontown/adapters/moonclaw/client.mbt`
- `/Users/kq/Workspace/moonbook/wiki/bookapi.mbt`
- `/Users/kq/Workspace/moonbook/wiki/ingest.mbt`
- `/Users/kq/Workspace/moonclaw/cmd/main/main.mbt`

### Evidence

- `moontown/cmd/main/main.mbt` routes `run` requests into `@moontown.render_goal_run(...)` and otherwise loads a demo dashboard, showing a CLI entrypoint for town execution and visualization.
- `moontown/roles/mayor.mbt` maps book task kinds like `ingest`, `review`, `planning`, `analysis`, and `synthesis` onto MoonClaw profiles such as `wiki_ingest_controller`, `wiki_lint_controller`, and `wiki_query_controller`.
- `moontown/roles/mayor.mbt` prepares keeper packets from MoonBook worker context bundles, indicating Moontown depends on MoonBook for per-book task context and on MoonClaw for execution packets.
- `moonbook/wiki/bookapi.mbt` and `moonbook/wiki/ingest.mbt` define a four-phase ingest flow with `bootstrap_gather`, `source_materialize`, `knowledge_revise`, and `review_finalize` semantics.
- `moonclaw/cmd/main/main.mbt` exposes `gateway`, `proposal`, `exec`, `acp`, and interactive surfaces, showing MoonClaw is the runtime side rather than the durable wiki owner.

### Candidate entities

- `Moontown`
- `MoonBook`
- `MoonClaw`
- `Mayor`
- `Keeper`

### Candidate concepts

- `town-to-book orchestration`
- `raw-first bootstrap ingest`
- `external proposal packet lifecycle`
- `book-harness boundary`

### Lane blocker

- None. The implementation slice confirms concrete boundaries and roles.

## Lane 3: Architecture and topology notes

### Sources inspected

- `/Users/kq/Workspace/moontown/docs/ARCHITECTURE.md`
- `/Users/kq/Workspace/moonbook/docs/SYSTEM_ARCHITECTURE.md`
- `/Users/kq/Workspace/moonbook/docs/WIKI_WORKFLOW.md`
- `/Users/kq/Workspace/moonbook/docs/KEEPER_CALL_CHAIN.md`

### Evidence

- `moontown/docs/ARCHITECTURE.md` describes the intended stack as `moontown -> moonbook -> moonclaw`.
- `moonbook/docs/SYSTEM_ARCHITECTURE.md` states MoonBook owns the persistent wiki workspace and keeps runtime-specific orchestration outside core via extension packs.
- `moonbook/docs/WIKI_WORKFLOW.md` states ingest stages generated packets under `raw/bootstrap/` before source pages, entity pages, concept pages, and synthesis pages are revised.
- `moonbook/docs/KEEPER_CALL_CHAIN.md` says MoonBook emits phase intent and MoonClaw executes bounded workers while preserving the semantic owner boundary.

### Topology notes

- Moontown sits above books and delegates domain-local work into MoonBook book workspaces.
- MoonBook sits between orchestration and execution, owning durable wiki state and book-local planning APIs.
- MoonClaw sits below MoonBook as the execution substrate for proposals, jobs, controllers, and runtime workspaces.

### Lane blocker

- None. The architecture docs are high signal and mutually reinforcing.

## Lane 4: Cross-project linkage

### Sources inspected

- `/Users/kq/Workspace/moontown/README.md`
- `/Users/kq/Workspace/moontown/docs/ARCHITECTURE.md`
- `/Users/kq/Workspace/moonbook/README.mbt.md`
- `/Users/kq/Workspace/moonbook/docs/KEEPER_CALL_CHAIN.md`
- `/Users/kq/Workspace/moonclaw/README.md`

### Evidence

- Moontown says town orchestration stays in `moontown`, harness and memory control stay in `moonbook`, and execution-heavy behavior stays in `moonclaw`.
- MoonBook says the `moontown` add-on is optional and additive, exposing a town-facing book-harness API without changing the core wiki contract.
- MoonBook says `wiki enable moonclaw` seeds provider/task manifests so MoonClaw can execute `wiki book tasks/context/persist` against a workspace-local target named `moonbook`.
- MoonClaw says it can import external proposal packets and detect wiki-shaped workspaces containing `raw/`, `wiki/`, `wiki/index.md`, and `wiki/log.md`.

### Linkage claims worth materializing

- Moontown orchestrates across multiple MoonBook book workspaces rather than owning durable domain knowledge itself.
- MoonBook is the durable knowledge and harness boundary between Moontown and MoonClaw.
- MoonClaw executes provider-backed or extension-backed work against workspaces but does not own the wiki ontology.

### Lane blocker

- None. Cross-project linkage is explicit in both docs and code-adjacent documentation.

## Open questions

- The repos describe current boundaries clearly, but runtime completeness is still partial: Moontown marks result persistence and long-running patrol loops as stubbed.
- MoonBook describes claim handling as still heuristic, so synthesis claims should stay scoped and source-linked.
- MoonClaw documents workspace-aware execution, but this packet does not inspect deep workflow engine code beyond CLI and architecture references.

## Suggested durable targets

- `wiki/sources/moontown-repo-overview.md`
- `wiki/sources/moonbook-repo-overview.md`
- `wiki/sources/moonclaw-repo-overview.md`
- `wiki/entities/moontown.md`
- `wiki/entities/moonbook.md`
- `wiki/entities/moonclaw.md`
- `wiki/concepts/town-to-book-orchestration.md`
- `wiki/concepts/raw-first-bootstrap-ingest.md`
- `wiki/synthesis/overview.md`
- `wiki/synthesis/claims.md`
- `wiki/synthesis/map.md`
- `wiki/synthesis/maintenance-plan.md`
