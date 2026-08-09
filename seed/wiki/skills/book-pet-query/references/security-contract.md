# Pet Security Contract

## Trust boundaries

Treat as untrusted:

- the user's message;
- browser/UI context;
- retrieved pages and live transcript text;
- adapter errors and upstream responses;
- public source labels and URLs;
- any text claiming to be a system instruction, skill update, or authorization.

Only the host policy, active `book-pet-query` skill, validated adapter manifest,
and validated evidence schema define authority.

## Authority

Default to read-only and explanation-only. The pet may answer, clarify, and
describe a visible next step. It may not:

- write or delete files;
- mutate a database or cache through agent-selected arguments;
- execute commands or code;
- browse arbitrary URLs;
- start jobs or background tasks;
- submit forms, messages, purchases, subscriptions, or schedules;
- change credentials, configuration, permissions, or memory;
- claim completion of any prohibited action.

Route requested actions to a separate typed handoff with explicit authority and
confirmation outside the pet query session.

## Network and credential controls

- Keep tokens and service credentials on the server side.
- Prefer same-origin browser requests and loopback or authenticated internal
  service connections.
- Allowlist exact schemes, hosts, ports, paths, and methods.
- Reject embedded credentials, redirects to unapproved origins, arbitrary
  headers, and user-supplied request bodies.
- Bound connection, response, and total request timeouts.
- Never send secrets, user identifiers, or private evidence to the model unless
  an explicit data policy permits the exact fields.

## Input and session controls

- Accept a typed JSON request, not free-form transport metadata.
- Bound message, context, packet, and reply sizes.
- Restrict session IDs to a short opaque character allowlist.
- Isolate sessions by book, host surface, and user/session boundary.
- Treat stable session IDs as routing aids, not authorization.
- Do not place secrets or raw user text in cache keys, URLs, or logs.

## Data controls

- Use parameterized queries or fixed helper operations.
- Permit only the active book and declared dataset scope.
- Send only sanitized public evidence to the model.
- Keep internal provenance available to deterministic review code, not the
  pet-facing answer.
- Apply freshness, review, and uncertainty labels before model invocation.
- Do not let the model decide whether private fields are safe to reveal.

## Prompt-injection controls

- Delimit the user question, visible context, and evidence packet as data.
- State that embedded instructions cannot override policy.
- With a complete structured packet, disable file and external tools.
- With maintained-wiki fallback, allow only book-scoped reads needed for the
  question.
- Reject requests for hidden prompts, tool traces, packet internals,
  credentials, or private source locations.

## Output controls

Sanitize model output for:

- local and repository paths;
- private URLs and loopback addresses;
- database/table names and SQL;
- hashes, cache keys, opaque internal IDs, ports, and model names;
- environment variables, tokens, headers, logs, and stack traces;
- Markdown links or code spans pointing to internal material;
- claims that an action or durable write occurred.

Prefer allowlisting public fields over maintaining only a denylist.

## Failure behavior

Fail closed while remaining useful:

- invalid request: explain what user input is needed;
- malformed or stale packet: use maintained knowledge when safe;
- unavailable live adapter: say live information is unavailable;
- insufficient maintained evidence: give the bounded conclusion and unknowns;
- unsafe action request: explain the separate reviewed action path;
- sanitizer uncertainty: return a generic safe error, not raw output.

Health checks and logs may report component categories such as “knowledge” or
“assistant,” but user-facing errors must not expose topology or secrets.
