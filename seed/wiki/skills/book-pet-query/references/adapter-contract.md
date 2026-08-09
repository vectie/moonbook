# Pet Adapter Contract

## Ownership split

Keep deterministic behavior in the host adapter:

- validation and intent classification;
- query normalization and parameter binding;
- data access, timeouts, retries, and rate limits;
- freshness checks, evidence-packet construction, and redaction;
- cache keys, concurrency limits, audit events, and health checks.

Keep semantic behavior in `book-pet-query`:

- route selection;
- concise explanation;
- uncertainty and review-boundary language;
- user-facing distinctions and safe next steps.

## Adapter manifest

Declare every adapter before use:

```json
{
  "protocol": "moonbook.pet-adapter.v1",
  "id": "conference-agenda",
  "book_id": "example-book",
  "mode": "structured | live",
  "intents": ["conference.schedule", "conference.session-summary"],
  "read_only": true,
  "max_input_chars": 2000,
  "timeout_ms": 5000,
  "output_protocol": "moonbook.pet-evidence.v1",
  "public_source_mode": "labels-only | approved-links",
  "requires_user_confirmation": false
}
```

Do not let user text select an undeclared adapter or override manifest limits.
An adapter marked `read_only: false` is ineligible for the pet query route.

## Deterministic pipeline

Implement this sequence:

1. Validate request shape, origin, session ID, message length, and visible
   context against allowlists.
2. Classify only supported intents. Return no classification when ambiguous.
3. Normalize terms and filters into typed values.
4. Execute a parameterized helper query or a fixed upstream request. Never
   accept user SQL, arbitrary URLs, paths, headers, or request bodies.
5. Convert the result into `moonbook.pet-evidence.v1`.
6. Remove private fields before model invocation.
7. Ask the model to answer only from the packet and active skill.
8. Sanitize the final response again before returning it.
9. Record redacted outcome metadata, never raw secrets or hidden prompts.

## Freeform fallback

When classification returns no supported structured intent:

- enter a new or isolated read-only keeper session;
- load `book-pet-query` and `wiki-query`;
- restrict the workspace to the active book;
- allow only bounded read, list, and search operations;
- prohibit writes, command execution, web access, jobs, and external actions;
- sanitize the answer before it reaches the host UI.

Do not send a malformed structured request through a broader adapter merely to
obtain an answer.

## Live adapters

For live events, availability, status, or telemetry:

- require an explicit current-time and freshness contract;
- resolve ambiguous subjects before querying;
- use short timeouts and bounded retries;
- distinguish “service unavailable,” “no current data,” and “no matching
  record”;
- never reconstruct live state from an old maintained page;
- never turn a read endpoint into subscription or action authority.

Subscriptions, purchases, scheduling, messages, and form submissions require a
separate reviewed action contract outside this skill.

## Cache and concurrency

For structured answers, derive the cache key from:

- active dataset fingerprint;
- normalized query and filters;
- locale;
- pet-skill digest or policy version;
- adapter version.

Never include raw tokens or personal identifiers. Use single-flight
coalescing for identical misses and a bounded worker pool. Do not share model
conversation history between unrelated users or cache entries.

## Product specialization

A host may provide:

- pet display name and tone;
- visible surface context;
- approved public source labels;
- domain adapters and packet schemas;
- safe starter questions;
- a reviewed action-handoff destination.

The host may not remove read-only mode, privacy redaction, packet validation,
scope matching, review boundaries, or fail-closed behavior.
