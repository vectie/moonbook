# MoonWiki requirements capability

MoonWiki is requirements and evidence functionality inside MoonBook. It is
never a standalone `product_id`, pack, application, model host or agent
runtime.

The canonical capability is:

```text
moonbook/wiki.requirements.prepare@0.1.0
```

It accepts `moonbook/wiki-requirements-prepare@1.0.0` and emits
`moonbook/wiki-requirements-packet@1.0.0`. MoonFlow must request
`workspace-mutation` authority because the pack-local adapter persists the
output artifact. The operation is deterministic, idempotent and reconcilable;
it has a `digital-artifact` claim ceiling.

## Epistemic boundary

The caller supplies statements and exact versioned evidence. MoonBook validates
and canonicalizes them, then separates them without using a language model:

- `facts`
- `calculations`
- `inferences`
- `unresolved_questions`

Every statement retains one or more evidence reference IDs, and every ID must
resolve to the packet's complete versioned evidence set. Conflicting evidence
or statement identities fail closed.

The packet always records:

```text
product_id = moonbook
functionality = moonwiki
agent_runtime = moonclaw
agent_execution_requested = false
review_status = pending
accepted_truth = false
accepted_into_book = false
requires_human_review = true
external_side_effects_applied = false
```

`agent_runtime = moonclaw` is a boundary declaration for any later reviewed
cognitive step. The preparation operation does not call MoonClaw, choose a
model, rewrite evidence, answer unresolved questions or approve knowledge.

## Durable adapter path

Prepare an idempotent workspace-relative packet:

```sh
moon run cmd/moonflow_adapter -- prepare-requirements \
  --workspace /absolute/workspace \
  --requirements-request inputs/requirements-request.json \
  --output outputs/requirements-packet.json
```

Recompute and reconcile it:

```sh
moon run cmd/moonflow_adapter -- reconcile-requirements \
  --workspace /absolute/workspace \
  --requirements-request inputs/requirements-request.json \
  --packet outputs/requirements-packet.json
```

If an output path already contains different bytes, the adapter fails rather
than overwriting the evidence identity. Reconciliation recomputes the canonical
packet from the exact request and reports `exact` only for a byte-equivalent
typed value.

For unattended MoonFlow execution, bind:

```text
product_id: moonbook
operation: moonbook/wiki.requirements.prepare@0.1.0
requested_authority: workspace-mutation
input_contracts:
  - moonbook/wiki-requirements-prepare@1.0.0
output_contracts:
  - moonbook/wiki-requirements-packet@1.0.0
```

The first input artifact is the exact typed requirements request. MoonFlow may
append immutable dependency evidence after it; every reference remains
workspace-relative, and the adapter verifies the current aggregate
artifact-set digest before reading the typed primary. The adapter writes the packet and a standard MoonFlow
result receipt. The artifact remains pending review until a separate,
authorized MoonBook acceptance path records a named-human decision.

## Capability truth

Three sources must agree:

- [`../pack.json`](../pack.json) owns the tool and schemas.
- [`../capabilities/moonflow.adapter-declaration.v1.json`](../capabilities/moonflow.adapter-declaration.v1.json)
  declares the MoonFlow v2 binding.
- host-generated, expiring health evidence proves the exact installed
  operation reference.

The historical `moonwiki_moonflow_adapter_capability_json` API now returns only
non-callable deprecation metadata. It must not be compiled into a live product
node.
