# Home

This workspace is an LLM-maintained wiki.

## Structure

- `../site/`: marketing website projection copied to `book/site/` during build
- [Index](./index.md): content catalog of the wiki
- [Log](./log.md): append-only timeline of ingests, queries, and lint passes
- [Claims Register](./synthesis/claims.md): structured claims extracted from sources
- [Maintenance Plan](./synthesis/maintenance-plan.md): queued multi-page wiki revisions
- [Synthesis Map](./synthesis/map.md): coverage and hub view across the wiki
- [Observations](./synthesis/observations.md): persisted worker results and promoted observations
- [Pending Review](./reviews/pending.md): human review queue for contested or high-value updates
- `../keeper/`: bounded active memory, user memory, and working memory for Keeper
- `../raw/`: immutable source documents

## Usage

1. Drop a source into `raw/`
2. Ask the LLM to ingest it into the wiki
3. Build or serve with MoonBook to publish the detailed wiki and the `site/` marketing projection together
