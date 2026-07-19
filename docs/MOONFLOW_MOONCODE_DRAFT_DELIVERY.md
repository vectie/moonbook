# MoonFlow delivery of reviewed MoonCode drafts

MoonBook owns this adapter because Bookkeeper owns the durable proposal,
review, work order, egress, and import receipt. MoonFlow remains a generic
transport and supervision kernel. MoonClaw remains the only agent runtime, and
MoonCode remains the implementation surface.

The adapter can do exactly one mutation: import one already reviewed,
digest-bound MoonBook egress as an inert MoonClaw proposal with status `Draft`.
It cannot confirm that proposal, execute it, create a MoonClaw run, or authorize
an external effect.

## Required evidence

A delivery request uses
`moonbook.bookkeeper.mooncode-draft-delivery.v1` and binds:

- a stable `delivery_id` and `delivery_version`;
- the exact Bookkeeper egress envelope reference;
- the current envelope digest, repeated as `expected_envelope_digest`.

Preparation replays the Bookkeeper journal, rejects any replay issue, verifies
that the egress is a `mooncode.work_order` from MoonBook to MoonFlow, verifies
its exact accepted named-human review, and recomputes the envelope's canonical
digest. A deterministic MoonClaw packet is then materialized from that egress.

Before invoking MoonClaw, MoonBook writes a fail-closed claim. If the process
dies after import but before receipt persistence, the same identity is blocked
for reconciliation instead of silently importing a duplicate proposal. A
successful response must contain `proposal_id` and `status: "Draft"`, and must
not contain a job, workflow, or run identity.

The immutable receipt binds the request, adapter version, envelope, work order,
packet digest, MoonClaw proposal ID, and MoonClaw output digest. Its
`confirmed`, `executed`, `external_effect_authorized`, and
`side_effects_applied` fields are always false.

## Build and direct operation

Build MoonBook's two native executables and use the generated binary paths from
your MoonBit target directory:

```sh
moon build --target native cmd/moonflow_adapter
moon build --target native cmd/moonflow_attestor
```

`<moonflow-adapter-binary> capabilities` emits the matching generic
`moonflow.adapter.v1` capability with adapter ID
`moonbook-mooncode-draft-delivery`. Put that object in MoonFlow's capabilities
artifact; its ID matches the example unattended driver.

Create a request from
[MOONCODE_DRAFT_DELIVERY_REQUEST.example.json](MOONCODE_DRAFT_DELIVERY_REQUEST.example.json),
replacing every illustrative record reference with the exact current values.
Then run:

```sh
<moonflow-adapter-binary> deliver-reviewed-draft \
  --workspace <book-workspace> \
  --delivery-request runtime/mooncode-delivery/request.json \
  --moonclaw <moonclaw-checkout> \
  --home <moonsuite-home> \
  --cwd <mooncode-workspace>
```

The adapter invokes MoonClaw through an argument array equivalent to:

```text
moon -C <moonclaw-checkout> run cmd/main -- proposal import <packet> --json --cwd <mooncode-workspace> [--home <moonsuite-home>]
```

There is no shell interpolation and no adapter option that can add `--confirm`
or `--inline`.

## Generic MoonFlow unattended driver

Use the driver object in
[MOONFLOW_MOONCODE_DRAFT_DRIVER.example.json](MOONFLOW_MOONCODE_DRAFT_DRIVER.example.json)
inside a `moonflow.unattended-manifest.v3` manifest. Substitute absolute native
binary/check-out paths and generate unique draft/final artifact paths for each
delivery identity. The `--output` value must equal the driver's sole
`draft_output_artifacts` entry.

MoonFlow replaces only its standard `{workspace}`, `{request}`, `{result}`,
`{receipt}`, and `{review}` argument placeholders. The product attestor is the
existing `cmd/moonflow_attestor` binary under a distinct attestor identity. It
rechecks the typed request and every receipt invariant, then copies that exact
receipt to the separately named final artifact.

The reviewer executable and review-authority ID are intentionally deployment
owned. They must be independent of both adapter and product attestor and must
emit MoonFlow's generic acceptance-review receipt. This adapter does not weaken
or bypass that generic MoonFlow gate.

Ordered HTTP transport is not used here: the required MoonClaw action is a
local CLI draft import. MoonFlow therefore invokes the bounded native adapter
as an executable. No MoonFlow source change or domain-specific branch is
required.

## Recovery and idempotency

- Reusing an identity with the same request returns the existing receipt.
- Reusing it with a different request, envelope digest, packet, or receipt is
  rejected.
- A claim without a receipt is never retried automatically. Inspect MoonClaw
  for the recorded packet/import outcome and reconcile it explicitly.
- Accepted MoonClaw assets and Bookkeeper evidence remain user-owned; removing
  the adapter does not remove either.

Draft delivery completes the transport loop only. Human confirmation inside
MoonClaw and any later MoonCode execution remain separate governed actions.
