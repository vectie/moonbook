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
fn sha256_bytes(value : Bytes) -> String {
  "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(value))
}

///|
async fn artifact_set_digest(
  root : String,
  artifacts : Array[String],
) -> String {
  let identities : Array[String] = []
  for reference in artifacts {
    let content = @fsx.read_bytes(workspace_path(root, reference))
    identities.push(reference + "|" + sha256_bytes(content))
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
fn primary_input_artifact(
  inputs : Array[String],
  operation_label : String,
) -> String raise {
  guard inputs is [primary, ..] else {
    fail("MoonFlow \{operation_label} requires a typed primary input artifact")
  }
  if !safe_relative(primary) {
    fail(
      "MoonFlow \{operation_label} primary input artifact must be workspace-relative",
    )
  }
  primary
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
async fn run_outcome_closure_direct(args : Array[String]) -> Unit {
  let root = option(args, "--workspace")
  let request_path = workspace_path(root, option(args, "--closure-request"))
  let request : @bookkeeper_store.ProductOutcomeClosureRequest = @json.from_json(
    read_json(request_path),
  )
  let receipt = @bookkeeper_store.close_product_outcome(root, request)
  println(receipt.to_json().stringify(indent=2))
}

///|
async fn run_outcome_submission_direct(args : Array[String]) -> Unit {
  let root = option(args, "--workspace")
  let request_path = workspace_path(root, option(args, "--submission"))
  let submission : @bookkeeper_store.ProductOutcomeSubmission = @json.from_json(
    read_json(request_path),
  )
  let receipt = @bookkeeper_store.submit_product_outcome(root, submission)
  println(receipt.to_json().stringify(indent=2))
}

///|
async fn run_requirements_prepare_direct(args : Array[String]) -> Unit {
  let root = option(args, "--workspace")
  let request_path = workspace_path(
    root,
    option(args, "--requirements-request"),
  )
  let output_path = workspace_path(root, option(args, "--output"))
  let request : @wiki.RequirementsPrepareRequest = @json.from_json(
    read_json(request_path),
  )
  let packet = @wiki.prepare_requirements(request)
  write_idempotent_json(output_path, packet.to_json())
  println(packet.to_json().stringify(indent=2))
}

///|
async fn run_requirements_reconcile_direct(args : Array[String]) -> Unit {
  let root = option(args, "--workspace")
  let request : @wiki.RequirementsPrepareRequest = @json.from_json(
    read_json(workspace_path(root, option(args, "--requirements-request"))),
  )
  let packet : @wiki.RequirementsPacket = @json.from_json(
    read_json(workspace_path(root, option(args, "--packet"))),
  )
  let reconciliation = @wiki.reconcile_requirements_packet(request, packet)
  println(reconciliation.to_json().stringify(indent=2))
  if !reconciliation.exact_match {
    fail("MoonBook requirements packet reconciliation failed")
  }
}

///|
async fn run_draft_delivery_unattended(args : Array[String]) -> Unit {
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
  let primary_input = primary_input_artifact(inputs, "draft delivery")
  let actual_input_digest = artifact_set_digest(root, inputs)
  if actual_input_digest != json_string(fields, "input_digest") {
    fail("MoonFlow input artifact digest changed")
  }
  let delivery_request : @bookkeeper_store.MoonCodeDraftDeliveryRequest = @json.from_json(
    read_json(workspace_path(root, primary_input)),
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
async fn run_outcome_closure_unattended(args : Array[String]) -> Unit {
  let root = option(args, "--workspace")
  let moonflow_request_ref = option(args, "--request")
  let result_ref = option(args, "--result")
  let output_ref = option(args, "--output")
  let request_json = read_json(workspace_path(root, moonflow_request_ref))
  guard request_json is Object(fields) else {
    fail("MoonFlow adapter request must be an object")
  }
  let operation = json_string(fields, "operation")
  if json_string(fields, "product_id") != "moonbook" ||
    !(operation == @moonbook.moonbook_outcome_closure_operation_id() ||
    operation == @moonbook.moonbook_outcome_closure_operation_ref()) ||
    json_string(fields, "requested_authority") != "workspace-mutation" {
    fail("MoonFlow request targets the wrong product, operation, or authority")
  }
  let input_contracts = json_strings(fields, "input_contracts")
  let output_contracts = json_strings(fields, "output_contracts")
  if input_contracts != ["moonbook/bookkeeper-product-outcome-closure@1.0.0"] ||
    output_contracts !=
    ["moonbook/bookkeeper-product-outcome-closure-receipt@1.0.0"] {
    fail("MoonFlow request omits the exact outcome-closure contracts")
  }
  let inputs = json_strings(fields, "input_artifacts")
  let primary_input = primary_input_artifact(inputs, "outcome closure")
  if artifact_set_digest(root, inputs) != json_string(fields, "input_digest") {
    fail("MoonFlow outcome-closure input artifact digest changed")
  }
  let closure_request : @bookkeeper_store.ProductOutcomeClosureRequest = @json.from_json(
    read_json(workspace_path(root, primary_input)),
  )
  let receipt = @bookkeeper_store.close_product_outcome(root, closure_request)
  write_idempotent_json(workspace_path(root, output_ref), receipt.to_json())
  let output_digest = artifact_set_digest(root, [output_ref])
  let result : Json = {
    "result_id": "result-" + json_string(fields, "request_id"),
    "request_id": json_string(fields, "request_id"),
    "attempt_id": json_string(fields, "attempt_id"),
    "idempotency_key": json_string(fields, "idempotency_key"),
    "product_id": "moonbook",
    "external_job_id": receipt.request.record_id,
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
async fn run_outcome_submission_unattended(args : Array[String]) -> Unit {
  let root = option(args, "--workspace")
  let request_ref = option(args, "--request")
  let result_ref = option(args, "--result")
  let output_ref = option(args, "--output")
  let request_json = read_json(workspace_path(root, request_ref))
  guard request_json is Object(fields) else {
    fail("MoonFlow adapter request must be an object")
  }
  let operation = json_string(fields, "operation")
  if json_string(fields, "product_id") != "moonbook" ||
    !(operation == @moonbook.moonbook_outcome_submission_operation_id() ||
    operation == @moonbook.moonbook_outcome_submission_operation_ref()) ||
    json_string(fields, "requested_authority") != "workspace-mutation" {
    fail("MoonFlow request targets the wrong product, operation, or authority")
  }
  if json_strings(fields, "input_contracts") !=
    ["moonbook/bookkeeper-product-outcome-submission@1.0.0"] ||
    json_strings(fields, "output_contracts") !=
    ["moonbook/bookkeeper-product-outcome-submission-receipt@1.0.0"] {
    fail("MoonFlow request omits the exact outcome-submission contracts")
  }
  let inputs = json_strings(fields, "input_artifacts")
  let primary_input = primary_input_artifact(inputs, "outcome submission")
  if artifact_set_digest(root, inputs) != json_string(fields, "input_digest") {
    fail("MoonFlow outcome-submission input artifact digest changed")
  }
  let submission : @bookkeeper_store.ProductOutcomeSubmission = @json.from_json(
    read_json(workspace_path(root, primary_input)),
  )
  let receipt = @bookkeeper_store.submit_product_outcome(root, submission)
  write_idempotent_json(workspace_path(root, output_ref), receipt.to_json())
  let output_digest = artifact_set_digest(root, [output_ref])
  let pending = receipt.pending_human_gate
  let result : Json = {
    "result_id": "result-" + json_string(fields, "request_id"),
    "request_id": json_string(fields, "request_id"),
    "attempt_id": json_string(fields, "attempt_id"),
    "idempotency_key": json_string(fields, "idempotency_key"),
    "product_id": "moonbook",
    "external_job_id": receipt.submission.record_id,
    "status": "Succeeded",
    "output_digest": output_digest,
    "output_artifacts": [output_ref],
    "error_kind": "",
    "compensable": false,
    "recorded_at": json_string(fields, "created_at"),
    "review_status": receipt.state,
    "pending_human_gate": pending,
  }
  write_idempotent_json(workspace_path(root, result_ref), result)
  println(result.stringify(indent=2))
}

///|
async fn run_requirements_prepare_unattended(args : Array[String]) -> Unit {
  let root = option(args, "--workspace")
  let moonflow_request_ref = option(args, "--request")
  let result_ref = option(args, "--result")
  let output_ref = option(args, "--output")
  let request_json = read_json(workspace_path(root, moonflow_request_ref))
  guard request_json is Object(fields) else {
    fail("MoonFlow adapter request must be an object")
  }
  let operation = json_string(fields, "operation")
  if json_string(fields, "product_id") != "moonbook" ||
    !(operation == @moonbook.moonbook_requirements_prepare_operation_id() ||
    operation == @moonbook.moonbook_requirements_prepare_operation_ref()) ||
    json_string(fields, "requested_authority") != "workspace-mutation" {
    fail("MoonFlow request targets the wrong product, operation, or authority")
  }
  let input_contracts = json_strings(fields, "input_contracts")
  let output_contracts = json_strings(fields, "output_contracts")
  if input_contracts != ["moonbook/wiki-requirements-prepare@1.0.0"] ||
    output_contracts != ["moonbook/wiki-requirements-packet@1.0.0"] {
    fail("MoonFlow request omits the exact requirements contracts")
  }
  let inputs = json_strings(fields, "input_artifacts")
  let primary_input = primary_input_artifact(inputs, "requirements preparation")
  if artifact_set_digest(root, inputs) != json_string(fields, "input_digest") {
    fail("MoonFlow requirements input artifact digest changed")
  }
  let request : @wiki.RequirementsPrepareRequest = @json.from_json(
    read_json(workspace_path(root, primary_input)),
  )
  let packet = @wiki.prepare_requirements(request)
  let reconciliation = @wiki.reconcile_requirements_packet(request, packet)
  if !reconciliation.exact_match {
    fail("MoonBook produced a non-reconciling requirements packet")
  }
  write_idempotent_json(workspace_path(root, output_ref), packet.to_json())
  let output_digest = artifact_set_digest(root, [output_ref])
  let result : Json = {
    "result_id": "result-" + json_string(fields, "request_id"),
    "request_id": json_string(fields, "request_id"),
    "attempt_id": json_string(fields, "attempt_id"),
    "idempotency_key": json_string(fields, "idempotency_key"),
    "product_id": "moonbook",
    "external_job_id": packet.packet.record_id,
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
async fn run_unattended(args : Array[String]) -> Unit {
  let root = option(args, "--workspace")
  let request_json = read_json(workspace_path(root, option(args, "--request")))
  guard request_json is Object(fields) else {
    fail("MoonFlow adapter request must be an object")
  }
  let operation = json_string(fields, "operation")
  if operation == @moonbook.moonbook_outcome_closure_operation_id() ||
    operation == @moonbook.moonbook_outcome_closure_operation_ref() {
    run_outcome_closure_unattended(args)
  } else if operation == @moonbook.moonbook_outcome_submission_operation_id() ||
    operation == @moonbook.moonbook_outcome_submission_operation_ref() {
    run_outcome_submission_unattended(args)
  } else if operation == @moonbook.moonbook_requirements_prepare_operation_id() ||
    operation == @moonbook.moonbook_requirements_prepare_operation_ref() {
    run_requirements_prepare_unattended(args)
  } else {
    run_draft_delivery_unattended(args)
  }
}

///|
async fn main {
  let args = @env.args()[1:].to_owned()
  try {
    match args {
      ["deliver-reviewed-draft", .. rest] => run_direct(rest.to_owned())
      ["close-product-outcome", .. rest] =>
        run_outcome_closure_direct(rest.to_owned())
      ["submit-product-outcome", .. rest] =>
        run_outcome_submission_direct(rest.to_owned())
      ["prepare-requirements", .. rest] =>
        run_requirements_prepare_direct(rest.to_owned())
      ["reconcile-requirements", .. rest] =>
        run_requirements_reconcile_direct(rest.to_owned())
      ["unattended", .. rest] => run_unattended(rest.to_owned())
      [] | ["capabilities"] =>
        println(
          @moonbook.moonbook_moonflow_adapter_declaration_json().stringify(
            indent=2,
          ),
        )
      _ =>
        fail(
          "usage: moonflow_adapter [capabilities | prepare-requirements ... | reconcile-requirements ... | submit-product-outcome ... | close-product-outcome ... | deliver-reviewed-draft ... | unattended ...]",
        )
    }
  } catch {
    error => {
      println(({ "accepted": false, "error": "\{error}" } : Json).stringify())
      @sys.exit(1)
    }
  }
}
