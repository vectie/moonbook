///|
// Content extraction helpers for generated UI state.

async fn ui_research_artifacts(root : String) -> Array[UiPanelItem] {
  let items : Array[UiPanelItem] = []
  for spec in research_artifact_specs() {
    let path = @path.Path(root).join(@path.Path(spec.path)).to_string()
    if @fsx.exists(path) {
      items.push({
        title: spec.title,
        detail: markdown_excerpt(@fsx.read_file(path), 260),
        meta: spec.path,
      })
    } else {
      items.push({
        title: spec.title,
        detail: "Missing required artifact. Bootstrap should remain incomplete until this research record exists or a precise blocker explains why it cannot be produced.",
        meta: "missing: \{spec.path}",
      })
    }
  }
  items
}

///|
async fn ui_research_brief(root : String) -> String {
  for
    relative in [
      "raw/bootstrap/synthesis-brief.md", "raw/bootstrap/evidence-matrix.md",
    ] {
    let path = @path.Path(root).join(@path.Path(relative)).to_string()
    if @fsx.exists(path) {
      return @fsx.read_file(path)
    }
  }
  "No synthesis brief has been generated yet. The site should stay diagnostic until the research lane writes `raw/bootstrap/synthesis-brief.md` or explains the blocker."
}

///|
async fn ui_marketing_brief(root : String) -> UiMarketingBrief {
  for
    relative in [
      "wiki/synthesis/marketing.md", "raw/bootstrap/marketing-brief.md", "site/marketing.md",
    ] {
    let path = @path.Path(root).join(@path.Path(relative)).to_string()
    if @fsx.exists(path) {
      return parse_marketing_brief(relative, @fsx.read_file(path))
    }
  }
  {
    source_path: "missing: raw/bootstrap/marketing-brief.md",
    headline: "Marketing brief needed",
    lede: "Load `skills/wiki-marketing/SKILL.md` and generate `raw/bootstrap/marketing-brief.md` before using this as a product website.",
    sections: [
      {
        title: "Authoring contract",
        body: "The generated site renderer is ready, but the persuasive product copy must come from a keeper-authored marketing brief rather than MoonBook code.",
        bullets: [
          "Write a seller-facing headline and lede", "Add feature, audience, strength, surface, and conversion sections",
          "Keep evidence and debug detail in the wiki, journal, or course surfaces",
        ],
      },
    ],
  }
}

///|
fn parse_marketing_brief(
  source_path : String,
  content : String,
) -> UiMarketingBrief {
  let headline_parts : Array[String] = []
  let lede_parts : Array[String] = []
  let sections : Array[UiMarketingSection] = []
  let body_parts : Array[String] = []
  let bullets : Array[String] = []
  let mut headline = ""
  let mut current_title = ""
  let mut seen_section = false
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if line.is_empty() {
      continue
    }
    if line.has_prefix("# ") {
      headline = clean_marketing_text(line[2:].trim().to_string())
      continue
    }
    if line.has_prefix("## ") {
      if !current_title.is_empty() {
        sections.push({
          title: current_title,
          body: body_parts.join(" "),
          bullets: bullets.copy(),
        })
        body_parts.clear()
        bullets.clear()
      }
      current_title = clean_marketing_text(line[3:].trim().to_string())
      seen_section = true
      continue
    }
    if line.has_prefix("### ") {
      let subtitle = clean_marketing_text(line[4:].trim().to_string())
      if seen_section {
        bullets.push(subtitle)
      } else {
        lede_parts.push(subtitle)
      }
      continue
    }
    if line.has_prefix("- ") {
      let item = clean_marketing_text(line[2:].trim().to_string())
      if seen_section {
        bullets.push(item)
      } else {
        lede_parts.push(item)
      }
      continue
    }
    let cleaned = clean_marketing_text(line)
    if seen_section {
      body_parts.push(cleaned)
    } else if headline.is_empty() {
      headline_parts.push(cleaned)
    } else {
      lede_parts.push(cleaned)
    }
  }
  if !current_title.is_empty() {
    sections.push({
      title: current_title,
      body: body_parts.join(" "),
      bullets: bullets.copy(),
    })
  }
  let resolved_headline = if !headline.is_empty() {
    headline
  } else if !headline_parts.is_empty() {
    clamp_text(headline_parts.join(" "), 130)
  } else {
    "Marketing brief needs a headline"
  }
  let resolved_lede = if lede_parts.is_empty() {
    "The marketing brief exists but needs a short seller-facing lede."
  } else {
    clamp_text(lede_parts.join(" "), 360)
  }
  let resolved_sections = if sections.is_empty() {
    [
      {
        title: "Brief needs sections",
        body: "Add `##` sections for features, buyers, strengths, surfaces, and conversion path.",
        bullets: [],
      },
    ]
  } else {
    normalize_marketing_sections(sections)
  }
  {
    source_path,
    headline: resolved_headline,
    lede: resolved_lede,
    sections: resolved_sections,
  }
}

