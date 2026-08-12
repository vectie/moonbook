---
name: wiki-course
description: Turn a software repository into a source-grounded, multi-page coursebook site that explains features, architecture, data flow, operation, and debugging, with a bounded MoonClaw documentation pet. Use when creating or refreshing repository documentation, onboarding material, operator guides, architecture tours, troubleshooting playbooks, or a Suanli-style docs portal from code and maintained evidence.
---

# Repository Coursebook

## Outcome

Transform one repository into a useful coursebook, not a prettified README.
The result must let a new reader answer three questions:

1. What does this system do, and what does it deliberately not do?
2. How do its components and data flows work?
3. How do I use, operate, and debug it without guessing?

The default reading experience is for newcomers. Teach the product before
showing the documentation process. Repository revisions, generation mechanics,
claim classifications, readiness judgments, source digests, and evidence gaps
belong in an explicit **Technical notes** view. Keep those records accurate and
available, but do not put them in the ordinary navigation, search results,
article header, or first-screen lesson content.

The generated site is a disposable projection over repository evidence. The
repository and accepted MoonBook pages remain authoritative.

Before acting, read:

- `references/repository-intake.md` for evidence collection and freshness;
- `references/coursebook-contract.md` for information architecture and the
  structured content schema;
- `references/pet-contract.md` before enabling the embedded assistant;
- `references/human-readable-content.md` when authoring lessons, examples, or
  exercises.

Reuse `assets/coursebook-site/`. Do not invent another site shell unless the
user explicitly asks for a different product surface.

## Inputs

Require:

- an absolute repository root;
- an output directory outside ignored build artifacts;
- a named primary reader, such as a new operator, platform engineer, or API
  client developer;
- a current repository revision and dirty-state marker;
- the repository's own instructions and product/architecture/operations docs.

Optional inputs include a public product-docs reference, preferred language,
deployment target, and a MoonClaw Gateway endpoint. Treat reference sites as
layout and information-architecture evidence, never as copy to reproduce.

## Workflow

### 1. Establish the truth boundary

Read repository instructions before source. Identify authoritative documents,
public contracts, executable entrypoints, deployment manifests, tests, and
known readiness or limitation records. Record contradictions rather than
silently choosing the most optimistic statement.

Do not ingest secrets, generated dependency trees, build outputs, production
state, raw prompts, credentials, private keys, model weights, or user data.

### 2. Build a repository evidence map

Create `coursebook-evidence.json` using the contract in
`references/repository-intake.md`. Every public factual page must name one or
more repository-relative sources. Record the inspected revision, working-tree
state, source digest, and inspection time.

Classify each claim as:

- `implemented` — supported by current code or executable tests;
- `documented` — promised by current authoritative documentation but not
  independently exercised during this run;
- `planned` — explicitly future or gated work;
- `simulated` — proven only by a fake, local, or synthetic environment;
- `unknown` — evidence is missing or contradictory.

Never turn `planned`, `simulated`, or `unknown` into an implemented feature.

### 3. Design the reader journey

Use this beginner-first top-level structure, adapting names without removing
the reader jobs:

1. **Overview** — product purpose, audience, major features, and safe boundaries.
2. **Quickstart** — first success and task-oriented guides with expected results.
3. **How it works** — architecture, ownership, trust, and important data flows.
4. **Deployment** — installation, configuration, runtime qualification, and upgrades.
5. **Operations** — routine observation, backup, recovery, and safe changes.
6. **Troubleshooting** — symptom-first playbooks, causes, checks, fixes.
7. **Reference** — public contracts, configuration, states, errors, and glossary.
8. **Technical notes** — source ledger, freshness, claim status, internal
   methodology, and readiness gaps; mark this group and its pages `advanced`.

Do not mirror the repository folder tree. Organize around reader questions.
Keep marketing, learning, operating, and evidence views distinguishable.
Do not lead with caveats, implementation badges, repository state, or reviewer
language. Put the direct beginner answer first; disclose the evidence behind it
only after the reader explicitly selects Technical notes.

### 4. Author structured pages

Create `coursebook.json` with contract
`moonbook.repository-coursebook.v1`. Use only the block kinds and fields in
`references/coursebook-contract.md`; the bundled client renders every value as
text and never trusts authored HTML.

Each page must include:

- a single reader question;
- a concise answer in the first screenful;
- audience and prerequisite information when relevant;
- one useful visual for multi-component architecture or multi-step flow;
- concrete commands or examples for task pages;
- observable success criteria;
- limitations or failure boundaries;
- repository-relative source references.

