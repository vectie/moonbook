---
name: wiki-marketing
description: Use when a MoonBook keeper must write real product marketing for the generated website. Creates raw/bootstrap/marketing-brief.md or wiki/synthesis/marketing.md with positioning, buyer pains, differentiated strengths, proof, objections, and conversion copy instead of generic feature summaries or renderer-hard-coded claims.
---

# Wiki Marketing

## Job

Write real marketing copy for a MoonBook workspace.

Real marketing means:

- pick a buyer
- name their pain
- make a clear promise
- explain why this product is different
- show concrete proof
- handle hesitation
- move the reader to the next action

Do not merely describe the system. Sell the outcome.

The renderer is thin. It turns a markdown brief into a page. This skill owns the
positioning, offer, message hierarchy, and conversion path.

## Output File

Write exactly one primary brief:

- draft: `raw/bootstrap/marketing-brief.md`
- promoted durable copy: `wiki/synthesis/marketing.md`

Use the promoted durable file only when the positioning has been reviewed.
Otherwise write the draft file.

## Exact Output Skeleton

For `raw/bootstrap/marketing-brief.md`, use this skeleton exactly.
You may change the text under each heading, but do not rename, reorder, or skip
the headings unless the user explicitly asks for a different marketing format.

```markdown
# <buyer-facing headline>

<hero lede paragraph 1: pain>

<hero lede paragraph 2: promise>

## The Problem

<buyer pain in plain language>

- <pain bullet>
- <pain bullet>
- <pain bullet>

## The Product

<what the product does in outcome language>

- <visible outcome>
- <visible outcome>
- <visible outcome>

## Why It Wins

<differentiated mechanism without backend leakage>

- <advantage>
- <advantage>
- <advantage>

## What You Can Ship

<concrete deliverables the buyer can show or use>

- <deliverable>
- <deliverable>
- <deliverable>

## Who It Is For

<one primary buyer plus secondary users only if useful>

- <buyer/user>
- <buyer/user>
- <buyer/user>

## Proof Points

<evidence translated into trust, not raw source dumps>

- <proof point>
- <proof point>
- <proof point>

## Objections

<handle the most likely hesitation honestly>

- <objection response>
- <objection response>

## Next Step

<simple CTA and route to proof>

- <action>
- <action>
```

If you cannot fill this skeleton from evidence, write a blocked marketing brief
using the same headings and explain the missing evidence under `## Proof Points`
and `## Next Step`. Do not switch to planning headings.

## Renderer Contract

The generated page parser expects:

```markdown
# Headline

Hero lede. One or two short paragraphs.

## Section Title

Section body.

- bullet
- bullet
```

Mapping:

- first `#` -> hero headline
- text before first `##` -> hero lede
- each `##` -> marketing card
- bullets -> card proof points or benefits

The renderer does not understand complex markdown blocks. Do not use tables,
HTML, footnotes, nested bullets, or code fences in the marketing brief.

Because the generated page shows `marketing-brief.md` directly, the brief must
already be buyer-ready. Do not expect renderer code to turn operational notes
into sales copy.

## Non-Negotiable Buyer-Facing Rules

Never use these as section headings:

- `Objective`
- `Evidence Base Used`
- `Audience`
- `Audience And Buying Situation`
- `Buyer Pain`
- `Core Buyer Pain`
- `Core Positioning`
- `Positioning`
- `Product Promise`
- `Differentiation`
- `Proof Points Sellers Can Use`
- `Seller-Facing Messaging Angles`
- `Messaging Guidance`
- `Suggested Seller Narrative`
- `Web Verification Status For Selling`
- `Web Verification Status`
- `Recommended Next Materialization`
- `Next Materialization Targets`
- `Positioning Guardrails`
- `Coverage Note`
- `Risks And What Not To Overclaim`
- `Suggested Buyer-Facing Claims`
- `Messaging Themes`

Those are planning notes, not marketing sections. If you need them, keep them in
`raw/bootstrap/synthesis-brief.md`, `wiki/history/debug-journal.md`, or an
internal note. The marketing brief must read like a page a buyer can consume.

