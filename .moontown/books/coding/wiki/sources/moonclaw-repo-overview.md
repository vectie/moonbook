# MoonClaw Repo Overview

## Source Identity

- Repo: `moonclaw`
- Module: `vectie/moonclaw`
- Source type: local repository overview and runtime workflow notes
- Primary materials:
  - `/Users/kq/Workspace/moonclaw/README.md`
  - `/Users/kq/Workspace/moonclaw/moon.mod.json`
  - `/Users/kq/Workspace/moonclaw/cmd/main/main.mbt`

## Synopsis

MoonClaw is an agent runtime and execution substrate with gateway, job workflows, memory, ACP remote-agent control, and workspace-aware proposal execution. In the three-repo stack, it appears as the runtime layer that imports external proposal packets and executes provider-backed or extension-backed work against local workspaces.

## Evidence

- The README describes MoonClaw as an agent runtime with gateway, jobs, memory, artifacts, and ACP remote-agent control.
- The README says it supports external proposal packet import into the normal proposal lifecycle.
- The README says it detects wiki-shaped workspaces containing `raw/`, `wiki/`, `wiki/index.md`, and `wiki/log.md` and includes that structure in runtime context.
- `cmd/main/main.mbt` exposes runtime-facing commands including `gateway`, `proposal`, `exec`, and `acp`.
- The README says provider-backed or extension-backed execution can target task providers instead of hardcoding one host boundary.

## Related Entities

- [MoonClaw](../entities/moonclaw.md)
- [MoonBook](../entities/moonbook.md)
- [Moontown](../entities/moontown.md)

## Related Concepts

- [External Proposal Packet Lifecycle](../concepts/external-proposal-packet-lifecycle.md)
- [Book-Harness Boundary](../concepts/book-harness-boundary.md)

## Open Questions

- This source pass does not inspect deeper workflow engine code, so runtime details stay at the README and CLI-boundary level.
