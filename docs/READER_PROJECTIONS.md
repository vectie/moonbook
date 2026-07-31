# Human-readable Reader Projections

MoonBook owns the human reading experience for an accepted book. MoonTown may
help a reader discover a domain building and MoonDesk may host the surface, but
neither should invent a second summary of the book.

## Product Decision

Use one canonical accepted body of knowledge and publish three disposable,
versioned projections over it:

```text
accepted MoonBook revision + evidence + review receipt
        |                |                 |
        v                v                 v
      Learn            Apply            Research
        \________________|_________________/
                         |
                 How maintained
             (separate disclosure)
```

- **Learn** builds a correct beginner mental model.
- **Apply** helps a practitioner complete a task and make decisions.
- **Research** lets an expert inspect evidence, method, disagreement, and
  uncertainty.
- **How maintained** exposes provenance, versions, review state, and operator
  diagnostics without polluting the reading path.

These are not independent books. Every projection identifies the same stable
book id and the same immutable canonical-source subject, revision, and digest.
Each view then keeps its own artifact references and content-addressed
projection identity. An unavailable projection is shown as unavailable; it
never silently falls back to marketing copy, generic workspace metrics, or
another audience level.

## Authoring Method

MoonBook uses a nine-step reader loop:

1. **Orient** — audience, prior knowledge, intended outcome, main message, why
   it matters, and next action.
2. **Explain** — one concept per chunk, familiar words, active voice, and terms
   defined at first use.
3. **Show** — a complete worked example with steps, reasons, and result.
4. **Practice** — a related task that produces a useful artifact.
5. **Self-explain** — a prompt asking why the steps work and where they fail.
6. **Retrieve** — a closed-book checkpoint with a concealed answer.
7. **Transfer** — a new situation that requires applying the concept.
8. **Prove** — sources, claim status, contradictions, confidence, and
   limitations.
9. **Revisit** — a later retrieval checkpoint instead of assuming one reading
   creates durable understanding.

This method deliberately combines communication and learning requirements.
Plain prose helps the reader enter the material; examples, retrieval, and
transfer help the reader learn it; evidence lineage prevents simplification
from changing what the book actually knows.

## Projection Contract

The public MoonBit package is `vectie/moonbook/reader_projection`, and its
stable contract version is `moonbook.reader_projection.v1`. Generated wiki
sites expose the current projections and their readiness in
`book/site/generated/reader-state.json`.

All projections expose:

- audience and assumed prior knowledge;
- title, main message, why it matters, estimated effort, and next action;
- canonical source revision, source digest, evidence references, and review
  status;
- readiness state with explicit missing requirements.

Learn additionally requires a concept route, inline glossary, worked examples,
and concealed retrieval answers. Apply additionally requires a procedure,
decision points, reusable template, exercise output, trade-offs, and transfer
task. Research additionally requires methods, evidence, contradictions,
uncertainty, limitations, and review lineage.

The projection is a read model, not accepted truth. Publication requires two
separate Bookkeeper decisions: a named human must accept the exact canonical
source subject and then accept the exact generated projection. A receipt for a
different version, digest, view, reviewer grant, or evidence set cannot be
reused.

`reader-state.json` includes the exact, content-addressed Bookkeeper candidate
records under `review_candidates`. A site build only emits those candidates;
it does not write to the Bookkeeper journal. A client or operator may persist
the canonical candidate first, review it through the existing governed
Bookkeeper command, then persist and review the desired projection candidate:

```text
moonbook bookkeeper record <book-root> <candidate.json>
moonbook bookkeeper review <book-root> <review-mutation.json>
```

On the next build, MoonBook replays the journal and exposes `Accepted` only
when exactly one matching human acceptance exists and the reviewer's latest
authority grant is still active. Missing, ambiguous, mismatched, revoked, or
replay-invalid receipts fail closed to a review-needed preview.

## Quality And Release Gates

The generator and reviewer should reject a reader projection when any of these
are missing:

- a specific reader contract (`general public` is not sufficient);
- a one-to-three-sentence main message in the first screenful;
- an explicit next action;
- definitions for unfamiliar terms;
- at least one worked example per core concept;
- practice, self-explanation, retrieval, and transfer in each lesson;
- source anchors for factual claims and visible important limitations;
- the canonical revision/digest and review status;
- independent review that the simplified wording preserved the claim.

Automated readability measurements are advisory diagnostics. They may flag
long sentences, dense paragraphs, weak headings, unexplained terms, or passive
voice, but they cannot prove that a reader understood the material.

For a high-value release, pretest with representative readers. The initial
acceptance target is that at least four of five can state the main idea,
explain one key concept, and complete the first exercise without assistance.
Record misses as evidence for a new immutable revision.

## Ownership And Call Chain

```text
MoonClaw candidate generation
  -> MoonBook course artifact and reader projections
  -> Bookkeeper acceptance of the exact canonical source
  -> Bookkeeper meaning-preservation review of each exact projection
  -> named-human acceptance receipts with current authority
  -> MoonBook publication
  -> optional MoonTown discovery / MoonDesk hosting
  -> reader comprehension evidence
  -> Bookkeeper gap update
  -> next reviewed revision proposal
```

MoonFlow may schedule the work. It does not author or accept content. MoonTown
may animate agents researching or discussing a book. It consumes MoonBook's
projection links and readiness; it does not own the book's learning model.

## Methodology Sources

The MoonBook method is a product synthesis, informed by:

- [W3C clear-content guidance](https://www.w3.org/WAI/WCAG2/supplemental/objectives/o3-clear-content/)
  on familiar words, short chunks, summaries, separated instructions, and
  explanations of implied content.
- [W3C cognitive-accessibility guidance](https://www.w3.org/WAI/people-use-web/abilities-barriers/cognitive/)
  on predictable structure, consistent labels, personalization, and concise
  language.
- [GOV.UK clear-language guidance](https://guidance.publishing.service.gov.uk/writing-to-gov-uk-standards/writing-guidelines/clear-language/)
  on audience language, active voice, and defining specialist terms.
- [CDC's Clear Communication Index](https://www.cdc.gov/ccindex/pdf/clear-communication-user-guide.pdf)
  on a named audience, one main message, first-screen placement, chunking,
  visual support, action, and audience testing.
- [The IES learning practice guide](https://ies.ed.gov/ncee/wwc/PracticeGuide/1)
  on worked examples, connecting abstract and concrete representations,
  retrieval questions, explanatory prompts, and spaced learning.
- [Roediger and Karpicke's retrieval-practice study](https://pubmed.ncbi.nlm.nih.gov/16507066/)
  on improved delayed retention after testing rather than restudy alone.
- [The expertise-reversal review](https://pubmed.ncbi.nlm.nih.gov/21443379/)
  on changing guidance as learner expertise changes.

The sources do not prescribe MoonBook's exact three-view contract. That
architecture is an inference: progressive disclosure is safer when every view
remains traceable to one accepted source of truth.
