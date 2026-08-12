# Repository intake and evidence contract

## Inspect in this order

1. Repository and nested agent instructions.
2. Product contract, README, architecture, plan, implementation status, release
   readiness, operations, security, recovery, and deployment documents.
3. Public API and contract packages.
4. Executable entrypoints and configuration loaders.
5. Deployment manifests and operator scripts.
6. Tests that exercise public behavior and failure paths.
7. Current git revision, dirty state, and ignored-output boundaries.

Use search to locate evidence, then read the complete relevant sections. A
filename or symbol match is not proof of behavior.

## Exclude

Do not copy or index:

- `.git`, dependency caches, build outputs, vendored packages, model weights;
- environment files, credential stores, certificates, keys, tokens, cookies;
- production databases, logs containing user content, raw prompts or outputs;
- hidden agent instructions or private tool traces;
- absolute host paths or private network topology.

## Evidence file

Write `coursebook-evidence.json`:

```json
{
  "contract_version": "moonbook.repository-coursebook-evidence.v1",
  "repository": {
    "name": "example",
    "revision": "git object id or explicit source revision",
    "working_tree": "clean|dirty|unavailable",
    "inspected_at": "RFC 3339 timestamp"
  },
  "sources": [
    {
      "id": "product-contract",
      "path": "docs/PRODUCT_CONTRACT.md",
      "digest": "sha256:<64 lowercase hex>",
      "kind": "product-contract",
      "public": true
    }
  ],
  "claims": [
    {
      "id": "claim-controller-reconciles",
      "statement": "The controller reconciles durable desired state.",
      "status": "implemented",
      "source_ids": ["product-contract", "controller-test"],
      "limitations": []
    }
  ],
  "open_gaps": []
}
```

IDs are stable lowercase slugs. Paths are normalized repository-relative paths
without `..`. Digests cover the exact inspected bytes. The public site may show
source labels and paths only when the repository itself is intended to be
public; otherwise expose stable source labels and keep paths server-side.

## Contradictions

When sources disagree:

1. prefer current executable behavior for an implementation claim;
2. prefer the product contract for intended boundaries;
3. preserve the disagreement and date/revision of each source;
4. mark the page `unknown` or `documented` when evidence cannot settle it;
5. never infer production readiness from a simulator or mocked test.

## Freshness

The coursebook is current only for the recorded revision and dirty snapshot.
Set `project.freshness` to `stale` when the repository revision changes, a
referenced source digest changes, or the evidence scan cannot be reproduced.
