# MoonBook Repo Overview

## Source Identity

- Repo: `moonbook`
- Module: `vectie/moonbook`
- Source type: local repository overview and wiki architecture docs
- Primary materials:
  - `/Users/kq/Workspace/moonbook/README.md`
  - `/Users/kq/Workspace/moonbook/README.mbt.md`
  - `/Users/kq/Workspace/moonbook/moon.mod.json`
  - `/Users/kq/Workspace/moonbook/docs/SYSTEM_ARCHITECTURE.md`
  - `/Users/kq/Workspace/moonbook/docs/WIKI_WORKFLOW.md`
  - `/Users/kq/Workspace/moonbook/docs/KEEPER_CALL_CHAIN.md`

## Synopsis

MoonBook is a MoonBit-native mdBook rewrite extended into a persistent wiki-maintainer workspace. It owns the raw-first bootstrap and durable wiki surfaces, including source pages, entity pages, concept pages, synthesis pages, review queues, and optional book-harness APIs used by Moontown.

## Evidence

- The README says MoonBook is a MoonBit rewrite of `mdBook` extended into a persistent wiki-maintainer workspace.
- The README and workflow docs say workers stage packets under `raw/bootstrap/` before Keeper ingests them into durable wiki pages.
- `docs/SYSTEM_ARCHITECTURE.md` says MoonBook owns the persistent wiki workspace and keeps runtime-specific orchestration outside the core workspace contract.
- `docs/WIKI_WORKFLOW.md` says ingest updates `wiki/sources/`, `wiki/entities/`, `wiki/concepts/`, `wiki/synthesis/overview.md`, `wiki/synthesis/claims.md`, `wiki/synthesis/map.md`, and `wiki/synthesis/maintenance-plan.md`.
- `README.mbt.md` says the `moontown` add-on is optional and exposes a town-facing book-harness API without changing the core wiki contract.

## Related Entities

- [MoonBook](../entities/moonbook.md)
- [Moontown](../entities/moontown.md)
- [MoonClaw](../entities/moonclaw.md)
- [Keeper](../entities/keeper.md)

## Related Concepts

- [Raw-First Bootstrap Ingest](../concepts/raw-first-bootstrap-ingest.md)
- [Town-to-Book Orchestration](../concepts/town-to-book-orchestration.md)
- [Book-Harness Boundary](../concepts/book-harness-boundary.md)

## Open Questions

- The README says claim handling is still heuristic and the deeper MoonClaw workflow pack is not yet the preferred operational path.
