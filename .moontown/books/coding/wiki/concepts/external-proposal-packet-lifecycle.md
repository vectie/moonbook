# External Proposal Packet Lifecycle

## Definition

The external proposal packet lifecycle is the cross-repo execution path where a host system prepares a packet, MoonClaw imports it into its proposal store, and the runtime executes it as a normal proposal or run.

## Why It Matters

This concept is the main execution linkage between the durable wiki side and the runtime side of the stack.

## Examples

- Moontown prepares keeper-facing external proposal packets from MoonBook task context.
- MoonClaw documents `proposal import <packet.json>` as a normal entry into its proposal lifecycle.
- MoonBook's keeper call-chain docs describe packet emission, profile application, workflow compilation, and execution in MoonClaw.

## Linked Entities

- [Moontown](../entities/moontown.md)
- [MoonBook](../entities/moonbook.md)
- [MoonClaw](../entities/moonclaw.md)
- [Mayor](../entities/mayor.md)

## Sources

- [Moontown Repo Overview](../sources/moontown-repo-overview.md)
- [MoonBook Repo Overview](../sources/moonbook-repo-overview.md)
- [MoonClaw Repo Overview](../sources/moonclaw-repo-overview.md)

## Open Questions

- This revision pass does not inspect the full workflow engine, so lifecycle details stay focused on packet import and boundary semantics.
