# MoonClaw

## Identity

MoonClaw is the runtime and execution substrate in this stack. It owns proposal import, job execution, gateway services, ACP control, run workspaces, and runtime-facing operator surfaces.

## Role

- Imports external proposal packets into its proposal lifecycle.
- Executes provider-backed or extension-backed workflows against local workspaces.
- Maintains run workspaces, artifacts, and runtime memory outside the durable wiki ontology.

## Relationships

- Executes packets and controller profiles prepared from [MoonBook](./moonbook.md) book tasks.
- Serves as the runtime substrate below [Moontown](./moontown.md)'s orchestration layer.
- Reads wiki-shaped workspace context when work targets a MoonBook-style wiki.
- Is described by [MoonClaw Repo Overview](../sources/moonclaw-repo-overview.md).

## Operational Relevance

MoonClaw matters when the stack needs bounded workers, proposal import, job execution, or operator-visible run state. It is the execution side of the stack, not the durable owner of domain knowledge.

## Change Notes

- Current docs emphasize external proposal packet import and workspace-aware execution as stable boundaries.
- Current docs also describe provider-backed and extension-backed execution as a general mechanism rather than a MoonBook-only special case.

## Uncertainty

- This revision pass does not inspect deep workflow engine internals, so fine-grained runtime semantics remain summarized at the architecture and CLI level.
