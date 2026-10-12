# Atomic policy artifact fixture adapter

The `cmd/policy_artifact_adapter` native executable publishes
`moonbook.policy-artifact-batch.local-fixture.v1`. It is an opt-in local
integration capability, not a live role provider, MoonGate authority receipt,
human claim review, external database, or public-policy approval.

`capability` returns the exact supported port. `read ROOT` validates and reads
the acknowledged journal. `append-local-fixture ROOT REQUEST.json` accepts only
complete advisory local-fixture batches with exact expected version, unique
operation/record identities, and payload digests. Writer draft/trace and
Rewriter draft/rewrite-receipt pairs are atomic. Incomplete sets, wrong mode,
digest changes, stale versions, and replayed appends fail closed. A caller
resumes by inspecting the exact previously acknowledged batch, not appending
the same stage again.

One exclusive file lock serializes a fully written and synced temporary
snapshot followed by an atomic same-filesystem rename. The payloads and their
receipts are in the same journal. A complete matching interrupted temporary
file can be published; an incomplete or conflicting temporary file is retained
and refused. Reads verify the entire version and receipt chain. The bounded
journal is at most 8 MiB; one payload is at most 1 MiB and a batch at most eight
artifacts. Snapshot and lock symlinks are refused. The configured root is a
trusted local host destination, not a browser-provided path.

This verifies local process interruption and atomic visibility. It does not
claim distributed DB transactions, arbitrary hostile local filesystem
containment, power-loss recovery, or production durability across machines.