///|
fn normalize_marketing_sections(
  sections : Array[UiMarketingSection],
) -> Array[UiMarketingSection] {
  let normalized : Array[UiMarketingSection] = []
  for
    title in [
      "The Problem", "The Product", "Why It Wins", "What You Can Ship", "Who It Is For",
      "Proof Points", "Objections", "Next Step",
    ] {
    let body_parts : Array[String] = []
    let bullets : Array[String] = []
    for section in sections {
      if marketing_canonical_section_title(section.title) == title {
        if !section.body.trim().is_empty() {
          body_parts.push(sanitize_marketing_surface_text(section.body))
        }
        for bullet in section.bullets {
          if !bullet.trim().is_empty() {
            let cleaned = sanitize_marketing_surface_text(bullet)
            if !cleaned.trim().is_empty() {
              bullets.push(cleaned)
            }
          }
        }
      }
    }
    if !body_parts.is_empty() || !bullets.is_empty() {
      normalized.push({ title, body: body_parts.join(" "), bullets })
    }
  }
  if normalized.is_empty() {
    [
      {
        title: "The Problem",
        body: "The marketing brief did not follow the wiki-marketing skill skeleton. Regenerate it from `skills/wiki-marketing/SKILL.md` before using this page as final copy.",
        bullets: [],
      },
    ]
  } else {
    normalized
  }
}

///|
fn marketing_canonical_section_title(title : String) -> String {
  let lower = title.trim().to_lower()
  if lower == "the problem" ||
    lower.contains("buyer pain") ||
    lower.contains("buyer problem") ||
    lower.contains("core buyer pain") ||
    lower.contains("pain") ||
    lower.contains("problem") {
    "The Problem"
  } else if lower == "the product" ||
    lower.contains("product promise") ||
    lower.contains("core promise") ||
    lower.contains("product") ||
    lower.contains("positioning") ||
    lower.contains("promise") {
    "The Product"
  } else if lower == "why it wins" ||
    lower.contains("differentiation") ||
    lower.contains("supported strength") ||
    lower.contains("strength") ||
    lower.contains("competitive framing") ||
    lower.contains("wins") {
    "Why It Wins"
  } else if lower == "what you can ship" ||
    lower.contains("seller narrative") ||
    lower.contains("messaging angle") ||
    lower.contains("ship") ||
    lower.contains("deliverable") ||
    lower.contains("materialization target") {
    "What You Can Ship"
  } else if lower == "who it is for" ||
    lower.contains("audience") ||
    lower.contains("buyer") ||
    lower.contains("who") {
    "Who It Is For"
  } else if lower == "proof points" ||
    lower.contains("proof") ||
    lower.contains("evidence") ||
    lower.contains("verification") {
    "Proof Points"
  } else if lower == "objections" ||
    lower.contains("objection") ||
    lower.contains("guardrail") ||
    lower.contains("risk") {
    "Objections"
  } else if lower == "next step" ||
    lower.contains("next") ||
    lower.contains("action") ||
    lower.contains("cta") {
    "Next Step"
  } else {
    "Proof Points"
  }
}

///|
fn clean_marketing_text(text : String) -> String {
  let stripped = text
    .replace_all(old="**", new="")
    .replace_all(old="`", new="")
    .to_string()
    .trim(chars="# ")
    .to_string()
  sanitize_marketing_surface_text(clean_report_text(stripped))
}

