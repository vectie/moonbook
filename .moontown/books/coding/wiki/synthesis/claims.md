# Claims Register

This page stores lightweight structured claims extracted from sources.

## Claims

### claim:stack-layering

- Claim: The current docs support a three-layer stack in which Moontown orchestrates, MoonBook owns durable book-local knowledge, and MoonClaw executes runtime workflows.
- Status: supported
- Confidence: high
- Support: 3 source pages
- Sources:
  - [Moontown Repo Overview](../sources/moontown-repo-overview.md)
  - [MoonBook Repo Overview](../sources/moonbook-repo-overview.md)
  - [MoonClaw Repo Overview](../sources/moonclaw-repo-overview.md)
- Related pages:
  - [Moontown](../entities/moontown.md)
  - [MoonBook](../entities/moonbook.md)
  - [MoonClaw](../entities/moonclaw.md)
  - [Overview](./overview.md)

### claim:raw-first-ingest-boundary

- Claim: MoonBook's durable wiki flow is raw-first: bootstrap gathering writes packets under `raw/bootstrap/` before source materialization and broader ontology revision.
- Status: supported
- Confidence: high
- Support: 1 source page with reinforcing workflow docs
- Sources:
  - [MoonBook Repo Overview](../sources/moonbook-repo-overview.md)
- Related pages:
  - [MoonBook](../entities/moonbook.md)
  - [Keeper](../entities/keeper.md)
  - [Raw-First Bootstrap Ingest](../concepts/raw-first-bootstrap-ingest.md)
  - [Overview](./overview.md)

### claim:book-harness-additive-boundary

- Claim: MoonBook exposes an additive book-harness boundary for outside orchestrators like Moontown without making town orchestration part of the core wiki contract.
- Status: supported
- Confidence: medium
- Support: 2 source pages
- Sources:
  - [MoonBook Repo Overview](../sources/moonbook-repo-overview.md)
  - [Moontown Repo Overview](../sources/moontown-repo-overview.md)
- Related pages:
  - [MoonBook](../entities/moonbook.md)
  - [Moontown](../entities/moontown.md)
  - [Book-Harness Boundary](../concepts/book-harness-boundary.md)

### claim:proposal-import-runtime-boundary

- Claim: MoonClaw is the execution boundary for external proposal packets rather than the durable owner of wiki ontology.
- Status: supported
- Confidence: high
- Support: 2 source pages
- Sources:
  - [MoonClaw Repo Overview](../sources/moonclaw-repo-overview.md)
  - [Moontown Repo Overview](../sources/moontown-repo-overview.md)
- Related pages:
  - [MoonClaw](../entities/moonclaw.md)
  - [External Proposal Packet Lifecycle](../concepts/external-proposal-packet-lifecycle.md)
  - [Overview](./overview.md)

### claim:closed-loop-status-is-partial

- Claim: The current stack documentation says some end-to-end operational loops are still incomplete, especially Moontown result persistence and some deeper MoonBook claim/runtime maturity.
- Status: supported
- Confidence: medium
- Support: 2 source pages
- Sources:
  - [Moontown Repo Overview](../sources/moontown-repo-overview.md)
  - [MoonBook Repo Overview](../sources/moonbook-repo-overview.md)
- Related pages:
  - [Moontown](../entities/moontown.md)
  - [MoonBook](../entities/moonbook.md)
  - [Maintenance Plan](./maintenance-plan.md)
