# Raw-First Bootstrap Ingest

## Definition

Raw-first bootstrap ingest is the workflow where discovery workers stage high-signal packets under `raw/bootstrap/` before durable source pages, entity pages, concept pages, and synthesis pages are revised.

## Why It Matters

This concept defines the durable knowledge boundary in MoonBook. It prevents weak discovery output, placeholders, or scaffolding files from being treated as stable wiki knowledge too early.

## Examples

- MoonBook's README says workers stage discovered source packets under `raw/bootstrap/` and Keeper ingests those packets into durable wiki pages.
- `docs/WIKI_WORKFLOW.md` says bootstrap discovery stages generated packets under `raw/bootstrap/` before source and ontology revision.
- `docs/KEEPER_CALL_CHAIN.md` describes `bootstrap_gather` as a semantic phase that gathers high-signal material and writes `raw/bootstrap/*`.

## Linked Entities

- [MoonBook](../entities/moonbook.md)
- [Keeper](../entities/keeper.md)

## Sources

- [MoonBook Repo Overview](../sources/moonbook-repo-overview.md)

## Open Questions

- The docs define the phase shape clearly, but claim extraction remains heuristic after source materialization.
