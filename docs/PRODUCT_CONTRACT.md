# MoonBook product contract

Class: platform product
Maturity: local alpha
Last reviewed: 2026-07-31

## Outcome

MoonBook turns sources, wiki pages, executable declarations, review records and
accepted outputs into a durable, inspectable book workspace.

## Users and jobs

- People collect, edit, review and publish durable knowledge.
- MoonClaw reads book-owned intent and writes bounded run artifacts.
- MoonFlow imports versioned work declarations.
- The Keeper maintains book health.
- The Bookkeeper compares intended, executed and observed outcomes through the
  Three-Gap loop and proposes reviewed capability improvements.

## Ownership

MoonBook owns book truth, source provenance, wiki state, accepted artifacts,
review history, projections and Bookkeeper learning records. It does not own
agent execution, provider access, generic orchestration or domain-specific
policy.

MoonWiki and Bookkeeper are capabilities inside MoonBook, not separate agent
runtimes or standalone applications.

## Capability status

| Capability | Status |
| --- | --- |
| Static book rendering, serve and watch | available |
| Persistent wiki workspace and source materialization | available |
| Knowledge bundles, graphs and projections | available |
| Executable work declarations and review queues | available |
| Keeper and Bookkeeper Three-Gap records | available locally |
| Exact cross-product outcome closure and reviewed-proposal handoff | available locally |
| Deterministic MoonWiki requirements packet preparation and reconciliation | available locally |
| Automatic capability promotion | excluded; named review required |
| Multi-user hosted knowledge service | planned |

## Three-Gap contract

The Bookkeeper records:

- **intent gap** — what the accepted requirement expected;
- **execution gap** — what the workflow and tools actually did;
- **outcome gap** — what happened after delivery or publication.

It may propose a capability revision. MoonFlow can evaluate that proposal in
canary or shadow mode, but neither MoonBook nor the producing product may
approve its own promotion.

The canonical cross-product operation is
`moonbook/bookkeeper.outcome.close@0.1.0`; `bookkeeper.close-loop` is an
aspirational legacy canvas label and is not executable capability truth. See
[Generic product-outcome closure](BOOKKEEPER_OUTCOME_CLOSURE.md).

The canonical requirements operation is
`moonbook/wiki.requirements.prepare@0.1.0`. It separates facts, calculations,
inferences and unresolved questions while preserving exact versioned evidence.
Its output is always a review-pending digital artifact, never accepted book
truth. MoonWiki is the functionality label; the callable `product_id` remains
`moonbook`. No model runs in this operation. If a later reviewed workflow needs
agent cognition, MoonClaw is the sole runtime. See
[MoonWiki requirements capability](MOONWIKI_REQUIREMENTS_CAPABILITY.md).

## Persistence and security

Raw evidence, accepted knowledge and generated projections remain distinct.
Untrusted documents require isolation and provenance before their extracted
content can influence an agent. Accepted user-owned artifacts survive pack
uninstall and upgrade.

## Verification

```sh
moon check
moon test
moon info
moon fmt
```

Use the book-specific fixture and adapter tests documented in `docs/README.md`
for changed workflows.

## Release gates and next milestones

- Complete backup/restore and restart recovery for executable books.
- Make Three-Gap outcome binding visible in the MoonBook/MoonDesk UI.
- Prove one learning proposal through canary, review, promotion or rollback.
- Clarify extension installation, permissions and upgrade behavior.