Do not put source IDs, local file labels, tool names, blocker IDs, or raw
artifact names in the hero or section headings. Source IDs can appear in a
short proof bullet only when needed, but the main copy should translate evidence
into buyer value.

Bad:

```markdown
## Evidence Base Used

- W1: fetched GitHub repository page
- L1: mounted-sources/readme
```

Good:

```markdown
## Proof Points

The product story is backed by a real repository, implementation files, and a
maintained research trail. Readers can start with the pitch and keep going into
the wiki when they want proof.

- public repository and local implementation evidence
- runtime and tool boundaries documented in the workspace
- research report kept beside the product surface
```

Before returning, scan every line beginning with `## `.
If any heading is not one of the eight skeleton headings, rewrite the brief.
Do not explain the violation in the brief; fix it.

## Product Page Shape

Write the brief so the generated site has this narrative arc:

1. Hero: promise and pain, not implementation.
2. Problem: the messy status quo the buyer recognizes.
3. Product: what the product makes possible.
4. Why it wins: differentiated mechanism in buyer language.
5. What you can ship: visible deliverables.
6. Who it is for: one primary buyer and a few secondary users.
7. Proof points: evidence translated into trust.
8. Objections: honest hesitation handling.
9. Next step: what the reader should click or do.

Every section should answer: "Why does this matter to the buyer?"

If the answer is "because the architecture is elegant," rewrite. Elegance is
supporting proof; the marketing claim is the outcome.

## Detail Without Backend Leakage

Use product nouns, not backend nouns.

Prefer:

- product page
- research report
- generated wiki
- operator journal
- skill center
- durable run record
- evidence-backed claim
- workspace surface

Avoid as main copy:

- provider task
- artifact contract
- raw/bootstrap
- ReviewQueued
- source materialization
- coverage readiness
- task id
- worktree path

Good:

> MoonClaw turns agent conversations into work that operators can inspect after
> the model stops talking.

Bad:

> MoonClaw produces provider task result envelopes with artifacts and memory
> candidates.

## MoonClaw Marketing Angle

When writing for MoonClaw, use this buyer interpretation unless the evidence
contradicts it:

- primary buyer: technical teams trying to turn agent conversations into
  governed, inspectable work
- core pain: chat output is transient, tool execution is scattered, and
  operators cannot easily see what happened
- product promise: proposals become durable jobs with workspaces, artifacts,
  memory, and operator visibility
- differentiation: full job runtime plus local/remote worker coordination, not a
  thin chat wrapper
- proof: README/runtime docs, job/provider/tool code, operator UI surfaces,
  public repo facts when verified
- caution: do not claim broad enterprise adoption or benchmark superiority
  unless the evidence proves it

Strong MoonClaw headline patterns:

- `Turn agent conversations into governed work.`
- `Run agents like jobs, not disposable chats.`
- `Keep every agent run visible, reviewable, and useful after it finishes.`
- `A runtime for teams that need agent work to leave evidence behind.`

Strong MoonClaw lede pattern:

```markdown
# Run agents like jobs, not disposable chats.

Most agent tools are easy to start and hard to operate: the conversation ends,
the files scatter, and nobody knows what changed. MoonClaw gives teams a runtime
where proposals become jobs, jobs get workspaces, outputs become artifacts, and
operators can inspect the trail.
```

## MoonBook Marketing Angle

When writing for MoonBook:

- primary buyer: teams turning active research or product knowledge into
  presentable surfaces
- core pain: docs, wiki, marketing page, and operating memory drift apart
- product promise: one workspace can publish a product page, book, wiki,
  journal, course, and skill center
- differentiation: marketing stays clean while durable knowledge stays detailed
- proof: generated pages, maintained wiki, static seed skills, test/build status

## Moontown Marketing Angle

When writing for Moontown:

- primary buyer: operators of long-running multi-agent or multi-domain work
- core pain: individual workers can act, but nobody sees the whole system
- product promise: a town-level control plane that schedules, routes, supervises,
  and records work across books and workers
- differentiation: domain memory stays in books while town owns policy,
  scheduling, and cross-book orchestration
- proof: town dashboard, goal runs, book registry, worker lanes, event history

## Quality Gate

Before returning success, check the generated brief:

