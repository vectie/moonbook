///|
fn option(
  args : Array[String],
  name : String,
  required? : Bool = true,
) -> String raise {
  for index in 0..<(args.length() - 1) {
    if args[index] == name {
      return args[index + 1]
    }
  }
  if required {
    fail("MoonBook MoonFlow adapter requires " + name)
  }
  ""
}

///|
fn option_or(
  args : Array[String],
  name : String,
  fallback : String,
) -> String raise {
  let value = option(args, name, required=false)
  if value.is_blank() {
    fallback
  } else {
    value
  }
}

///|
fn safe_relative(reference : String) -> Bool {
  let normalized = reference.trim().replace(old="\\", new="/")
  !normalized.is_blank() &&
  !normalized.has_prefix("/") &&
  !normalized.split("/").any(part => part.is_blank() || part == "..")
}

///|
fn workspace_path(root : String, reference : String) -> String raise {
  if !safe_relative(reference) {
    fail("MoonBook MoonFlow adapter requires a workspace-relative path")
  }
  @pathx.join(@pathx.normalize(root), reference)
}

///|
async fn read_json(path : String) -> Json {
  @json.parse(@fsx.read_file(path))
}

///|
async fn write_idempotent_json(path : String, value : Json) -> Unit {
  let text = value.stringify(indent=2) + "\n"
  if @fsx.exists(path) {
    if @fsx.read_file(path) != text {
      fail("MoonBook MoonFlow adapter output identity has conflicting content")
    }
    return
  }
  @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true)
  @fsx.write_to_file(path, text, create=0o600)
}

///|
fn sha256_text(value : String) -> String {
  "sha256:" +
  @crypto.bytes_to_hex_string(@crypto.sha256(@encoding/utf8.encode(value)))
}

///|
async fn artifact_set_digest(
  root : String,
  artifacts : Array[String],
) -> String {
  let identities : Array[String] = []
  for reference in artifacts {
    let content = @fsx.read_file(workspace_path(root, reference))
    identities.push(reference + "|" + sha256_text(content))
  }
  sha256_text(identities.join("\n"))
}

///|
fn json_string(fields : Map[String, Json], key : String) -> String raise {
  match fields.get(key) {
    Some(String(value)) if !value.is_blank() => value
    _ => fail("MoonBook MoonFlow request requires " + key)
  }
}

///|
fn json_strings(
  fields : Map[String, Json],
  key : String,
) -> Array[String] raise {
  match fields.get(key) {
    Some(Array(items)) =>
      items.map(item => {
        match item {
          String(value) if !value.is_blank() => value
          _ => fail("MoonBook MoonFlow request requires string " + key)
        }
      })
    _ => fail("MoonBook MoonFlow request requires " + key)
  }
}

///|
async fn import_moonclaw_draft(
  root : String,
  request : @bookkeeper_store.MoonCodeDraftDeliveryRequest,
  moonclaw_root : String,
  home : String,
  cwd : String,
) -> @bookkeeper_store.MoonCodeDraftImportReceipt {
  let plan = match
    @bookkeeper_store.prepare_mooncode_draft_delivery(root, request) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  match plan.existing_receipt {
    Some(receipt) if plan.already_imported => return receipt
    _ => ()
  }
  ignore(@wiki.enable_extension(root, "moonclaw"))
  let args = [
    "-C",
    moonclaw_root,
    "run",
    "cmd/main",
    "--",
    "proposal",
    "import",
    plan.packet_path,
    "--json",
    "--cwd",
    cwd,
    ..if home.is_blank() {
      []
    } else {
      ["--home", home]
    },
  ]
  // `--confirm` and `--inline` are deliberately impossible to add through the
  // adapter contract. A successful response must still prove Draft status.
  let (code, stdout, stderr) = @process.collect_output("moon", args, cwd=root)
  if code != 0 {
    fail(
      "MoonClaw draft import failed with code \{code}: " +
      stderr.text().to_string(),
    )
  }
  let output = @json.parse(stdout.text().trim()) catch {
    error => fail("MoonClaw draft import returned invalid JSON: \{error}")
  }
  match @bookkeeper_store.complete_mooncode_draft_delivery(root, plan, output) {
    Ok(receipt) => receipt
    Err(error) => fail(error)
  }
}

