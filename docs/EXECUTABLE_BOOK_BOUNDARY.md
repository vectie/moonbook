# Executable Book Boundary

Last checked: 2026-06-18.

MoonBook is the durable executable book. It owns the filesystem truth that both
human-language and executable/code-language editing operate on.

## Standalone Project Rule

MoonBook must run as its own checkout. It may persist artifacts produced by external runtimes, but it must not require adjacent MoonClaw, MoonTown, or MoonDesk source checkouts to build, test, serve, or edit books. Cross-project integration should use configured paths, published packages, or runtime protocols.

## Product Model

```text
MoonBook = executable book
MoonWiki = human-language book editing
MoonCode = executable/code-language book editing
MoonClaw = the single bounded agent runtime
MoonTown = coordination network for books
Bookkeeper = acceptance gate
```

MoonBook should not become an agent runtime. It stores accepted knowledge,
accepted code, sources, evidence, review receipts, generated sites, package
manifests, and durable outputs.

Bookkeeper agent work runs on MoonClaw. Bookkeeper's existing visual surface is
MoonBook Rabbita; it does not introduce another runtime or frontend. When that
work needs durable orchestration, MoonClaw may use MoonFlow as a generic engine,
but MoonFlow has no agent model loop, persona, or reasoning lifecycle.

For the Three-Gap closed loop, MoonBook emits a snapshot-bound
`moonbook.bookkeeper.moonclaw-request.v1` packet and submits it to MoonClaw's
existing external-proposal runtime using the generated
`bookkeeper_three_gap_controller` profile. Its analysis steps use
`gpt-5.6-sol`. MoonClaw performs evidence interpretation and candidate proposal
work; MoonBook still owns every durable record, deterministic validation,
Rabbita projection, and named-human acceptance gate. A MoonClaw run result is
never itself a persisted finding, accepted proposal, MoonCode dispatch, or
capability adoption.

MoonBook closes the runtime-to-book boundary with the deterministic command
`bookkeeper moonclaw ingest-result <root> <packet.json> <result.json>`. It
validates the strict `moonbook.bookkeeper.moonclaw-result.v1` shape against the
packet's embedded immutable snapshot and binding digest, then materializes only
a review-gated Three-Gap finding or capability proposal into the journal and
Rabbita queue. Exact replay is idempotent; changed content under the same
identity/version fails closed. This path never installs reviewer authority,
creates an acceptance receipt, or applies the proposed capability. Named-human
`bookkeeper review` remains a later, separately authorized operation.

## Durable Layout

A mature executable book can contain both prose and executable behavior:

```text
<book>/
  book.json
  raw/
    inbox/
    bootstrap/
    extracted/
    analysis-runs/
  wiki/
    index.md
    sources/
    methods/
    reviews/
    history/
  skills/
  schemas/
  tools/
  apps/
  portable/app-tool/
  site/generated/
  .moonsuite/products/mooncode/sessions/
```

MoonBook already strongly owns the Wiki side: `wiki init`, `wiki ingest`,
`wiki query`, `wiki review`, `wiki lint`, `raw/bootstrap`, seeded skills,
standing-watch decisions, and review queues.

The next documentation and template hardening is to make the Code side equally
first-class: book-owned `tools/`, `apps/`, package manifests, test evidence,
MoonCode review receipts, and executable artifact promotion should be described
as normal MoonBook surfaces, not only as MoonDesk or MoonClaw side effects.

## Boundary Rules

- MoonBook owns durable truth and accepted artifacts.
- MoonClaw may stage raw results, code diffs, package proof, and runtime events.
- Bookkeeper/user review decides what is accepted.
- MoonTown schedules and coordinates book work, but does not own topic memory.
- MoonDesk projects and edits the book, but should not own book semantics.

## Generic Bookkeeper Finalization

The public bookkeeper package owns the domain-neutral finalization boundary. It
is separate from the wiki persistence API so packs can declare acceptance
requirements without adding domain branches to Bookkeeper.

The stable moonbook.bookkeeper.v1 contracts are:

- DeliverableCandidate
- BookkeeperDecision
- DeliverableBundle
- OutcomeObservation
- ThreeGapAssessment
- CapabilityProposal
- LearningReceipt

project_acceptance_requirements copies pack identity, pack version, and ordered
declarations into the candidate snapshot. finalize_deliverable produces an
immutable bundle only for Accept after artifacts, evidence, provenance,
requirements, checklists, workflow/gate/cost/authority receipts, reviewer
authority, release/acceptance receipts, retention/rollback references, and
delivery/publication authorization pass validation. A supplied outcome must
match the exact bundle id/version and candidate id/version/digest. Invalid
accept requests fail closed to Revise; Reject, Revise, and Escalate never carry
a deliverable bundle.

Capability proposals and learning receipts are versioned, owner-routed,
evidence-linked review records. They deliberately expose no self-application
path: an accepted learning receipt records review but does not modify the
capability.

### Bookkeeper Rabbita Projection

MoonBook's existing Rabbita application contains the sole generic Bookkeeper
operator surface. Its UI snapshot contract is `moonbook.bookkeeper.ui.v1` and
is loaded from `.moonbook/bookkeeper/ui-state.json` inside the active workspace.
The snapshot is a projection of the contracts above, not a second source of
truth and not an authority token. It exposes the acceptance, outcome,
Three-Gap, proposal, review, MoonCode work-order, evaluation, and adoption
lanes, including evidence/issue counts, owner routes, human-review requirements,
and next-action labels.

Missing, malformed, or incompatible snapshots fail closed to visibly empty
lanes. MoonBook's native Bookkeeper store now persists immutable JSON journal
events under `.moonbook/bookkeeper/journal/`, replays every event with exact
identity/version/digest linkage, and atomically rebuilds both `snapshot.json`
and `ui-state.json`. A process lock serializes mutations; same-reference replay
is idempotent and conflicting content fails closed. Each stage also validates
the canonical payload contract (`moonbook.bookkeeper.v1`, Three-Gap v1, or
capability-adoption v1 as appropriate) before journaling, and recomputes the
record's SHA-256 digest from canonical persisted JSON rather than trusting a
declared payload digest.

The existing MoonBook host exposes domain-neutral routes inside the normal
`moonbook serve` process:

- `GET /api/bookkeeper/state`
- `GET /api/bookkeeper/ui-state`
- `GET /api/bookkeeper/authorities`
- `POST /api/bookkeeper/replay`
- `POST /api/bookkeeper/records`
- `POST /api/bookkeeper/reviews`
- `POST /api/bookkeeper/envelopes/ingress`
- `POST /api/bookkeeper/envelopes/egress`

There is no separate Bookkeeper application, frontend build, app entrypoint, or
server. The existing Rabbita UI remains the only visual surface. Successful
mutations atomically refresh its served `moonbook-ui-state.json` and live-reload
token. The same Rabbita surface now includes an operator console for selecting
an exact durable record, binding an active CLI-installed authority, preparing a
governed review, replaying the journal, and submitting generic ingress, record,
review, and egress JSON values. It never installs authority or performs the
external action represented by an envelope.

For normal builds, MoonBook compiles the existing `ui/rabbita-book` module and
copies its app shell, JavaScript, UI state, and client config into
`<build-dir>/apps/moonbook/`. Normal `moonbook serve` keeps the rendered book at
`/` and serves that application at `/apps/moonbook/`; the nested app uses the
same workspace-bound `/api/bookkeeper/**` routes. This is static application
mounting inside the normal MoonBook host, not a second Bookkeeper app, server,
or agent runtime.

Review acceptance requires an exact active human authority grant installed by
the local `moonbook bookkeeper authority install` CLI. The HTTP API cannot
create authority grants. Reviews bind the exact subject, evidence snapshot,
reviewer grant, requested disposition, and receipt. Invalid accept requests
fail closed to `Revise` and are not journaled.

Generic ingress and egress envelopes can carry MoonFlow handoffs, MoonCode work
orders, and MoonCode results. They require exact durable links and explicitly
set both external activation and side effects to false. No envelope, API route,
or CLI command can execute MoonCode, activate a capability, deploy, publish, or
trade.