- The headline can be understood without knowing MoonBook internals.
- The hero lede names pain and outcome in two short paragraphs or less.
- No section title is an internal planning label.
- No section body begins with `###`.
- No section body is mostly source IDs or file paths.
- At least five sections explain buyer value.
- At least one section handles objections honestly.
- At least one section routes serious readers to proof without dumping evidence.
- The page would still make sense if pasted into a public website.

If the brief fails any item, rewrite it before returning success.

## Self-Review Before Returning

After drafting, compare the headings to the exact skeleton. The only accepted
`##` headings are:

- `## The Problem`
- `## The Product`
- `## Why It Wins`
- `## What You Can Ship`
- `## Who It Is For`
- `## Proof Points`
- `## Objections`
- `## Next Step`

If any other `##` heading appears, rewrite before saving the file.

Then run this content check mentally:

- If a section reads like a research note, convert it to buyer value.
- If a bullet begins with a source ID, rewrite it as a trust point.
- If a paragraph says "Evidence:" or "Source:", fold the proof into plain
  language.
- If the brief mentions a file path, task id, run id, provider task, raw
  artifact, or materialization target, remove it unless the user explicitly
  asked for an internal operator page.
- If the copy would be embarrassing on a public product site, rewrite it.

## Required Marketing Sections

Write these sections in this order:

1. `## The Problem`
2. `## The Product`
3. `## Why It Wins`
4. `## What You Can Ship`
5. `## Who It Is For`
6. `## Proof Points`
7. `## Next Step`

Optional if useful:

- `## Objections`
- `## Demo Story`
- `## Launch Offer`

## Before Writing: Positioning Pass

Read the workspace enough to answer these questions:

1. Who is the most likely buyer or evaluator?
2. What painful current situation are they in?
3. What outcome does this project let them reach faster?
4. What makes this product meaningfully different?
5. What visible surfaces prove the promise?
6. What should the reader click next?

Use these sources:

- `wiki/synthesis/overview.md`
- `wiki/synthesis/map.md`
- `wiki/index.md`
- `raw/bootstrap/deep-report.md`, if present
- `raw/bootstrap/synthesis-brief.md`, if present
- `wiki/synthesis/report.md`, if present
- `wiki/history/journey.md`, only for launch momentum

Do not dump those sources into the page. Use them to decide what can be claimed.

## Buyer Selection

Choose one primary buyer. Do not write for everyone equally.

For MoonBook-like workspaces, strong buyers are usually:

- founders preparing a product demo
- product teams turning internal knowledge into a launchable surface
- research teams turning ongoing source work into readable synthesis
- operators running a long-lived agent workspace
- technical teams that need docs, memory, and presentation to stay aligned

Pick one as the main audience, then mention secondary audiences only if useful.

Bad:

- "For founders, teams, researchers, operators, students, and everyone."

Good:

- "For teams turning active research or product work into something they can
  show, explain, and keep current."

## Pain Before Feature

Every section should start from pain or desired outcome, not implementation.

Weak:

- "MoonBook has a wiki, book, journal, course, and skill manager."

Better:

- "Most knowledge projects split the pitch, docs, source trail, and operating
  memory across different tools. MoonBook keeps them in one workspace and gives
  each audience the right surface."

Weak:

- "MoonBook has skills."

Better:

- "When the same publishing or research task comes up again, the workflow can be
  codified into a skill instead of rediscovered in chat."

## Headline Formula

Use one of these patterns:

- `Ship the pitch and the proof from one maintained workspace.`
- `Turn active knowledge work into a product-ready site.`
- `Stop losing the story between notes, docs, and demos.`
- `A product front door for work that keeps changing.`
- `{Project} turns maintained knowledge into something people can buy into.`

Rules:

- no internal nouns as the main hook unless the audience already knows them
- no "AI-powered" unless the benefit is clearer than the buzzword
- no "wiki server" or "markdown renderer" as the headline
- no "bootstrap", "review queue", "coverage", or "artifact"

## Hero Lede Formula

Use two sentences:

1. Name the messy situation.
2. Show how the product fixes it.

Example:

