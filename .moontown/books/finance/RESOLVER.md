# Resolver

This file routes tasks to the right skills and context files.

## Routes

- intent: ingest
  skill: `skills/wiki-ingest/SKILL.md`
  supporting_skills: `skills/source-diarize/SKILL.md`, `skills/entity-revise/SKILL.md`, `skills/concept-revise/SKILL.md`, `skills/synthesis-revise/SKILL.md`, `skills/claim-audit/SKILL.md`, `skills/index-maintain/SKILL.md`
  load_first: `wiki/index.md`, `wiki/log.md`, `wiki/synthesis/maintenance-plan.md`
- intent: query
  skill: `skills/wiki-query/SKILL.md`
  supporting_skills: `skills/query-promote/SKILL.md`, `skills/claim-audit/SKILL.md`
  load_first: `wiki/index.md`, `wiki/synthesis/overview.md`, `wiki/synthesis/claims.md`
- intent: lint
  skill: `skills/wiki-lint/SKILL.md`
  supporting_skills: `skills/contradiction-review/SKILL.md`, `skills/index-maintain/SKILL.md`, `skills/memory-prune/SKILL.md`
  load_first: `wiki/index.md`, `wiki/log.md`, `wiki/synthesis/map.md`, `keeper/INSIGHTS.md`
- intent: review
  skill: `skills/wiki-review/SKILL.md`
  supporting_skills: `skills/review-decision/SKILL.md`, `skills/contradiction-review/SKILL.md`, `skills/claim-audit/SKILL.md`
  load_first: `wiki/reviews/pending.md`, `wiki/reviews/approved.md`, `wiki/synthesis/evidence.md`
- intent: memory
  skill: `skills/wiki-memory/SKILL.md`
  supporting_skills: `skills/memory-prune/SKILL.md`, `skills/query-promote/SKILL.md`
  load_first: `keeper/MEMORY.md`, `keeper/USER.md`, `keeper/WORKING.md`, `keeper/INSIGHTS.md`
- intent: marketing
  skill: `skills/wiki-marketing/SKILL.md`
  supporting_skills: `skills/wiki-query/SKILL.md`, `skills/synthesis-revise/SKILL.md`, `skills/query-promote/SKILL.md`
  load_first: `wiki/synthesis/overview.md`, `wiki/index.md`, `wiki/synthesis/map.md`, `keeper/INSIGHTS.md`, `site/index.html`
