# Keeper

## Identity

Keeper is the book-local maintenance role described by MoonBook and referenced by Moontown handoff flows. It is the domain-scoped side of ingest, memory control, and durable wiki revision.

## Role

- Ingests bootstrap packets into durable wiki pages.
- Uses bounded memory and evidence surfaces inside a MoonBook workspace.
- Serves as the local handoff target for town-issued or workflow-issued wiki maintenance work.

## Relationships

- Operates inside [MoonBook](./moonbook.md) workspaces.
- Receives handoff packets prepared by [Mayor](./mayor.md) in [Moontown](./moontown.md).
- Hands execution work to [MoonClaw](./moonclaw.md) workflow lanes while preserving MoonBook-owned semantics.
- Is evidenced by [MoonBook Repo Overview](../sources/moonbook-repo-overview.md).

## Operational Relevance

Keeper is the practical owner of raw-first ingest and durable wiki revision inside each book boundary.

## Uncertainty

- The role is strongly documented as a boundary, but this source pass does not inspect all seeded policy files or every runtime profile.
