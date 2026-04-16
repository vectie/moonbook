# MoonClaw Raw-First Contract

## Purpose

This reference defines how MoonClaw workers should cooperate on raw-first wiki maintenance.

## Worker split

Controller responsibilities:

- decide the stage order
- require concrete artifacts
- reject generic success text

Gather worker responsibilities:

- inspect hinted repos and files
- stage packets under `raw/bootstrap/`
- report exact paths and evidence

Revision worker responsibilities:

- convert packets into maintained source, entity, concept, or synthesis pages
- update `wiki/index.md`
- update `wiki/log.md`

Review worker responsibilities:

- reject administrative-only results
- validate support and ontology quality

## Result contract

Never return a success-shaped result with:

- empty `artifacts`
- no `raw/bootstrap/*` packet for bootstrap work
- no substantive `wiki/*` page

If that happens, return a blocker with the missing next action.

## Strong blocker example

`Blocked: inspected the hinted repos but only staged one shallow packet. No durable source page could be written because the material did not yet cover runtime and provider behavior.`
