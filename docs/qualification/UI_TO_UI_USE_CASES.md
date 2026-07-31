# MoonBook and Bookkeeper UI-to-UI qualification

Last reviewed: 2026-07-31

MoonBook serves one existing Rabbita application containing both the book
workspace and the domain-neutral Bookkeeper console:

```text
entrypoint id: bookkeeper-console
service path:  /apps/moonbook/
default example port: 4321
```

There is no separate Bookkeeper application. MoonBook owns durable accepted
knowledge, exact human review, and Three-Gap records. MoonClaw performs bounded
agent work; MoonFlow orchestrates; neither may self-install reviewer authority.

## Prerequisites and launch

Use a disposable book for qualification:

```sh
export MB_REPO=/Users/kq/Workspace/moonbook
export MF_QUAL="${MF_QUAL:-$(mktemp -d /tmp/moonsuite-research-ui-qualification.XXXXXX)}"
export MB_QUAL="$MF_QUAL/book"

test ! -e "$MB_QUAL" || {
  echo "Refusing to overwrite existing qualification book: $MB_QUAL" >&2
  exit 1
}
cd "$MB_REPO"
moon run --release cmd/main -- wiki init "$MB_QUAL"
moon run --release cmd/main -- build "$MB_QUAL"
moon run --release cmd/main -- serve "$MB_QUAL" -n 127.0.0.1 -p 4321
```

Reuse MoonFind's exact `MF_QUAL` for MB-02. MoonBook uses a release executable
here because very large debug-native builds can exceed the AArch64 local-branch
range; this does not change Bookkeeper semantics.

Open:

```text
http://127.0.0.1:4321/apps/moonbook/
```

The rendered book remains at `/`; the operator application is mounted under
`/apps/moonbook/` by the same process and workspace.

## MB-01 — inspect one executable book

1. Open the operator URL.
2. Confirm the book title, pages, sources, synthesis, review queue, and runtime
   status are loaded from `moonbook-ui-state.json`.
3. Use the left navigation to open **Bookkeeper** and **Review queue**.
4. Confirm the Bookkeeper projection reports whether it loaded and shows its
   durable lanes.

Expected visible result:

- one Rabbita application, not separate MoonBook/Bookkeeper apps;
- lanes for deliverable acceptance, outcome binding, Three-Gap findings and
  reviews, capability proposal/review, work orders, evaluation, and adoption;
- empty lanes are visibly empty rather than fabricated.

## MB-02 — receive a MoonFind outcome and stop at human review

After MoonFind and MoonChat complete the accepted path, copy the exact
MoonFind-created submission into the disposable book:

```sh
RUN=humanoid-cross-paper-demo
SUBMISSION_SOURCE="$MF_QUAL/suite/.moonsuite/products/moonfind/runs/$RUN/bookkeeper-outcome-submission.json"
mkdir -p "$MB_QUAL/records"
cp "$SUBMISSION_SOURCE" "$MB_QUAL/records/product-outcome-submission.json"

cd "$MB_REPO"
moon run cmd/moonflow_adapter -- submit-product-outcome \
  --workspace "$MB_QUAL" \
  --submission records/product-outcome-submission.json
```

Reload the MoonBook application.

Expected visible result:

- a new deliverable appears in **deliverable acceptance**;
- status says it awaits human review;
- the correlated `product.result` ingress is durable;
- no Three-Gap finding or capability proposal is accepted yet;
- activation remains false.

Primary evidence:

```text
$MB_QUAL/.moonbook/bookkeeper/journal/
$MB_QUAL/.moonbook/bookkeeper/snapshot.json
$MB_QUAL/.moonbook/bookkeeper/ui-state.json
```

## MB-N1 — no reviewer authority

Run MB-02 before installing an authority grant.

1. Open the Bookkeeper console.
2. Select the pending deliverable.
3. Choose **Governed review**.

Expected visible result:

- the UI says no active reviewer authority is installed;
- it instructs the operator to use
  `moonbook bookkeeper authority install`;
- the browser cannot invent or install authority;
- submission remains disabled or is rejected without mutation.

## MB-03 — exact named-human deliverable acceptance

Authority installation is deliberately CLI-only. Prepare a grant whose
`evidence_refs` are the exact evidence ids on the pending deliverable:

```json
{
  "contract_version": "moonbook.bookkeeper.store.v1",
  "grant": {
    "record_id": "grant-research-qualification",
    "record_version": "v1",
    "record_digest": "sha256:replace-with-a-stable-64-hex-digest"
  },
  "reviewer_id": "research-qualification-reviewer",
  "reviewer_kind": "Human",
  "authority_ref": "authority://research-qualification-reviewer",
  "evidence_refs": ["replace-with-evidence-id-from-the-selected-record"],
  "active": true,
  "granted_at": 1785456000
}
```

Save it as `$MB_QUAL/records/reviewer-grant.json`, then:

```sh
cd "$MB_REPO"
moon run --release cmd/main -- bookkeeper authority install \
  "$MB_QUAL" "$MB_QUAL/records/reviewer-grant.json"
```

In the UI:

1. Reload and open **Bookkeeper**.
2. Select the new reviewer authority.
3. Select the exact pending deliverable.
4. Choose **Governed review**.
5. Inspect the generated JSON. It must bind the selected record id, version,
   digest, evidence, human reviewer, grant, and `Accept` disposition.
6. Click the mutation submit action once.
7. Click **Replay durable store**.

Expected visible result:

- the exact deliverable shows accepted;
- a named-human receipt is visible in the projection;
- there are no external side effects.

Replay the same MoonFind submission:

```sh
cd "$MB_REPO"
moon run cmd/moonflow_adapter -- submit-product-outcome \
  --workspace "$MB_QUAL" \
  --submission records/product-outcome-submission.json
```

Reload the UI. The deterministic Three-Gap assessment may now appear, but it
must stop at its own named-human review gate. Later capability proposals also
have a separate human gate. No screen may imply automatic capability
activation.

## MB-N2 — reject conflicting or non-human review

Try one failure at a time in a disposable workspace:

- change the selected record digest in the review draft;
- use a reviewer id different from the installed grant;
- set reviewer kind to `Agent`;
- reuse a mutation id with different content.

Expected result:

- the mutation is rejected with an exact issue;
- the prior journal and projection remain intact;
- replay reports the same durable truth.

## Failure recovery

- UI state stale: click **Replay durable store**, then reload. `moonbook serve`
  also refreshes generated state after accepted mutations.
- Interrupted write: run
  `moon run --release cmd/main -- bookkeeper replay "$MB_QUAL"` and inspect
  replay issues.
- Wrong submission version: restore the exact MoonFind artifact; do not patch
  journal records.
- Missing authority: install a separately reviewed CLI grant. The UI must never
  add one.

## Qualification record

```text
date:
operator:
MoonBook commit:
book root:
browser URL:
MB-01: PASS | FAIL | BLOCKED
MB-02: PASS | FAIL | BLOCKED
MB-N1: PASS | FAIL | BLOCKED
MB-03: PASS | FAIL | BLOCKED
MB-N2: PASS | FAIL | BLOCKED
deliverable ref:
review receipt ref:
Three-Gap ref:
screenshots:
notes:
```
