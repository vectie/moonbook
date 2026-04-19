# Moontown

## Identity

Moontown is the town-level orchestration layer in this stack. It coordinates multiple book domains and delegates domain-local work toward MoonBook and MoonClaw rather than trying to own the durable wiki itself.

## Role

- Provides town-wide routing and scheduling.
- Holds global orchestration state and operator-facing scene views.
- Uses the `Mayor` role to decide dispatch and prepare keeper packets for book-local work.

## Relationships

- Dispatches book-local planning and execution into [MoonBook](./moonbook.md) book workspaces.
- Prepares keeper proposal packets that are executed by [MoonClaw](./moonclaw.md).
- Uses [Mayor](./mayor.md) as the strategic runtime that maps task kinds onto execution profiles.
- Is described by [Moontown Repo Overview](../sources/moontown-repo-overview.md).

## Operational Relevance

Moontown matters when work spans more than one book or when an operator needs town-wide visibility over packets, proposals, runs, health, and scheduling.

## Change Notes

- Current docs describe a clearer additive boundary: town orchestration belongs in Moontown, while durable harness and memory control belong in MoonBook and execution-heavy behavior belongs in MoonClaw.
- Current docs also say automatic result persistence back into MoonBook and long-running patrol loops are still stubbed, so the orchestration layer is not yet fully closed-loop.

## Uncertainty

- The current source set is strong on architecture and role boundaries but lighter on the exact runtime behavior of unfinished daemon and persistence loops.
