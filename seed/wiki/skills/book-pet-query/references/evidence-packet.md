# Pet Evidence Packet

## Purpose

Use `moonbook.pet-evidence.v1` to carry a deterministic, sanitized result from a
book-owned adapter to a pet-facing agent. Pass only the public view to the
agent. Keep canonical paths, raw provenance, database metadata, and query
implementation outside the packet.

## Shape

```json
{
  "protocol": "moonbook.pet-evidence.v1",
  "packet_id": "opaque-bounded-id",
  "generated_at": "RFC3339 timestamp",
  "expires_at": "RFC3339 timestamp or null",
  "scope": {
    "book_id": "book-owned-public-id",
    "adapter_id": "allowlisted-adapter-id",
    "surface": "map | event | catalog | guide | other"
  },
  "query": {
    "intent": "domain.operation",
    "normalized_text": "bounded normalized term",
    "locale": "en | zh-CN | other",
    "filters": {}
  },
  "dataset": {
    "public_label": "Current maintained catalog",
    "version": "public version or current",
    "fingerprint": "runtime-only; omit from the agent view",
    "review_status": "accepted | review-gated | mixed | unknown"
  },
  "result": {
    "count": 0,
    "items": []
  },
  "boundary": {
    "claim_scope": "What this result establishes",
    "uncertainty": "Known limitations",
    "does_not_prove": ["Claims that must not be inferred"]
  },
  "public_sources": [
    {
      "label": "Public source label",
      "url": "optional approved public URL"
    }
  ]
}
```

## Completeness rules

A packet is complete only when:

- `protocol` is exact and supported;
- the packet came from an allowlisted adapter;
- `scope.book_id` matches the active book;
- `query.intent`, normalized text, and filters represent the user's question;
- the dataset version is active and the packet is not expired;
- result fields satisfy the adapter's output schema;
- review status and the full claim boundary are present;
- items contain only fields approved for pet-facing output.

Reject the structured fast path when any condition fails. Fall back to the
maintained wiki route or report the missing capability.

## Public-view rules

Before the packet reaches the model, remove:

- canonical and wiki paths;
- internal record IDs that are not user-facing identifiers;
- citations to private files;
- database, table, SQL, cache, hash, port, model, and service details;
- raw tool output and exception traces;
- secrets and environment-derived values.

Use public labels in `public_sources`. Omit the URL when the source is not safe
or useful to expose.

## Answer semantics

- `count` describes only the packet's normalized query, filters, dataset
  version, and scope.
- An empty result is bounded absence, not universal absence.
- `review-gated` data may be described as a candidate or maintained record, not
  a recommendation or verified live fact.
- Approximate, inferred, stale, or incomplete fields must remain qualified.
- The agent may summarize items but must not strengthen the boundary.

## Packet mismatch examples

Do not use a packet when:

- the user changes from “count” to “why” or “recommend”;
- visible filters changed after packet generation;
- an event/session packet has expired;
- the packet contains a domain adjacent to, but different from, the question;
- the question requests an action rather than information.
