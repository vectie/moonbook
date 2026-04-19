# Town-to-Book Orchestration

## Definition

Town-to-book orchestration is the pattern where Moontown manages cross-book routing and scheduling while delegating domain-local knowledge work into MoonBook book workspaces and MoonClaw execution lanes.

## Why It Matters

This concept explains why the stack is split across three repos instead of collapsing into one runtime. It keeps global orchestration separate from durable domain knowledge and separate again from execution-heavy workflow runtime.

## Examples

- Moontown describes itself as the town-level layer above multiple MoonBook domains and MoonClaw runtimes.
- Moontown's Mayor role prepares keeper packets from MoonBook worker context.
- MoonBook exposes optional town-facing book-harness APIs rather than moving town logic into the wiki core.

## Linked Entities

- [Moontown](../entities/moontown.md)
- [MoonBook](../entities/moonbook.md)
- [MoonClaw](../entities/moonclaw.md)
- [Mayor](../entities/mayor.md)

## Sources

- [Moontown Repo Overview](../sources/moontown-repo-overview.md)
- [MoonBook Repo Overview](../sources/moonbook-repo-overview.md)

## Open Questions

- The orchestration boundary is clear, but the sources still describe some result-persistence loops as unfinished.