///|
fn sanitize_marketing_surface_text(text : String) -> String {
  let mut cleaned = text
    .replace_all(old="raw/bootstrap/", new="research intake ")
    .replace_all(old="raw/bootstrap", new="research intake")
    .replace_all(old="wiki/sources/", new="source page ")
    .replace_all(old="wiki/entities/", new="entity page ")
    .replace_all(old="wiki/concepts/", new="concept page ")
    .replace_all(old="wiki/synthesis/", new="synthesis page ")
    .replace_all(old="memory_candidates", new="memory signals")
    .replace_all(old="requires_review", new="review signals")
    .replace_all(old="notify_town", new="town notification signals")
    .replace_all(old="task_id", new="task identifier")
    .replace_all(old="bootstrap_gather", new="research gathering")
    .replace_all(old="source_materialize", new="source preparation")
    .replace_all(old="knowledge_revise", new="knowledge revision")
    .replace_all(old="review_finalize", new="review closeout")
    .replace_all(old="marketing_project", new="marketing projection")
    .to_string()
  for prefix in ["C", "L", "W", "B"] {
    for index in 1..<31 {
      cleaned = cleaned
        .replace_all(old="\{prefix}\{index}, ", new="")
        .replace_all(old=", \{prefix}\{index}", new="")
        .replace_all(old="(\{prefix}\{index})", new="")
        .replace_all(old="\{prefix}\{index}.", new="")
        .replace_all(old="\{prefix}\{index}", new="")
        .to_string()
    }
  }
  cleaned
  .replace_all(old="Supported by .", new="")
  .replace_all(old="Supported by", new="")
  .replace_all(old="via .", new="")
  .replace_all(old=" .", new=".")
  .replace_all(old=" ,", new=",")
  .replace_all(old="  ", new=" ")
  .to_string()
  .trim()
  .to_string()
}

///|
async fn ui_research_long_report(root : String) -> String {
  for relative in ["wiki/synthesis/report.md", "raw/bootstrap/deep-report.md"] {
    let path = @path.Path(root).join(@path.Path(relative)).to_string()
    if @fsx.exists(path) {
      return @fsx.read_file(path)
    }
  }
  ""
}

