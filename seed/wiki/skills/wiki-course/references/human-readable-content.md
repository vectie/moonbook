# Human-readable content method

MoonBook uses a repeatable teaching and evidence method. It is a synthesis of
plain-language, cognitive-accessibility, clear-communication, and learning-
science guidance; it is not a verbatim standard from any one source.

## The MoonBook reader loop

Apply this loop to each important concept or lesson.

1. **Orient** — name the audience, prior knowledge, intended outcome, main
   message, why it matters, and next action.
2. **Explain** — teach one concept per chunk with familiar words, active voice,
   short sentences, and definitions at first use.
3. **Show** — give a fully worked example: the problem, each meaningful step,
   the reason for the step, and the result.
4. **Practice** — ask the reader to complete a nearby task and produce a useful
   artifact.
5. **Self-explain** — ask why the demonstrated steps work and when they would
   not work.
6. **Retrieve** — ask a closed-book question. Keep its answer concealed until
   the reader chooses to reveal it.
7. **Transfer** — ask the reader to apply the idea in a meaningfully different
   situation.
8. **Prove** — retain source anchors, claim status, confidence, contradictions,
   and limitations. Simplifying language must not simplify away uncertainty.
9. **Revisit** — schedule or recommend a later retrieval checkpoint instead of
   treating one reading as mastery. In a structured lesson, write a Revisit
   prompt and a positive `Revisit after days:` value.

## Progressive reader projections

Project one accepted book revision at three depths:

| Projection | Reader goal | Required emphasis |
|---|---|---|
| Learn | Form a correct mental model | main message, prerequisites, glossary, plain explanation, worked example, checkpoint |
| Apply | Complete a real task | procedure, decisions, template, exercise, output, trade-offs, transfer |
| Research | Inspect and challenge the conclusion | methods, evidence, citations, contradictions, uncertainty, limitations, review lineage |

Keep **How maintained** separate. Provider state, run ids, raw logs, review
queues, file paths, and operator diagnostics can be disclosed there without
turning the lesson into a control panel.

Missing projections must be labelled unavailable. Never fill a missing Learn
view with marketing prose or silently substitute an expert report.

## Release gates

A reader projection is ready only when:

- its audience is specific enough to recruit for a comprehension check;
- its main message is one to three sentences and appears first;
- its next action is explicit;
- unfamiliar terms are defined at first use;
- every core concept has a worked example;
- each lesson has practice, self-explanation, retrieval, transfer, and a
  positive revisit interval;
- factual claims retain accepted source anchors;
- important disagreement and uncertainty remain visible;
- the projection records the canonical source revision and review status;
- a separate reviewer confirms that simplification preserved meaning.

Use automated prose signals only as diagnostics. Sentence length, passive-voice
counts, heading density, and language-specific readability formulae can find
likely problems, but they do not demonstrate comprehension.

For important releases, test with representative readers. At least four of
five should be able to state the main idea, explain one key concept, and
complete the first exercise without assistance. Record failures as input to a
new version rather than editing an accepted projection in place.

## Source basis

- [W3C: Clear Content](https://www.w3.org/WAI/WCAG2/supplemental/objectives/o3-clear-content/)
- [W3C: Cognitive, Learning, and Neurological Disabilities](https://www.w3.org/WAI/people-use-web/abilities-barriers/cognitive/)
- [W3C COGA: Making Content Usable](https://www.w3.org/TR/coga-usable/)
- [GOV.UK: Clear language](https://guidance.publishing.service.gov.uk/writing-to-gov-uk-standards/writing-guidelines/clear-language/)
- [CDC Clear Communication Index](https://www.cdc.gov/ccindex/pdf/clear-communication-user-guide.pdf)
- [NIH Clear & Simple](https://www.nih.gov/institutes-nih/nih-office-director/office-communications-public-liaison/clear-communication/clear-simple)
- [IES practice guide: Organizing Instruction and Study to Improve Student Learning](https://ies.ed.gov/ncee/wwc/PracticeGuide/1)
- [Roediger and Karpicke: Test-enhanced learning](https://pubmed.ncbi.nlm.nih.gov/16507066/)
- [Expertise reversal effect review](https://pubmed.ncbi.nlm.nih.gov/21443379/)

These sources motivate the method. MoonBook's exact loop, three projections,
and evidence-preservation gates are product decisions derived from them.