```markdown
# Ship the pitch and the proof from one maintained workspace.

Most technical projects split their story across markdown files, internal notes,
debug logs, and half-finished demo pages. MoonBook gives the same workspace a
clean product website, a detailed wiki, a structured book, a journey timeline,
and skill-managed operating routines so the story stays presentable as the work
keeps changing.
```

## Section Guidance

### The Problem

Make the reader feel the pain.

Good angles:

- the product story gets stale
- docs and demos drift apart
- research output is detailed but not sellable
- internal notes leak into public presentation
- every update requires rebuilding the website by hand
- chat results disappear instead of becoming maintained knowledge

Example:

```markdown
## The Problem

Growing projects usually end up with two bad choices: keep a polished website
that drifts away from the work, or expose raw notes that make the product look
unfinished. Neither helps when a founder, teammate, or operator needs to
understand the value quickly.

- polished pages get stale
- raw markdown exposes too much internal process
- research and docs rarely turn into a clear product story
```

### The Product

State what the product is in buyer language.

Do not begin with "MoonBook is a MoonBit rewrite...". That belongs in docs, not
marketing.

Example:

```markdown
## The Product

MoonBook turns a maintained knowledge workspace into a set of launch-ready
surfaces. The product page explains the value, the wiki holds the depth, the
book gives structured reading, and the journal and skill center show how the
workspace keeps improving.

- product website for first impressions
- wiki and book for proof
- journal and skills for operating trust
```

### Why It Wins

Describe the differentiated advantage without naming competitors.

Useful contrasts:

- not just a static markdown renderer
- not just a chat transcript
- not just a generic website builder
- not just a private notes folder

Do not name other products unless the user explicitly asks and sources support
the comparison.

Example:

```markdown
## Why It Wins

MoonBook keeps the marketing surface separate from the source of truth. That
means the public page can stay crisp while the wiki keeps the detailed memory,
evidence, revisions, and procedures behind it.

- clean story outside
- maintained knowledge inside
- repeatable skills instead of one-off updates
```

### What You Can Ship

List concrete deliverables.

Do not list internal implementation details. List visible outcomes.

Good deliverables:

- product landing page
- detailed wiki
- structured book
- research report
- journey timeline
- course surface
- skill manager
- local serving flow

Example:

```markdown
## What You Can Ship

One workspace can publish a product page for buyers, a book for readers, a wiki
for deep context, and operating surfaces for the people maintaining the work.

- launch page
- docs/book
- maintained wiki
- journey timeline
- skill center
```

### Who It Is For

Be specific.

Example:

```markdown
## Who It Is For

MoonBook is strongest for teams whose knowledge changes faster than their public
website. It helps people who need to explain the work clearly without losing the
details that make the explanation credible.

- founders preparing demos
- technical teams aligning docs and product story
- researchers turning source work into readable synthesis
- operators managing long-lived agent workspaces
```

### Proof Points

Use proof that a reader can inspect.

Good proof:

- generated `book/site/generated/index.html`
- generated wiki pages
- generated course and journal views
- static skills copied from repo seeds
- test/build commands passed if known
- source-backed report pages if present

Do not expose file paths as the main copy. Translate them.

Example:

```markdown
## Proof Points

The generated site is not just a mockup. It ships beside the rendered book and
links into the deeper workspace surfaces, so readers can move from pitch to
proof without leaving the project.

- product page generated with the book
- wiki stays available for detail
- journal and skills remain one click away for operators
```

### Next Step

Make the call to action simple.

Good CTAs:

- open the generated product page
- inspect the wiki
- read the book
- review the journal
- install or edit a skill

Example:

```markdown
## Next Step

Start with the product page, then open the wiki or book when you need detail.
Use the journal and skill center when the question changes from "what is this?"
to "how is this maintained?"

- read the product story
- open the wiki for proof
- use skills to make the workflow repeatable
```

## Objection Handling

If the workspace has enough material, include `## Objections`.

Common objections:

- "Is this just a markdown renderer?"
- "Will the marketing page drift from the real docs?"
- "Does this require a heavy backend?"
- "Can I keep private detail out of the public page?"

Answer in buyer language.

Example:

```markdown
## Objections

MoonBook is not trying to make every surface say the same thing. It gives each
audience the right layer while keeping the workspace connected underneath.

- marketing stays clean
- wiki keeps detail
- skills keep repeatable maintenance
```