///|
async fn ui_research_report(
  root : String,
  title : String,
) -> Array[UiResearchReportSection] {
  let brief = read_workspace_text(root, "raw/bootstrap/synthesis-brief.md")
  let evidence = read_workspace_text(root, "raw/bootstrap/evidence-matrix.md")
  let local_sources = read_workspace_text(
    root, "raw/bootstrap/local-sources.md",
  )
  let source_screen = read_workspace_text(
    root, "raw/bootstrap/source-screen.md",
  )
  let source_page = read_workspace_text(
    root, "wiki/sources/research-evidence.md",
  )
  let overview = read_workspace_text(root, "wiki/synthesis/overview.md")
  let evidence_rows = parse_research_evidence_rows(evidence)
  let corpus = brief +
    "\n\n" +
    evidence +
    "\n\n" +
    local_sources +
    "\n\n" +
    source_screen +
    "\n\n" +
    source_page +
    "\n\n" +
    overview
  [
    {
      title: "Executive summary",
      detail: research_executive_summary(title, brief, evidence_rows),
      evidence: report_evidence_from_rows(
        evidence_rows,
        ["readme", "overview", "synthesis", title.to_lower()],
        evidence,
        "executive",
      ),
    },
    {
      title: "What is \{title}?",
      detail: research_topic_summary(title, brief, evidence_rows),
      evidence: report_evidence_from_rows(
        evidence_rows,
        [title.to_lower(), "readme", "overview"],
        evidence,
        title.to_lower(),
      ),
    },
    {
      title: "Architecture",
      detail: research_keyword_summary(
        evidence_rows,
        [
          "architecture", "component", "topology", "boundary", "controller", "adapter",
          "routing",
        ],
        "Architecture evidence is still thin. Add files or source rows that describe components, boundaries, controllers, workers, and handoff points.",
      ),
      evidence: report_evidence_from_rows(
        evidence_rows,
        ["architecture", "topology", "controller", "adapter", "routing"],
        evidence,
        "architecture",
      ),
    },
    {
      title: "Runtime model",
      detail: research_keyword_summary(
        evidence_rows,
        [
          "runtime", "job", "session", "worker", "task", "provider", "gateway", "tool",
        ],
        "Runtime behavior is not yet summarized from evidence. The next gather pass should inspect job, provider, session, and worker runtime files.",
      ),
      evidence: report_evidence_from_rows(
        evidence_rows,
        ["runtime", "job", "session", "worker", "provider", "tool"],
        evidence,
        "runtime",
      ),
    },
    {
      title: "Memory and state",
      detail: research_keyword_summary(
        evidence_rows,
        [
          "memory", "state", "artifact", "workspace", "persistent", "durable", "storage",
          "keeper",
        ],
        "Memory and state behavior still needs a sourced section. Capture what is durable, what is temporary, and which layer owns each state family.",
      ),
      evidence: report_evidence_from_rows(
        evidence_rows,
        ["memory", "state", "artifact", "workspace", "storage", "keeper"],
        evidence,
        "memory",
      ),
    },
    {
      title: "Relationship to Moontown and MoonBook",
      detail: research_relationship_summary(title, corpus, evidence_rows),
      evidence: report_evidence_from_rows(
        evidence_rows,
        [
          "moontown", "moonbook", "moonclaw", "relationship", "orchestration", "materialization",
        ],
        evidence,
        "moontown",
      ),
    },
    {
      title: "Comparative positioning",
      detail: research_comparison_summary(title, source_screen, evidence_rows),
      evidence: report_evidence_from_rows(
        evidence_rows,
        [
          "mdbook", "openclaw", "maria", "compare", "comparison", "rewrite", "motivated",
        ],
        source_screen + "\n" + evidence,
        "comparison",
      ),
    },
    {
      title: "Maturity and gaps",
      detail: research_maturity_summary(brief, evidence_rows),
      evidence: report_evidence_from_rows(
        evidence_rows,
        ["gap", "missing", "risk", "blocker", "future", "todo", "needs"],
        brief + "\n" + evidence,
        "gap",
      ),
    },
    {
      title: "Evidence table",
      detail: if evidence.trim().is_empty() {
        "No evidence matrix exists yet. Generate `raw/bootstrap/evidence-matrix.md` before treating this as a research report."
      } else {
        research_evidence_table_summary(evidence_rows)
      },
      evidence: "raw/bootstrap/evidence-matrix.md",
    },
  ]
}

///|
fn parse_research_evidence_rows(content : String) -> Array[ResearchEvidenceRow] {
  let rows : Array[ResearchEvidenceRow] = []
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if !line.has_prefix("|") || line.contains("---") {
      continue
    }
    let cells = line
      .split("|")
      .map(fn(part) { part.trim().to_string() })
      .to_array()
    if cells.length() < 5 {
      continue
    }
    let source_id = cells[1]
    if source_id.is_empty() ||
      source_id == "Source ID" ||
      source_id == "Claim ID" {
      continue
    }
    rows.push({
      source_id,
      evidence: clean_report_text(cells[2]),
      locator: clean_report_text(cells[3]),
      confidence: clean_report_text(cells[4]),
      notes: if cells.length() > 5 {
        clean_report_text(cells[5])
      } else {
        ""
      },
    })
  }
  rows
}

///|
fn research_executive_summary(
  title : String,
  brief : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  match
    best_report_paragraph(brief, [
      "executive", "summary", "answer", "finding", "verified",
    ]) {
    Some(text) =>
      if is_shallow_report_paragraph(text) {
        research_executive_summary_from_rows(title, rows)
      } else {
        text
      }
    None => research_executive_summary_from_rows(title, rows)
  }
}

///|
fn research_executive_summary_from_rows(
  title : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  if rows.is_empty() {
    "No executive summary is available yet. Generate `raw/bootstrap/synthesis-brief.md` with a direct answer before presenting this page as a research article."
  } else {
    "\{title} is supported by \{rows.length()} screened evidence rows. The strongest current basis is \{row_brief(rows[0])}; keep explicit gaps visible until the synthesis brief becomes more analytical."
  }
}

