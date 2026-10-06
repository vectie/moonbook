# Portable human-accepted Desk lessons

Desk's explicit **Accept learning** action can materialize one immutable Book-owned
Markdown memory record. This uses the existing portable-agent memory layout and
review-status reader; it does not change ingestion acceptance, source verification,
Bookkeeper evaluation/promotion, or the agent bundle schema.

## Canonical layout

- Procedure: `memory/procedures/desk-<sha256-of-proposal-id>.md`
- Knowledge, preference, capability idea: `memory/beliefs/desk-<sha256-of-proposal-id>.md`

The filename uses the lowercase 64-character hex digest of the original UTF-8
proposal ID, because legacy Desk IDs can contain the full lesson slug and exceed
filesystem name limits. The complete original ID is retained in provenance.

Each file starts with a closed Markdown metadata block. `status: accepted` is the
existing admission field. `lesson_kind` is one of `knowledge`, `preference`,
`procedure`, or `capability`. The other metadata fields are `proposal_id`,
`workspace_id`, `created_at`, and `decided_at`; string values are JSON-quoted YAML
scalars. The readable body names the lesson kind and includes the exact full detail
and source. A final JSON block carries the existing
`moondesk.learning-proposal.v1` record (without Desk's persistence receipt), which
is the authoritative lossless provenance representation.

The origin workspace ID is provenance, not a portable agent ID or an installation
directory. The bridge does not change `book.json`, `book.toml`, identity files,
`state/agent-installation.json`, a published version, or the importer's workspace.
Bundle identity/version/revision continue to be owned by the existing agent pack
and installation operations.

`capability` means an accepted **capability idea**, never a provisioned tool,
evaluated capability, `promoted` procedure, or activation permission. `preference`
retains its explicit type; this bridge does not rewrite or prune `keeper/USER.md`.
These immutable full lessons complement rather than replace bounded Keeper
working/preference memory. No automatic native Town runtime hydration is implied.

## Commit and retry behavior

Desk journals the original human decision before attempting the Book write. The
same proposal ID always selects the same file. The complete file is written to a
private temporary file, synced, then atomically renamed without replacement.
An existing exact byte match is an idempotent success; different bytes, symlinks,
or an invalid target are a conflict/failure and are never overwritten. Temporary
files live outside the exported memory trees.

Desk's existing proposal response carries an additive `book_learning` receipt:
`status` (`pending`, `persisted`, `failed`, or `unsupported`), `path` (Book-relative), `revision`
(SHA-256 of the exact bytes), and `error` (empty on success). Acceptance time and
the provenance record remain unchanged across retries. A crash after journaling
or after Book materialization can be recovered by retrying that one proposal.
An interrupted receipt write must not be reported as successful completion.

Previously accepted Desk-only lessons are not automatically migrated by reads or
startup. Their per-item **Save to book** action explicitly retries that historical
accepted record. Proposed and rejected records cannot use this action. Ordinary
Desk prompt learning remains based on accepted Desk records, including historical
ones, as before.
Suite-root learning also retains the existing propose/accept/reject and prompt
behavior. Its accepted record reports `unsupported` for portable persistence and
explains that a MoonBook must be selected for portable lessons; no Book file is
written and no saved-to-Book success is claimed.

## Export boundary

`build_agent_bundle`/`pack_agent` collect both memory trees, and the existing
frontmatter reader admits these accepted `.md` files. Import restores the exact
bytes and the existing bundle installation lineage. Candidate/rejected records
are excluded. Existing export policies still apply, including secret-like content,
machine-local root paths, and file-size exclusions; acceptance does not bypass
those policies or promise publication of every source string.
