# Wiki Workflow

This document describes the current MoonBook wiki-maintainer loop.

## Goal

MoonBook’s wiki mode is designed to turn raw source files into a persistent markdown knowledge base instead of answering from raw documents every time.

Current commands:

- `moonbook wiki init`
- `moonbook wiki enable`
- `moonbook wiki ingest`
- `moonbook wiki query`
- `moonbook wiki book`
- `moonbook wiki review`
- `moonbook wiki lint`

## Workspace Lifecycle

### 1. Initialize

```bash
moon run cmd/main -- wiki init ./research-wiki
```

This creates:

- `raw/`
- `keeper/`
- `wiki/`
- `wiki/SUMMARY.md`
- `wiki/index.md`
- `wiki/log.md`
- `wiki/synthesis/claims.md`
- `wiki/synthesis/maintenance-plan.md`
- `wiki/synthesis/query-insights.md`
- `wiki/synthesis/observations.md`
- `wiki/reviews/pending.md`
- `wiki/reviews/approved.md`
- `keeper/MEMORY.md`
- `keeper/USER.md`
- `keeper/WORKING.md`
- `keeper/POLICY.md`

### 2. Enable Optional Runtime Pack

```bash
moon run cmd/main -- wiki enable moonclaw ./research-wiki
moon run cmd/main -- wiki enable moontown ./research-wiki
moon run cmd/main -- wiki book catalog ./research-wiki
```

This is optional. It installs runtime-specific files without changing the core workspace contract.

### 3. Ingest Sources

```bash
moon run cmd/main -- wiki ingest ./research-wiki ./raw/article.md
```

Current ingest behavior:

- creates a source page in `wiki/sources/`
- extracts first-pass entities and concepts
- updates `wiki/entities/`
- updates `wiki/concepts/`
- updates `wiki/synthesis/overview.md`
- updates `wiki/synthesis/claims.md`
- updates `wiki/synthesis/maintenance-plan.md`
- queues contested or low-confidence claims in `wiki/reviews/pending.md`
- updates `wiki/SUMMARY.md`, `wiki/index.md`, and `wiki/log.md`

### 4. Query the Maintained Wiki

```bash
moon run cmd/main -- wiki query ./research-wiki "How do these sources connect?" --save
```

Current query behavior:

- searches markdown pages under `wiki/`
- ranks by lightweight keyword relevance
- prints an answer with citations
- with `--save`, writes a saved query page under `wiki/queries/`
- updates `wiki/synthesis/query-insights.md`
- propagates `Query Signals` into cited pages
- updates `wiki/synthesis/maintenance-plan.md`
- can queue a review item for later promotion

### 5. Book Harness APIs

For town-level orchestration, MoonBook can expose a machine-readable book boundary:

```bash
moon run cmd/main -- wiki book tasks ./research-wiki "refresh synthesis for recent ingest"
moon run cmd/main -- wiki book context ./research-wiki "refresh synthesis for recent ingest" --task goal-refresh-synthesis
moon run cmd/main -- wiki book summary ./research-wiki
moon run cmd/main -- wiki book health ./research-wiki
```

Current book-harness behavior:

- exports a catalog record for persisted town bootstrap
- accepts town-style goals into book-local planning
- produces local tasks inside the book boundary
- hydrates worker context from book policy, routines, Keeper memory, and durable wiki pages
- persists worker results into `synthesis/observations.md`
- syncs non-durable memory candidates into bounded Keeper memory files
- promotes durable memory candidates into target pages
- reports book-local state and health without requiring a town runtime

### 6. Review

List pending review items:

```bash
moon run cmd/main -- wiki review list ./research-wiki
```

Approve one item:

```bash
moon run cmd/main -- wiki review approve ./research-wiki <review-id>
```

Reject one item:

```bash
moon run cmd/main -- wiki review reject ./research-wiki <review-id>
```

Current review behavior:

- moves items from `reviews/pending.md` to `reviews/approved.md`
- for claim reviews, promotes changes into `synthesis/claims.md`
- for query reviews, promotes changes into `synthesis/overview.md`
- updates `synthesis/maintenance-plan.md`
- appends the action to `wiki/log.md`

### 7. Lint

```bash
moon run cmd/main -- wiki lint ./research-wiki
```

Current lint checks:

- orphan pages
- missing index coverage
- placeholder sections
- stale wording
- simple contradictions
- missing concept pages
- weak synthesis and claim coverage
- low-confidence claims not actually queued for review
- review backlog growth

## Current Content Model

The maintained wiki currently revolves around these page families:

- `wiki/sources/`
  source summary pages
- `wiki/entities/`
  first-pass entity pages
- `wiki/concepts/`
  first-pass concept pages
- `wiki/synthesis/overview.md`
  rolling cross-source notes
- `wiki/synthesis/claims.md`
  lightweight structured claims
- `wiki/synthesis/maintenance-plan.md`
  queued follow-up work
- `wiki/synthesis/query-insights.md`
  durable saved-query insights
- `wiki/synthesis/observations.md`
  persisted worker results and promoted observations
- `wiki/reviews/`
  pending and approved operator review items
- `keeper/MEMORY.md`
  reusable active domain memory
- `keeper/USER.md`
  user preferences and collaboration habits
- `keeper/WORKING.md`
  short-lived task and observation memory

## Current Limits

The workflow is real, but still partial.

What it does well now:

- persistent markdown workspace
- source-to-related-page updates
- saved query filing
- lightweight review lifecycle
- static build/serve of the resulting wiki

What is still missing:

- richer domain-specific synthesis planning
- deeper page rewrites during review approval
- a true claim graph or evidence model
- smarter retrieval than the current ranking heuristic
- first-class operator UI around the wiki flow