///|
fn research_topic_summary(
  title : String,
  brief : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  match
    best_report_paragraph(brief, [
      title.to_lower(),
      "what is",
      "role",
      "purpose",
      "system",
    ]) {
    Some(text) =>
      if is_shallow_report_paragraph(text) {
        research_topic_summary_from_rows(title, rows)
      } else {
        text
      }
    None => research_topic_summary_from_rows(title, rows)
  }
}

///|
fn research_topic_summary_from_rows(
  title : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  let selected = select_evidence_rows(
    rows,
    [title.to_lower(), "readme", "overview", "home"],
    2,
  )
  if selected.is_empty() {
    "\{title} has not been explained from verified evidence yet. The report needs a role paragraph sourced from the synthesis brief or entity page."
  } else {
    "\{title} is described through \{selected.length()} high-signal source row(s): \{row_list_sentence(selected)}"
  }
}

///|
fn is_shallow_report_paragraph(text : String) -> Bool {
  let lowered = text.to_lower()
  lowered.has_prefix("topic:") ||
  lowered.has_prefix("verified findings:") ||
  lowered.has_prefix("web verification status:") ||
  lowered.has_prefix("next materialization:") ||
  lowered.contains("local source hints were mounted") ||
  lowered.contains("candidate source lists are not enough")
}

///|
fn best_non_shallow_report_paragraph(
  corpus : String,
  keywords : Array[String],
) -> String? {
  match best_report_paragraph(corpus, keywords) {
    Some(text) =>
      if is_shallow_report_paragraph(text) {
        None
      } else {
        Some(text)
      }
    None => None
  }
}

///|
fn research_keyword_summary(
  rows : Array[ResearchEvidenceRow],
  keywords : Array[String],
  fallback : String,
) -> String {
  let selected = select_evidence_rows(rows, keywords, 3)
  if selected.is_empty() {
    fallback
  } else {
    "The screened evidence points to \{row_list_sentence(selected)}"
  }
}

///|
fn research_relationship_summary(
  title : String,
  corpus : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  ignore(corpus)
  let selected = select_evidence_rows(
    rows,
    [
      "moontown", "moonbook", "moonclaw", "orchestration", "materialization", "runtime",
    ],
    3,
  )
  if selected.is_empty() {
    "Cross-project relationship evidence is not yet strong enough. The report should explain town orchestration, book memory/materialization, and claw execution boundaries."
  } else {
    "\{title} should be read inside the town-book-claw split: Moontown owns orchestration, MoonBook owns durable workspace and memory materialization, and MoonClaw owns worker execution. Current supporting rows: \{row_list_sentence(selected)}"
  }
}

///|
fn research_comparison_summary(
  title : String,
  source_screen : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  ignore(source_screen)
  let selected = select_evidence_rows(
    rows,
    [
      "mdbook", "openclaw", "maria", "compare", "comparison", "rewrite", "motivated",
    ],
    2,
  )
  if selected.is_empty() {
    "No supported comparison section exists yet for \{title}. The report should avoid external positioning claims until source-screen rows and evidence rows support them."
  } else {
    "Comparative positioning is supported only where the evidence names a lineage or adjacent system. Current support: \{row_list_sentence(selected)}"
  }
}

///|
fn research_maturity_summary(
  brief : String,
  rows : Array[ResearchEvidenceRow],
) -> String {
  match
    best_non_shallow_report_paragraph(brief, [
      "maturity", "gap", "missing", "risk", "blocker", "future", "trajectory",
    ]) {
    Some(text) => text
    None =>
      if rows.is_empty() {
        "Maturity is not yet assessed from evidence. The synthesis brief should distinguish verified behavior, provisional behavior, and implementation gaps."
      } else {
        let weak_rows = select_evidence_rows(
          rows,
          [
            "needs", "missing", "blocked", "provisional", "candidate", "unavailable",
          ],
          2,
        )
        if weak_rows.is_empty() {
          "Maturity looks presentable at the evidence-envelope level: \{rows.length()} source rows were screened. The next improvement is deeper synthesis, not more generic process copy."
        } else {
          "Maturity is mixed. The evidence envelope has \{rows.length()} screened rows, but gaps remain around \{row_list_sentence(weak_rows)}"
        }
      }
  }
}

