# Generic product-outcome closure

## Outcome

MoonBook owns one generic closed-loop operation:

```text
moonbook/bookkeeper.outcome.close@0.1.0
```

This is the executable replacement for the aspirational canvas label
`bookkeeper.close-loop`. A canvas or workflow must use the exact versioned
operation and schema identities:

```text
input  moonbook/bookkeeper-product-outcome-closure@1.0.0
output moonbook/bookkeeper-product-outcome-closure-receipt@1.0.0
```

No finance, media, robotics or other domain policy is implemented here.
Producing products retain ownership of their deliverables, results and outcome
metrics.

## Exact intake boundary

Before closure, the existing Bookkeeper store must contain:

1. a `DeliverableAcceptance` record;
2. its exact named-human `Accept` review receipt;
3. a `product.result` ingress envelope from the producing product, whose
   subject is that exact deliverable;
4. the complete canonical union of deliverable and result evidence.

The request repeats the exact identity, version and digest of the deliverable,
result and review receipt. Substituted versions, partial evidence, conflicting
evidence identities and non-human review receipts fail closed.

The producing product supplies three structured gap statements:

- information: unknown → known;
- recognition: known → matters;
- decisiveness: matters → action.

MoonBook validates severity and evidence linkage and deterministically records
all three dimensions in one `ThreeGapAssessment`. It does not ask an LLM to
invent a gap, severity or evidence reference.

## Resumable governed progression

The same request is replayed after each human decision:

```text
exact accepted deliverable + exact product.result
  → durable outcome binding
  → deterministic Three-Gap assessment
  → G1 named-human assessment review
  → reviewable capability proposal
  → G2 named-human proposal review
  → non-activating MoonFlow handoff
  → later MoonFlow evaluation and separate activation review
```

The operation is journal-idempotent. If it stops after a record is written,
replaying the request reconciles against that exact record rather than
duplicating it.

The receipt states one of:

- `assessment_review_required`;
- `closed_no_capability_change`;
- `proposal_review_required`;
- `reviewed_proposal_handed_off`.

Every receipt has `activation_authorized: false` and
`external_side_effects_applied: false`. The handoff is evidence that a reviewed
proposal is ready for MoonFlow evaluation. It is not a capability activation
request and cannot install, canary, promote or roll back a capability.

## Runtime boundary

The implementation reuses:

- `bookkeeper` for immutable deliverable, Three-Gap and proposal types;
- `bookkeeper_store` for the journal, replay, authority grants, reviews and UI
  projection;
- `cmd/moonflow_adapter` for the existing pack-local adapter process.

It creates no second agent runtime and no separate Bookkeeper application.
MoonClaw remains the generic agent runtime. MoonFlow remains the workflow and
activation-state owner. Existing MoonBook/Rabbita projections display the
durable records and pending reviews.

Direct invocation:

```sh
moon run cmd/moonflow_adapter -- close-product-outcome \
  --workspace /path/to/book \
  --closure-request records/outcome-closure.json
```

MoonFlow `unattended` invocation uses the same adapter command with the
canonical operation and schema references above.

## Capability truth and health

The product manifest is [`../pack.json`](../pack.json). The pack-local MoonFlow
v2 binding is
[`../capabilities/moonflow.adapter-declaration.v1.json`](../capabilities/moonflow.adapter-declaration.v1.json).

Health is installation-owned and expiring. Generate it only after an actual
focused closure check:

```sh
moon run cmd/moonbook_adapter -- health \
  2026-07-31T00:00:00Z \
  2026-07-31T00:05:00Z \
  health/moonbook-outcome-close.json \
  sha256:<64-lowercase-hex-digits>
```

The host verifies the referenced bytes, combines the manifest, declaration and
health attestation into `moonflow.capability-source-bundle.v1`, and compiles a
catalog. MoonGate only projects the operation after that catalog passes
conformance.

## Remaining human gates

- The deterministic Three-Gap assessment requires named-human review.
- A proposed capability change requires a second named-human review.
- MoonFlow evaluation, canary/shadow policy and activation review remain
  separate.
- The producing product must provide real outcome evidence and a truthful
  `product.result` ingress; MoonBook does not manufacture business outcomes.
