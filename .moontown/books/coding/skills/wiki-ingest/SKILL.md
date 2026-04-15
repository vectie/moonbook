---
name: wiki-ingest
description: Ingest one source into the wiki by reading, diarizing, revising pages, and preserving uncertainty.
---

# Wiki Ingest

Parameters:

- SOURCE: the raw source path
- QUESTION: what matters about this source, if the user gave one

Method:

1. Read `RESOLVER.md`, `wiki/index.md`, and `wiki/log.md`.
2. Read SOURCE directly. Build a compact diarized view: what the source says, what changed, what is uncertain, and what other pages it touches.
3. Revise maintained wiki pages first. Prefer updates to entities, concepts, synthesis, claims, and review queues over one-off note creation.
4. If a new page is justified, make it stable and domain-shaped, not token-shaped.
5. Record contradictions, supersession hints, and weak evidence instead of flattening them.
6. Update `wiki/index.md`, `wiki/log.md`, and `wiki/synthesis/maintenance-plan.md`.