When Chinese is requested, author a complete `coursebook.zh-CN.json` overlay:
translate the shell, navigation, every page, and every human-facing block while
preserving commands, protocol ids, paths, code, model names, and reader-entered
technical values. Persist the native English/简体中文 selector and update the
document language and title on every switch.

Task pages must prefer copy-paste recipes built from repository-owned scripts.
Exercise those scripts in the safest representative environment, show the
observable success condition, and state which hardware or production claims
the run does not prove. Product tours should embed real screenshots captured
from the current rendered product; label disconnected, simulated, or fixture
state honestly and never draw fake health data into a screenshot.

Source references remain mandatory data even when the standard UI hides them.
Use `"visibility":"advanced"` for pages or blocks that primarily discuss
repository process, evidence classification, readiness judgment, provenance,
or documentation generation. Do not mark safety instructions or user-facing
limitations advanced merely because they are inconvenient; readers still need
those to perform a task safely.

Debug pages must start with the symptom, then show likely causes, safe checks,
expected observations, and recovery. Never publish a command that destroys
state, disables security, prints secrets, or broadens authority without an
explicit warning and confirmation boundary.

### 5. Install the reusable site

Copy the contents of `assets/coursebook-site/` into the requested site root,
then replace `coursebook.example.json` with the authored `coursebook.json`.
Keep the asset filenames stable:

```text
index.html
styles.css
app.js
server.mjs
coursebook.json
coursebook.zh-CN.json (when localized)
coursebook-evidence.json
images/ (when screenshots are available)
```

The shell owns responsive navigation, local search, page routing, code copying,
next/previous navigation, the explicit Technical notes switch, advanced source
disclosure, and the pet panel. Product facts belong only in `coursebook.json`
and `coursebook-evidence.json`.

### 6. Configure the documentation pet

The static coursebook must remain fully usable without an agent. The pet is an
optional same-origin enhancement served by `server.mjs`.

The pet may answer only from the generated coursebook and its public evidence
map. It returns typed public page citations, not filesystem paths or tool
traces. It is read-only and cannot edit the repository, run user commands,
browse arbitrary URLs, or execute an operational action.

Follow `references/pet-contract.md` exactly. Reuse MoonClaw's read-only Cowork
session endpoint; do not create another agent runtime.

### 7. Verify before publishing

Run all of these:

- parse the coursebook, evidence, and every requested locale JSON file;
- scan for absolute paths, credentials, private addresses, unresolved
  placeholders, raw prompts, and secret-like values;
- verify every navigation page id and every citation target exists;
- verify every source reference is repository-relative and present;
- serve the site and exercise search, routing, back/forward, code copy, mobile
  navigation, empty search, standard/advanced switching, direct advanced links,
  pet-offline, pet-refusal, and pet-success states;
- verify standard mode omits advanced pages, status badges, source details,
  revision metadata, and advanced-only blocks from navigation and search;
- inspect desktop and 390 px layouts, keyboard focus, 200% text zoom, reduced
  motion, and print output;
- verify screenshots load, have useful alternative text, and match the stated
  product state; execute every published copy-paste recipe or record the exact
  external prerequisite that prevents execution;
- compare important claims against the current repository revision again.

Publication is a freshness claim. If the repository changes after inspection,
mark the site stale or regenerate it.

## Output contract

Return a compact completion record containing:

- repository root and inspected revision;
- site root;
- page count and navigation groups;
- source count and unresolved evidence gaps;
- pet status (`disabled`, `configured`, or `verified`);
- checks performed and checks that require the real deployment;
- exact preview and production serve commands.

When used through provider-task execution, retain the standard fields
`task_id`, `summary`, `artifacts`, `memory_candidates`, `requires_review`, and
`notify_town`.

## Quality bar

A strong coursebook:

- teaches the actual system rather than paraphrasing directory names;
- distinguishes feature, mechanism, procedure, and evidence;
- makes architecture and data movement visible;
- gives commands together with expected results and rollback boundaries;
- turns error messages into symptom-first debugging paths;
- preserves uncertainty and production-readiness gaps;
- teaches newcomers without exposing repository process or reviewer judgment
  until Technical notes is explicitly selected;
- works without JavaScript-generated unsafe HTML or third-party CDN assets;
- stays fully bilingual when localization is requested, without translating
  commands, ids, paths, protocol values, or reader-authored content;
- remains useful when MoonClaw is offline;
- keeps every assistant answer bounded to public coursebook evidence.

Reject the result when it is mostly a landing page, a single giant article, a
folder-tree dump, generic AI prose, or a collection of commands without
observable outcomes.
