# Extension Packs

MoonBook supports optional runtime integration through extension packs.

The goal is to keep wiki workspaces agent-agnostic by default while still allowing runtime-specific setup when needed.

## Design Goal

MoonBook should own:

- workspace shape
- wiki file contract
- build/render/serve behavior
- durable `wiki/*` materialization from raw research envelopes

Extension packs should own:

- runtime-specific config files
- runtime-specific helper docs
- runtime-specific manifests
- bounded worker execution and raw artifact collection

This keeps MoonBook from being strongly coupled to a single agent/runtime.

## Current Flow

Initialize a plain wiki workspace:

```bash
moon run cmd/main -- wiki init ./research-wiki
```

Then install a runtime pack explicitly:

```bash
moon run cmd/main -- wiki enable moonclaw ./research-wiki
moon run cmd/main -- wiki enable moontown ./research-wiki
```

## Current Pack

Supported today:

- `moonclaw`
- `moontown`

Installed files by pack:

- `moonclaw`
  - `.moonbook/extensions/moonclaw.json`
  - `moonclaw.json`
  - `moonclaw.jobs.json`
  - `IDENTITY.md`
  - `USER.md`
  - `ROUTINES.md`
  - `MEMORY.md`
  - `KEEPER.md`
  - `skills/wiki-maintainer/SKILL.md`
  - `skills/wiki-review/SKILL.md`
- `moontown`
  - `.moonbook/extensions/moontown.json`
  - `moontown.book.json`
  - `BOOK_API.md`

The `moontown` pack is aligned to Moontown's current persisted bootstrap shape:

- MoonBook can export a catalog-style record with `moonbook wiki book catalog`
- `moontown.book.json` advertises both that catalog export and the town-to-book API commands

The `moonclaw` pack is aligned to MoonClaw's current role substrate:

- controller profiles carry explicit `role_runtime` planner envelopes
- gather/review workers carry explicit execution envelopes
- MoonBook owns the lead/review policy files and skill docs that make the embedded planner feel book-specific
- MoonBook seeds `.moonclaw/providers.json` with the provider-task target name `moonbook`
- MoonClaw is expected to return a strict research envelope under `raw/bootstrap/`; MoonBook decides what becomes durable `wiki/sources/`, `wiki/entities/`, `wiki/concepts/`, and synthesis pages

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
- multiple real packs (`moonclaw`, `moontown`)

What is still missing:

- richer pack metadata
- stronger validation of pack contents
- clearer compatibility/versioning rules between MoonBook and extension packs
