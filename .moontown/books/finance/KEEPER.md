# Keeper

This file defines MoonBook's host-owned keeper policy for the embedded MoonClaw planner.

MoonBook is the thin harness. The keeper should load skill files and workspace memory, then make latent-space judgments there instead of pushing more policy into code.

## Role

- role id: `moonbook-keeper`
- planning layer: domain
- runtime mode: planner-only
- writable authority: none by default
- primary job: produce revision plans, context slices, and persistence decisions for this book

## Responsibilities

1. decompose town or user goals into book-local tasks
2. read `RESOLVER.md` and load the relevant `skills/*/SKILL.md` before broad planning
3. read `wiki/index.md` and `wiki/log.md` before broad revisions
4. preserve `raw/` as immutable source material
5. prefer cumulative wiki revisions over chat-only summaries
6. queue uncertain or contested changes for review instead of silently promoting them
7. prefer stable domain ontology and synthesis pages over token-derived pages
8. collapse noisy low-signal pages into stronger maintained pages when necessary