### Canonical Three-Gap Protocol

The canonical protocol exactly binds an accepted `DeliverableBundle` and its
`OutcomeObservation` to versioned feedback, defect, cost, operator-time, and
metric evidence. The binding preserves the exact deliverable and outcome
identity, version, and digest references rather than inferring association.

The fast loop classifies each finding with an exact transition: Information gap
(`Unknown` → `Known`), Recognition gap (`Known` → `Matters`), or
Decisiveness gap (`Matters` → `Act`). Every finding is versioned,
evidence-linked, severity-rated, owner-routed, and immediately represented by a
non-applying `LearningReceipt` reviewed by a named human. The fast-loop review
requires an opaque, versioned authority attestation whose explicit
`ReviewerKind` is `Human` and whose finding, learning key, subject, proposed
receipt, reviewer authority, evidence set, and requested disposition exactly
match the attempted review. Missing, stale, mismatched, unnamed, unauthorized,
`Automation`, `Agent`, and `System` attestations fail closed and emit no
reviewed finding.

The slow loop deterministically deduplicates and aggregates repeated reviewed
findings. It creates a versioned `CapabilityProposal` only when explicit policy
thresholds pass; threshold failure remains an explicit non-promotion decision
with no proposal.

For MoonClaw-originated proposals, MoonBook places the complete versioned
promotion policy in the packet and remains the deterministic owner of the
decision. On ingest it reconstructs each exact named-human review, reruns the
typed aggregation policy, and generates the SHA-256 aggregation receipt itself.
MoonClaw supplies proposed capability semantics only; it cannot choose policy
thresholds, claim promotion flags, or manufacture the aggregation digest.

MoonCode-ready work-order projection requires an exact, versioned review
attestation with an explicit `ReviewerKind`. Only `Human` is accepted;
`Automation`, `Agent`, and `System` fail closed. The projection is a
review-bound value, not submission or execution.

MoonCode result closure is a separate governed boundary. A
`MoonCodeWorkResultCandidate` is emitted only when one versioned result and its
canonical changed-artifact and evidence snapshots exactly bind to the prior
human-attested work-order projection, policy-promoted `CapabilityProposal`, and
accepted `LearningReceipt`. Exact duplicate replay is idempotent; conflicting,
stale, incomplete, or mismatched identities, versions, digests, provenance, or
authority references fail closed with typed issues and no candidate.

A versioned `CapabilityEvaluation` remains auditable whether it passes or
fails. Passing requires complete declared tests, valid versioned evidence and
metric observations or receipts, an explicit pass result, and a nonblank
versioned rollback reference. A failed or incomplete evaluation cannot
authorize adoption.

Capability adoption uses the same `Accept`, `Reject`, `Revise`, and `Escalate`
vocabulary. Only a requested `Accept` with the exact result candidate, passing
evaluation, and opaque exact attestation from a named, authorized `Human` emits
an immutable `CapabilityVersionReceipt`. Invalid accepts fail closed to
`Revise`; the other dispositions are always non-adopting. The receipt links the
old and new capability versions and digests to the originating Three-Gap
findings, proposal, accepted learning receipt, work-order review authority and
attestation, changed artifacts, evaluation evidence/tests/metrics, named-human
adoption authority, and rollback reference.

The version receipt authorizes adoption as a reviewed value only. Bookkeeper
does not execute MoonCode, apply or activate the capability, mutate memory,
policy, or skills, persist the decision, deploy or publish artifacts, or
integrate MoonFlow. Every result, evaluation, attestation, decision, and receipt
keeps the non-applying boundary explicit.

Bookkeeper performs no silent self-modification and applies no code, policy,
skill, or capability change. Named human review and MoonCode remain separate
authority boundaries, and Bookkeeper exposes no path that collapses either
boundary into application.

## Portable Event Contract

MoonBook publishes meaningful book changes with a project-local JSON contract
named `moonbook.executable_event.v1`. This is not a shared source dependency:
other projects may mirror the same JSON fields, but MoonBook remains runnable as
its own checkout.

