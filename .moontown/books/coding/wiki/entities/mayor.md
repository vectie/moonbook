# Mayor

## Identity

Mayor is the strategic runtime role embedded by Moontown for town-level dispatch and keeper packet preparation.

## Role

- Decides dispatch for town tasks.
- Patrols town state.
- Prepares keeper-facing proposal packets from MoonBook task context.

## Relationships

- Lives inside [Moontown](./moontown.md).
- Uses [MoonBook](./moonbook.md) worker context to prepare packets.
- Maps tasks onto [MoonClaw](./moonclaw.md) controller profiles such as `wiki_ingest_controller` and `wiki_query_controller`.
- Is evidenced by [Moontown Repo Overview](../sources/moontown-repo-overview.md).

## Operational Relevance

Mayor is the explicit bridge between town scheduling and bounded keeper execution.

## Uncertainty

- The current sources clarify role mapping and packet preparation more than detailed patrol behavior.
