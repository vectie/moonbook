///|
async fn[T : @json.FromJson] read_json_file(path : String) -> T {
  @json.from_json(@json.parse(@fsx.read_file(path))) catch {
    error => fail("invalid Bookkeeper JSON file \{path}: \{error}")
  }
}

///|
async fn run_bookkeeper(args : Array[String]) -> Unit {
  match args {
    ["reflect", root, observation_path] => {
      let record = @wiki.reflect_bookkeeper_file(root, observation_path) catch {
        error => {
          println("moonbook bookkeeper reflect failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["record-spatial", root, study_path] => {
      let record = @wiki.record_spatial_reference_file(root, study_path) catch {
        error => {
          println("moonbook bookkeeper record-spatial failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["promote", root, reflection_id, review_ref] => {
      let paths = @wiki.promote_bookkeeper_procedures(
        root, reflection_id, review_ref,
      ) catch {
        error => {
          println("moonbook bookkeeper promote failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(paths)
    }
    ["reconcile-flow", root, projection_path, work_item_id, recorded_at] => {
      let record = @wiki.reconcile_flow_projection_file(
        root, projection_path, work_item_id, recorded_at,
      ) catch {
        error => {
          println("moonbook bookkeeper reconcile-flow failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["reconcile-run", root, projection_path, recorded_at] => {
      let record = @wiki.reconcile_flow_run_file(
        root, projection_path, recorded_at,
      ) catch {
        error => {
          println("moonbook bookkeeper reconcile-run failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["propose-revision", root, request_path] => {
      let record = @wiki.write_plan_revision(root, request_path) catch {
        error => {
          println("moonbook bookkeeper propose-revision failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["metacognition", root] => {
      let status = @wiki.metacognition_status_json(root) catch {
        error => {
          println("moonbook bookkeeper metacognition failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(status)
    }
    ["moonclaw", "submit", .. raw] =>
      run_bookkeeper_moonclaw_submit(raw.to_owned())
    ["moonclaw", "ingest-result", root, packet_path, result_path] =>
      run_bookkeeper_moonclaw_ingest_result(root, packet_path, result_path)
    ["mooncode", "project", root, request_path] =>
      run_bookkeeper_work_order_project(root, request_path)
    ["mooncode", "egress", root, request_path] =>
      run_bookkeeper_work_order_egress(root, request_path)
    ["mooncode", "import-draft", .. raw] =>
      run_bookkeeper_mooncode_import_draft(raw.to_owned())
    ["state", root] => run_bookkeeper_state(root)
    ["state"] => run_bookkeeper_state(".")
    ["replay", root] => run_bookkeeper_replay(root)
    ["replay"] => run_bookkeeper_replay(".")
    ["record", root, path] => run_bookkeeper_record(root, path)
    ["record", path] => run_bookkeeper_record(".", path)
    ["review", root, path] => run_bookkeeper_review(root, path)
    ["review", path] => run_bookkeeper_review(".", path)
    ["ingress", root, path] => run_bookkeeper_envelope(root, path, true)
    ["ingress", path] => run_bookkeeper_envelope(".", path, true)
    ["egress", root, path] => run_bookkeeper_envelope(root, path, false)
    ["egress", path] => run_bookkeeper_envelope(".", path, false)
    ["authority", "install", root, path] =>
      run_bookkeeper_authority_install(root, path)
    ["authority", "install", path] =>
      run_bookkeeper_authority_install(".", path)
    _ =>
      println(
        "moonbook bookkeeper usage:\nmoonbook bookkeeper reflect <book-root> <observation.json>\nmoonbook bookkeeper record-spatial <book-root> <study.json>\nmoonbook bookkeeper promote <book-root> <reflection-id> <review-receipt-ref>\nmoonbook bookkeeper reconcile-flow <book-root> <projection.json> <work-item-id> <recorded-at>\nmoonbook bookkeeper reconcile-run <book-root> <projection.json> <recorded-at>\nmoonbook bookkeeper propose-revision <book-root> <request.json>\nmoonbook bookkeeper metacognition <book-root>\nmoonbook bookkeeper moonclaw submit <root> <request.json> [--confirm] [--home <dir>] [--cwd <dir>] [--moonclaw <dir>]\nmoonbook bookkeeper moonclaw ingest-result <root> <packet.json> <moonclaw-result.json>\nmoonbook bookkeeper mooncode project <root> <request.json>\nmoonbook bookkeeper mooncode egress <root> <request.json>\nmoonbook bookkeeper mooncode import-draft <root> <request.json> [--home <dir>] [--cwd <dir>] [--moonclaw <dir>]\nmoonbook bookkeeper state [root]\nmoonbook bookkeeper replay [root]\nmoonbook bookkeeper authority install [root] <grant.json>\nmoonbook bookkeeper record [root] <record.json>\nmoonbook bookkeeper review [root] <mutation.json>\nmoonbook bookkeeper ingress [root] <envelope.json>\nmoonbook bookkeeper egress [root] <envelope.json>",
      )
  }
}

///|
async fn run_bookkeeper_work_order_project(
  root : String,
  request_path : String,
) -> Unit {
  let request : @bookkeeper_store.GovernedWorkOrderBridgeRequest = read_json_file(
    resolve_keeper_packet_path(root, request_path),
  ) catch {
    error => {
      println("moonbook bookkeeper mooncode project failed: \{error}")
      return
    }
  }
  let result = @bookkeeper_store.project_governed_mooncode_work_order(
    root, request,
  ) catch {
    error => {
      println("moonbook bookkeeper mooncode project failed: \{error}")
      return
    }
  }
  print_json(result)
}

///|
async fn run_bookkeeper_work_order_egress(
  root : String,
  request_path : String,
) -> Unit {
  let request : @bookkeeper_store.GovernedWorkOrderEgressRequest = read_json_file(
    resolve_keeper_packet_path(root, request_path),
  ) catch {
    error => {
      println("moonbook bookkeeper mooncode egress failed: \{error}")
      return
    }
  }
  let result = @bookkeeper_store.emit_governed_mooncode_work_order(
    root, request,
  ) catch {
    error => {
      println("moonbook bookkeeper mooncode egress failed: \{error}")
      return
    }
  }
  print_json(result)
}

///|
async fn run_bookkeeper_mooncode_import_draft(args : Array[String]) -> Unit {
  let positional : Array[String] = []
  let mut home : String? = None
  let mut cwd : String? = None
  let mut moonclaw_root : String? = None
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--home" | "--cwd" | "--moonclaw" as option => {
        if index + 1 >= args.length() {
          println(
            "moonbook bookkeeper mooncode import-draft failed: missing value after " +
            option,
          )
          return
        }
        match option {
          "--home" => home = Some(args[index + 1])
          "--cwd" => cwd = Some(args[index + 1])
          _ => moonclaw_root = Some(args[index + 1])
        }
        index += 2
      }
      value => {
        positional.push(value)
        index += 1
      }
    }
  }
  if positional.length() != 2 {
    println(
      "moonbook bookkeeper mooncode import-draft failed: usage requires <root> <request.json>",
    )
    return
  }
  let root = positional[0]
  let request : @bookkeeper_store.MoonCodeDraftImportRequest = read_json_file(
    resolve_keeper_packet_path(root, positional[1]),
  ) catch {
    error => {
      println("moonbook bookkeeper mooncode import-draft failed: \{error}")
      return
    }
  }
  let packet_path = match
    @bookkeeper_store.materialize_mooncode_draft_packet(root, request) {
    Ok(path) => path
    Err(error) => {
      println("moonbook bookkeeper mooncode import-draft failed: " + error)
      return
    }
  }
  ignore(@wiki.enable_extension(root, "moonclaw"))
  let moon_args = [
    "-C",
    moonclaw_root.unwrap_or(default_moonclaw_root(root)),
    "run",
    "cmd/main",
    "--",
    "proposal",
    "import",
    packet_path,
    "--json",
    "--cwd",
    cwd.unwrap_or(root),
    ..match home {
      Some(value) => ["--home", value]
      None => []
    },
  ]
  let code = @process.run("moon", moon_args)
  if code != 0 {
    println(
      "moonbook bookkeeper mooncode import-draft failed: MoonClaw proposal import exited with code \{code}",
    )
    return
  }
  println(
    "MoonClaw draft imported without confirmation or execution: " + packet_path,
  )
}

///|
struct BookkeeperMoonClawRequest {
  contract_version : String
  request_id : String
  request_version : String
  subject : @bookkeeper.VersionedRecordReference
  objective : String
  recorded_at : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
struct BookkeeperMoonClawPacket {
  packet_id : String
  title : String
  summary : String
  request_text : String
  profile : String
  output_contract : String
  source_path : String
  context_pages : Array[String]
  related_pages : Array[String]
  skill_paths : Array[String]
  notes : Array[String]
  tags : Array[String]
  metadata : Json
} derive(Debug, Eq, ToJson, FromJson)

///|
struct ParsedBookkeeperMoonClawArgs {
  root : String
  request_path : String
  confirm : Bool
  home : String?
  cwd : String
  moonclaw_root : String
}

///|
fn bookkeeper_moonclaw_request_contract_version() -> String {
  "moonbook.bookkeeper.moonclaw-request.v1"
}

///|
fn bookkeeper_moonclaw_result_contract_version() -> String {
  "moonbook.bookkeeper.moonclaw-result.v1"
}

///|
fn bookkeeper_three_gap_learning_policy_ref() -> @bookkeeper.VersionedRecordReference {
  let payload : Json = {
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "policy_id": "moonbook-three-gap-learning-key-policy",
    "policy_version": "v1",
    "key_basis": "exact_outcome_subject",
    "candidate_cardinality": 1,
  }
  {
    record_id: "moonbook-three-gap-learning-key-policy",
    record_version: "v1",
    record_digest: @bookkeeper_store.bookkeeper_payload_digest(payload),
  }
}

///|
/// The slow-loop promotion policy is owned and versioned by MoonBook. MoonClaw
/// receives this complete value as input; it may not invent thresholds or
/// replace the policy reference in a capability candidate.
fn bookkeeper_capability_promotion_policy() -> @bookkeeper.CapabilityPromotionPolicy {
  let basis : Json = {
    "contract_version": @bookkeeper.three_gap_contract_version(),
    "policy_id": "moonbook-capability-promotion-policy",
    "policy_version": "v1",
    "minimum_reviewed_findings": 3,
    "minimum_severity": 2,
    "required_gap_classes": [
      "information_gap", "recognition_gap", "decisiveness_gap",
    ],
  }
  let digest = @bookkeeper_store.bookkeeper_payload_digest(basis)
  let policy : @bookkeeper.VersionedRecordReference = {
    record_id: "moonbook-capability-promotion-policy",
    record_version: "v1",
    record_digest: digest,
  }
  @bookkeeper.CapabilityPromotionPolicy::new(
    policy~,
    minimum_reviewed_findings=3,
    minimum_severity=2,
    required_gap_classes=[
      @bookkeeper.InformationGap,
      @bookkeeper.RecognitionGap,
      @bookkeeper.DecisivenessGap,
    ],
    evidence_refs=[
      {
        reference_id: policy.record_id,
        reference_version: policy.record_version,
        digest: policy.record_digest,
        provenance_ref: "moonbook://bookkeeper/policies/capability-promotion/v1",
      },
    ],
  )
}

///|
fn bookkeeper_outcome_learning_key(
  subject : @bookkeeper.VersionedRecordReference,
) -> @bookkeeper.VersionedRecordReference {
  let policy = bookkeeper_three_gap_learning_policy_ref()
  let binding : Json = {
    "contract_version": "moonbook.bookkeeper.learning-key.v1",
    "policy": policy.to_json(),
    "outcome_subject": subject.to_json(),
  }
  let digest = @bookkeeper_store.bookkeeper_payload_digest(binding)
  {
    record_id: "three-gap-learning-" + digest[7:].to_owned(),
    record_version: policy.record_version,
    record_digest: digest,
  }
}

///|
fn bookkeeper_moonclaw_learning_key(
  subject : @bookkeeper_store.DurableBookkeeperRecord,
) -> @bookkeeper.VersionedRecordReference raise {
  match subject.stage {
    OutcomeBinding => bookkeeper_outcome_learning_key(subject.record)
    ThreeGapFinding => {
      guard subject.payload is Object(fields) else {
        fail("Three-Gap subject payload must be an object")
      }
      guard fields.get("learning_key") is Some(value) else {
        fail("Three-Gap subject payload is missing learning_key")
      }
      let key : @bookkeeper.VersionedRecordReference = @json.from_json(value)
      if key.record_id.is_blank() ||
        key.record_version.is_blank() ||
        key.record_digest.is_blank() {
        fail("Three-Gap subject learning_key is incomplete")
      }
      key
    }
    _ => fail("unsupported Bookkeeper MoonClaw learning subject")
  }
}

///|
fn bookkeeper_moonclaw_evidence_compare(
  left : @bookkeeper.VersionedEvidenceReference,
  right : @bookkeeper.VersionedEvidenceReference,
) -> Int {
  let by_id = left.reference_id.compare(right.reference_id)
  if by_id != 0 {
    return by_id
  }
  let by_version = left.reference_version.compare(right.reference_version)
  if by_version != 0 {
    return by_version
  }
  let by_digest = left.digest.compare(right.digest)
  if by_digest != 0 {
    return by_digest
  }
  left.provenance_ref.compare(right.provenance_ref)
}

///|
fn bookkeeper_moonclaw_canonical_evidence(
  records : ArrayView[@bookkeeper_store.DurableBookkeeperRecord],
) -> Array[@bookkeeper.VersionedEvidenceReference] raise {
  let evidence : Array[@bookkeeper.VersionedEvidenceReference] = []
  for record in records {
    for reference in record.evidence_refs {
      evidence.push(reference)
    }
  }
  evidence.sort_by(bookkeeper_moonclaw_evidence_compare)
  let unique : Array[@bookkeeper.VersionedEvidenceReference] = []
  for reference in evidence {
    match unique.last() {
      Some(previous) if previous.reference_id == reference.reference_id &&
        previous.reference_version == reference.reference_version =>
        if previous != reference {
          fail("conflicting exact evidence identity in source records")
        }
      _ => unique.push(reference)
    }
  }
  unique
}

///|
fn bookkeeper_moonclaw_capability_evidence(
  records : ArrayView[@bookkeeper_store.DurableBookkeeperRecord],
) -> Array[@bookkeeper.VersionedEvidenceReference] raise {
  let evidence = bookkeeper_moonclaw_canonical_evidence(records)
  let policy = bookkeeper_capability_promotion_policy()
  for reference in policy.evidence_refs {
    evidence.push(reference)
  }
  evidence.sort_by(bookkeeper_moonclaw_evidence_compare)
  let unique : Array[@bookkeeper.VersionedEvidenceReference] = []
  for reference in evidence {
    match unique.last() {
      Some(previous) if previous.reference_id == reference.reference_id &&
        previous.reference_version == reference.reference_version =>
        if previous != reference {
          fail("conflicting exact evidence identity in promotion inputs")
        }
      _ => unique.push(reference)
    }
  }
  unique
}

///|
fn bookkeeper_moonclaw_result_contract(
  subject : @bookkeeper_store.DurableBookkeeperRecord,
  learning_key : @bookkeeper.VersionedRecordReference,
) -> Json {
  let promotion_policy = bookkeeper_capability_promotion_policy()
  let (candidate_schema, candidate_stage, canonical_evidence_source) = match
    subject.stage {
    OutcomeBinding =>
      (
        "three_gap_finding.v1", "three_gap_finding", "metadata.canonical_evidence_refs",
      )
    ThreeGapFinding =>
      (
        "capability_proposal.v1", "capability_proposal", "candidate.links exact accepted findings",
      )
    _ => ("not_applicable", "not_applicable", "not_applicable")
  }
  {
    "contract_version": bookkeeper_moonclaw_result_contract_version(),
    "candidate_schema": candidate_schema,
    "candidate_stage": candidate_stage,
    "candidate_cardinality": 1,
    "composite_candidates_allowed": false,
    "learning_key": learning_key.to_json(),
    "learning_key_source": "moonbook",
    "learning_key_policy": bookkeeper_three_gap_learning_policy_ref().to_json(),
    "promotion_policy": promotion_policy.to_json(),
    "aggregation_digest_source": "moonbook",
    "canonical_evidence_source": canonical_evidence_source,
  }
}

///|
fn bookkeeper_moonclaw_packet_binding_digest(
  packet_id : String,
  request : BookkeeperMoonClawRequest,
  subject : @bookkeeper_store.DurableBookkeeperRecord,
  source_snapshot_digest : String,
  result_contract : Json,
  canonical_evidence_refs : Array[@bookkeeper.VersionedEvidenceReference],
) -> String {
  @bookkeeper_store.bookkeeper_payload_digest({
    "packet_id": packet_id,
    "profile": "bookkeeper_three_gap_controller",
    "output_contract": bookkeeper_moonclaw_result_contract_version(),
    "request": request.to_json(),
    "subject_record": subject.to_json(),
    "source_snapshot_digest": source_snapshot_digest,
    "result_contract": result_contract,
    "canonical_evidence_refs": canonical_evidence_refs.to_json(),
  })
}

///|
fn bookkeeper_moonclaw_safe_id(value : String, label : String) -> Unit raise {
  if value.is_blank() ||
    value.contains("/") ||
    value.contains("\\") ||
    value.contains("..") {
    fail("\{label} must be a safe non-blank identifier")
  }
}

///|
fn bookkeeper_moonclaw_subject_record(
  snapshot : @bookkeeper_store.BookkeeperStoreSnapshot,
  request : BookkeeperMoonClawRequest,
) -> @bookkeeper_store.DurableBookkeeperRecord raise {
  if request.contract_version != bookkeeper_moonclaw_request_contract_version() {
    fail("unsupported Bookkeeper MoonClaw request contract")
  }
  bookkeeper_moonclaw_safe_id(request.request_id, "request_id")
  bookkeeper_moonclaw_safe_id(request.request_version, "request_version")
  if request.objective.is_blank() {
    fail("Bookkeeper MoonClaw objective is required")
  }
  if request.recorded_at <= 0 {
    fail("Bookkeeper MoonClaw recorded_at must be a positive epoch value")
  }
  if !snapshot.replay_issues.is_empty() {
    fail("Bookkeeper snapshot has replay issues and cannot be submitted")
  }
  let mut subject : @bookkeeper_store.DurableBookkeeperRecord? = None
  for record in snapshot.records {
    if record.record == request.subject {
      subject = Some(record)
      break
    }
  }
  let record = match subject {
    Some(record) => record
    None => fail("Bookkeeper MoonClaw subject is not an exact durable record")
  }
  match record.stage {
    OutcomeBinding => ()
    ThreeGapFinding => {
      let accepted = snapshot.reviews.any(fn(review) {
        review.stage == ThreeGapFinding &&
        review.subject == record.record &&
        review.review_complete &&
        review.disposition == Accept &&
        review.reviewer_kind == Human
      })
      if !accepted {
        fail(
          "capability proposal analysis requires an exact named-human accepted Three-Gap finding",
        )
      }
    }
    _ =>
      fail(
        "Bookkeeper MoonClaw subject must be an outcome binding or a human-accepted Three-Gap finding",
      )
  }
  record
}

///|
fn bookkeeper_moonclaw_packet_path(
  root : String,
  request : BookkeeperMoonClawRequest,
) -> String {
  moonbook_cmd_path(root)
  .join(moonbook_cmd_path("keeper/jobs"))
  .join(
    moonbook_cmd_path(
      "bookkeeper-\{request.request_id}--\{request.request_version}.json",
    ),
  )
  .normalize()
  .to_string()
}

///|
fn bookkeeper_moonclaw_packet(
  request : BookkeeperMoonClawRequest,
  subject : @bookkeeper_store.DurableBookkeeperRecord,
  snapshot : @bookkeeper_store.BookkeeperStoreSnapshot,
) -> BookkeeperMoonClawPacket raise {
  let snapshot_path = ".moonbook/bookkeeper/snapshot.json"
  let ui_state_path = ".moonbook/bookkeeper/ui-state.json"
  let snapshot_digest = @bookkeeper_store.bookkeeper_payload_digest(
    snapshot.to_json(),
  )
  let packet_id = "bookkeeper-\{request.request_id}-\{request.request_version}"
  let learning_key = bookkeeper_moonclaw_learning_key(subject)
  let result_contract = bookkeeper_moonclaw_result_contract(
    subject, learning_key,
  )
  let canonical_evidence_refs = bookkeeper_moonclaw_canonical_evidence([subject])
  let packet_digest = bookkeeper_moonclaw_packet_binding_digest(
    packet_id, request, subject, snapshot_digest, result_contract, canonical_evidence_refs,
  )
  let evidence_note = match subject.stage {
    OutcomeBinding =>
      "Copy metadata.result_contract.learning_key and metadata.canonical_evidence_refs exactly; MoonClaw must not derive, reorder, or invent them."
    ThreeGapFinding =>
      "Copy metadata.result_contract.learning_key and promotion_policy exactly. Capability evidence is the canonical union of every exact linked accepted finding plus promotion-policy evidence; MoonBook recomputes and verifies it."
    _ => "MoonBook owns canonical evidence derivation."
  }
  {
    packet_id,
    title: "Bookkeeper closed loop for \{request.request_id}",
    summary: "Run evidence-bound Three-Gap analysis or capability proposal aggregation through MoonClaw without transferring durable ownership from MoonBook.",
    request_text: "Bookkeeper \{subject.stage.id()} request: \{request.objective}",
    profile: "bookkeeper_three_gap_controller",
    output_contract: bookkeeper_moonclaw_result_contract_version(),
    source_path: snapshot_path,
    context_pages: [snapshot_path, ui_state_path, "KEEPER.md"],
    related_pages: [],
    skill_paths: ["skills/wiki-review/SKILL.md"],
    notes: [
      "MoonClaw is the agent runtime; MoonBook owns the durable Bookkeeper journal and Rabbita projection.",
      "Read-only state: moonbook bookkeeper state <workspace>.", "Candidate persistence from this packet uses: moonbook bookkeeper moonclaw ingest-result <workspace> <packet.json> <moonclaw-result.json>.",
      evidence_note, "Acceptance remains a later named-human call with a CLI-installed grant: moonbook bookkeeper review <workspace> <mutation.json>.",
      "Never modify .moonbook/bookkeeper directly and never fabricate authority, review, or adoption.",
    ],
    tags: ["bookkeeper", "three-gap", "capability-learning"],
    metadata: {
      "request_contract": request.contract_version,
      "request": request.to_json(),
      "subject_stage": subject.stage.id(),
      "subject_record": subject.to_json(),
      "result_contract": result_contract,
      "canonical_evidence_refs": canonical_evidence_refs.to_json(),
      "source_snapshot_digest": snapshot_digest,
      "source_snapshot": snapshot.to_json(),
      "source_packet_digest": packet_digest,
      "model": "gpt-5.6-sol",
      "agent_runtime": "moonclaw",
      "durable_owner": "moonbook",
      "human_review_required": true,
      "side_effects_allowed": false,
    },
  }
}

///|
async fn persist_bookkeeper_moonclaw_packet(
  root : String,
  request : BookkeeperMoonClawRequest,
  packet : BookkeeperMoonClawPacket,
) -> String {
  let path = bookkeeper_moonclaw_packet_path(root, request)
  let directory = moonbook_cmd_path(path).dirname().to_string()
  @fsx.make_directory(directory, recursive=true, exists_ok=true)
  let text = packet.to_json().stringify(indent=2)
  if @fsx.exists(path) {
    if @fsx.read_file(path) == text {
      return path
    }
    fail("Bookkeeper MoonClaw packet identity already has different content")
  }
  @fsx.write_to_file(path, text, create=0o600)
  path
}

///|
fn parse_bookkeeper_moonclaw_args(
  args : Array[String],
) -> ParsedBookkeeperMoonClawArgs raise {
  let positional : Array[String] = []
  let mut confirm = false
  let mut home : String? = None
  let mut cwd : String? = None
  let mut moonclaw_root : String? = None
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "--confirm" => {
        confirm = true
        i += 1
      }
      "--home" => {
        if i + 1 >= args.length() {
          fail("usage requires a value after --home")
        }
        home = Some(args[i + 1])
        i += 2
      }
      "--cwd" => {
        if i + 1 >= args.length() {
          fail("usage requires a value after --cwd")
        }
        cwd = Some(args[i + 1])
        i += 2
      }
      "--moonclaw" => {
        if i + 1 >= args.length() {
          fail("usage requires a value after --moonclaw")
        }
        moonclaw_root = Some(args[i + 1])
        i += 2
      }
      value => {
        positional.push(value)
        i += 1
      }
    }
  }
  if positional.length() != 2 {
    fail(
      "usage: moonbook bookkeeper moonclaw submit <root> <request.json> [--confirm] [--home <dir>] [--cwd <dir>] [--moonclaw <dir>]",
    )
  }
  let root = positional[0]
  {
    root,
    request_path: resolve_keeper_packet_path(root, positional[1]),
    confirm,
    home,
    cwd: cwd.unwrap_or(root),
    moonclaw_root: moonclaw_root.unwrap_or(default_moonclaw_root(root)),
  }
}

///|
async fn execute_bookkeeper_moonclaw_submit(
  parsed : ParsedBookkeeperMoonClawArgs,
) -> Unit {
  let request : BookkeeperMoonClawRequest = read_json_file(parsed.request_path)
  let snapshot = @bookkeeper_store.rebuild_bookkeeper_projection(parsed.root)
  let subject = bookkeeper_moonclaw_subject_record(snapshot, request)
  let install = @wiki.enable_extension(parsed.root, "moonclaw")
  let packet = bookkeeper_moonclaw_packet(request, subject, snapshot)
  let packet_path = persist_bookkeeper_moonclaw_packet(
    parsed.root,
    request,
    packet,
  )
  println("bookkeeper MoonClaw profile: \{install.root}/moonclaw.jobs.json")
  println("bookkeeper MoonClaw packet: \{packet_path}")
  let moon_args = [
    "-C",
    parsed.moonclaw_root,
    "run",
    "cmd/main",
    "--",
    "proposal",
    "import",
    packet_path,
    "--json",
    "--cwd",
    parsed.cwd,
    ..match parsed.home {
      Some(home) => ["--home", home]
      None => []
    },
    ..if parsed.confirm {
      ["--confirm"]
    } else {
      []
    },
  ]
  let code = @process.run("moon", moon_args)
  if code != 0 {
    fail("MoonClaw proposal import exited with code \{code}")
  }
}

///|
async fn run_bookkeeper_moonclaw_submit(args : Array[String]) -> Unit {
  let parsed = parse_bookkeeper_moonclaw_args(args) catch {
    error => {
      println("moonbook bookkeeper moonclaw submit failed: \{error}")
      return
    }
  }
  execute_bookkeeper_moonclaw_submit(parsed) catch {
    error => println("moonbook bookkeeper moonclaw submit failed: \{error}")
  }
}

///|
async fn run_bookkeeper_authority_install(root : String, path : String) -> Unit {
  let grant : @bookkeeper_store.BookkeeperAuthorityGrant = read_json_file(path) catch {
    error => {
      println("moonbook bookkeeper authority failed: \{error}")
      return
    }
  }
  let registry = @bookkeeper_store.install_bookkeeper_authority_grant(
    root, grant,
  ) catch {
    error => {
      println("moonbook bookkeeper authority failed: \{error}")
      return
    }
  }
  print_json(registry)
}

///|
async fn run_bookkeeper_state(root : String) -> Unit {
  let snapshot = @bookkeeper_store.replay_bookkeeper_store(root) catch {
    error => {
      println("moonbook bookkeeper state failed: \{error}")
      return
    }
  }
  print_json(snapshot)
}

///|
async fn run_bookkeeper_replay(root : String) -> Unit {
  let snapshot = @bookkeeper_store.rebuild_bookkeeper_projection(root) catch {
    error => {
      println("moonbook bookkeeper replay failed: \{error}")
      return
    }
  }
  print_json(snapshot)
  println(
    "bookkeeper UI projection: \{@bookkeeper_store.bookkeeper_ui_state_path(root)}",
  )
}

///|
async fn run_bookkeeper_record(root : String, path : String) -> Unit {
  let record : @bookkeeper_store.DurableBookkeeperRecord = read_json_file(path) catch {
    error => {
      println("moonbook bookkeeper record failed: \{error}")
      return
    }
  }
  let result = @bookkeeper_store.persist_bookkeeper_record(root, record) catch {
    error => {
      println("moonbook bookkeeper record failed: \{error}")
      return
    }
  }
  print_json(result)
}

///|
async fn run_bookkeeper_review(root : String, path : String) -> Unit {
  let mutation : @bookkeeper_store.GovernedReviewMutation = read_json_file(path) catch {
    error => {
      println("moonbook bookkeeper review failed: \{error}")
      return
    }
  }
  let result = @bookkeeper_store.apply_governed_review(root, mutation) catch {
    error => {
      println("moonbook bookkeeper review failed: \{error}")
      return
    }
  }
  print_json(result)
}

///|
async fn run_bookkeeper_envelope(
  root : String,
  path : String,
  ingress : Bool,
) -> Unit {
  let envelope : @bookkeeper_store.BookkeeperTransportEnvelope = read_json_file(
    path,
  ) catch {
    error => {
      println("moonbook bookkeeper envelope failed: \{error}")
      return
    }
  }
  let expected = if ingress {
    @bookkeeper_store.Ingress
  } else {
    @bookkeeper_store.Egress
  }
  if envelope.direction != expected {
    println(
      "moonbook bookkeeper envelope failed: direction does not match command",
    )
    return
  }
  let result = @bookkeeper_store.persist_transport_envelope(root, envelope) catch {
    error => {
      println("moonbook bookkeeper envelope failed: \{error}")
      return
    }
  }
  print_json(result)
}
