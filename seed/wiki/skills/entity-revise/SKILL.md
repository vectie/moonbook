---
name: entity-revise
description: Revise entity pages so they accumulate durable identity, role, relationships, and operational relevance instead of fragmenting into weak duplicate notes.
---

# Entity Revise

## Purpose

Use this skill when a source or synthesis update affects a named entity.
Examples include:

- a repo
- a system component
- a service
- a role
- a person or team when relevant to the domain

## Inputs

Read:

1. the existing entity page if present
2. relevant source pages
3. relevant concept pages
4. nearby synthesis pages when the entity has system-level importance

## Main questions

For the entity, determine:

- what it is
- what role it plays
- what it is related to
- what changed
- what remains uncertain

## Page design rules

Entity pages should be:

- identity-first
- relationship-aware
- cumulative
- stable over time

Avoid turning them into:

- generic note buckets
- one-source summaries
- token-derived fragments

## Revision priorities

Prefer updating:

- identity section
- role and responsibilities
- relationships
- operational relevance
- change notes with source support

## Relationship rules

Relationships should say something real.

Good:

- "Moontown dispatches work into MoonBook book workspaces."

Bad:

- "Moontown is related to MoonBook."

## Uncertainty rules

If the source support is partial, say so.
Do not imply stable identity from weak signals.

## Anti-patterns

- duplicate entity pages
- entity pages that are just restated source summaries
- pages with no relationships
- vague role descriptions

## Checklist

Before finishing, confirm:

- the entity has a clear identity
- the role is explicit
- the relationships are concrete
- uncertainty is preserved

## Failure modes

Common failure modes:

- the page turns into a source summary instead of an entity page
- the page says what the entity is but not why it matters
- relationships are vague
- changes are recorded without support

Fix these before considering the revision complete.

## Exploration Quality Contract

Every run should improve the book's ability to answer deeper and broader
questions about its topic.

- Go deeper: explain the mechanism, evidence chain, confidence boundary,
  contradiction, or internal dependency that makes the result true, weak, or
  blocked.
- Go broader: connect the result to adjacent entities, concepts, source pages,
  downstream decisions, and book-maintenance consequences.
- Generate new questions: record follow-up questions that would change the
  answer, expose missing evidence, or open a useful next investigation.
- Generate new directions: name the next durable page, review item, experiment,
  comparison, or synthesis update that should grow from this work.
- Prefer longer meaningful text over short status output when evidence exists:
  give enough context that a future keeper can resume without the chat history.
