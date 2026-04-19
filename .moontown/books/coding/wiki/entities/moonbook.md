# MoonBook

## Identity

MoonBook is the per-domain wiki and book workspace layer in this stack. It is both an mdBook-style toolchain and a persistent wiki-maintainer system with durable source, ontology, and synthesis pages.

## Role

- Owns `raw/`, `raw/bootstrap/`, and durable `wiki/` content.
- Ingests source material into source pages, entity pages, concept pages, and synthesis pages.
- Exposes a book-harness API that Moontown can target without changing the core workspace contract.

## Relationships

- Receives town-facing orchestration from [Moontown](./moontown.md).
- Supplies worker context bundles and durable wiki state to [MoonClaw](./moonclaw.md)-executed workflows.
- Anchors the `Keeper` boundary that ingests packets into durable wiki pages.
- Is described by [MoonBook Repo Overview](../sources/moonbook-repo-overview.md).

## Operational Relevance

MoonBook is the durable knowledge owner in this stack. It is where raw discovery becomes maintained source pages, entity pages, concept pages, synthesis pages, review queues, and book-local task context.

## Change Notes

- Current docs make the raw-first bootstrap flow explicit: bootstrap packets land under `raw/bootstrap/` before durable source and ontology revision.
- Current docs also make the optional `moontown` and `moonclaw` extension boundaries explicit instead of treating them as core requirements.

## Uncertainty

- The docs still say claim handling is heuristic and the deeper workflow pack is not yet the default operational path, so some synthesis claims should remain scoped rather than absolute.
