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

Use this default top-level structure, adapting names without removing the
reader jobs:

1. **Start here** — product purpose, audience, boundaries, current readiness.
2. **System tour** — feature map, architecture, ownership, trust boundaries.
3. **Data flows** — request, deployment, state, and failure flows.
4. **Use it** — quickstarts and task-oriented guides with expected results.
5. **Operate it** — installation, configuration, observability, recovery.
6. **Debug it** — symptom-first playbooks, messages, causes, checks, fixes.
7. **Reference** — contracts, configuration, states, glossary, source ledger.

Do not mirror the repository folder tree. Organize around reader questions.
Keep marketing, learning, operating, and evidence views distinguishable.

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
coursebook-evidence.json
```

The shell owns responsive navigation, local search, page routing, source
disclosure, code copying, next/previous navigation, and the pet panel. Product
facts belong only in `coursebook.json` and `coursebook-evidence.json`.

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

- parse both JSON files;
- scan for absolute paths, credentials, private addresses, unresolved
  placeholders, raw prompts, and secret-like values;
- verify every navigation page id and every citation target exists;
- verify every source reference is repository-relative and present;
- serve the site and exercise search, routing, back/forward, code copy, mobile
  navigation, empty search, pet-offline, pet-refusal, and pet-success states;
- inspect desktop and 390 px layouts, keyboard focus, 200% text zoom, reduced
  motion, and print output;
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
- works without JavaScript-generated unsafe HTML or third-party CDN assets;
- remains useful when MoonClaw is offline;
- keeps every assistant answer bounded to public coursebook evidence.

Reject the result when it is mostly a landing page, a single giant article, a
folder-tree dump, generic AI prose, or a collection of commands without
observable outcomes.
