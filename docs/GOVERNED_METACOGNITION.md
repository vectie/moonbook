# Governed Bookkeeper Metacognition

MoonBook owns durable knowledge, reflection, and procedural memory. It does not
execute product work, validate robot hardware, accept simulation as physical
evidence, or grant authority.

## Three-gap loop

Every Bookkeeper reflection may produce:

- an information gap when required evidence is missing or stale;
- a cognition gap when the importance, consequence, or conflict of an
  observation is unresolved;
- an execution gap when the next governed action is known but absent.

`moonbook bookkeeper reflect` and `bookkeeper reconcile-flow` persist these
gaps into `memory/gaps/graph.json`. Nodes deduplicate by requirement and gap
kind, retain their first and latest reflection identities, and become resolved
only through a later reflection. An execution gap is invalid unless it includes
at least one proposed action.

Belief updates are folded into `memory/beliefs/index.json`. Supporting and
contradicting evidence remain separate. Consequence links and invalidation
triggers make it possible to reopen research when a dependency, source, or
requirement changes.

## Procedure learning

Accepted observations and exact MoonFlow acceptance receipts may create
procedure candidates. A candidate must declare applicability, steps,
verification, failure modes, counterexamples, invalidation triggers, and
evidence. One success remains a candidate. Two distinct accepted reflections
with the same stable procedure identity promote it, or an explicit review
receipt can promote it with:

```text
moonbook bookkeeper promote <book-root> <reflection-id> <review-receipt-ref>
```

This prevents one lucky run from becoming habit. Reuse must stop when an
invalidation trigger fires, and the counterexamples explain what would have
caused rejection.

## Native plan revision

When evidence invalidates an assumption, Bookkeeper compiles an immutable
`moonbook.plan-revision-proposal.v1` and a
`moonbook.plan-revision-lineage.v1` record:

```text
moonbook bookkeeper propose-revision <book-root> <request.json>
```

The input identifies the parent and proposed revision, invalid assumption,
reason, evidence, changed declarations with old/new criteria, and unchanged
declarations. The output is written under
`flow/revisions/<revision>/`. Revision identities are idempotent and fail closed
if reused with different content. MoonFlow consumes the proposal to migrate
only revalidated checkpoints; MoonBook never rewrites the parent history.

## Operator/status surface

```text
moonbook bookkeeper metacognition <book-root>
```

The status contract returns the gap graph, belief index, and procedure learning
index as one inspectable projection. It is intended for MoonDesk and autonomous
planning, not as a substitute for the underlying durable files.