///|
fn research_evidence_table_summary(rows : Array[ResearchEvidenceRow]) -> String {
  if rows.is_empty() {
    return "The evidence matrix exists but has no parseable source rows yet."
  }
  let local_count = research_evidence_ref_count(rows, "L")
  let web_count = research_evidence_ref_count(rows, "W")
  let examples = select_evidence_rows(
    rows,
    ["readme", "architecture", "runtime", "memory", "provider", "tool"],
    3,
  )
  "The report is backed by \{rows.length()} screened source row(s): \{local_count} local and \{web_count} web. Representative rows: \{row_list_sentence(examples)}"
}

///|
fn research_evidence_ref_count(
  rows : Array[ResearchEvidenceRow],
  prefix : String,
) -> Int {
  let refs : Array[String] = []
  for row in rows {
    for field in [row.source_id, row.locator, row.evidence, row.notes] {
      for source_ref in research_evidence_refs(field, prefix) {
        if !refs.contains(source_ref) {
          refs.push(source_ref)
        }
      }
    }
  }
  refs.length()
}

///|
fn research_evidence_refs(text : String, prefix : String) -> Array[String] {
  let refs : Array[String] = []
  let normalized = text
    .replace_all(old=",", new=" ")
    .replace_all(old=";", new=" ")
    .replace_all(old="(", new=" ")
    .replace_all(old=")", new=" ")
    .replace_all(old="[", new=" ")
    .replace_all(old="]", new=" ")
    .replace_all(old="`", new=" ")
  for token in normalized.split(" ") {
    let item = token.trim().trim(chars=".:").to_string()
    if item.length() < 2 || !item.has_prefix(prefix) {
      continue
    }
    let suffix = item[prefix.length():]
    if suffix.is_empty() {
      continue
    }
    let mut all_digits = true
    for ch in suffix {
      if ch < '0' || ch > '9' {
        all_digits = false
        break
      }
    }
    if all_digits && !refs.contains(item) {
      refs.push(item)
    }
  }
  refs
}

///|
async fn read_workspace_text(root : String, relative : String) -> String {
  let path = @path.Path(root).join(@path.Path(relative)).to_string()
  if @fsx.exists(path) {
    @fsx.read_file(path)
  } else {
    ""
  }
}

///|
fn report_evidence(corpus : String, keyword : String) -> String {
  match best_report_paragraph(corpus, [keyword]) {
    Some(text) => clamp_text(text, 180)
    None => "Evidence pending"
  }
}

///|
fn report_evidence_from_rows(
  rows : Array[ResearchEvidenceRow],
  keywords : Array[String],
  fallback_corpus : String,
  fallback_keyword : String,
) -> String {
  let selected = select_evidence_rows(rows, keywords, 1)
  if selected.is_empty() {
    report_evidence(fallback_corpus, fallback_keyword)
  } else {
    clamp_text("\{selected[0].source_id}: \{row_brief(selected[0])}", 180)
  }
}

///|
fn select_evidence_rows(
  rows : Array[ResearchEvidenceRow],
  keywords : Array[String],
  limit : Int,
) -> Array[ResearchEvidenceRow] {
  let selected : Array[ResearchEvidenceRow] = []
  for row in rows {
    if evidence_row_matches(row, keywords) {
      selected.push(row)
      if selected.length() >= limit {
        break
      }
    }
  }
  if selected.is_empty() && !rows.is_empty() && limit > 0 {
    selected.push(rows[0])
  }
  selected
}

///|
fn evidence_row_matches(
  row : ResearchEvidenceRow,
  keywords : Array[String],
) -> Bool {
  let haystack = (row.source_id +
  " " +
  row.evidence +
  " " +
  row.locator +
  " " +
  row.confidence +
  " " +
  row.notes).to_lower()
  for keyword in keywords {
    let key = keyword.trim().to_lower()
    if !key.is_empty() && haystack.contains(key) {
      return true
    }
  }
  false
}

///|
fn row_list_sentence(rows : Array[ResearchEvidenceRow]) -> String {
  rows.map(fn(row) { "\{row.source_id} (\{row_brief(row)})" }).join("; ") + "."
}

