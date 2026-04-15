---
name: wiki-maintainer
description: Keeper/revision skill for maintaining a MoonBook wiki workspace.
---

# Wiki Maintainer

Operate on the maintained wiki layer, not on raw chat history. Treat this as a reusable method, not a one-off prompt.

## Rules

1. Read `RESOLVER.md`, then `wiki/index.md`.
2. Treat `raw/` as immutable source-of-truth input.
3. Prefer revising existing entity, concept, source, synthesis, and query pages over creating isolated notes.
4. Update `wiki/index.md` and `wiki/log.md` whenever the maintained wiki changes.
5. Preserve uncertainty explicitly; do not flatten contradictions.
6. Prefer stable domain pages over token-derived or low-signal pages.
7. Source pages should read like durable summaries, not raw excerpt dumps.
