# Generic product-outcome closure

## Outcome

MoonBook owns one generic closed-loop operation:

```text
moonbook/bookkeeper.outcome.close@0.1.0
```

Producing packs normally enter it through the replayable intake operation:

```text
moonbook/bookkeeper.outcome.submit@0.1.0
```

`bookkeeper.outcome.submit` is the canonical MoonDesk/MoonTown-to-MoonBook
boundary for the exact `ProductOutcomeSubmission` emitted by MoonClaw. It
accepts an evidence-bound product deliverable, result, external decision
evidence, and explicit Three-Gap statements. The complete submission JSON is
retained inside the immutable deliverable payload; it is not reconstructed
from a reduced transport projection. The operation creates the canonical
Bookkeeper deliverable and `product.result` ingress, then stops at MoonBook's
own named-human deliverable review. Replaying that exact submission after the
review delegates to `bookkeeper.outcome.close`; later replays advance only
through the existing assessment and proposal gates.

These are the executable replacements for the aspirational canvas label
`bookkeeper.close-loop`. A canvas or workflow must use the exact versioned
operation and schema identities:

```text
input  moonbook/bookkeeper-product-outcome-submission@1.0.0
output moonbook/bookkeeper-product-outcome-submission-receipt@1.0.0

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

When all three supplied gaps explicitly state `present: false` and `severity: 0`,
the existing v1 submission and closure contracts permit all four capability
descriptor fields to be omitted together: `capability_id`, `capability_version`,
`capability_change_digest`, and `capability_summary`. A partial group or null is
invalid. A present gap still requires the complete real descriptor. Existing
complete descriptors remain valid even for no-gap outcomes, and their canonical
serialization and assessment summary are unchanged. Omission does not remove
evidence, summaries, or the existing human review gates.

An omitted descriptor uses the supplied outcome summary for the assessment and,
after its existing review, closes as `closed_no_capability_change`. It produces
no capability proposal or activation handoff. Native typed callers use four
`String?` fields (`Some` for existing values, `None` for omission); function names
and flat JSON field names remain unchanged. See the checked
[no-change example](../bookkeeper_store/OUTCOME_NO_CHANGE.mbt.md).

This compatibility applies to MoonBook's direct, unattended, and UI-host intake
paths. MoonClaw's independent supervisor schema still requires a complete
descriptor and is not changed by this feature. Existing full-descriptor producers
continue to use their current wire without modification.

MoonBook validates severity and evidence linkage and deterministically records
all three dimensions in one `ThreeGapAssessment`. It does not ask an LLM to
invent a gap, severity or evidence reference.

An external MoonChat acceptance record may be submitted as decision evidence,
but it never installs reviewer authority or substitutes for a MoonBook review.
Reviewer grants remain locally installed and the existing Rabbita Bookkeeper
screen owns each exact human decision.

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

Each MoonBook gate recognizes exactly one complete named-human `Accept` or
`Reject` receipt for the exact subject/version/digest. `Revise`, `Escalate`,
incomplete or non-human reviews do not advance the chain. Multiple final
decisions are ambiguous and fail closed. A `Reject` terminates that immutable
version: deliverable rejection creates no assessment, assessment rejection
creates no proposal, and proposal rejection creates no MoonFlow handoff. A new
attempt requires a new immutable version.

The operation is journal-idempotent. If it stops after a record is written,
replaying the request reconciles against that exact record rather than
duplicating it.

The intake receipt states one of:

- `deliverable_review_required`;
- `deliverable_rejected`;
- any closure state listed below.

The closure receipt states one of:

- `assessment_review_required`;
- `assessment_rejected`;
- `closed_no_capability_change`;
- `proposal_review_required`;
- `proposal_rejected`;
- `reviewed_proposal_handed_off`.

Receipts include the exact durable review reference and explicit final
disposition when present. Because journal replay derives these receipts from
immutable records, the chain is durable and replayable without accepting or
learning from an outcome automatically.

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
moon run cmd/moonflow_adapter -- submit-product-outcome \
  --workspace /path/to/book \
  --submission records/product-outcome-submission.json

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

## Continue an imported task outcome in the browser

After receiving an accepted Proj task in **Make and reuse a lesson**, the
outcome-review panel shows already-saved submissions bound to that exact task
and accepted report. A new task handoff alone supplies context, not outcome
evidence. If no submission exists, choose **Import outcome file** and select a
complete `ProductOutcomeSubmission` produced for this task. Inspect its outcome
summary and evidence before explicitly saving it for review. Raw contract details
stay available in the disclosure.

The ordered path uses the existing decisions:

1. Import the complete evidence-bound outcome, or resume an existing submission
2. Open its exact deliverable in the existing named-human review controls
3. After acceptance, choose **Continue outcome review** to prepare the assessment
4. Open and review that exact assessment using the same controls
5. Refresh the handoff and choose **Start lesson from this assessment**

The existing host exposes `/api/bookkeeper/lessons/outcome-import` and
`/api/bookkeeper/lessons/outcome-continue`. Both receive the exact task handoff;
import also receives the complete submission, while continuation receives only
the saved submission reference and reloads its original immutable payload.
Responses use the existing lesson-operation wrapper and fresh task-handoff
readback. No Book path is accepted from the request. The handoff readback adds
`outcome_submissions`, including the next exact record and current review stage.

Import only reconciles the deliverable and result ingress. Continuation shares
the existing intake and assessment-preparation implementation and structurally
stops before capability proposals. It does not perform a human review, modify
accepted knowledge, activate a capability, or turn Proj's internal acceptance
into a customer outcome. The general adapter's later capability progression is
unchanged. Repeated calls preserve journal identities; an interrupted intake can
resume from its saved submission. Rejected versions stay rejected, and incomplete,
changed or differently bound files are rejected without inventing missing fields.

A complete producer file remains a prerequisite, using the conditional descriptor
rule above for an explicitly no-gap outcome. Successful execution does not
guarantee that one exists. The browser does not author or infer Three-Gap claims,
capability metadata, post-delivery observations, customer acceptance or cash.
Existing installed reviewer permissions are still required; no new review gate
or authority grant is added. The ordinary **Replay and verify** action continues
to rebuild projections, and is distinct from explicitly continuing an outcome.

## Remaining human gates

After assessment review, [reviewed outcome lessons](REVIEWED_OUTCOME_LESSONS.md)
can preserve explicit guidance and applicability in the existing journal. The
Bookkeeper UI supports authoring, named review and retrieval for a later task;
this does not activate the capability proposal.

- The deterministic Three-Gap assessment requires named-human review.
- A proposed capability change requires a second named-human review.
- MoonFlow evaluation, canary/shadow policy and activation review remain
  separate.
- The producing product must provide real outcome evidence and a truthful
  `product.result` ingress; MoonBook does not manufacture business outcomes.
