# MoonBook product contract

## Agent practice workbook

The reviewed-lesson teaching brief can start a fixed-exercise practice workbook.
Operators record first/after-feedback responses, observations and next practice,
resume exact JSON and export a readable report. Guidance changes remain visible;
responses never move to rewritten tasks. Observations are unverified and return
through ordinary revision and named-human review before any accepted change.
See [practice workbook](AGENT_PRACTICE_WORKBOOK.md) for workflow, bounds and the
separate blocking full-UI/native/provider/release gates.

Selected observations can now [enter the existing correction rehearsal](PRACTICE_CORRECTIONS.md)
with explicit first-response attribution and exact preserved source context.
After-feedback responses are not silently relabeled as revised-guidance results.
The ordinary comparison, staging and named-human review path remains in charge.

Class: domain pack
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
| Portable agent pack/inspect/verify/diff | available locally |
| Agent merge preview, import, upgrade and rollback | available locally |

Conformance: **L2 usable locally** for the ordinary Bookkeeper review and
replay-recovery journey. Cross-product L3 remains conditional on an exact
producer submission, MoonFlow receipt, and separately installed named-human
authority.

## Three-Gap contract

The Bookkeeper records:

- **intent gap** — what the accepted requirement expected;
- **execution gap** — what the workflow and tools actually did;
- **outcome gap** — what happened after delivery or publication.

It may propose a capability revision. MoonFlow can evaluate that proposal in
canary or shadow mode, but neither MoonBook nor the producing product may
approve its own promotion.

The canonical cross-product intake and replay operation is
`moonbook/bookkeeper.outcome.submit@0.1.0`; its internal closure operation is
`moonbook/bookkeeper.outcome.close@0.1.0`. `bookkeeper.close-loop` is an
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

## Rehearsal-backed next-task guidance

The existing outcome-lesson UI now has a connected same-example rehearsal path:
write scoped correction → compare supplied outputs on literal checks → save the
exact trial-backed candidate → named-human review → select its exact guidance
version for Proj's existing native Start capture. Existing history handles
reviewed revisions and rollback. See [the workflow](TEACH_ONCE_REHEARSAL.md).
This does not run a model or authorize capability adoption. Author verification
covers the executable preview and source parsing; native/UI qualification remains
blocked by missing workspace dependencies.

## Comparative reuse of reviewed approaches

The scoped lesson results now connect to a two-to-four approach comparison for
one exact later task. A creator supplies one common example, outputs per reviewed
lesson and shared literal checks, inspects per-check differences, then explicitly
returns one all-pass sampled approach through the existing confirmed Proj handoff.
[Comparative lesson reuse](COMPARATIVE_LESSON_REUSE.md) describes limits and recovery.
This is tab-local supplied-output comparison, not a model run or accepted
learning evidence. Standalone current-UI compilation and focused controller,
rendering and synthetic handoff tests passed; integrated Leaf/runtime/browser
qualification remains blocked.

## Continue unfinished experience-led corrections

The contrasting-case revision editor can explicitly save an unfinished browser
copy, inspect it after reload, and resume its authored fields/cases only into a
fresh revision of the same current accepted lesson. Comparison and staging must
be repeated before ordinary named-human review. Checked replacement/removal,
storage failure and stale-history recovery are explicit. See
[Saved correction drafts](SAVED_CORRECTION_DRAFTS.md). This preserves correction
effort without changing host learning authority or portable-agent contents.

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
- Qualify `moonbook.agent_bundle.v1` across fresh import, protected merge,
  upgrade, rollback and tamper-rejection scenarios.

## Experience-led task scope interview

Current reviewed lesson browsing now feeds a staged task-scope interview:
inspect missing conditions → explicitly answer known task facts → inspect
conflicting or invalidated lessons → apply to the existing exact retrieval.
Answers can be removed or discarded; changed task or lesson context requires a
fresh interview. No task facts are inferred from lesson text and no guidance is
automatically attached. [Task scope interview](TASK_SCOPE_INTERVIEW.md) documents
recovery and the local qualification boundary.

## Contrasting-case revision rehearsal

After a named-reviewed guidance change, [retest a recorded task](RETEST_CORRECTED_GUIDANCE.md)
lets the operator inspect both scopes and explicitly prepare the historical
exercise under a selected current version. Ordinary next-round controls create
blank observations; different version records retain separate attribution in
comparison. This is local experience authoring, with no inferred applicability,
execution, accepted learning or new authority.

The accepted-current history revision editor includes a local workbench for two to
six operator-supplied useful/adverse cases. It exposes per-fragment differences,
iterative guidance editing, and explicit staging into the ordinary revision/review
lane. This is sampled literal-check evidence only; no model or authority changes
are involved. See [the workflow and limits](CONTRASTING_REVISION_REHEARSAL.md).

## Retained teaching examples in later corrections

The current accepted lesson can supply its retained successful examples to the
next contrasting-case revision. The user chooses examples, supplies blank-start
fresh outputs and a new adverse case, then compares and stages through the same
named-review lane. Old inputs, outputs and checks remain immutable and attributed.
See [retained teaching cases](RETAINED_TEACHING_CASES.md). This is operator-reported
experience reuse, without model execution or automatic acceptance.

## Bounded CSV teaching-case intake

Operators can preview and explicitly import a bounded, strict CSV case set into
an accepted-current lesson's existing contrasting revision rehearsal. Exact
parsed fields and validation errors are visible before atomic import. Import
fills only pristine manual slots or appends; authored cases, immutable retained
examples, ordinary revision fields and accepted guidance are preserved. New
examples remain operator reports and use the normal comparison, staging and
named-human review path. See [CSV teaching-case intake](CSV_TEACHING_CASE_INTAKE.md)
for the exact header, limits, interruption behavior and evidence boundary.

## Experience-led decision notebook

The reviewed lesson browser supports a local planning notebook across distinct
prior experiences. Users preserve each exact lesson's scope, outcome and named
review references, write application notes and tensions, reorder the evidence,
and articulate a proposed decision with an unresolved next check. Explicit JSON
download/preview/restore continues editing across reloads; standalone inert HTML
provides an offline reading output. Rechecking live guidance flags changed or
missing captures without overwriting history. Authored judgments and imported
review labels remain separate from accepted Book truth. See
[decision notebook workflow and boundaries](DECISION_NOTEBOOK.md).
The qualification contribution is limited to MOONBOOK-R02's later-decision
applicability and original-outcome-preservation slice; full outcome intake and
closure, timestamp exchange, and reviewer-promotion gates remain unqualified.
