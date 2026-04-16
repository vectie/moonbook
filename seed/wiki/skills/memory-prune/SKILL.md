---
name: memory-prune
description: Keep Keeper memory bounded and useful by pruning stale working residue and promoting durable signals.
---

# Memory Prune

## Purpose

Use this skill to keep Keeper memory bounded and useful.

## Inputs

Read:

1. `keeper/MEMORY.md`
2. `keeper/USER.md`
3. `keeper/WORKING.md`
4. `keeper/INSIGHTS.md`

## Main tasks

1. remove repetitive working-memory items
2. remove expired task residue
3. preserve real user preferences
4. preserve durable operational memory
5. recommend promotion when a memory item now belongs in the wiki

## Pruning rules

Prune aggressively when:

- items are redundant
- items are outdated
- items were promoted already

Do not prune:

- stable collaboration preferences
- still-active operational context

## Anti-patterns

- deleting useful working state too early
- keeping every old task note forever
- moving user preferences into generic memory buckets

## Checklist

Before finishing, confirm:

- noise went down
- useful memory stayed
- durable knowledge was routed upward when appropriate

## Example good prune

- remove three repeated task-status notes from `keeper/WORKING.md` after the durable outcome was promoted into the wiki

## Example bad prune

- deleting an active unresolved blocker because it looked repetitive

## Escalation rules

Escalate when:

- working memory is large because the wiki is missing durable coverage
- repeated noise points to a structural workflow problem
- a user preference and a task note are mixed together

## Final reminder

Pruning is not deletion for its own sake.
It is boundary management.

## Additional heuristics

Keep an item when:

- it is still active
- it will matter in the next few runs
- deleting it would force needless rediscovery

Drop or rewrite an item when:

- it repeats a stronger existing note
- it refers to a completed task
- it belongs in the wiki instead

## Example good rewrite

- compress four similar task notes into one clear unresolved blocker

## Operator reminder

The point is not a shorter file.
The point is a cleaner working boundary.
Prefer fewer, stronger notes over many repetitive ones.
Leave the next run with less confusion, not less data.
