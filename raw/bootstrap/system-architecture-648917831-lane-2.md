# Bootstrap Packet: System Architecture Lane 2

## Short summary

MoonBook separates an mdBook-compatible book toolchain from a persistent wiki workspace layer, but both share rendering, build, and serve infrastructure. The inspected code shows that the wiki layer is not just conceptual documentation: it is concretely implemented through workspace bootstrapping in `wiki/init.mbt`, task-planning and bootstrap lane orchestration in `wiki/bookapi.mbt`, and diagnostic/project-state projection in `wiki/ui_state.mbt`.

## Evidence

- `docs/SYSTEM_ARCHITECTURE.md:3` states the repo has two major product layers: the mdBook-compatible toolchain and the persistent wiki workspace layer.
- `docs/SYSTEM_ARCHITECTURE.md:48` identifies `wiki/init.mbt` as the workspace bootstrap module and `wiki/bookapi.mbt` as the town-facing harness API surface.
- `docs/SYSTEM_ARCHITECTURE.md:77` lists wiki-layer responsibilities including creating `raw/` and `wiki/` workspaces, maintaining evidence, synthesis maps, persistent markdown pages, and query result persistence.
- `docs/SYSTEM_ARCHITECTURE.md:89` defines the workspace contract as file-based and agent-agnostic, with core directories including `raw/`, `keeper/`, `wiki/`, and subdirectories such as `wiki/sources/`, `wiki/entities/`, `wiki/concepts/`, and `wiki/synthesis/`.
- `wiki/init.mbt:18` constructs `raw/`, `raw/assets/`, and `raw/bootstrap/`, confirming bootstrap packets are a first-class workspace artifact.
- `wiki/init.mbt:67` through `wiki/init.mbt:96` resolves durable wiki destinations including `wiki/entities/`, `wiki/concepts/`, `wiki/synthesis/claims.md`, `wiki/synthesis/maintenance-plan.md`, `wiki/synthesis/map.md`, `wiki/synthesis/observations.md`, and `wiki/synthesis/evidence.md`.
- `wiki/init.mbt:193` through `wiki/init.mbt:205` creates the core wiki directory tree, including `wiki/entities/`, `wiki/concepts/`, `wiki/synthesis/`, `wiki/queries/`, `wiki/reviews/`, and `wiki/sources/`.
- `wiki/init.mbt:235` through `wiki/init.mbt:304` seeds the workspace with foundational files like `wiki/index.md`, `wiki/log.md`, `wiki/synthesis/*.md`, `keeper/*.md`, and a placeholder in `raw/bootstrap/`.
- `wiki/bookapi.mbt:163` shows `produce_task_batch` derives planning from workspace state and health, indicating bootstrap work is guided by local coverage signals rather than generic workflow steps.
- `wiki/bookapi.mbt:196` through `wiki/bookapi.mbt:233` routes weak-coverage or research-style goals into ingest/bootstrap work that explicitly inspects `raw/`, `raw/bootstrap/`, `wiki/sources/`, and synthesis planning pages.
- `wiki/bookapi.mbt:320` through `wiki/bookapi.mbt:369` defines the semantic bootstrap phases: `bootstrap_gather`, `source_materialize`, `knowledge_revise`, and `review_finalize`.
- `wiki/bookapi.mbt:326` through `wiki/bookapi.mbt:333` describes `Gather bootstrap materials` as a fan-out phase with 2-4 bounded gather lanes that must inspect only small high-signal slices, produce concrete `raw/bootstrap` packets with provenance, and report blockers when evidence is weak.
- `wiki/ui_state.mbt:108` shows UI state generation reads workspace summary, health, keeper state, review queue, and synthesis files, meaning the architecture is surfaced operationally through generated project diagnostics.
- `wiki/ui_state.mbt:151` through `wiki/ui_state.mbt:167` exposes page families for claims, synthesis map, and evidence, reinforcing that these files are intended as maintained durable surfaces rather than incidental implementation details.
- `wiki/ui_state.mbt:219` through `wiki/ui_state.mbt:233` explicitly distinguishes mature synthesis from bootstrap-incomplete states based on verified source coverage and ontology coverage, which is a concrete signal for later durable source and concept/entity work.

## Candidate durable pages

- `wiki/concepts/architecture-layers.md` - explain the two-layer split between book toolchain and wiki workspace, with boundary notes on shared infrastructure.
- `wiki/concepts/wiki-workspace-contract.md` - capture the file-based workspace contract, required directories, and agent-agnostic design intent.
- `wiki/concepts/bootstrap-phases.md` - document the four-phase bootstrap model and the meaning of bounded gather lanes.
- `wiki/entities/bookapi.md` - describe `wiki/bookapi.mbt` as the task-planning and harness API component for local goal acceptance, bootstrap planning, and worker hydration.
- `wiki/entities/wiki-init.md` - describe `wiki/init.mbt` as the workspace bootstrapper and seed-file provisioner.
- `wiki/entities/ui-state.md` - describe `wiki/ui_state.mbt` as the workspace diagnostics and projection layer for readiness, review, evidence, and skill status.
- `wiki/sources/system-architecture-doc.md` - durable source page distilled from `docs/SYSTEM_ARCHITECTURE.md` if later materialization confirms it is substantive enough as a primary architectural source.
- `wiki/synthesis/overview.md` - later synthesis target connecting architecture intent to implemented modules once durable source pages exist.

## Open gaps and blockers

- This slice is architecture-heavy and code-structure-heavy; it does not inspect runtime behavior, tests, or additional wiki modules such as `wiki/ingest.mbt`, `wiki/query.mbt`, or `wiki/workspace.mbt`.
- `docs/SYSTEM_ARCHITECTURE.md` is strong for design intent, but this lane alone does not verify whether every documented responsibility is fully implemented across the rest of the codebase.
- Candidate durable pages are only hypotheses from this evidence slice; no claim is made here that the current wiki already covers them.
- The local path `/Users/kq/Workspace/moonbook/raw/bootstrap/` was not present at inspection time, so this packet is written as bootstrap evidence for the requested path but also suggests the workspace may not have been initialized in this checkout.
