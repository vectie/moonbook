///|
pub struct UiStatusChip {
  label : String
  tone : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiMetric {
  label : String
  value : String
  note : String
  tone : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiWorkflowItem {
  title : String
  detail : String
  status : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiPanelItem {
  title : String
  detail : String
  meta : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiChapterLink {
  title : String
  href : String
  source_path : String
  number : String
} derive(Show, ToJson, FromJson)

///|
pub struct UiState {
  title : String
  summary : String
  status_chips : Array[UiStatusChip]
  metrics : Array[UiMetric]
  workflow : Array[UiWorkflowItem]
  review_queue : Array[UiPanelItem]
  keeper_items : Array[UiPanelItem]
  page_families : Array[UiPanelItem]
  chapters : Array[UiChapterLink]
  synthesis_preview : String
} derive(Show, ToJson, FromJson)

///|
pub async fn generate_ui_state(root : String) -> UiState {
  let workspace = workspace_paths(root)
  let state = summarize_state(root)
  let health = report_health(root)
  let keeper = keeper_snapshot(root)
  let pending = list_pending_reviews(root)
  let claims_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("synthesis/claims.md"))
    .to_string()
  let claims_text = if @fsx.exists(claims_path) {
    @fsx.read_file(claims_path)
  } else {
    ""
  }
  let status_chips = ui_status_chips(state, health)
  let metrics = ui_metrics(state, health)
  let workflow = ui_workflow_items(state, health)
  let review_queue = ui_review_queue(root, pending)
  let keeper_items = [
    {
      title: "Active Memory",
      detail: "Reusable domain memory kept in Keeper for future worker hydration.",
      meta: "\{keeper.active_memory.length()} entries",
    },
    {
      title: "User Memory",
      detail: "Stable user collaboration preferences kept separate from task-local recall.",
      meta: "\{keeper.user_memory.length()} entries",
    },
    {
      title: "Working Memory",
      detail: if keeper.working_memory.length() >= 8 {
        "Working memory is crowded and should be pruned or promoted."
      } else {
        "Short-lived task memory remains within the bounded window."
      },
      meta: "\{keeper.working_memory.length()} entries",
    },
  ]
  let page_families = [
    {
      title: "Claims Register",
      detail: "Claim ids, confidence, support, supersession, and related-page metadata.",
      meta: "\{count_heading_entries(claims_text)} claims",
    },
    {
      title: "Synthesis Map",
      detail: "Coverage counts, hub pages, and open loops for planning pressure.",
      meta: "wiki/synthesis/map.md",
    },
    {
      title: "Evidence",
      detail: "Support records for persisted results and review outcomes.",
      meta: "\{count_evidence_entries(root)} records",
    },
  ]
  {
    title: catalog_name(root),
    summary: catalog_purpose(root),
    status_chips,
    metrics,
    workflow,
    review_queue,
    keeper_items,
    page_families,
    chapters: ui_chapter_links(root),
    synthesis_preview: ui_synthesis_preview(root),
  }
}

///|
pub async fn write_ui_state(root : String, output_path : String) -> String {
  let state = generate_ui_state(root)
  @fsx.write_to_file(
    output_path,
    state.to_json().stringify(indent=2),
    create=0o644,
  )
  output_path
}

///|
fn ui_status_chips(
  state : BookStateSummary,
  health : BookHealthReport,
) -> Array[UiStatusChip] {
  let chips : Array[UiStatusChip] = []
  chips.push({
    label: health.level,
    tone: if health.level == "healthy" {
      "healthy"
    } else {
      "alert"
    },
  })
  if state.pending_review_count > 0 {
    chips.push({ label: "pending review", tone: "review" })
  }
  if health.maintenance_entry_count > 0 || health.keeper_working_count >= 8 {
    chips.push({ label: "planning pressure", tone: "alert" })
  }
  chips
}

///|
fn ui_metrics(
  state : BookStateSummary,
  health : BookHealthReport,
) -> Array[UiMetric] {
  [
    {
      label: "Pending Review",
      value: state.pending_review_count.to_string(),
      note: "Queued claim, query, and result promotions awaiting operator review.",
      tone: if state.pending_review_count > 0 {
        "review"
      } else {
        "healthy"
      },
    },
    {
      label: "Evidence Coverage",
      value: state.evidence_count.to_string(),
      note: "Persisted results and review outcomes now leave an auditable support trail.",
      tone: if state.evidence_count > 0 {
        "healthy"
      } else {
        "alert"
      },
    },
    {
      label: "Open Loops",
      value: health.issues.length().to_string(),
      note: if health.issues.is_empty() {
        "No active health issues are currently blocking the local book loop."
      } else {
        health.issues.join("; ")
      },
      tone: if health.issues.is_empty() {
        "healthy"
      } else {
        "alert"
      },
    },
    {
      label: "Entity Hubs",
      value: state.entity_count.to_string(),
      note: "Entity pages feed the synthesis map and reciprocal relationship graph.",
      tone: "info",
    },
  ]
}

///|
fn ui_workflow_items(
  state : BookStateSummary,
  health : BookHealthReport,
) -> Array[UiWorkflowItem] {
  [
    {
      title: "Ingest",
      detail: "Sources update entity, concept, claim, reciprocal relationship, and synthesis-map pages in one pass.",
      status: "active",
    },
    {
      title: "Query",
      detail: "Saved answers propagate query signals, Keeper memory, and synthesis-map updates.",
      status: if state.page_count > 0 {
        "active"
      } else {
        "idle"
      },
    },
    {
      title: "Review",
      detail: "Approvals can promote into overview, claims, cited pages, and staged durable targets.",
      status: if state.pending_review_count > 0 {
        "expanded"
      } else {
        "stable"
      },
    },
    {
      title: "Keeper",
      detail: "Memory, evidence, and planning signals remain visible through Keeper insights and the UI snapshot.",
      status: if health.keeper_working_count >= 8 {
        "crowded"
      } else {
        "stable"
      },
    },
  ]
}

///|
async fn ui_review_queue(
  root : String,
  pending : Array[ReviewItem],
) -> Array[UiPanelItem] {
  let workspace = workspace_paths(root)
  let page_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("reviews/pending.md"))
    .to_string()
  let content = if @fsx.exists(page_path) {
    @fsx.read_file(page_path)
  } else {
    ""
  }
  let blocks = parse_review_blocks(content)
  let items : Array[UiPanelItem] = []
  for item in pending {
    let mut matched : ReviewBlock? = None
    for entry in blocks {
      if entry.review_id == item.review_id {
        matched = Some(entry)
        break
      }
    }
    match matched {
      Some(block) =>
        items.push({
          title: "\{item.kind} | \{item.title}",
          detail: find_review_field(block.block, "- Reason: ").unwrap_or(
            "Pending review item.",
          ),
          meta: find_review_field(block.block, "- Merge policy: `").unwrap_or(
            item.status,
          ),
        })
      None =>
        items.push({
          title: "\{item.kind} | \{item.title}",
          detail: "Pending review item.",
          meta: item.status,
        })
    }
    if items.length() >= 4 {
      break
    }
  }
  if items.is_empty() {
    [
      {
        title: "Review Queue",
        detail: "No pending review items.",
        meta: "healthy",
      },
    ]
  } else {
    items
  }
}

///|
async fn ui_chapter_links(root : String) -> Array[UiChapterLink] {
  let workspace = workspace_paths(root)
  let summary_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("SUMMARY.md"))
    .to_string()
  if !@fsx.exists(summary_path) {
    return []
  }
  let items : Array[UiChapterLink] = []
  let mut number = 1
  for raw in @fsx.read_file(summary_path).split("\n") {
    let line = raw.trim().to_string()
    if !line.has_prefix("- [") {
      continue
    }
    match summary_link_parts(line) {
      Some((title, href)) => {
        items.push({
          title,
          href: markdown_href_to_html(href),
          source_path: href,
          number: number.to_string(),
        })
        number += 1
      }
      None => ()
    }
    if items.length() >= 8 {
      break
    }
  }
  items
}

///|
fn summary_link_parts(line : String) -> (String, String)? {
  match line.find("](") {
    Some(split) =>
      if line.has_suffix(")") {
        Some(
          (
            line[3:split].to_string(),
            line[split + 2:line.length() - 1]
            .strip_prefix("./")
            .unwrap_or(line[split + 2:line.length() - 1])
            .to_string(),
          ),
        )
      } else {
        None
      }
    None => None
  }
}

///|
fn markdown_href_to_html(href : String) -> String {
  if href.has_suffix(".md") {
    href[:href.length() - 3].to_string() + ".html"
  } else {
    href
  }
}

///|
async fn ui_synthesis_preview(root : String) -> String {
  let workspace = workspace_paths(root)
  let map_path = @path.Path(workspace.wiki_dir)
    .join(@path.Path("synthesis/map.md"))
    .to_string()
  if !@fsx.exists(map_path) {
    return "No synthesis map available yet."
  }
  let lines : Array[String] = []
  for raw in @fsx.read_file(map_path).split("\n") {
    let line = raw.to_string()
    if line.trim().is_empty() {
      continue
    }
    lines.push(line)
    if lines.length() >= 14 {
      break
    }
  }
  lines.join("\n")
}

///|
test "summary link parts parse markdown bullets" {
  let parsed = summary_link_parts("- [Home](./Home.md)").unwrap()
  assert_eq(parsed.0, "Home")
  assert_eq(parsed.1, "Home.md")
}