## Copy Quality Bar

A good marketing brief should pass these tests:

- A non-technical buyer can understand the headline.
- The first paragraph says why the product matters.
- Each section begins with value, not internals.
- Bullets are benefits or visible deliverables.
- The page gives a reason to click deeper.
- The copy avoids generic AI hype.
- The copy does not expose task ids, raw artifacts, coverage counters, or debug state.
- The product sounds useful even if the reader never sees the code.

Reject the brief and rewrite if it sounds like:

- a feature inventory
- a changelog
- an architecture note
- a debug report
- a README intro
- a vague "AI knowledge management" pitch

## Strong Words To Prefer

Use concrete verbs:

- ship
- publish
- explain
- prove
- maintain
- align
- package
- present
- turn into
- keep current

Use concrete nouns:

- product page
- source of truth
- wiki
- book
- journey
- skill
- demo
- proof
- workspace
- operating surface

Avoid weak phrases:

- "leverage"
- "seamlessly"
- "unlock potential"
- "AI-powered productivity"
- "next-generation"
- "holistic solution"
- "robust and scalable" unless proven

## Full Example: Stronger Marketing Brief

```markdown
# Ship the pitch and the proof from one maintained workspace.

Most technical projects lose the product story as soon as the real work starts:
notes pile up, docs drift, research gets buried, and the demo page stops matching
what the team actually knows. MoonBook turns that active workspace into a clean
product front door with the wiki, book, journal, course, and skill center still
one click away.

## The Problem

Teams should not have to choose between a polished website and a truthful
workspace. The public page needs to be simple, but the work behind it needs
memory, evidence, and repeatable procedures.

- polished pages drift away from reality
- raw notes make the product look unfinished
- research and docs rarely become a crisp story

## The Product

MoonBook packages a knowledge workspace into reader-specific surfaces. Buyers
see the product story first, technical readers can open the wiki or book, and
operators can inspect the journal and skills that keep the workspace moving.

- product page for the pitch
- wiki and book for depth
- journal and skill center for operation

## Why It Wins

The marketing page does not pretend to be the source of truth. It stays focused
on the value while the wiki carries the detailed memory and the skills carry the
repeatable maintenance workflow.

- clean story outside
- durable knowledge inside
- repeatable skills instead of one-off copy updates

## What You Can Ship

MoonBook lets one local project produce a product page, a rendered book, a
maintained wiki, a journey timeline, an educational course, and a skill manager.
That means the demo, docs, and operating room can move together.

- launch-ready product page
- structured documentation
- detailed wiki
- progress journal
- skill management surface

## Who It Is For

MoonBook is for teams whose knowledge changes too quickly for a separate website
to stay accurate. It is especially useful when the project needs to be shown,
explained, and maintained at the same time.

- founders preparing demos
- product teams aligning story and docs
- researchers turning source work into synthesis
- operators maintaining long-running agent workspaces

## Proof Points

The generated page ships beside the rendered book and links into the deeper
workspace surfaces. The reader can start with the pitch and immediately move to
the wiki, book, journal, course, or skills when they want proof.

- product page generated with the build
- deeper wiki remains available
- operating surfaces stay close without crowding the pitch

## Next Step

Open the product page first. If the story is interesting, continue into the wiki
or book for proof; if you need to operate the workspace, open the journal and
skills.

- read the pitch
- inspect the proof
- turn repeated work into skills
```

## Failure Mode

If the workspace is too empty to market, write a useful blocker, not fake hype:

```markdown
# Marketing brief blocked

This workspace does not yet contain enough product substance to write a
seller-facing page.

## The Problem

The current project has scaffolding but no clear buyer promise, proof surface, or
durable synthesis to support a marketing claim.

- missing product outcome
- missing proof pages
- missing buyer-specific positioning

## Next Step

Run ingest or research first, then rerun the marketing pass after the wiki has
enough substance to support a real promise.
```

## Final Rule

Do not improve marketing by editing renderer code.

Improve:

- the brief
- the skill
- the underlying wiki evidence

The renderer owns layout. This skill owns selling.
