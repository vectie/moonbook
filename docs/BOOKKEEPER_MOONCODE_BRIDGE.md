# Bookkeeper to MoonCode governed bridge

This bridge closes the implementation handoff without adding an agent runtime
to MoonBook or MoonFlow.

The call path is deliberately split into independently reviewed stages:

1. MoonBook loads an exact policy-promoted `CapabilityProposal`, its accepted
   named-human review receipt, and the matching active authority grant.
2. MoonBook reconstructs the canonical learning values and calls
   `project_mooncode_work_order`. The resulting durable work order is inert and
   enters `awaiting human review`.
3. A named human separately reviews that exact `MoonCodeWorkOrder` through the
   existing Bookkeeper review API and Rabbita UI.
4. A second explicit action creates a generic `mooncode.work_order` egress for
   MoonFlow. The envelope carries exact evidence and review links and always has
   `external_activation_allowed=false` and `side_effects_applied=false`.
5. The optional draft importer materializes the egress payload and invokes
   MoonClaw's existing `proposal import` path without `--confirm`. It creates a
   draft only; no code runs until a later human confirms it in MoonClaw.

MoonClaw remains the sole model and agent runtime. MoonCode is the reviewed
coding surface. MoonBook owns the durable proposal, authority, review,
work-order, result, evaluation, and adoption records. MoonFlow remains a generic
transport/orchestration boundary and receives no Bookkeeper or MoonCode domain
branch.

## Commands

```text
moonbook bookkeeper mooncode project <root> <request.json>
moonbook bookkeeper review <root> <work-order-review.json>
moonbook bookkeeper mooncode egress <root> <request.json>
moonbook bookkeeper mooncode import-draft <root> <request.json> [--home <dir>] [--cwd <dir>] [--moonclaw <dir>]
```

The Rabbita Bookkeeper operator panel exposes the projection and egress actions
and explains why either action is disabled. It reuses the existing application;
there is no separate Bookkeeper UI.

The remaining deployment integration is a concrete generic MoonFlow delivery
adapter that transports the accepted egress to the draft importer. That adapter
must not confirm the MoonClaw proposal or execute MoonCode.