///|
async fn run_direct(args : Array[String]) -> Unit {
  let root = option(args, "--workspace")
  let request_path = workspace_path(root, option(args, "--delivery-request"))
  let request : @bookkeeper_store.MoonCodeDraftDeliveryRequest = @json.from_json(
    read_json(request_path),
  )
  let receipt = import_moonclaw_draft(
    root,
    request,
    option(args, "--moonclaw"),
    option(args, "--home", required=false),
    option_or(args, "--cwd", root),
  )
  println(receipt.to_json().stringify(indent=2))
}

///|
async fn run_unattended(args : Array[String]) -> Unit {
  let root = option(args, "--workspace")
  let moonflow_request_ref = option(args, "--request")
  let result_ref = option(args, "--result")
  let output_ref = option(args, "--output")
  let request_json = read_json(workspace_path(root, moonflow_request_ref))
  guard request_json is Object(fields) else {
    fail("MoonFlow adapter request must be an object")
  }
  if json_string(fields, "product_id") != "moonbook" ||
    json_string(fields, "operation") != "deliver-reviewed-mooncode-draft" ||
    json_string(fields, "requested_authority") != "workspace-mutation" {
    fail("MoonFlow request targets the wrong product, operation, or authority")
  }
  let input_contracts = json_strings(fields, "input_contracts")
  let output_contracts = json_strings(fields, "output_contracts")
  if !input_contracts.contains(
      @bookkeeper_store.mooncode_draft_delivery_contract_version(),
    ) ||
    !output_contracts.contains(
      @bookkeeper_store.mooncode_draft_delivery_contract_version(),
    ) {
    fail("MoonFlow request omits the draft-delivery contracts")
  }
  let inputs = json_strings(fields, "input_artifacts")
  if inputs.length() != 1 {
    fail("MoonFlow draft delivery requires exactly one input artifact")
  }
  let actual_input_digest = artifact_set_digest(root, inputs)
  if actual_input_digest != json_string(fields, "input_digest") {
    fail("MoonFlow input artifact digest changed")
  }
  let delivery_request : @bookkeeper_store.MoonCodeDraftDeliveryRequest = @json.from_json(
    read_json(workspace_path(root, inputs[0])),
  )
  let receipt = import_moonclaw_draft(
    root,
    delivery_request,
    option(args, "--moonclaw"),
    option(args, "--home", required=false),
    option_or(args, "--cwd", root),
  )
  write_idempotent_json(workspace_path(root, output_ref), receipt.to_json())
  let output_digest = artifact_set_digest(root, [output_ref])
  let result : Json = {
    "result_id": "result-" + json_string(fields, "request_id"),
    "request_id": json_string(fields, "request_id"),
    "attempt_id": json_string(fields, "attempt_id"),
    "idempotency_key": json_string(fields, "idempotency_key"),
    "product_id": "moonbook",
    "external_job_id": receipt.moonclaw_proposal_id,
    "status": "Succeeded",
    "output_digest": output_digest,
    "output_artifacts": [output_ref],
    "error_kind": "",
    "compensable": false,
    "recorded_at": json_string(fields, "created_at"),
  }
  write_idempotent_json(workspace_path(root, result_ref), result)
  println(result.stringify(indent=2))
}

///|
async fn main {
  let args = @env.args()[1:].to_owned()
  try {
    match args {
      ["deliver-reviewed-draft", .. rest] => run_direct(rest.to_owned())
      ["unattended", .. rest] => run_unattended(rest.to_owned())
      [] | ["capabilities"] =>
        println(
          @moonbook.moonbook_mooncode_draft_delivery_capability_json().stringify(
            indent=2,
          ),
        )
      _ =>
        fail(
          "usage: moonflow_adapter [capabilities | deliver-reviewed-draft ... | unattended ...]",
        )
    }
  } catch {
    error => {
      println(({ "accepted": false, "error": "\{error}" } : Json).stringify())
      @sys.exit(1)
    }
  }
}
