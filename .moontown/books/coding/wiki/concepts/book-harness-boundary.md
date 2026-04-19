# Book-Harness Boundary

## Definition

The book-harness boundary is the interface where MoonBook exposes per-book tasks, context hydration, persistence, summary, and health to outside orchestrators without giving up ownership of the workspace and wiki semantics.

## Why It Matters

This concept explains how Moontown can coordinate book-local work without replacing MoonBook as the domain owner.

## Examples

- MoonBook documents `wiki book` commands for task production, context hydration, summary, and health.
- MoonBook says the `moontown` add-on exposes a town-facing book API without changing the core workspace contract.
- Moontown uses MoonBook worker context bundles when preparing keeper packets.

## Linked Entities

- [MoonBook](../entities/moonbook.md)
- [Moontown](../entities/moontown.md)
- [Mayor](../entities/mayor.md)

## Sources

- [MoonBook Repo Overview](../sources/moonbook-repo-overview.md)
- [Moontown Repo Overview](../sources/moontown-repo-overview.md)

## Open Questions

- The interface is documented mostly through CLI and architecture docs rather than a stable RPC service contract.
