# Portable and Evolving Agents

Status: implemented locally

Contract: `moonbook.agent_bundle.v1`

## Product statement

A MoonBook is a portable, inspectable, versioned agent that accumulates
knowledge and evidence over time. MoonClaw animates it; Bookkeeper governs how
learned behavior becomes the next version.

```text
MoonBook   portable identity, knowledge, skills, procedures and adopted versions
MoonClaw   live conversations, queues, tool execution and context assembly
MoonFort   isolated processes, temporary files and executable artifacts
MoonTown   schedules, leases and cross-book coordination
MoonGate   model routing, comparison evidence, latency, token and cost metrics
MoonDesk   normal chat-and-document experience
Bookkeeper candidate, evaluation, review, adoption and rollback boundary
```

An exported agent is not a running process. It never contains an active queue,
temporary prompt, provider credential, chain-of-thought, MoonFort process state,
MoonTown lease, browser-local state or machine-specific workspace root.

## Bundle format

`moonbook agent pack` writes one self-contained `.moonbook-agent` JSON artifact.
All embedded files use safe workspace-relative paths, base64 content and SHA-256
digests. The complete unsigned manifest has its own canonical digest.

The v1 bundle contains:

- identity and book-owned policy;
- approved user preferences;
- accepted knowledge pages;
- active skills, schemas, tools and apps;
- accepted procedures, capabilities and evaluations when present;
- durable standing-watch intent;
- extension declarations and digest-bound runtime dependency locks;
- named memory limits and exported admission/promotion counters;
- explicit exclusions and export policy.

The public `agent` package also defines `AgentSourceLocation`,
`AgentArtifactLocation`, `AgentMemoryRecord`, `AgentMemoryPolicy`, and
`AgentMemoryMetrics`. These give MoonDesk and MoonClaw a typed portable schema
for page/slide/sheet/range/section anchors, artifact promotion, memory scope and
lifecycle, sensitivity, provenance, confidence, expiry, invalidation,
supersession, named limits, and admission/export counters.

Each generated knowledge-page record now carries a content digest/revision,
portable provenance references, a typed section locator, sensitivity,
invalidation/supersession slots, and a review-receipt slot. The local
`KnowledgeBundle.root` remains mount metadata for an opened book; it is never
copied into the portable agent artifact.

The exporter allows no working memory or runtime state, scans included content
for credential-shaped values, ignores symlinks and special files, limits the
size of each payload, rejects files containing the source machine's absolute
book root, and excludes unreviewed knowledge, beliefs, procedures, evaluations,
or behavior. Exclusions
remain visible in the manifest rather than disappearing silently.

## Commands

```sh
moon run cmd/main -- agent pack [book] [version] [output]
moon run cmd/main -- agent inspect <bundle>
moon run cmd/main -- agent verify <bundle>
moon run cmd/main -- agent diff <left-bundle> <right-bundle>
moon run cmd/main -- agent merge <bundle> <book>
moon run cmd/main -- agent import <bundle> <new-book>
moon run cmd/main -- agent upgrade <bundle> <book>
moon run cmd/main -- agent rollback <book> <receipt>
```

`merge` is deliberately non-applying. It writes
`state/agent-merge-plan.json`, classifies additions, replacements and unchanged
files, and calls out conflicts in identity, preferences and policy. `upgrade`
is the explicit applying operation.

Before import or upgrade changes a book file, MoonBook writes a private rollback
receipt under `.moonbook/agent/receipts/`. It records the exact prior bytes and
installation state. Rollback validates every stored digest before restoring or
removing files.

## Evolution lifecycle

```text
work performed
  -> outcome observed
  -> gap or reusable procedure detected
  -> candidate recorded
  -> shadow or canary evaluation
  -> evidence and counterexamples accumulated
  -> governed adoption receipt
  -> active capability version advances
  -> new agent bundle exported
```

Knowledge may accumulate provisionally. Low-risk preferences may follow a
pre-authorized user policy. Behavioral capabilities do not silently activate.
Only accepted knowledge and adopted behavior enter the active portable bundle;
failed experiments remain evidence so the book does not relearn the same
mistake.

## Workspace-feature ownership

The normal MoonDesk experience draws on the portable book without moving live
runtime concerns into it:

| Feature | MoonBook-owned durable state | Runtime state kept elsewhere |
| --- | --- | --- |
| Document conversations | promoted decisions, summaries, document/baseline bindings | MoonClaw messages and queue |
| Typed sources and artifacts | portable path, digest, provenance and document locator | MoonFort temporary artifact handle |
| Add-context palette | searchable book catalog | current selection and composer state |
| Recurring work | standing-watch intent and accepted outcomes | MoonTown schedule, lease and next run |
| Run comparison | accepted evaluation and promoted result | MoonCode branches and active sandboxes |
| Preferences and glossary | reviewed book/user memory | ephemeral context cache |
| Anchored review | accepted resolution and receipt | MoonFlow presence, unread and draft replies |

MoonWiki displays normal answers, sources, artifacts and actionable warnings.
Developer controls, reasoning summaries, terminal output and tool transcripts
belong in MoonCode.

## Compatibility and future versions

The manifest declares required MoonClaw, MoonFort, MoonTown and MoonGate
protocol ranges, required/optional status, capabilities and migration action.
Every dependency declaration has its own canonical digest and is also covered
by the bundle digest. Verification rejects changed, duplicate or missing
required locks. Memory policy and counters are likewise covered and verified
against the exported file set.

A later contract may add detached cryptographic publisher signatures without
weakening v1 verification. Content and lock digests provide integrity today;
they intentionally do not claim publisher identity or key trust.

Bundle and installation timestamps are signed 64-bit Unix milliseconds, not
32-bit timer counters. CLI failures return a nonzero exit status. Existing
symlink destinations are rejected before import/upgrade writes or rollback
restoration; this preflight is not a sandbox against concurrent filesystem
mutation by another process with write access to the same book.

## Verification

```sh
moon check --target native --warn-list +73
moon test agent --target native
moon test --target native
moon info
moon fmt
```

Test the negative cases as carefully as the happy path: payload tampering,
unsafe relative paths, duplicate paths, non-accepted knowledge, credential-like
content, dependency-lock tampering, memory-counter mismatch, protected merge
conflicts, wrong-book rollback receipts and changed rollback bytes.
