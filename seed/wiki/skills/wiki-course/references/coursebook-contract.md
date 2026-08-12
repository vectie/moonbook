# Coursebook content contract

The browser reads `coursebook.json` and renders a safe structured document. It
does not evaluate HTML from the content file.

## Root shape

```json
{
  "contract_version": "moonbook.repository-coursebook.v1",
  "project": {
    "name": "Example",
    "short_name": "EX",
    "tagline": "One precise sentence.",
    "description": "What the reader will learn.",
    "language": "en",
    "revision": "source revision",
    "freshness": "current|stale|draft",
    "updated_at": "RFC 3339 timestamp"
  },
  "navigation": [
    {"id":"overview","label":"Overview","page_ids":["welcome"]},
    {"id":"advanced","label":"Technical notes","visibility":"advanced","page_ids":["readiness"]}
  ],
  "pages": [],
  "suggested_questions": []
}
```

Page IDs and navigation IDs are unique lowercase slugs. Every page appears
exactly once in navigation.

Navigation groups, pages, and individual blocks may set
`"visibility":"advanced"`. The standard reader view excludes those values
from navigation, search, pagination, status display, and rendering. The reader
must explicitly select Technical notes or open a direct advanced-page URL.
Visibility is progressive disclosure, not an access-control boundary; never
put secrets or private repository data in either JSON file.

## Page shape

```json
{
  "id": "welcome",
  "group_id": "start",
  "title": "What is Example?",
  "summary": "Direct answer shown above the fold.",
  "audience": "New platform operator",
  "estimated_minutes": 6,
  "status": "implemented|documented|planned|simulated|unknown",
  "tags": ["overview"],
  "source_ids": ["product-contract"],
  "visibility": "advanced",
  "blocks": []
}
```

## Supported blocks

- `heading`: `level` (2 or 3), `text`, optional `id`.
- `paragraph`: `text`.
- `bullets`: `items` array of strings.
- `steps`: `items` array of `{title, text}`.
- `callout`: `tone` (`info|success|warning|danger`), `title`, `text`.
- `code`: `language`, optional `label`, `code`.
- `table`: `columns` array and `rows` array of equally sized string arrays.
- `flow`: optional `title`, `steps` array of `{title, text, tone?}`.
- `cards`: `items` array of `{title, text, href?}`; `href` may be a coursebook
  page id or a public `https` URL.
- `troubleshooting`: `symptom`, `likely_causes`, `checks`, `resolution`, and
  optional `escalate_when`, all string arrays except `symptom`.
- `checkpoint`: `question`, `answer`, optional `revisit_after_days`.
- `image`: repository-owned `src` below `./images/`, descriptive `alt`, and
  optional `caption`. Capture the actual rendered product when possible; never
  substitute a concept mockup while calling it a product screenshot.

Keep raw wire IDs, commands, paths, and error codes unchanged inside code or
reference fields. Explain them in adjacent prose instead of translating or
rewriting them.

## Localization projection

When bilingual delivery is requested, publish `coursebook.zh-CN.json` beside
the English source. It uses contract
`moonbook.repository-coursebook-locale.v1`, locale `zh-CN`, a `ui` string map,
localized navigation labels, every page id, and one overlay block for every
base block. Overlay blocks retain the base `kind`; they translate labels,
prose, table cells, captions, and alt text but never replace `code`, ids, paths,
protocol values, or wire enums. Use `coursebook.zh-CN.example.json` as the
structural reference. A partial locale file is invalid.

## Source linkage

Every factual page has `source_ids`. High-risk claims—security, data handling,
destructive operations, production readiness, billing, or access—also need an
adjacent callout describing their limitation or verification boundary.

Evidence records and claim classifications remain complete even when their UI
is advanced-only. Ordinary safety boundaries, destructive-operation warnings,
and user-visible limitations stay in standard lessons; only internal process,
provenance, freshness, readiness judgment, and reviewer material are hidden by
default.

## Page anatomy

Prefer this order:

1. direct summary;
2. why the reader cares;
3. mechanism or flow;
4. example or procedure;
5. success signal and failure boundary;
6. checkpoint or next page.

Do not force exercises into pure reference pages. Use checkpoints where they
improve recall, not as decoration.
