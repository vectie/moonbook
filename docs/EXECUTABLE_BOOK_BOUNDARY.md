# Executable Book Boundary

Last checked: 2026-06-18.

MoonBook is the durable executable book. It owns the filesystem truth that both
human-language and executable/code-language editing operate on.

## Standalone Project Rule

MoonBook must run as its own checkout. It may persist artifacts produced by external runtimes, but it must not require adjacent MoonClaw, Moontown, or Moondesk source checkouts to build, test, serve, or edit books. Cross-project integration should use configured paths, published packages, or runtime protocols.

## Product Model

```text
MoonBook = executable book
MoonWiki = human-language book editing
MoonCode = executable/code-language book editing
MoonClaw = bounded execution engine
Moontown = coordination network for books
Bookkeeper = acceptance gate
```

MoonBook should not become an agent runtime. It stores accepted knowledge,
accepted code, sources, evidence, review receipts, generated sites, package
manifests, and durable outputs.

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
  .moonclaw/mooncode/sessions/
```

MoonBook already strongly owns the Wiki side: `wiki init`, `wiki ingest`,
`wiki query`, `wiki review`, `wiki lint`, `raw/bootstrap`, seeded skills,
standing-watch decisions, and review queues.

The next documentation and template hardening is to make the Code side equally
first-class: book-owned `tools/`, `apps/`, package manifests, test evidence,
MoonCode review receipts, and executable artifact promotion should be described
as normal MoonBook surfaces, not only as Moondesk or MoonClaw side effects.

## Boundary Rules

- MoonBook owns durable truth and accepted artifacts.
- MoonClaw may stage raw results, code diffs, package proof, and runtime events.
- Bookkeeper/user review decides what is accepted.
- Moontown schedules and coordinates book work, but does not own topic memory.
- Moondesk projects and edits the book, but should not own book semantics.
