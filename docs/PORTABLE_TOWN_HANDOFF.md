# File-carried MoonBook and output handoff

This increment transfers an experienced Book and explicitly selected output bytes in an ordinary `.moonbook-agent`. Town records and privately shares the publisher's exact expected source descriptor. The publisher supplies the actual file separately. Town does not upload, retain, download, or verify those unseen bytes.

## Sender

1. Accept useful learning through the existing workflow. Choose only output files you intend to give the recipient. Inspect accepted/excluded memory and identity files as well as selected outputs; current policy and secret heuristics are not a comprehensive privacy review.
2. Create an explicit selection JSON array. Paths are Book-relative; each included group preserves its chosen relative layout inside `portable/outputs/<artifact_id>/`. Use unique IDs and destinations. `included: false` carries only the reference, never bytes.

```json
[
  {
    "artifact_id": "report",
    "label": "Final report",
    "mime_type": "application/pdf",
    "included": true,
    "files": [{"source_path": "outputs/report.pdf", "path": "report.pdf"}],
    "reference": [],
    "declared_digest": [],
    "preview_path": [],
    "app_entrypoint": []
  }
]
```

The selection and output manifest use the existing MoonBit option encoding: `[]` means absent, `["index.html"]` means present. An app group must explicitly list its entrypoint and every asset; `app_entrypoint` and `preview_path` are relative to that group's layout. These fields declare included files, not a capability to execute them. Already exported Desk app-tool bytes retain the existing `portable/app-tool/` collector and manifest.

3. Pack, inspect, verify, and save the exact descriptor:

```text
moonbook agent pack <book> <version> <package.moonbook-agent> <outputs.json>
moonbook agent inspect <package.moonbook-agent>
moonbook agent verify <package.moonbook-agent>
moonbook agent source <package.moonbook-agent>
```

Save `source`'s JSON output. Its manifest fields use explicit JSON null/string. Without the final selection argument, ordinary `agent pack` behaves as before. Missing, excluded, over-limit, duplicate, unsafe or symlink selections fail rather than silently claiming a complete output set. The existing 16 MiB per-file limit applies; there is no new general total-package limit.

4. In the existing authenticated Town owner client, add this JSON as `portable_source` to the existing agent-draft payload sent to `POST /miniapp/marketplace/listings/agent`. Keep the rest of the existing draft fields. Review the returned `portable_binding`; use the existing share preview and same-tenant grant routes. After the first attachment, the exact source cannot be changed or removed for that listing ID; a new package needs a new versioned listing ID. Existing card/public index fields remain unchanged.
5. Give the recipient the original package through a separately chosen file-transfer channel. Keep the original package and expected binding. Do not repack to rediscover its identity: ordinary packing can normalize source wiki projections and changes package timestamps/digests.

## Recipient

1. Under your own existing Town session, read `GET /miniapp/marketplace/shared-listings`. Save the selected `portable_binding` object as `town-binding.json`. This is publisher-declared expected metadata, not Town byte verification or a cryptographic signature.
2. Choose the matching package file supplied separately, and choose a new local Book destination:

```text
moonbook agent import-exact <package.moonbook-agent> <new-book> <town-binding.json>
moonbook agent verify-import <retained-package.moonbook-agent> <book>
```

Exact import checks the raw file hash and length, normal bundle verification, source tuple, manifest digest/counts, and every output member. It does not fall back to the latest version, title, publisher's active Book, or hosted Try. The local filename may differ; that display name does not change byte identity. Mismatch is rejected before destination initialization. An existing target conflicts.

After successful import, member hashes are rechecked and `state/portable-source-binding.json` records the source binding, ordinary installation receipt, and separate local target identity. An application failure raises the original error and does not emit a complete exact receipt; initialization may leave a partial new folder requiring inspection. Do not interpret an old successful receipt as proof of current bytes after editing. `verify-import` checks current members against the retained package and reports drift.

For Desk, choose `<your-suite>/books/<new-local-name>` and refresh discovery. Existing TOML Book discovery recognizes it. No fabricated `book.json` or new installer bridge is required.

## Scope

- Private sharing remains subject to existing authenticated ownership and same-tenant grants
- Public review/publication and publisher-hosted Try remain separate existing flows
- Files are transported as inert artifacts; arbitrary file formats are not promised to render or execute
- No Bunnia marketplace UI is added because that checkout is absent
- No new credential, hosting service, account actor override, or agent runtime is introduced

## Library examples

```mbt nocheck
let outputs : Array[@agent.PortableOutputSelection] = [{
  artifact_id: "report", label: "Final report", mime_type: "application/pdf",
  included: true, files: [{ source_path: "outputs/report.pdf", path: "report.pdf" }],
  reference: None, declared_digest: None, preview_path: None, app_entrypoint: None,
}]
let path = @agent.pack_agent(root, version="1.0.0", output="report.moonbook-agent", outputs~)
let source = @agent.describe_portable_source(path)
let receipt = @agent.import_agent_bundle_exact(path, destination, binding_path)
```
