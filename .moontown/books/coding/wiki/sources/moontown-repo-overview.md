# Moontown Repo Overview

## Source Identity

- Repo: `moontown`
- Module: `vectie/moontown`
- Source type: local repository overview and architecture docs
- Primary materials:
  - `/Users/kq/Workspace/moontown/README.md`
  - `/Users/kq/Workspace/moontown/moon.mod.json`
  - `/Users/kq/Workspace/moontown/cmd/main/main.mbt`
  - `/Users/kq/Workspace/moontown/roles/mayor.mbt`
  - `/Users/kq/Workspace/moontown/docs/ARCHITECTURE.md`

## Synopsis

Moontown is a town-level orchestration layer that coordinates multiple MoonBook book domains and multiple MoonClaw runtimes. Its docs and role code position it above per-book wiki maintenance, with a strategic Mayor role that prepares keeper packets and routes work into book-local execution lanes.

## Evidence

- The README describes Moontown as a town-level orchestration layer above multiple `moonbook` domains and multiple `moonclaw` runtimes.
- The README says town orchestration stays in `moontown`, harness and memory control stay in `moonbook`, and execution-heavy behavior stays in `moonclaw`.
- `roles/mayor.mbt` maps task kinds like `ingest`, `review`, and `synthesis` onto MoonClaw controller profiles.
- `roles/mayor.mbt` prepares keeper packets from MoonBook worker context bundles, showing a concrete handoff boundary rather than a vague integration claim.
- `docs/ARCHITECTURE.md` describes the intended stack as `moontown -> moonbook -> moonclaw`.

## Related Entities

- [Moontown](../entities/moontown.md)
- [MoonBook](../entities/moonbook.md)
- [MoonClaw](../entities/moonclaw.md)
- [Mayor](../entities/mayor.md)

## Related Concepts

- [Town-to-Book Orchestration](../concepts/town-to-book-orchestration.md)
- [External Proposal Packet Lifecycle](../concepts/external-proposal-packet-lifecycle.md)

## Open Questions

- The README still marks long-running run polling, automatic result persistence back into MoonBook, and daemon patrol loops as stubbed.