Core fields:

```json
{
  "protocol": "moonbook.executable_event.v1",
  "id": "book-event-<book-id>-<evidence-or-result-id>",
  "source": "moonbook",
  "book_id": "<book-id>",
  "result_id": "<result-id>",
  "run_id": "<optional-runtime-run-id>",
  "event_type": "knowledge_accepted | review_required",
  "accepted": true,
  "requires_review": false,
  "notify_town": true,
  "summary": "<operator-readable summary>",
  "artifacts": ["wiki/...", "tools/...", "apps/..."],
  "evidence_id": "<optional-evidence-id>",
  "review_path": "<optional-review-page>",
  "lifecycle_proof": {
    "contract_id": "mooncode-executable-book-lifecycle.v1",
    "owner": "moonclaw",
    "session_id": "<runtime-session-id>",
    "book_root": "<book-root>",
    "ready": false,
    "status": "blocked",
    "completed_step_count": 7,
    "step_count": 9,
    "blocked_step_count": 2,
    "first_blocker_id": "package_output",
    "first_blocker_label": "Package output",
    "first_blocker_evidence": "package results 0, package events 0"
  }
}
```

`run_id`, `evidence_id`, `review_path`, and `lifecycle_proof` are optional and
may be omitted when absent.

MoonCode producers include their native `command_id` and `result_id` on the
surrounding envelope or executable event when available. The nested
`BookResult` uses `result_id` directly; MoonCode result persistence is not
adapted through generic MoonClaw task identity.

If a MoonCode/MoonClaw envelope includes `executable_book_lifecycle`, MoonBook
persists it as `lifecycle_proof` on the executable event. The proof is book-owned
evidence after persistence: consumers must read it from
`events/latest.json` or the CLI persist response, not from transient
runtime sidecars. Lifecycle proof does not by itself accept knowledge; the event
still uses `knowledge_accepted` or `review_required` to express Bookkeeper state.

`knowledge_accepted` means the book changed without requiring another
Bookkeeper pass. `review_required` means MoonBook stored durable artifacts, but
the result must not be treated as accepted knowledge or executable code until
review accepts it.

Every `wiki extension persist` writes the event as book-owned evidence:

```text
<book>/events/<event-id>.json
<book>/events/latest.json
```

The CLI persist response includes `executable_event_path`,
`latest_executable_event_path`, and `executable_event`. Downstream projects
should consume that returned event instead of reconstructing accepted/review
state from pages, logs, or sidecar hints.

## Native Knowledge Bundle

MoonBook also publishes a compact product contract named
`moonbook.knowledge_bundle.v1`. This is the stable read model for MoonDesk,
MoonTown, MoonClaw clients, and future suite tools when they need current book
state without scraping markdown or rendered HTML.

The bundle contains:

- current summary and health
- typed durable page records
- source quality and review status
- outbound links
- a graph of durable page relationships
- the executable event protocol id used for result notifications

`moonbook wiki bundle [root]` writes the standalone package under
`book/knowledge/`. Build/serve projection also writes
`book/site/generated/knowledge-bundle.json` and `graph.json`.

This is a MoonBook-native feature. The value is a clear, small, inspectable
contract that preserves MoonBook's richer executable-book semantics.

## Native Book State Snapshot

MoonBook also publishes `moonbook.book_state.v1`, a higher-level state snapshot
for consumers that need one file instead of multiple probes.

`moonbook wiki extension state [root]` returns the snapshot as JSON for runtime
consumers. `moonbook wiki state [root]` writes `state/state.json` for human
or file-based inspection. Build/serve projection also writes
`book/site/generated/book-state.json`.

The snapshot contains:

- catalog identity
- current summary and health
- the embedded `moonbook.knowledge_bundle.v1`
- the latest executable-book event when present
- canonical paths for the review queue, generated graph, generated bundle, and
  latest event

Suite tools should prefer this snapshot for dashboards and routing decisions,
then drill into the knowledge bundle only when they need page-level records or
graph edges. They should not scrape `wiki/SUMMARY.md`, generated site files,
review pages, and event files independently when the snapshot is available.
