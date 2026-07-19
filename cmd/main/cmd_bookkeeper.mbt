///|
async fn[T : @json.FromJson] read_json_file(path : String) -> T {
  @json.from_json(@json.parse(@fsx.read_file(path))) catch {
    error => fail("invalid Bookkeeper JSON file \{path}: \{error}")
  }
}

///|
async fn run_bookkeeper(args : Array[String]) -> Unit {
  match args {
    ["moonclaw", "submit", .. raw] =>
      run_bookkeeper_moonclaw_submit(raw.to_owned())
    ["moonclaw", "ingest-result", root, packet_path, result_path] =>
      run_bookkeeper_moonclaw_ingest_result(root, packet_path, result_path)
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
        "moonbook bookkeeper usage:\nmoonbook bookkeeper moonclaw submit <root> <request.json> [--confirm] [--home <dir>] [--cwd <dir>] [--moonclaw <dir>]\nmoonbook bookkeeper moonclaw ingest-result <root> <packet.json> <moonclaw-result.json>\nmoonbook bookkeeper state [root]\nmoonbook bookkeeper replay [root]\nmoonbook bookkeeper authority install [root] <grant.json>\nmoonbook bookkeeper record [root] <record.json>\nmoonbook bookkeeper review [root] <mutation.json>\nmoonbook bookkeeper ingress [root] <envelope.json>\nmoonbook bookkeeper egress [root] <envelope.json>",
      )
  }
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
fn bookkeeper_moonclaw_packet_binding_digest(
  packet_id : String,
  request : BookkeeperMoonClawRequest,
  subject : @bookkeeper_store.DurableBookkeeperRecord,
  source_snapshot_digest : String,
) -> String {
  @bookkeeper_store.bookkeeper_payload_digest({
    "packet_id": packet_id,
    "profile": "bookkeeper_three_gap_controller",
    "output_contract": bookkeeper_moonclaw_result_contract_version(),
    "request": request.to_json(),
    "subject_record": subject.to_json(),
    "source_snapshot_digest": source_snapshot_digest,
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
) -> BookkeeperMoonClawPacket {
  let snapshot_path = ".moonbook/bookkeeper/snapshot.json"
  let ui_state_path = ".moonbook/bookkeeper/ui-state.json"
  let snapshot_digest = @bookkeeper_store.bookkeeper_payload_digest(
    snapshot.to_json(),
  )
  let packet_id = "bookkeeper-\{request.request_id}-\{request.request_version}"
  let packet_digest = bookkeeper_moonclaw_packet_binding_digest(
    packet_id, request, subject, snapshot_digest,
  )
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
      "Acceptance remains a later named-human call with a CLI-installed grant: moonbook bookkeeper review <workspace> <mutation.json>.",
      "Never modify .moonbook/bookkeeper directly and never fabricate authority, review, or adoption.",
    ],
    tags: ["bookkeeper", "three-gap", "capability-learning"],
    metadata: {
      "request_contract": request.contract_version,
      "request": request.to_json(),
      "subject_stage": subject.stage.id(),
      "subject_record": subject.to_json(),
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
