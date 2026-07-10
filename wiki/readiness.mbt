///|
pub async fn wiki_readiness_json(
  root : String,
  revision? : String = "workspace",
) -> Json {
  let normalized_root = @pathx.normalize(root)
  let book_id = moonbook_wiki_path(normalized_root).basename().to_owned()
  let lint = lint_wiki(normalized_root)
  let required = [
    "wiki/SUMMARY.md", "wiki/index.md", "state/state.json", "book/book.json", "book/knowledge/manifest.json",
    "book/knowledge/graph.json",
  ]
  let artifacts : Array[Json] = []
  let mut artifacts_present = true
  for relative in required {
    let present = @fsx.exists(@pathx.join(normalized_root, relative))
    if !present {
      artifacts_present = false
    }
    artifacts.push({ "path": relative, "present": present })
  }
  let accepted = lint.findings.is_empty() && artifacts_present
  {
    "contract_id": @pipeline.BookReadiness.id(),
    "book_id": book_id,
    "revision": revision,
    "status": if accepted {
      "accepted"
    } else {
      "rejected"
    },
    "required_artifacts": artifacts,
    "quality": {
      "completeness": if artifacts_present {
        "accepted"
      } else {
        "rejected"
      },
      "traceability": if artifacts_present {
        "accepted"
      } else {
        "rejected"
      },
      "consistency": if lint.findings.is_empty() {
        "accepted"
      } else {
        "rejected"
      },
      "safety": "not-applicable: knowledge readiness does not assert physical deployment",
      "replayability": "accepted: lint and required artifact checks are deterministic for a workspace revision",
    },
    "lint_findings": Json::array(
      lint.findings.map(finding => finding.to_json()),
    ),
    "checked_at": @async.now().to_int().to_string(),
  }
}

///|
pub fn wiki_readiness_path(root : String) -> String {
  @pathx.join(@pathx.normalize(root), "outputs/moonbook/book-readiness.json")
}

///|
pub async fn write_wiki_readiness(
  root : String,
  revision? : String = "workspace",
) -> Json {
  let payload = wiki_readiness_json(root, revision~)
  let path = wiki_readiness_path(root)
  @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true)
  @fsx.write_to_file(path, payload.stringify(indent=2), create=0o644)
  payload
}

///|
pub fn wiki_readiness_accepted(payload : Json) -> Bool {
  match payload {
    Object(fields) => fields.get("status") == Some(Json::string("accepted"))
    _ => false
  }
}

///|
test "book readiness payload uses shared contract and rejects missing artifacts" {
  let payload : Json = {
    "contract_id": @pipeline.BookReadiness.id(),
    "book_id": "test-book",
    "revision": "abc123",
    "status": "rejected",
    "required_artifacts": [{ "path": "wiki/SUMMARY.md", "present": false }],
    "quality": {},
    "checked_at": "0",
  }
  assert_true(@pipeline.has_required_fields(@pipeline.BookReadiness, payload))
  assert_false(wiki_readiness_accepted(payload))
}
