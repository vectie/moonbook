# Overview

## Stack View

The gathered source pages describe a three-layer stack rather than three interchangeable tools.

- [Moontown](../entities/moontown.md) is the orchestration layer for multiple books and runtimes.
- [MoonBook](../entities/moonbook.md) is the durable per-domain workspace and wiki owner.
- [MoonClaw](../entities/moonclaw.md) is the execution substrate for proposals, workflows, and run workspaces.

## Cross-Source Synthesis

The most stable cross-source pattern is a top-down delegation chain: Moontown routes and packages work, MoonBook owns durable knowledge and book-local context, and MoonClaw executes runtime workflows against workspaces.

The architecture docs reinforce a second pattern: durable knowledge and runtime execution are intentionally separated. MoonBook keeps `raw/`, `raw/bootstrap/`, `wiki/`, review, and synthesis state inside the workspace contract, while MoonClaw stays focused on proposal import, workflow execution, and operator-visible run state.

A third pattern is that the handoff boundary is explicit rather than merely implied. Moontown's Mayor prepares keeper packets from MoonBook worker context, MoonBook documents the semantic phase graph for ingest, and MoonClaw documents external proposal import plus wiki-workspace detection.

## Tensions And Open Loops

- Moontown still marks some result-persistence and patrol flows as stubbed, so the orchestration loop is not fully closed.
- MoonBook still describes claim handling as heuristic, so durable claims should remain scoped to documented boundaries.
- This pass confirms the stack boundary strongly at README and architecture-doc level, but deeper runtime internals were only sampled lightly.

## Source Links

- [Moontown Repo Overview](../sources/moontown-repo-overview.md)
- [MoonBook Repo Overview](../sources/moonbook-repo-overview.md)
- [MoonClaw Repo Overview](../sources/moonclaw-repo-overview.md)
- [Town-to-Book Orchestration](../concepts/town-to-book-orchestration.md)
- [Raw-First Bootstrap Ingest](../concepts/raw-first-bootstrap-ingest.md)
- [External Proposal Packet Lifecycle](../concepts/external-proposal-packet-lifecycle.md)
