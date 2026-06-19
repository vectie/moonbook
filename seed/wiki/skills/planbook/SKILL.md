---
name: planbook
description: Maintain a plan-first MoonBook workspace for executable plans, acceptance criteria, implementation evidence, and self-healing repair packets.
---

# PlanBook

## Purpose

Use this skill when the book is not trying to teach a course or publish a
research report. A PlanBook turns goals, bug reports, design notes, validation
logs, and operator decisions into durable plans that can drive implementation
and later verification.

A good PlanBook makes work restartable:

- the problem is explicit
- the owner boundary is explicit
- the proposed change is bounded
- the files or systems to inspect are named
- the acceptance criteria are checkable
- validation evidence is recorded after work happens
- unresolved gaps become follow-up repair packets

## Inputs

Read these first when they exist:

1. `plans/index.md`
2. `wiki/planning/index.md`
3. `wiki/planning/execution-evidence.md`
4. `wiki/reviews/active-plan-review.md`
5. `wiki/log.md`
6. `keeper/WORKING.md`
7. `keeper/INSIGHTS.md`
8. the user request or repair packet under `raw/`

Then inspect only the source files, docs, test output, or run logs needed to
make the plan executable. Do not summarize an entire repository when a bounded
file map is enough.

## Output Contract

Produce a `keeper.planbook.packet.v1` style result.

Required fields in the final answer or packet:

- `decision`: `ready_to_execute`, `needs_owner`, `needs_more_context`, or
  `blocked`
- `plan_path`: durable plan path, usually `plans/<slug>/plan.md`
- `owner`: the component that owns the next change
- `acceptance_criteria`: concrete checkboxes or testable statements
- `validation_commands`: commands or manual checks that prove the plan worked
- `changed_artifacts`: files written or intentionally left unchanged
- `follow_up_gaps`: remaining gaps, each with owner and next action

## Plan Shape

Write plans in this order:

1. Title and status
2. Goal
3. Problem statement
4. Non-goals
5. Owner boundaries
6. Context read
7. Proposed implementation
8. File map
9. Acceptance criteria
10. Validation plan
11. Risks and rollback
12. Handoff notes

Use checkboxes for acceptance criteria. Keep them precise enough that a later
agent can mark them true or false without rereading the entire conversation.

## Owner Boundaries

Respect the system split:

- Moontown owns control-plane orchestration, live autonomy, town UI, routing,
  repair dispatch, and cross-book status.
- MoonBook owns workspace semantics, skills, durable wiki/plan/course/research
  artifacts, generated sites, review queues, and book-local memory.
- MoonClaw owns execution, worker runtimes, tool use, observations, and packaged
  results.
- Moondesk owns human-facing desktop/file-manager style interaction.

If a gap belongs to another component, do not hide that with a local workaround.
Write a plan or repair packet for the correct owner.

## Quality Rules

- Do not present planning as completed implementation.
- Do not use `research-report/SKILL.md` unless the requested artifact is a
  research report.
- Do not use `wiki-course/SKILL.md` unless the requested artifact teaches a
  learner.
- Prefer one clear plan over many versioned drafts.
- When quality is low, revise the same plan in place instead of creating
  `v1`, `v2`, `v3` plan sprawl.
- Separate operational evidence from domain evidence.
- Record commands and outcomes, not just intentions.
- If validation was not run, say exactly why.

## Quality Bar

A PlanBook artifact is only good when another agent can resume from it without
asking the original author what was meant. Before returning, check that the plan
is:

- Executable: it names concrete tasks, files, commands, and decision points.
- Evidence-aware: every diagnosis points to observed files, logs, tests, docs,
  or an explicit unknown.
- Owner-bounded: each gap names the component that should fix it, especially
  when the owner is not the current book.
- Acceptance-tested: criteria are checkboxes that can be verified true or false.
- Restartable: it records current status, next action, and validation evidence.
- Risk-aware: it names likely failure modes, rollback, and what not to change.
- Non-fake: it never marks unresolved or external-owner work as complete.

## Review Rubric

When reviewing a plan or repair packet, fail the artifact if any of these are
true:

- the owner boundary is missing or assigns work to the wrong component
- acceptance criteria are vague, subjective, or not testable
- validation commands are absent, impossible, or unrelated to the change
- the file map is missing for code work
- the plan hides external-owner gaps behind a local workaround
- the packet creates version sprawl instead of revising the durable plan
- operational evidence is counted as domain knowledge
- the final packet omits `remaining_blockers`

If none of those failures apply, use `remaining_blockers: none`. If blockers
remain, list each blocker with owner, evidence, and the next dispatchable action.

## Concrete Example

Request:

> Make the town able to fix its own missing live-autonomy gaps.

Good output:

```markdown
# Live Autonomy Self-Healing Plan

Status: ready_to_execute
Owner: moontown

## Goal

Moontown should discover open PlanBook criteria, dispatch bounded repair work,
reconcile results, and refresh the live spine without pretending unresolved
external-owner gaps are solved.

## Acceptance Criteria

- [ ] `planbook autonomy` lists open and satisfied criteria from durable state.
- [ ] `planbook repair status` shows the active repair packet and owner.
- [ ] `live refresh` updates PlanBook gap counts from authoritative state.
- [ ] External-owner gaps remain open until the owning repo exposes the required
  artifact or profile.

## Validation

- `moon check --no-render`
- `moon test planbook_autonomy_wbtest.mbt live_autonomy_wbtest.mbt`
- `moon run cmd/main -- planbook autonomy`
- `moon run cmd/main -- live refresh`
```

## Result Packet

```yaml
decision: ready_to_execute
plan_path: plans/live-autonomy-self-healing/plan.md
owner: moontown
acceptance_criteria:
  - planbook autonomy lists durable open and satisfied criteria
  - repair status exposes active packet, owner, and evidence
validation_commands:
  - moon check --no-render
  - moon test planbook_autonomy_wbtest.mbt live_autonomy_wbtest.mbt
changed_artifacts:
  - plans/live-autonomy-self-healing/plan.md
  - wiki/planning/index.md
follow_up_gaps:
  - owner: moonbook
    next_action: expose a stable book-health field if needed by Moontown
remaining_blockers: none
```

Bad output:

```markdown
The system is now self-healing.
```

This is bad because it does not identify criteria, owner, evidence, validation,
or remaining gaps.

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
