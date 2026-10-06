///|
/// These opt-in tests consume files emitted by the real Proj export handler and
/// Desk import/prepare path. They deliberately do not manufacture either wire.
fn human_result_digest(bytes : Bytes) -> String {
  "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
fn human_result_content(source : Bytes) -> Bytes raise {
  guard @json.parse(@utf8.decode(source))
    is {
      "contract_version": "moonproj.accepted-human-result.v1",
      "source_product": "moonproj",
      "provenance_scope": "captured_accepted_human_revision",
      "authenticity": "unsigned_source_observation",
      "authorizing": false,
      "content": {
        "encoding": "base64",
        "media_type": "text/plain;charset=utf-8",
        "size_bytes": Number(size),
        "sha256": String(digest),
        "data": String(data),
        ..
      },
      ..
    } else {
    fail("expected actual Proj accepted human result export")
  }
  let content = @base64.decode(data, ignore_whitespace=false)
  assert_eq(content.length().to_double(), size)
  assert_eq(human_result_digest(content), digest)
  assert_true(content.length() <= 256 * 1024)
  // Decoding and encoding prove valid UTF-8 without replacing source JSON bytes.
  assert_eq(@utf8.encode(@utf8.decode(content)), content)
  content
}

///|
async fn human_result_member_proofs(
  package : String,
  target : String,
) -> Array[Json] {
  assert_true(@agent.verify_portable_import_members(package, target).is_empty())
  let bundle = @agent.read_agent_bundle(package)
  let proofs : Array[Json] = []
  for file in bundle.files {
    let expected = @base64.decode(file.content, ignore_whitespace=false)
    let actual = @fsx.read_bytes(target + "/" + file.path)
    assert_eq(actual, expected)
    assert_eq(human_result_digest(actual), file.digest)
    proofs.push({
      "path": file.path,
      "sha256": file.digest,
      "size_bytes": actual.length(),
      "bytes_identical": true,
    })
  }
  proofs
}

///|
async test "accepted human result paired producer selection packs and roundtrips actual source bytes" {
  guard @env.get_env_var("MOONBOOK_HUMAN_RESULT_FIXTURE_MODE") is Some("export") else {
    return
  }
  let dir = @env.get_env_var("MOONBOOK_HUMAN_RESULT_FIXTURE_DIR").unwrap()
  let desk = @env.get_env_var("MOONBOOK_HUMAN_RESULT_DESK_FIXTURES").unwrap()
  let proj = @env.get_env_var("MOONBOOK_HUMAN_RESULT_PROJ_FIXTURES").unwrap()
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let results : Array[Json] = []
  let artifact_ids : Array[String] = []
  for name in ["unicode", "empty", "max", "unicode-v2"] {
    let root = desk + "/" + name + "/book"
    let source_bytes = @fsx.read_bytes(proj + "/" + name + ".json")
    let content_bytes = human_result_content(source_bytes)
    if name == "empty" {
      assert_eq(content_bytes.length(), 0)
    }
    if name == "max" {
      assert_eq(content_bytes.length(), 256 * 1024)
    }
    let selection_path = desk + "/" + name + "/outputs-selection.json"
    let outputs : Array[@agent.PortableOutputSelection] = @json.from_json(
      @json.parse(@fsx.read_file(selection_path)),
    )
    assert_eq(outputs.length(), 1)
    let selected = outputs[0]
    artifact_ids.push(selected.artifact_id)
    assert_true(selected.included)
    assert_eq(selected.files.length(), 2)
    for member in selected.files {
      let expected = match member.path {
        "source.json" => source_bytes
        "content.txt" => content_bytes
        _ => fail("unexpected Desk selected member: " + member.path)
      }
      assert_eq(@fsx.read_bytes(root + "/" + member.source_path), expected)
    }
    // Desk stages inside a selected Book. The isolated fixture supplies only
    // that Book's normal metadata; its emitted output selection is unchanged.
    @wiki.init_workspace(root) |> ignore
    let package_name = match name {
      "unicode" => "sender-v1.moonbook-agent"
      "unicode-v2" => "sender-v2.moonbook-agent"
      _ => name + ".moonbook-agent"
    }
    let package = @agent.pack_agent(
      root,
      version="accepted-human-result-" + name,
      output=dir + "/" + package_name,
      outputs~,
    )
    let source = @agent.describe_portable_source(package)
    assert_eq(source.included_output_count, 1)
    assert_eq(source.reference_only_count, 0)
    let source_path = match name {
      "unicode" => dir + "/source.json"
      "unicode-v2" => dir + "/source-v2.json"
      _ => dir + "/" + name + "-source.json"
    }
    @fsx.write_to_file(
      source_path,
      source.to_json().stringify(indent=2) + "\n",
      create=0o644,
    )
    // This is an explicitly labelled synthetic expectation for the Book-only
    // test. A separate phase consumes the binding actually emitted by Town.
    let expectation_path = dir + "/" + name + "-synthetic-expectation.json"
    @fsx.write_to_file(
      expectation_path,
      portable_test_binding(source).to_json().stringify(indent=2) + "\n",
      create=0o644,
    )
    let target = dir + "/book-only-recipients/" + name + " renamed 学习结果"
    let receipt = @agent.import_agent_bundle_exact(
      package, target, expectation_path,
    )
    assert_true(receipt.member_bytes_verified)
    assert_eq(receipt.status, "complete")
    assert_eq(receipt.source, source)
    assert_true(receipt.local_book_id != source.agent_id)
    let prefix = "portable/outputs/" + selected.artifact_id + "/"
    assert_eq(
      @fsx.read_bytes(target + "/" + prefix + "source.json"),
      source_bytes,
    )
    assert_eq(
      @fsx.read_bytes(target + "/" + prefix + "content.txt"),
      content_bytes,
    )
    let proofs = human_result_member_proofs(package, target)
    let bundle = @agent.read_agent_bundle(package)
    assert_eq(
      bundle.files.filter(file => file.path.has_prefix(prefix)).length(),
      2,
    )
    assert_true(
      bundle.files
      .filter(file => file.path.has_prefix(prefix))
      .all(file => file.role == "artifact"),
    )
    if name == "unicode" {
      // Mutable paths must not revise an already exported package. Replace
      // only these synthetic staged inputs, verify v1, then restore them.
      let later_source = @fsx.read_bytes(proj + "/unicode-v2.json")
      let later_content = human_result_content(later_source)
      for member in selected.files {
        @fsx.write_bytes(
          root + "/" + member.source_path,
          if member.path == "source.json" {
            later_source
          } else {
            later_content
          },
        )
      }
      assert_eq(@agent.describe_portable_source(package), source)
      assert_eq(
        @fsx.read_bytes(target + "/" + prefix + "source.json"),
        source_bytes,
      )
      assert_true(
        @agent.verify_portable_import_members(package, target).is_empty(),
      )
      for member in selected.files {
        @fsx.write_bytes(
          root + "/" + member.source_path,
          if member.path == "source.json" {
            source_bytes
          } else {
            content_bytes
          },
        )
      }
      for member in selected.files {
        assert_eq(
          @fsx.read_bytes(root + "/" + member.source_path),
          if member.path == "source.json" {
            source_bytes
          } else {
            content_bytes
          },
        )
      }
    }
    results.push({
      "case": name,
      "proj_source": proj + "/" + name + ".json",
      "source_sha256": human_result_digest(source_bytes),
      "source_size_bytes": source_bytes.length(),
      "content_sha256": human_result_digest(content_bytes),
      "content_size_bytes": content_bytes.length(),
      "desk_selection": selection_path,
      "desk_selection_sha256": human_result_digest(
        @fsx.read_bytes(selection_path),
      ),
      "artifact_id": selected.artifact_id,
      "package": package,
      "source": source,
      "book_only_expectation_scope": "synthetic_offline_expectation_not_town_authorization",
      "receipt": receipt,
      "member_proofs": proofs,
    })
  }
  let v1 = @agent.describe_portable_source(dir + "/sender-v1.moonbook-agent")
  let saved_v1 : @agent.PortableSource = @json.from_json(
    @json.parse(@fsx.read_file(dir + "/source.json")),
  )
  assert_eq(v1, saved_v1)
  let v2 = @agent.describe_portable_source(dir + "/sender-v2.moonbook-agent")
  assert_true(v1.package_sha256 != v2.package_sha256)
  assert_true(v1.bundle_digest != v2.bundle_digest)
  assert_true(artifact_ids[0] != artifact_ids[3])
  @fsx.write_to_file(
    dir + "/paired-export-proof.json",
    (
      {
        "contract": "moonbook.accepted_human_result_paired_proof.v1",
        "source": "actual_proj_handler_exports",
        "selection": "actual_desk_import_and_prepare_output",
        "pack_and_import": "real_book_agent_apis",
        "desk_native_pack_subprocess_exercised": false,
        "town_transferred_package_bytes": false,
        "v1_unchanged_after_v2_package": true,
        "v1_unchanged_after_staged_source_paths_change": true,
        "staged_source_paths_restored": true,
        "source_authenticity": "unsigned_source_observation",
        "authorizing": false,
        "review_promotion": false,
        "cases": results,
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
}

///|
async test "accepted human result Town bound import survives copy rename and rejects package tamper" {
  guard @env.get_env_var("MOONBOOK_HUMAN_RESULT_FIXTURE_MODE") is Some("import") else {
    return
  }
  let dir = @env.get_env_var("MOONBOOK_HUMAN_RESULT_FIXTURE_DIR").unwrap()
  let binding_path = dir + "/town-binding.json"
  let binding : @agent.PortableTownBinding = @json.from_json(
    @json.parse(@fsx.read_file(binding_path)),
  )
  let original = dir + "/sender-v1.moonbook-agent"
  let original_bytes = @fsx.read_bytes(original)
  let town_download = @env.get_env_var(
    "MOONBOOK_HUMAN_RESULT_TOWN_DOWNLOADED_PACKAGE",
  )
  let input = town_download.unwrap_or(original)
  let input_bytes = @fsx.read_bytes(input)
  assert_eq(input_bytes, original_bytes)
  let inbox = dir + "/recipient-inbox"
  @fsx.make_directory(inbox, recursive=true, exists_ok=true)
  let renamed = inbox + "/different filename 学习结果.moonbook-agent"
  @fsx.write_bytes(renamed, input_bytes, create=0o644)
  let copied_source = @agent.verify_agent_bundle_against_source(
    renamed,
    binding.source,
  )
  assert_true(copied_source.package_filename != binding.source.package_filename)
  assert_eq(copied_source.package_sha256, binding.source.package_sha256)
  assert_eq(@fsx.read_bytes(renamed), original_bytes)
  let rejected_v2 = dir + "/recipient-books/rejected-v2"
  let v2_error = try
    @agent.import_agent_bundle_exact(
      dir + "/sender-v2.moonbook-agent",
      rejected_v2,
      binding_path,
    )
  catch {
    error => "\{error}"
  } noraise {
    _ => fail("newer package must not satisfy retained v1 expectation")
  }
  assert_false(@fsx.exists(rejected_v2))
  let target = dir + "/recipient-books/new local name 学习结果"
  let receipt = @agent.import_agent_bundle_exact(renamed, target, binding_path)
  assert_eq(receipt.source, binding.source)
  assert_true(receipt.local_book_id != receipt.source.agent_id)
  let proofs = human_result_member_proofs(renamed, target)
  let bundle = @agent.read_agent_bundle(renamed)
  guard bundle.files
    .iter()
    .find_first(file => file.path.has_suffix("/content.txt"))
    is Some(content) else {
    fail("missing accepted human content output")
  }
  // Recheck current members rather than trusting the earlier import receipt.
  @fsx.write_bytes(target + "/" + content.path, b"changed after import")
  assert_eq(@agent.verify_portable_import_members(renamed, target), [
    content.path,
  ])
  @fsx.write_bytes(
    target + "/" + content.path,
    @base64.decode(content.content, ignore_whitespace=false),
  )
  assert_true(@agent.verify_portable_import_members(renamed, target).is_empty())
  let tampered_value = @json.parse(@utf8.decode(original_bytes))
  guard tampered_value is Object(fields) &&
    fields.get("files") is Some(Array(files)) else {
    fail("malformed original package")
  }
  let mut changed = false
  for file in files {
    if file is Object(member) &&
      member.get("path") is Some(String(path)) &&
      path == content.path {
      member["content"] = @base64.encode(b"tampered payload", padding=true).to_json()
      changed = true
    }
  }
  assert_true(changed)
  let tampered = inbox + "/tampered.moonbook-agent"
  @fsx.write_to_file(
    tampered,
    tampered_value.stringify(indent=2) + "\n",
    create=0o644,
  )
  assert_false(@agent.verify_agent_bundle(tampered).ok)
  let rejected_tamper = dir + "/recipient-books/rejected-tamper"
  let tamper_error = try
    @agent.import_agent_bundle_exact(tampered, rejected_tamper, binding_path)
  catch {
    error => "\{error}"
  } noraise {
    _ => fail("tampered package must fail before import")
  }
  assert_false(@fsx.exists(rejected_tamper))
  assert_eq(@fsx.read_bytes(original), original_bytes)
  @fsx.write_to_file(
    dir + "/town-bound-roundtrip-proof.json",
    (
      {
        "contract": "moonbook.accepted_human_result_town_roundtrip.v1",
        "binding": "actual_town_fixture_output",
        "transfer": if town_download is Some(_) {
          "town_production_handler_private_store_real_client_sink_then_local_copy"
        } else {
          "explicit_local_file_copy"
        },
        "town_transferred_package_bytes": town_download is Some(_),
        "town_download_path": town_download,
        "copy_rename_preserves_exact_package_bytes": true,
        "source": binding.source,
        "receipt": receipt,
        "member_proofs": proofs,
        "v2_rejected_before_target_creation": true,
        "v2_rejection": v2_error,
        "tamper_rejected_before_target_creation": true,
        "tamper_rejection": tamper_error,
        "current_member_drift_detected_and_restored": true,
        "source_authenticity": "unsigned_source_observation",
        "authorizing": false,
        "review_promotion": false,
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
}
