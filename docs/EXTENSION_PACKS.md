# Extension Packs

MoonBook supports optional runtime integration through extension packs.

The goal is to keep wiki workspaces agent-agnostic by default while still allowing runtime-specific setup when needed.

## Design Goal

MoonBook should own:

- workspace shape
- wiki file contract
- build/render/serve behavior

Extension packs should own:

- runtime-specific config files
- runtime-specific helper docs
- runtime-specific manifests

This keeps MoonBook from being strongly coupled to a single agent/runtime.

## Current Flow

Initialize a plain wiki workspace:

```bash
moon run cmd/main -- wiki init ./research-wiki
```

Then install a runtime pack explicitly:

```bash
moon run cmd/main -- wiki enable moonclaw ./research-wiki
```

## Current Pack

Supported today:

- `moonclaw`

Installed files include:

- `.moonbook/extensions/moonclaw.json`
- `moonclaw.json`
- `moonclaw.jobs.json`
- `IDENTITY.md`
- `USER.md`
- `ROUTINES.md`
- `MEMORY.md`

The exact set depends on the pack installer, but the important boundary is that these files are added by `wiki enable`, not by `wiki init`.

## Workspace Boundary

Core workspace files that should remain runtime-neutral:

- `raw/`
- `wiki/`
- `wiki/index.md`
- `wiki/log.md`
- `wiki/SUMMARY.md`
- `AGENTS.md`
- `wiki.toml`

Runtime-specific files should not be assumed to exist unless the matching extension has been enabled.

## Current Manifest Location

Extension manifests are recorded under:

```text
.moonbook/extensions/
```

This is the runtime integration boundary MoonBook currently owns.

## Operational Guidance

Use extension packs when:

- you want MoonBook workspaces to be directly usable by another runtime
- you want runtime-specific profiles or context documents seeded into the workspace
- you want to preserve the core wiki contract without baking runtime assumptions into it

Do not use extension packs to:

- change the meaning of the core wiki directories
- redefine the build/render behavior of MoonBook itself
- bypass the core workspace contract

## Current Limitation

The extension system is still early.

What exists:

- explicit enable step
- manifest directory
- one real pack (`moonclaw`)

What is still missing:

- multiple first-class packs
- richer pack metadata
- stronger validation of pack contents
- clearer compatibility/versioning rules between MoonBook and extension packs
