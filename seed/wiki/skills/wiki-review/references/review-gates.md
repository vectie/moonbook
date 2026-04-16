# Review Gates

## Purpose

This reference defines the approval gate for durable promotion.

## Approve only when

- cited evidence exists
- the target page is appropriate
- wording strength matches support
- ontology quality improves or stays clean
- the change helps future query or ingest work

## Reject when

- the run is administrative-only
- the evidence is missing
- the target page is wrong
- the wording overclaims
- the change adds clutter or duplicate pages

## Request revision when

- the evidence is real but incomplete
- the page target should change
- the writing is unclear
- the change needs narrower scope

## Special gate for MoonClaw ingest runs

If the controller claims success but lists no substantive `wiki/*` page artifacts, treat it as blocked and send it back.