///|
fn row_brief(row : ResearchEvidenceRow) -> String {
  let base = if !row.evidence.is_empty() {
    row.evidence
  } else if !row.locator.is_empty() {
    row.locator
  } else {
    row.notes
  }
  clamp_text(clean_report_text(base), 220)
}

///|
fn clean_report_text(text : String) -> String {
  let focused = match marker_tail(text, "preview=") {
    Some(value) => value
    None =>
      match marker_tail(text, "snippet=") {
        Some(value) => value
        None => text
      }
  }
  focused
  .replace_all(old="`", new="")
  .replace_all(old="**", new="")
  .replace_all(old="alias=", new="")
  .replace_all(old="path=", new="")
  .replace_all(old="original=", new="")
  .replace_all(old="preview=", new="")
  .replace_all(old="snippet=", new="")
  .replace_all(old="status=included", new="")
  .replace_all(old="status=fetched", new="")
  .to_string()
  .trim()
  .to_string()
}

///|
fn marker_tail(text : String, marker : String) -> String? {
  match text.find(marker) {
    Some(index) => Some(text[index + marker.length():].trim().to_string())
    None => None
  }
}

///|
fn best_report_paragraph(corpus : String, keywords : Array[String]) -> String? {
  let chunks = markdown_paragraphs(corpus)
  let mut best_score = 0
  let mut best_text : String? = None
  for chunk in chunks {
    let lowered = chunk.to_lower()
    let mut score = 0
    for keyword in keywords {
      let key = keyword.trim().to_lower()
      if !key.is_empty() && lowered.contains(key) {
        score += 1
      }
    }
    if score > best_score {
      best_score = score
      best_text = Some(clamp_text(chunk, 620))
    }
  }
  best_text
}

///|
fn markdown_paragraphs(content : String) -> Array[String] {
  let chunks : Array[String] = []
  let current : Array[String] = []
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if line.is_empty() {
      if !current.is_empty() {
        chunks.push(current.join(" "))
        current.clear()
      }
      continue
    }
    if line == "---" || line.has_prefix("```") {
      continue
    }
    if line.has_prefix("|") {
      continue
    }
    let cleaned = if line.has_prefix("#") {
      line.replace(old="#", new="").to_string().trim().to_string()
    } else {
      line
    }
    if !cleaned.is_empty() {
      current.push(cleaned)
    }
  }
  if !current.is_empty() {
    chunks.push(current.join(" "))
  }
  chunks
}

///|
fn clamp_text(text : String, max_len : Int) -> String {
  if text.length() <= max_len {
    text
  } else if max_len <= 3 {
    "...".to_string()
  } else {
    let builder = StringBuilder::new()
    let mut count = 0
    for ch in text {
      if count >= max_len - 3 {
        break
      }
      builder.write_char(ch)
      count += 1
    }
    builder.to_string() + "..."
  }
}

///|
priv struct ResearchArtifactSpec {
  title : String
  path : String
}

///|
fn research_artifact_specs() -> Array[ResearchArtifactSpec] {
  [
    { title: "Research question", path: "raw/bootstrap/research-question.md" },
    { title: "Search log", path: "raw/bootstrap/search-log.md" },
    { title: "Source screen", path: "raw/bootstrap/source-screen.md" },
    { title: "Evidence matrix", path: "raw/bootstrap/evidence-matrix.md" },
    { title: "Local sources", path: "raw/bootstrap/local-sources.md" },
    { title: "Synthesis brief", path: "raw/bootstrap/synthesis-brief.md" },
    { title: "Deep report", path: "raw/bootstrap/deep-report.md" },
  ]
}

///|
fn markdown_excerpt(content : String, max_len : Int) -> String {
  let parts : Array[String] = []

  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if line.is_empty() ||
      line.has_prefix("#") ||
      line.has_prefix("|") ||
      line == "---" ||
      line.has_prefix("```") {
      continue
    }
    parts.push(clean_report_text(line))
    if parts.join(" ").length() >= max_len {
      break
    }
  }
  let joined = parts.join(" ")
  if joined.is_empty() {
    return "Artifact exists but does not yet contain a readable summary."
  }
  clamp_text(joined, max_len)
}
