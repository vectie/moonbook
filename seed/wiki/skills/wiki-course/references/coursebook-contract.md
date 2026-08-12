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
    {"id":"start","label":"Start here","page_ids":["welcome"]}
  ],
  "pages": [],
  "suggested_questions": []
}
```

Page IDs and navigation IDs are unique lowercase slugs. Every page appears
exactly once in navigation.

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

Keep raw wire IDs, commands, paths, and error codes unchanged inside code or
reference fields. Explain them in adjacent prose instead of translating or
rewriting them.

## Source linkage

Every factual page has `source_ids`. High-risk claims—security, data handling,
destructive operations, production readiness, billing, or access—also need an
adjacent callout describing their limitation or verification boundary.

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
