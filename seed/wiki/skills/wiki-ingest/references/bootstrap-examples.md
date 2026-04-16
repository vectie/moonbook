# Bootstrap Examples

## Repo research packet example

```
# Moontown research packet

## Provenance
- ../moontown/README.md
- ../moontown/goal_run.mbt
- ../moontown/roles/mayor.mbt

## Synopsis
Moontown is the town-level control plane. It schedules goals, routes them into books, and tracks multi-stage runs.

## Evidence
- goal runs persist state and events
- mayor logic shapes dispatch
- books receive domain-local goals

## Entities
- Moontown
- Mayor
- Goal Run

## Concepts
- control plane
- ingest-first routing
- town-level orchestration

## Open questions
- how recovery is surfaced to operators
- how experiment policy is enforced

## Suggested pages
- wiki/sources/moontown-source.md
- wiki/entities/moontown.md
- wiki/concepts/control-plane.md
```

## Multi-project bootstrap guidance

When the user asks for `research moontown, moonbook and moonclaw`:

1. create one packet per project
2. then create one cross-project packet
3. revise source pages first
4. revise cross-project synthesis only after source pages exist

## File naming guidance

Prefer stable names:

- `raw/bootstrap/moontown-overview.md`
- `raw/bootstrap/moonbook-overview.md`
- `raw/bootstrap/moonclaw-overview.md`
- `raw/bootstrap/cross-project-topology.md`

Avoid vague names such as:

- `notes.md`
- `result.md`
- `research.md`
