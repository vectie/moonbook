///|
/// An explicitly selected source file and its layout within one inert artifact.
pub(all) struct PortableOutputSelectionFile {
  source_path : String
  path : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// No URL is fetched. Reference-only items carry no member bytes.
pub(all) struct PortableOutputSelection {
  artifact_id : String
  label : String
  mime_type : String
  included : Bool
  files : Array[PortableOutputSelectionFile]
  reference : String?
  declared_digest : String?
  preview_path : String?
  app_entrypoint : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct PortableOutputFile {
  path : String
  size_bytes : Int
  digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct PortableOutput {
  artifact_id : String
  label : String
  mime_type : String
  included : Bool
  files : Array[PortableOutputFile]
  reference : String?
  declared_digest : String?
  preview_path : String?
  app_entrypoint : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct PortableOutputsManifest {
  contract : String
  outputs : Array[PortableOutput]
} derive(Debug, Eq, ToJson, FromJson)

///|
fn portable_outputs_manifest_path() -> String {
  "portable/outputs.manifest.v1.json"
}

///|
fn portable_output_prefix(id : String) -> String raise {
  guard agent_relative_path_safe(id) && !id.contains("/") else {
    fail("output artifact_id must be one safe path component")
  }
  "portable/outputs/" + id + "/"
}

///|
fn portable_output_member(prefix : String, path : String) -> String raise {
  guard agent_relative_path_safe(path) else {
    fail("unsafe selected output layout: " + path)
  }
  prefix + path
}

///|
fn portable_output_link(prefix : String, path : String?) -> String? raise {
  path.map(path => portable_output_member(prefix, path))
}

///|
async fn agent_collect_outputs(
  root : String,
  selections : Array[PortableOutputSelection],
  files : Array[AgentBundleFile],
) -> Unit {
  if selections.is_empty() {
    return
  }
  let outputs : Array[PortableOutput] = []
  let ids : Map[String, Unit] = Map([])
  for selected in selections {
    let prefix = portable_output_prefix(selected.artifact_id)
    guard !ids.contains(selected.artifact_id) else {
      fail("duplicate output artifact_id")
    }
    ids[selected.artifact_id] = ()
    let members : Array[PortableOutputFile] = []
    for selected_file in selected.files {
      guard selected.included else {
        fail("reference-only output cannot select files")
      }
      let path = portable_output_member(prefix, selected_file.path)
      guard !files.any(file => file.path == path) else {
        fail("duplicate output destination: " + path)
      }
      // Reuse the existing no-symlink component check before the existing
      // collector reads the selected source exactly once.
      agent_check_target(root, selected_file.source_path)
      guard @fsx.exists(@pathx.join(root, selected_file.source_path)) else {
        fail("selected output is missing: " + selected_file.source_path)
      }
      let collected : Array[AgentBundleFile] = []
      let excluded : Array[AgentBundleExclusion] = []
      agent_collect_file(root, selected_file.source_path, collected, excluded)
      guard collected.get(0) is Some(file) else {
        fail(
          "selected output excluded: " +
          selected_file.source_path +
          "; " +
          excluded.map(item => item.reason).join("; "),
        )
      }
      let member = { ..file, path, role: "artifact", }
      files.push(member)
      members.push({
        path,
        size_bytes: member.size_bytes,
        digest: member.digest,
      })
    }
    members.sort_by((a, b) => a.path.compare(b.path))
    outputs.push({
      artifact_id: selected.artifact_id,
      label: selected.label,
      mime_type: selected.mime_type,
      included: selected.included,
      files: members,
      reference: selected.reference,
      declared_digest: selected.declared_digest,
      preview_path: portable_output_link(prefix, selected.preview_path),
      app_entrypoint: portable_output_link(prefix, selected.app_entrypoint),
    })
  }
  outputs.sort_by((a, b) => a.artifact_id.compare(b.artifact_id))
  let manifest : PortableOutputsManifest = {
    contract: "moonbook.portable_outputs.v1",
    outputs,
  }
  let content = @utf8.encode(manifest.to_json().stringify(indent=2) + "\n")
  guard content.length() <= AgentBundleMaxFileBytes else {
    fail("output manifest exceeds portable-agent size policy")
  }
  files.push({
    path: portable_outputs_manifest_path(),
    role: "artifact",
    encoding: "base64",
    digest: agent_sha256_bytes(content),
    size_bytes: content.length(),
    review_status: "accepted",
    sensitivity: "book-exportable",
    content: @base64.encode(content, padding=true),
  })
  portable_manifest_from_files(files) |> ignore
}

///|
fn portable_manifest_from_files(
  files : Array[AgentBundleFile],
) -> PortableOutputsManifest? raise {
  let manifests = files.filter(file => {
    file.path == portable_outputs_manifest_path()
  })
  if manifests.is_empty() {
    guard !files.any(file => file.path.has_prefix("portable/outputs/")) else {
      fail("portable outputs require their manifest")
    }
    return None
  }
  guard manifests.length() == 1 else { fail("duplicate output manifest") }
  let manifest : PortableOutputsManifest = @json.from_json(
    @json.parse(
      @utf8.decode(
        @base64.decode(manifests[0].content, ignore_whitespace=false),
      ),
    ),
  )
  guard manifest.contract == "moonbook.portable_outputs.v1" else {
    fail("unsupported output manifest")
  }
  let ids : Map[String, Unit] = Map([])
  let seen : Map[String, Unit] = Map([])
  let mut previous_id = ""
  for output in manifest.outputs {
    let prefix = portable_output_prefix(output.artifact_id)
    guard !ids.contains(output.artifact_id) &&
      previous_id.compare(output.artifact_id) < 0 else {
      fail("output IDs must be unique and sorted")
    }
    ids[output.artifact_id] = ()
    previous_id = output.artifact_id
    guard output.label.trim() != "" &&
      output.mime_type.contains("/") &&
      output.mime_type.trim() == output.mime_type else {
      fail("output label and declared MIME type required")
    }
    if !output.included {
      guard output.files.is_empty() &&
        output.preview_path is None &&
        output.app_entrypoint is None &&
        output.reference is Some(ref) &&
        ref.trim() != "" else {
        fail("reference-only output must have only a reference")
      }
      if output.declared_digest is Some(digest) &&
        !@wiki.executable_source_digest_is_valid(digest) {
        fail("invalid declared reference digest")
      }
      continue
    }
    guard !output.files.is_empty() &&
      output.reference is None &&
      output.declared_digest is None else {
      fail("included output must contain actual members only")
    }
    let mut previous_path = ""
    for member in output.files {
      guard member.path.has_prefix(prefix) &&
        agent_relative_path_safe(member.path) &&
        !seen.contains(member.path) &&
        previous_path.compare(member.path) < 0 else {
        fail("invalid or duplicate output member")
      }
      seen[member.path] = ()
      previous_path = member.path
      guard files.iter().find_first(file => file.path == member.path)
        is Some(file) else {
        fail("manifest output member is missing: " + member.path)
      }
      guard file.role == "artifact" &&
        file.size_bytes <= AgentBundleMaxFileBytes &&
        file.size_bytes == member.size_bytes &&
        file.digest == member.digest else {
        fail("output manifest does not match member: " + member.path)
      }
    }
    for link in [output.preview_path, output.app_entrypoint] {
      if link is Some(path) && !output.files.any(file => file.path == path) {
        fail("output preview or app entrypoint is not included")
      }
    }
  }
  guard files
    .filter(file => file.path.has_prefix("portable/outputs/"))
    .all(file => seen.contains(file.path)) else {
    fail("output bytes absent from manifest")
  }
  Some(manifest)
}
