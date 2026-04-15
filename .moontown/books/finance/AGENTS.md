# Wiki Maintainer Instructions

This workspace is a persistent LLM-maintained wiki.

MoonBook is the thin harness. Skills carry the domain procedures. Keep deterministic indexing, bookkeeping, and safety in code. Keep judgment, synthesis, diarization, and revision planning in skill files.

## Layers

- `raw/`: immutable source documents. Read-only unless the user explicitly asks to organize files.
- `wiki/`: maintained markdown knowledge base. The LLM owns updates here.
- `site/`: optional marketing website projection for presentation. Build copies it to `book/site/`.
- `wiki/index.md`: content catalog. Update it whenever pages are added or meaningfully changed.
- `wiki/log.md`: append-only activity log. Add one entry per ingest, query, or lint pass.

- `wiki/reviews/pending.md`: items that should be reviewed before being treated as trusted synthesis.
- `wiki/reviews/approved.md`: review items that have been accepted or resolved.

- `wiki/synthesis/maintenance-plan.md`: queue of planned multi-page wiki revisions.

- `RESOLVER.md`: route tasks to the correct skill and context bundle.
- `ROUTINES.md`: shared harness routine, kept short.
- `skills/*/SKILL.md`: reusable procedures that teach the agent how to work this wiki.
- Use a two-layer skill shape: a small set of orchestration skills and a larger set of narrower worker skills.

## Extension Boundary

- Core wiki workspaces should stay agent-agnostic.
- Agent-specific runtime files should be installed through optional extension packs.
- Do not assume a single agent runtime owns the workspace.

## Operations

### Ingest

When ingesting a source:

1. Read `RESOLVER.md` and load `skills/wiki-ingest/SKILL.md`
2. Read the source from `raw/`
3. Create or update relevant wiki pages in `wiki/`
4. Prefer revising related entity, concept, and synthesis pages instead of creating isolated summaries only
5. Update `wiki/index.md`
6. Append a timestamped entry to `wiki/log.md`
7. Preserve uncertainty and note contradictions explicitly
8. Queue contested or low-confidence updates in `wiki/reviews/pending.md`

### Query

When answering a question:

1. Read `RESOLVER.md` and load `skills/wiki-query/SKILL.md`
2. Read `wiki/index.md` first
3. Read the relevant wiki pages
4. Answer from the wiki with citations to page paths
5. If the answer creates durable value, propose filing it back into the wiki

### Marketing

When updating the marketing projection:

1. Read `RESOLVER.md` and load `skills/wiki-marketing/SKILL.md`
2. Treat `wiki/` as the detailed source of truth and `site/` as the compressed presentation layer
3. Keep claims accurate, but rewrite them into audience-facing product language
4. Prefer stable capability framing, clear product boundaries, and links back into maintained wiki pages

### Lint

Periodically check for:

- orphan pages
- stale claims
- contradictions across pages
- missing entity or concept pages
- weak cross-references

## Conventions

- Prefer one concept or entity per page
- Use markdown links between related pages
- Do not delete user-authored raw sources
- Keep the wiki cumulative and revision-oriented, not chatty
