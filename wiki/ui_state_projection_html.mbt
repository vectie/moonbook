///|
// HTML, CSS, and JavaScript projection renderers for generated site surfaces.

fn marketing_projection_html(state : UiState, updated_note : String) -> String {
  ignore(updated_note)
  let book_prefix = "../../"
  let marketing_sections = marketing_brief_sections_html(state.marketing_brief)
  let hero_panels = marketing_hero_panels_html(state.marketing_brief)
  let research_article = research_article_projection_html(state)
  let product_story = escape_html(state.marketing_brief.lede)
  let project_title = escape_html(state.title)
  let hero_headline = escape_html(state.marketing_brief.headline)
  "<!doctype html>\n" +
  "<html lang=\"en\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\">\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" +
  "  <title>\{project_title} Marketing Projection</title>\n" +
  "  <meta name=\"description\" content=\"Marketing projection generated from MoonBook workspace state and product advantages.\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n" +
  "  <link href=\"https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap\" rel=\"stylesheet\">\n" +
  "  <script src=\"https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js\"></script>\n" +
  "  <link rel=\"stylesheet\" href=\"./styles.css\">\n" +
  "</head>\n" +
  "<body data-page=\"marketing\">\n" +
  "  <div class=\"backdrop\"></div>\n" +
  "  <header class=\"topbar\">\n" +
  "    <a class=\"brand\" href=\"\{book_prefix}index.html\"><span class=\"brand-mark\">MB</span><span>\{project_title}</span></a>\n" +
  "    <nav class=\"nav\">\n" +
  "      <a href=\"\{book_prefix}Home.html\">Wiki</a>\n" +
  "      <a href=\"\{book_prefix}index.html\">Book</a>\n" +
  "      <a href=\"#research\">Research</a>\n" +
  "      <a href=\"#features\">Story</a>\n" +
  "      <a href=\"#conversion\">Depth</a>\n" +
  "      <a href=\"./skills.html\">Skills</a>\n" +
  "    </nav>\n" +
  "  </header>\n" +
  "  <main class=\"page-shell\">\n" +
  "    <section class=\"hero reveal\">\n" +
  "      <div class=\"hero-copy\">\n" +
  "        <p class=\"eyebrow\">Product website</p>\n" +
  "        <h1>\{hero_headline}</h1>\n" +
  "        <p class=\"lede\">\{product_story}</p>\n" +
  "        <div class=\"hero-actions\">\n" +
  "          <a class=\"button button-primary\" href=\"#features\">See the product</a>\n" +
  "          <a class=\"button button-secondary\" href=\"\{book_prefix}Home.html\">Explore the wiki</a>\n" +
  "          <a class=\"button button-secondary\" href=\"./journal.html\">View progress</a>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "      <div class=\"hero-stage tilt\">\n" +
  "        \{hero_panels}\n" +
  "      </div>\n" +
  "    </section>\n" +
  research_article +
  "    <section class=\"section reveal\" id=\"features\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Product story</p>\n" +
  "        <h2>What the product offers, who it helps, and where readers should go next.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"workflow-grid\">\{marketing_sections}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"conversion\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Conversion path</p>\n" +
  "        <h2>Start with the product page, then open the surfaces that prove depth.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"depth-grid product-depth-grid\">\n" +
  "        <div class=\"depth-card\"><h3>For readers who want proof</h3><p>Keep the sales page focused, then route serious readers to the detailed wiki and structured book when they want substance.</p><div class=\"hero-actions stacked\"><a class=\"button button-secondary\" href=\"\{book_prefix}Home.html\">Open wiki</a><a class=\"button button-secondary\" href=\"\{book_prefix}index.html\">Open book</a></div></div>\n" +
  "        <div class=\"depth-card\"><h3>For teams who operate it</h3><p>The journal, course, and skill manager stay one click away without crowding the product story.</p><div class=\"hero-actions stacked\"><a class=\"button button-secondary\" href=\"./journal.html\">Journal</a><a class=\"button button-secondary\" href=\"./course.html\">Course</a><a class=\"button button-secondary\" href=\"./skills.html\">Skills</a></div></div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "  </main>\n" +
  "  <script src=\"./app.js\"></script>\n" +
  "</body>\n" +
  "</html>\n"
}

///|
fn marketing_projection_entry_html(state : UiState) -> String {
  let project_title = escape_html(state.title)
  "<!doctype html>\n" +
  "<html lang=\"en\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\">\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" +
  "  <meta http-equiv=\"refresh\" content=\"0; url=./generated/index.html\">\n" +
  "  <title>\{project_title} Marketing Projection</title>\n" +
  "  <meta name=\"description\" content=\"Opening the live generated marketing projection for \{project_title}.\">\n" +
  "  <link rel=\"canonical\" href=\"./generated/index.html\">\n" +
  "  <style>body{margin:0;min-height:100vh;display:grid;place-items:center;font-family:system-ui,sans-serif;background:#fff7ea;color:#13241f}.card{max-width:42rem;padding:2rem;border:1px solid rgba(19,36,31,.14);border-radius:24px;background:#fffaf2;box-shadow:0 24px 80px rgba(20,34,29,.12)}a{color:#173c34;font-weight:700}</style>\n" +
  "</head>\n" +
  "<body>\n" +
  "  <main class=\"card\">\n" +
  "    <p>Opening the live generated marketing projection for \{project_title}.</p>\n" +
  "    <p><a href=\"./generated/index.html\">Open generated projection</a></p>\n" +
  "  </main>\n" +
  "  <script>location.replace('./generated/index.html');</script>\n" +
  "</body>\n" +
  "</html>\n"
}

///|
fn marketing_panel_item(item : UiPanelItem) -> String {
  "<article class=\"panel-item\">" +
  "<strong>\{escape_html(item.title)}</strong>" +
  "<p>\{escape_html(item.detail)}</p>" +
  "<small>\{escape_html(item.meta)}</small>" +
  "</article>"
}

///|
fn marketing_journey_item(item : UiJourneyItem) -> String {
  let highlights = item.highlights
    .map(fn(highlight) { "<li>\{escape_html(highlight)}</li>" })
    .join("")
  "<article class=\"journey-card\">" +
  "<div class=\"journey-meta\"><span>\{escape_html(item.stage)}</span><span class=\"journey-status status-\{escape_html(item.status)}\">\{escape_html(item.status)}</span></div>" +
  "<h3>\{escape_html(item.title)}</h3>" +
  "<p>\{escape_html(item.summary)}</p>" +
  "<ul>\{highlights}</ul>" +
  "</article>"
}

///|
fn marketing_brief_sections_html(brief : UiMarketingBrief) -> String {
  let cards : Array[String] = []
  for section in brief.sections {
    if !section.title.trim().is_empty() &&
      (!section.body.trim().is_empty() || !section.bullets.is_empty()) {
      cards.push(marketing_brief_section_card(section))
    }
  }
  if cards.is_empty() {
    "<article class=\"workflow-card marketing-card\"><span class=\"workflow-status status-needed\">brief needed</span><h3>Marketing brief needs content</h3><p>Generate `raw/bootstrap/marketing-brief.md` from `skills/wiki-marketing/SKILL.md` so this page can present real buyer-facing positioning.</p></article>"
  } else {
    cards.join("")
  }
}

///|
fn marketing_hero_panels_html(brief : UiMarketingBrief) -> String {
  let first = brief.sections.get(0)
  let second = brief.sections.get(1)
  let first_panel = match first {
    Some(section) => marketing_hero_panel("product focus", section, false)
    None =>
      "<div class=\"panel-block\"><span class=\"panel-label\">product focus</span><p>\{escape_html(brief.lede)}</p></div>"
  }
  let second_panel = match second {
    Some(section) => marketing_hero_panel("reader value", section, true)
    None =>
      "<div class=\"panel-block panel-block-dark\"><span class=\"panel-label\">reader value</span><p>Open the deeper surfaces when you need proof, docs, timeline, or repeatable procedures.</p></div>"
  }
  first_panel + second_panel
}

///|
fn marketing_hero_panel(
  label : String,
  section : UiMarketingSection,
  dark : Bool,
) -> String {
  let block_class = if dark {
    "panel-block panel-block-dark"
  } else {
    "panel-block"
  }
  let bullets = if section.bullets.is_empty() {
    ""
  } else {
    let take_count = if section.bullets.length() < 3 {
      section.bullets.length()
    } else {
      3
    }
    let visible : Array[String] = []
    for index in 0..<take_count {
      visible.push(section.bullets[index])
    }
    "<ul class=\"hero-panel-list\">" +
    visible.map(fn(item) { "<li>\{escape_html(item)}</li>" }).join("") +
    "</ul>"
  }
  "<div class=\"\{block_class}\">" +
  "<span class=\"panel-label\">\{escape_html(label)}</span>" +
  "<h3>\{escape_html(section.title)}</h3>" +
  (if section.body.trim().is_empty() {
    ""
  } else {
    "<p>\{escape_html(section.body)}</p>"
  }) +
  bullets +
  "</div>"
}

///|
fn marketing_brief_section_card(section : UiMarketingSection) -> String {
  let body = section.body.trim().to_owned()
  let bullets = if section.bullets.is_empty() {
    ""
  } else {
    "<ul>" +
    section.bullets.map(fn(item) { "<li>\{escape_html(item)}</li>" }).join("") +
    "</ul>"
  }
  "<article class=\"workflow-card marketing-card\">" +
  "<span class=\"workflow-status status-active\">highlight</span>" +
  "<h3>\{escape_html(section.title)}</h3>" +
  (if body.is_empty() { "" } else { "<p>\{escape_html(body)}</p>" }) +
  bullets +
  "</article>"
}

///|
fn research_article_projection_html(state : UiState) -> String {
  if !state.research_long_report.trim().is_empty() {
    "<section class=\"section reveal\" id=\"research\">" +
    "<div class=\"section-heading\">" +
    "<p class=\"eyebrow\">Deep research</p>" +
    "<h2>The generated site should present the knowledge, not only the product shell.</h2>" +
    "</div>" +
    "<div class=\"article-layout\">" +
    report_toc_html(state.research_long_report, "report") +
    "<article class=\"long-report article-report\">" +
    markdown_report_html(state.research_long_report, "report") +
    "</article>" +
    "</div>" +
    "</section>"
  } else {
    let cards = state.research_report
      .map(fn(section) { research_report_card_html(section) })
      .join("")
    "<section class=\"section reveal\" id=\"research\">" +
    "<div class=\"section-heading\">" +
    "<p class=\"eyebrow\">Research readiness</p>" +
    "<h2>The article view needs `raw/bootstrap/deep-report.md` before it can match a deep-research page.</h2>" +
    "</div>" +
    "<div class=\"report-grid\">\{cards}</div>" +
    "</section>"
  }
}

///|
fn research_report_card_html(section : UiResearchReportSection) -> String {
  "<article class=\"report-card\">" +
  "<div class=\"report-card-head\"><span class=\"workflow-status status-needed\">research</span><h3>\{escape_html(section.title)}</h3></div>" +
  "<p>\{escape_html(section.detail)}</p>" +
  (if section.evidence.trim().is_empty() {
    ""
  } else {
    "<div class=\"report-evidence\">\{escape_html(section.evidence)}</div>"
  }) +
  "</article>"
}

///|
fn markdown_report_html(markdown : String, id_prefix : String) -> String {
  let lines = markdown.split("\n").to_array()
  let html : Array[String] = []
  let mut index = 0
  let mut heading_index = 0
  let mut list_tag = ""
  while index < lines.length() {
    let line = lines[index].trim().to_owned()
    if line.is_empty() {
      if !list_tag.is_empty() {
        html.push("</\{list_tag}>")
        list_tag = ""
      }
      index += 1
      continue
    }
    let details_prefix = "<details><summary>reveal answer</summary>"
    if line.to_lower().has_prefix(details_prefix) {
      let details_start = index
      if !list_tag.is_empty() {
        html.push("</\{list_tag}>")
        list_tag = ""
      }
      let answer_parts : Array[String] = []
      let mut first = line[details_prefix.length():].trim().to_owned()
      if first.to_lower().has_suffix("</details>") {
        first = first[:first.length() - 10].trim().to_owned()
      }
      if !first.is_empty() {
        answer_parts.push(first)
      }
      let mut closed = line.to_lower().has_suffix("</details>")
      index += 1
      while index < lines.length() && !closed {
        let mut part = lines[index].trim().to_owned()
        if part.to_lower().has_suffix("</details>") {
          part = part[:part.length() - 10].trim().to_owned()
          closed = true
        }
        if !part.is_empty() {
          answer_parts.push(part)
        }
        index += 1
      }
      if closed {
        html.push(reader_answer_disclosure_html(answer_parts.join(" ")))
      } else {
        html.push(markdown_reader_paragraph_html(line))
        index = details_start + 1
      }
      continue
    }
    if line.has_prefix("```mermaid") {
      if !list_tag.is_empty() {
        html.push("</\{list_tag}>")
        list_tag = ""
      }
      let code : Array[String] = []
      index += 1
      while index < lines.length() && !lines[index].trim().has_prefix("```") {
        code.push(lines[index].to_owned())
        index += 1
      }
      let rendered_code = escape_html(code.join("\n"))
      html.push("<div class=\"mermaid report-mermaid\">\{rendered_code}</div>")
      index += 1
      continue
    }
    if line.has_prefix("```") {
      if !list_tag.is_empty() {
        html.push("</\{list_tag}>")
        list_tag = ""
      }
      let code : Array[String] = []
      index += 1
      while index < lines.length() && !lines[index].trim().has_prefix("```") {
        code.push(lines[index].to_owned())
        index += 1
      }
      let rendered_code = escape_html(code.join("\n"))
      html.push(
        "<pre class=\"report-code\"><code>\{rendered_code}</code></pre>",
      )
      index += 1
      continue
    }
    if line.has_prefix("|") {
      if !list_tag.is_empty() {
        html.push("</\{list_tag}>")
        list_tag = ""
      }
      let table_lines : Array[String] = []
      while index < lines.length() && lines[index].trim().has_prefix("|") {
        table_lines.push(lines[index].trim().to_owned())
        index += 1
      }
      html.push(markdown_table_html(table_lines))
      continue
    }
    if line.has_prefix("- ") {
      if list_tag != "ul" {
        if !list_tag.is_empty() {
          html.push("</\{list_tag}>")
        }
        html.push("<ul>")
        list_tag = "ul"
      }
      html.push("<li>\{inline_markdown_html(line[2:].trim().to_owned())}</li>")
      index += 1
      continue
    }
    match reader_numbered_item(line) {
      Some(item) => {
        if list_tag != "ol" {
          if !list_tag.is_empty() {
            html.push("</\{list_tag}>")
          }
          html.push("<ol>")
          list_tag = "ol"
        }
        html.push("<li>\{inline_markdown_html(item)}</li>")
        index += 1
        continue
      }
      None => ()
    }
    if !list_tag.is_empty() {
      html.push("</\{list_tag}>")
      list_tag = ""
    }
    if line.has_prefix("# ") {
      heading_index += 1
      html.push(
        "<h2 id=\"\{escape_html(id_prefix)}-sec-\{heading_index}\">\{inline_markdown_html(line[2:].trim().to_owned())}</h2>",
      )
    } else if line.has_prefix("## ") {
      heading_index += 1
      html.push(
        "<h3 id=\"\{escape_html(id_prefix)}-sec-\{heading_index}\">\{inline_markdown_html(line[3:].trim().to_owned())}</h3>",
      )
    } else if line.has_prefix("### ") {
      html.push(markdown_reader_heading_html(line[4:].trim().to_owned()))
    } else {
      html.push(markdown_reader_paragraph_html(line))
    }
    index += 1
  }
  if !list_tag.is_empty() {
    html.push("</\{list_tag}>")
  }
  html.join("")
}

///|
fn markdown_reader_heading_html(title : String) -> String {
  let tone = match title.to_lower() {
    "objective" | "plain explanation" => "orientation"
    "why it matters" => "meaning"
    "worked example" | "concrete example" | "example" => "example"
    "exercise" | "output artifact" | "transfer" | "transfer task" => "practice"
    "checkpoint" | "retrieval" | "retrieval checkpoint" | "self-explanation" =>
      "checkpoint"
    "sources and limitations" | "sources / limitations" => "trace"
    "common mistake" | "revisit" => "caution"
    _ => ""
  }
  if tone.is_empty() {
    "<h4>\{inline_markdown_html(title)}</h4>"
  } else {
    "<h4 class=\"reader-section-heading reader-section-heading-\{tone}\">\{inline_markdown_html(title)}</h4>"
  }
}

///|
fn markdown_reader_paragraph_html(line : String) -> String {
  let lower = line.to_lower()
  let details_prefix = "<details><summary>reveal answer</summary>"
  if lower.has_prefix(details_prefix) && lower.has_suffix("</details>") {
    let answer = line[details_prefix.length():line.length() - 10]
      .trim()
      .to_owned()
    return reader_answer_disclosure_html(answer)
  }
  for
    spec in [
      ("objective:", "Objective", "orientation"),
      ("plain explanation:", "Plain explanation", "orientation"),
      ("why it matters:", "Why it matters", "meaning"),
      ("concrete example:", "Example", "example"),
      ("example:", "Example", "example"),
      ("worked example:", "Worked example", "example"),
      ("exercise:", "Exercise", "practice"),
      ("output artifact:", "Output artifact", "practice"),
      ("checkpoint:", "Checkpoint", "checkpoint"),
      ("checkpoint answer:", "Checkpoint answer", "answer"),
      ("self-explanation:", "Self-explanation", "checkpoint"),
      ("retrieval checkpoint:", "Retrieval checkpoint", "checkpoint"),
      ("retrieval:", "Retrieval checkpoint", "checkpoint"),
      ("transfer task:", "Transfer task", "practice"),
      ("transfer:", "Transfer task", "practice"),
      ("sources / limitations:", "Sources and limitations", "trace"),
      ("sources and limitations:", "Sources and limitations", "trace"),
      ("revisit:", "Revisit", "caution"),
      ("common mistake:", "Common mistake", "caution"),
    ] {
    if lower.has_prefix(spec.0) {
      let detail = line[spec.0.length():].trim().to_owned()
      if spec.2 == "answer" {
        return reader_answer_disclosure_html(detail)
      }
      return "<aside class=\"reader-callout reader-callout-\{spec.2}\"><span>\{escape_html(spec.1)}</span><p>\{inline_markdown_html(detail)}</p></aside>"
    }
  }
  "<p>\{inline_markdown_html(line)}</p>"
}

///|
fn reader_answer_disclosure_html(answer : String) -> String {
  "<details class=\"reader-answer\"><summary>Reveal answer</summary><p>\{inline_markdown_html(answer)}</p></details>"
}

///|
fn report_toc_html(markdown : String, id_prefix : String) -> String {
  let links : Array[String] = []
  let mut heading_index = 0
  for raw in markdown.split("\n") {
    let line = raw.trim().to_owned()
    if line.has_prefix("# ") || line.has_prefix("## ") {
      heading_index += 1
      let title = if line.has_prefix("## ") {
        line[3:].trim().to_owned()
      } else {
        line[2:].trim().to_owned()
      }
      if !title.is_empty() && links.length() < 14 {
        links.push(
          "<a href=\"#\{escape_html(id_prefix)}-sec-\{heading_index}\">\{inline_markdown_html(title)}</a>",
        )
      }
    }
  }
  if links.is_empty() {
    ""
  } else {
    let body = links.join("")
    "<aside class=\"article-toc\"><p class=\"eyebrow\">Contents</p>\{body}</aside>"
  }
}

///|
fn markdown_table_html(lines : Array[String]) -> String {
  let rows : Array[String] = []
  let mut is_head = true
  for raw in lines {
    if raw.contains("---") {
      continue
    }
    let cells = raw
      .split("|")
      .map(fn(part) { part.trim().to_owned() })
      .to_array()
    let visible : Array[String] = []
    for cell in cells {
      if !cell.is_empty() {
        visible.push(cell)
      }
    }
    if visible.is_empty() {
      continue
    }
    let tag = if is_head { "th" } else { "td" }
    rows.push(
      "<tr>" +
      visible
      .map(fn(cell) { "<\{tag}>\{inline_markdown_html(cell)}</\{tag}>" })
      .join("") +
      "</tr>",
    )
    is_head = false
  }
  if rows.is_empty() {
    ""
  } else {
    let body = rows.join("")
    "<div class=\"report-table-wrap\"><table class=\"report-table\">\{body}</table></div>"
  }
}

///|
fn inline_markdown_html(text : String) -> String {
  escape_html(text)
  .replace_all(old="**", new="")
  .replace_all(old="`", new="")
  .to_string()
}

///|
async fn marketing_update_note(root : String) -> String {
  let workspace = workspace_paths(root)
  let log_path = moonbook_wiki_path(workspace.wiki_dir)
    .join(moonbook_wiki_path("log.md"))
    .to_string()
  if !@fsx.exists(log_path) {
    return "No log available."
  }
  let lines = @fsx.read_file(log_path).split("\n").to_array()
  for index = lines.length() - 1; index >= 0; index = index - 1 {
    let line = lines[index].trim().to_owned()
    if line.has_prefix("## [") {
      return line
    }
  }
  "Workspace log present."
}

///|
fn journal_projection_html(state : UiState, updated_note : String) -> String {
  let book_prefix = "../../"
  let timeline = state.journey
    .map(fn(item) { marketing_journey_item(item) })
    .join("")
  let stages = state.workflow
    .map(fn(item) {
      "<article class=\"module-card\">" +
      "<span class=\"module-kicker\">\{escape_html(item.status)}</span>" +
      "<h3>\{escape_html(item.title)}</h3>" +
      "<p>\{escape_html(item.detail)}</p>" +
      "</article>"
    })
    .join("")
  let metrics = state.metrics
    .map(fn(metric) {
      "<article class=\"metric-card metric-\{metric.tone}\">" +
      "<span class=\"metric-label\">\{escape_html(metric.label)}</span>" +
      "<strong>\{escape_html(metric.value)}</strong>" +
      "<p>\{escape_html(metric.note)}</p>" +
      "</article>"
    })
    .join("")
  let chapters = state.chapters
    .map(fn(item) {
      "<a class=\"chapter-link\" href=\"\{book_prefix}\{escape_html(item.href)}\">" +
      "<span class=\"chapter-number\">\{escape_html(item.number)}</span>" +
      "<span class=\"chapter-copy\"><strong>\{escape_html(item.title)}</strong><small>\{escape_html(item.source_path)}</small></span>" +
      "</a>"
    })
    .join("")
  let next_actions = state.readiness
    .map(fn(item) { marketing_panel_item(item) })
    .join("")
  let synthesis_preview = escape_html(state.synthesis_preview)
  let update_note_html = escape_html(updated_note)
  "<!doctype html>\n" +
  "<html lang=\"en\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\">\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" +
  "  <title>\{escape_html(state.title)} Journal</title>\n" +
  "  <meta name=\"description\" content=\"Journal view generated from MoonBook journey and wiki state.\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n" +
  "  <link href=\"https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap\" rel=\"stylesheet\">\n" +
  "  <link rel=\"stylesheet\" href=\"./styles.css\">\n" +
  "</head>\n" +
  "<body data-page=\"journal\">\n" +
  "  <div class=\"backdrop\"></div>\n" +
  "  <header class=\"topbar\">\n" +
  "    <a class=\"brand\" href=\"./index.html\"><span class=\"brand-mark\">MB</span><span>\{escape_html(state.title)}</span></a>\n" +
  "    <nav class=\"nav\">\n" +
  "      <a href=\"./index.html\">Marketing</a>\n" +
  "      <a href=\"./skills.html\">Skills</a>\n" +
  "      <a href=\"\{book_prefix}Home.html\">Wiki</a>\n" +
  "      <a href=\"#timeline\">Timeline</a>\n" +
  "      <a href=\"#next\">Next</a>\n" +
  "    </nav>\n" +
  "  </header>\n" +
  "  <main class=\"page-shell journal-shell\">\n" +
  "    <section class=\"hero reveal\">\n" +
  "      <div class=\"hero-copy\">\n" +
  "        <p class=\"eyebrow\">Journal view</p>\n" +
  "        <h1>Follow the book from earlier runs through the current state and the next pressure points.</h1>\n" +
  "        <p class=\"lede\">\{escape_html(state.summary)}</p>\n" +
  "        <div class=\"hero-actions\">\n" +
  "          <a class=\"button button-primary\" href=\"\{book_prefix}Home.html\">Open maintained wiki</a>\n" +
  "          <a class=\"button button-secondary\" href=\"./index.html\">Back to marketing</a>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "      <div class=\"hero-stage\">\n" +
  "        <div class=\"panel-block\">\n" +
  "          <span class=\"panel-label\">What changed recently</span>\n" +
  "          <pre><code>\{update_note_html}</code></pre>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Current operating shape</p>\n" +
  "        <h2>What phases define the book right now.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"workflow-grid\">\{stages}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"timeline\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Past to now</p>\n" +
  "        <h2>Timeline of major runs, decisions, and open loops.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"journey-grid\">\{timeline}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Now</p>\n" +
  "        <h2>The current state that the timeline has produced.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"metric-grid\">\{metrics}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"next\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Future</p>\n" +
  "        <h2>What still needs attention next.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"triple-grid\">\n" +
  "        <div class=\"panel-shell\"><h3>Next actions</h3>\{next_actions}</div>\n" +
  "        <div class=\"depth-card\"><h3>Chapter links</h3><div class=\"chapter-stack\">\{chapters}</div></div>\n" +
  "        <div class=\"depth-card\"><h3>Synthesis preview</h3><pre class=\"preview-block\"><code>\{synthesis_preview}</code></pre></div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "  </main>\n" +
  "  <script src=\"./app.js\"></script>\n" +
  "</body>\n" +
  "</html>\n"
}

///|
fn course_projection_html(
  state : UiState,
  reader : ReaderArtifactBundle,
  projections : UiReaderProjectionBundle,
) -> String {
  let book_prefix = "../../"
  let selector = reader_view_selector_html(reader, projections)
  let learn = reader_view_panel_html(reader.learn, projections.learn, false)
  let apply = reader_view_panel_html(reader.apply, projections.apply, true)
  let research = reader_view_panel_html(
    reader.research,
    projections.research,
    true,
  )
  let maintenance_trace = reader_maintenance_trace_html(reader, projections)
  "<!doctype html>\n" +
  "<html lang=\"en\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\">\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" +
  "  <title>\{escape_html(state.title)} Reader</title>\n" +
  "  <meta name=\"description\" content=\"Reader-first Learn, Apply, and Research views generated from MoonBook artifacts.\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n" +
  "  <link href=\"https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap\" rel=\"stylesheet\">\n" +
  "  <link rel=\"stylesheet\" href=\"./styles.css\">\n" +
  "</head>\n" +
  "<body data-page=\"reader\">\n" +
  "  <div class=\"backdrop\"></div>\n" +
  "  <header class=\"topbar\">\n" +
  "    <a class=\"brand\" href=\"./index.html\"><span class=\"brand-mark\">MB</span><span>\{escape_html(state.title)}</span></a>\n" +
  "    <nav class=\"nav\">\n" +
  "      <a href=\"./course.html?view=learn\" data-reader-nav=\"learn\">Learn</a>\n" +
  "      <a href=\"./course.html?view=apply\" data-reader-nav=\"apply\">Apply</a>\n" +
  "      <a href=\"./course.html?view=research\" data-reader-nav=\"research\">Research</a>\n" +
  "      <a class=\"nav-maintenance\" href=\"#maintenance\">How it is maintained</a>\n" +
  "    </nav>\n" +
  "  </header>\n" +
  "  <main class=\"page-shell reader-shell\">\n" +
  "    <section class=\"hero reveal\">\n" +
  "      <div class=\"hero-copy\">\n" +
  "        <p class=\"eyebrow\">Reader views</p>\n" +
  "        <h1>Read \{escape_html(state.title)} at the depth you need.</h1>\n" +
  "        <p class=\"lede\">Start with a plain-language path, move into practice, or inspect the underlying research. Every view comes from this book's artifacts; unavailable content stays visibly unavailable.</p>\n" +
  "      </div>\n" +
  "      <div class=\"hero-stage reader-principle\">\n" +
  "        <div class=\"panel-block\">\n" +
  "          <span class=\"panel-label\">One book, three routes</span>\n" +
  "          <p><strong>Learn</strong> builds orientation. <strong>Apply</strong> turns ideas into an artifact. <strong>Research</strong> exposes claims and evidence.</p>\n" +
  "        </div>\n" +
  "        <div class=\"panel-block panel-block-dark\">\n" +
  "          <span class=\"panel-label\">Truth boundary</span>\n" +
  "          <p>Simplification changes presentation, never the accepted source. Each view names the artifact it rendered.</p>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal reader-route-section\" aria-label=\"Choose a reading route\">\n" +
  "      \{selector}\n" +
  "    </section>\n" +
  "    \{learn}\n" +
  "    \{apply}\n" +
  "    \{research}\n" +
  "    <section class=\"section reveal maintenance-section\" id=\"maintenance\">\n" +
  "      <details class=\"maintenance-disclosure\">\n" +
  "        <summary><span><small>Separate operator surface</small>How this book is maintained</span><span aria-hidden=\"true\">＋</span></summary>\n" +
  "        <div class=\"maintenance-body\">\n" +
  "          <p>Reader views contain domain knowledge. Workflow state, journals, skill diagnostics, and canonical wiki pages remain available without interrupting the reading path.</p>\n" +
  "          \{maintenance_trace}\n" +
  "          <div class=\"hero-actions\"><a class=\"button button-secondary\" href=\"\{book_prefix}Home.html\">Maintained wiki</a><a class=\"button button-secondary\" href=\"./reader-state.json\">Reader quality record</a><a class=\"button button-secondary\" href=\"./journal.html\">Journal</a><a class=\"button button-secondary\" href=\"./skills.html\">Skill diagnostics</a></div>\n" +
  "        </div>\n" +
  "      </details>\n" +
  "    </section>\n" +
  "  </main>\n" +
  "  <script src=\"./app.js\"></script>\n" +
  "</body>\n" +
  "</html>\n"
}

///|
fn reader_view_selector_html(
  reader : ReaderArtifactBundle,
  projections : UiReaderProjectionBundle,
) -> String {
  "<nav class=\"reader-view-selector\" aria-label=\"Reading depth\">" +
  reader_view_selector_item(reader.learn, projections.learn, true) +
  reader_view_selector_item(reader.apply, projections.apply, false) +
  reader_view_selector_item(reader.research, projections.research, false) +
  "</nav>"
}

///|
fn reader_view_selector_item(
  artifact : ReaderArtifactContent,
  projection : @reader_projection.ReaderProjection,
  selected : Bool,
) -> String {
  let selected_class = if selected { " is-selected" } else { "" }
  let current = if selected { " aria-current=\"page\"" } else { "" }
  let availability = reader_artifact_status_label(artifact, projection)
  let availability_class = if !artifact.available {
    "is-missing"
  } else if projection.source_review_status() == Accepted &&
    projection.projection_review_status() == Accepted {
    "is-ready"
  } else {
    "is-draft"
  }
  let explanation = match artifact.view {
    "learn" => "Understand the idea"
    "apply" => "Make something with it"
    _ => "Inspect claims and evidence"
  }
  "<a class=\"reader-view-choice\{selected_class}\" href=\"./course.html?view=\{escape_html(artifact.view)}\" data-reader-choice=\"\{escape_html(artifact.view)}\"\{current}>" +
  "<span class=\"reader-view-icon\" aria-hidden=\"true\">\{reader_view_icon(artifact.view)}</span>" +
  "<span><strong>\{escape_html(artifact.label)}</strong><small>\{escape_html(explanation)}</small></span>" +
  "<em class=\"reader-availability \{availability_class}\">\{escape_html(availability)}</em>" +
  "</a>"
}

///|
fn reader_view_icon(view : String) -> String {
  match view {
    "learn" => "◎"
    "apply" => "◇"
    _ => "⌁"
  }
}

///|
fn reader_artifact_status_label(
  artifact : ReaderArtifactContent,
  projection : @reader_projection.ReaderProjection,
) -> String {
  if !artifact.available {
    "Missing"
  } else if projection.source_review_status() == Accepted &&
    projection.projection_review_status() == Accepted {
    "Accepted"
  } else if projection.source_review_status() == Accepted {
    "Projection review needed"
  } else {
    "Needs review"
  }
}

///|
fn reader_view_panel_html(
  artifact : ReaderArtifactContent,
  projection : @reader_projection.ReaderProjection,
  hidden : Bool,
) -> String {
  let hidden_attr = if hidden { " hidden" } else { "" }
  let meta = if artifact.available {
    "<span>About \{artifact.estimated_minutes.to_string()} min</span><span>\{escape_html(reader_artifact_status_label(artifact, projection))}</span>"
  } else {
    "<span>Source not ready</span>"
  }
  let body = if artifact.available {
    let id_prefix = "reader-\{artifact.view}"
    "<div class=\"article-layout reader-article-layout\">" +
    report_toc_html(artifact.markdown, id_prefix) +
    "<article class=\"long-report article-report reader-article\">" +
    markdown_report_html(artifact.markdown, id_prefix) +
    "</article></div>"
  } else {
    "<div class=\"reader-empty\"><span class=\"reader-empty-icon\" aria-hidden=\"true\">○</span><div><h3>Nothing is being hidden</h3><p>\{escape_html(artifact.summary)}</p></div></div>"
  }
  "<section class=\"section reveal reader-panel\" data-reader-panel=\"\{escape_html(artifact.view)}\"\{hidden_attr}>" +
  "<div class=\"reader-panel-heading\"><div><p class=\"eyebrow\">\{escape_html(artifact.label)} view</p><h2>\{escape_html(artifact.title)}</h2><p class=\"lede\">\{escape_html(artifact.summary)}</p></div><div class=\"reader-source-meta\">\{meta}</div></div>" +
  "<aside class=\"reader-next-action\"><span class=\"panel-label\">Your next move</span><strong>\{escape_html(artifact.next_action)}</strong></aside>" +
  body +
  "</section>"
}

///|
fn reader_maintenance_trace_html(
  reader : ReaderArtifactBundle,
  projections : UiReaderProjectionBundle,
) -> String {
  let cards = reader_maintenance_trace_card(reader.learn, projections.learn) +
    reader_maintenance_trace_card(reader.apply, projections.apply) +
    reader_maintenance_trace_card(reader.research, projections.research)
  "<div class=\"reader-trace-grid\">\{cards}</div>"
}

///|
fn reader_maintenance_trace_card(
  artifact : ReaderArtifactContent,
  projection : @reader_projection.ReaderProjection,
) -> String {
  let readiness = projection.readiness()
  let release_status = if readiness.publishable {
    "Publishable"
  } else {
    "Draft preview"
  }
  "<article class=\"reader-trace-card\"><div><strong>\{escape_html(artifact.label)}</strong><span>\{escape_html(release_status)}</span></div><p>\{escape_html(artifact.source_path)}</p><dl><div><dt>Reader quality</dt><dd>\{readiness.reader_quality_score.to_string()}/100 · \{readiness.quality_dimensions_ready.to_string()}/9 dimensions</dd></div><div><dt>Open gaps</dt><dd>\{readiness.issues.length().to_string()}</dd></div><div><dt>Source review</dt><dd>\{escape_html(projection.source_review_status().key())}</dd></div><div><dt>Revision</dt><dd>\{escape_html(artifact.source_revision)}</dd></div><div><dt>Digest</dt><dd>\{escape_html(artifact.source_digest)}</dd></div></dl></article>"
}

///|
fn skills_projection_html(state : UiState, updated_note : String) -> String {
  let book_prefix = "../../"
  let diagnostics = state.skill_diagnostics
  let metric_cards = [
      {
        label: "Tracked Skills",
        value: diagnostics.total_count.to_string(),
        note: "Workspace plus seeded core and extension skills visible in one surface.",
        tone: "healthy",
      },
      {
        label: "Workspace Overrides",
        value: diagnostics.workspace_count.to_string(),
        note: "Skills living under the active workspace `skills/` directory.",
        tone: if diagnostics.workspace_count > 0 {
          "review"
        } else {
          "info"
        },
      },
      {
        label: "Duplicate Names",
        value: diagnostics.duplicate_count.to_string(),
        note: "Name collisions across scopes that can confuse selection and override behavior.",
        tone: if diagnostics.duplicate_count > 0 {
          "alert"
        } else {
          "healthy"
        },
      },
      {
        label: "Missing References",
        value: diagnostics.missing_reference_count.to_string(),
        note: "Bundled `references/` paths mentioned by skills but missing on disk.",
        tone: if diagnostics.missing_reference_count > 0 {
          "alert"
        } else {
          "healthy"
        },
      },
    ]
    .map(fn(metric) {
      "<article class=\"metric-card metric-\{metric.tone}\">" +
      "<span class=\"metric-label\">\{escape_html(metric.label)}</span>" +
      "<strong>\{escape_html(metric.value)}</strong>" +
      "<p>\{escape_html(metric.note)}</p>" +
      "</article>"
    })
    .join("")
  let first_skill = if state.skills.is_empty() {
    empty_ui_skill_item()
  } else {
    state.skills[0]
  }
  let duplicate_items = if diagnostics.duplicate_names.is_empty() {
    "<article class=\"panel-item\"><strong>No duplicate names</strong><p>The current inventory does not collide on skill names.</p><small>healthy</small></article>"
  } else {
    diagnostics.duplicate_names
    .map(fn(name) {
      "<article class=\"panel-item\"><strong>\{escape_html(name)}</strong><p>This skill name exists in more than one scope. Check the detail panel to see override and shadow relationships.</p><small>duplicate</small></article>"
    })
    .join("")
  }
  let warning_items = if diagnostics.warnings.is_empty() {
    "<article class=\"panel-item\"><strong>No doctor warnings</strong><p>The skill inventory has no extra warnings beyond duplicates or missing references.</p><small>clean</small></article>"
  } else {
    diagnostics.warnings
    .map(fn(warning) {
      "<article class=\"panel-item\"><strong>Doctor warning</strong><p>\{escape_html(warning)}</p><small>attention</small></article>"
    })
    .join("")
  }
  let first_skill_references = join_lines(first_skill.references)
  let first_skill_overrides = join_lines_or_default(
    first_skill.overrides,
    "None",
  )
  let first_skill_shadowed = join_lines_or_default(
    first_skill.shadowed_by,
    "Not shadowed",
  )
  let first_skill_selected_excerpt = join_lines_or_default(
    first_skill.compare_selected_excerpt,
    "No selected excerpt.",
  )
  let first_skill_baseline_excerpt = join_lines_or_default(
    first_skill.compare_baseline_excerpt,
    "No baseline excerpt.",
  )
  let root_json = escape_html(state.root)
  let skill_rows = state.skills
    .map(fn(skill) {
      let extension_attr = if skill.extension == "-" {
        ""
      } else {
        " data-extension=\"\{escape_html(skill.extension)}\""
      }
      let duplicate = if skill.duplicate { "true" } else { "false" }
      let scope_tone = if skill.scope == "workspace" {
        "review"
      } else if skill.scope == "seed-extension" {
        "alert"
      } else {
        "healthy"
      }
      let duplicate_badge = if skill.duplicate {
        "<span class=\"chip chip-alert\">duplicate</span>"
      } else {
        ""
      }
      let description = if skill.description.is_empty() {
        "No description."
      } else {
        skill.description
      }
      "<button class=\"skill-row\" type=\"button\" data-skill-key=\"\{escape_html(skill.key)}\" data-skill-name=\"\{escape_html(skill.name)}\" data-scope=\"\{escape_html(skill.scope)}\" data-origin=\"\{escape_html(skill.origin)}\" data-duplicate=\"\{duplicate}\"\{extension_attr}>" +
      "<span class=\"skill-row-head\"><strong>\{escape_html(skill.name)}</strong><span class=\"skill-badges\"><span class=\"chip chip-\{scope_tone}\">\{escape_html(skill.scope)}</span>\{duplicate_badge}</span></span>" +
      "<span class=\"skill-row-body\">\{escape_html(description)}</span>" +
      "<span class=\"skill-row-meta\">\{escape_html(skill.extension)} · \{escape_html(skill.path)}</span>" +
      "</button>"
    })
    .join("")
  let skills_json = escape_html(state.to_json().stringify(indent=2))
  "<!doctype html>\n" +
  "<html lang=\"en\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\">\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" +
  "  <title>\{escape_html(state.title)} Skills</title>\n" +
  "  <meta name=\"description\" content=\"Skill manager view generated from MoonBook skill inventory and diagnostics.\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n" +
  "  <link href=\"https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap\" rel=\"stylesheet\">\n" +
  "  <link rel=\"stylesheet\" href=\"./styles.css\">\n" +
  "</head>\n" +
  "<body data-page=\"skills\">\n" +
  "  <div class=\"backdrop\"></div>\n" +
  "  <header class=\"topbar\">\n" +
  "    <a class=\"brand\" href=\"./index.html\"><span class=\"brand-mark\">MB</span><span>\{escape_html(state.title)}</span></a>\n" +
  "    <nav class=\"nav\">\n" +
  "      <a href=\"./index.html\">Marketing</a>\n" +
  "      <a href=\"./journal.html\">Journal</a>\n" +
  "      <a href=\"./course.html\">Course</a>\n" +
  "      <a href=\"\{book_prefix}Home.html\">Wiki</a>\n" +
  "      <a href=\"#explorer\">Explorer</a>\n" +
  "    </nav>\n" +
  "  </header>\n" +
  "  <main class=\"page-shell journal-shell\">\n" +
  "    <section class=\"hero reveal\">\n" +
  "      <div class=\"hero-copy\">\n" +
  "        <p class=\"eyebrow\">Skill manager</p>\n" +
  "        <h1>Scan, compare, and inspect the skills that actually steer this workspace.</h1>\n" +
  "        <p class=\"lede\">This surface pulls together workspace overrides, core seeded skills, extension skill packs, duplicate names, bundled references, and doctor warnings in one browser view.</p>\n" +
  "        <div class=\"hero-actions\">\n" +
  "          <a class=\"button button-primary\" href=\"#explorer\">Open explorer</a>\n" +
  "          <a class=\"button button-secondary\" href=\"\{book_prefix}Home.html\">Open wiki</a>\n" +
  "          <a class=\"button button-secondary\" href=\"./index.html\">Back to marketing</a>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "      <div class=\"hero-stage tilt\">\n" +
  "        <div class=\"panel-block\">\n" +
  "          <span class=\"panel-label\">what changed</span>\n" +
  "          <pre><code>\{escape_html(updated_note)}</code></pre>\n" +
  "        </div>\n" +
  "        <div class=\"panel-block panel-block-dark\">\n" +
  "          <span class=\"panel-label\">first resolved skill</span>\n" +
  "          <p><strong>\{escape_html(first_skill.name)}</strong></p>\n" +
  "          <p>\{escape_html(first_skill.description)}</p>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Inventory</p>\n" +
  "        <h2>Browser-first visibility over the skill substrate.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"metric-grid\">\{metric_cards}</div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Pressure points</p>\n" +
  "        <h2>Duplicate names and doctor warnings stay visible.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"triple-grid skill-diagnostics-grid\">\n" +
  "        <div class=\"panel-shell\"><h3>Duplicate names</h3>\{duplicate_items}</div>\n" +
  "        <div class=\"panel-shell\"><h3>Doctor warnings</h3>\{warning_items}</div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"explorer\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Explorer</p>\n" +
  "        <h2>Filter the inventory, then inspect one skill in detail.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"skill-explorer\">\n" +
  "        <aside class=\"skill-sidebar panel-shell\">\n" +
  "          <div class=\"skill-toolbar\">\n" +
  "            <input id=\"skill-search\" class=\"skill-search\" type=\"search\" placeholder=\"Search skills, scopes, or origins\">\n" +
  "            <div class=\"skill-filters\">\n" +
  "              <button class=\"filter-pill is-active\" type=\"button\" data-skill-filter=\"all\">All</button>\n" +
  "              <button class=\"filter-pill\" type=\"button\" data-skill-filter=\"workspace\">Workspace</button>\n" +
  "              <button class=\"filter-pill\" type=\"button\" data-skill-filter=\"seed-core\">Seed Core</button>\n" +
  "              <button class=\"filter-pill\" type=\"button\" data-skill-filter=\"seed-extension\">Seed Extension</button>\n" +
  "              <button class=\"filter-pill\" type=\"button\" data-skill-filter=\"duplicate\">Duplicates</button>\n" +
  "            </div>\n" +
  "          </div>\n" +
  "          <div id=\"skill-list\" class=\"skill-list\">\{skill_rows}</div>\n" +
  "          <p id=\"skill-empty\" class=\"skill-empty\" hidden>No skills match the current filter.</p>\n" +
  "        </aside>\n" +
  "        <section class=\"skill-detail panel-shell\">\n" +
  "          <div class=\"skill-detail-head\">\n" +
  "            <div>\n" +
  "              <p class=\"eyebrow\">Selected skill</p>\n" +
  "              <h3 id=\"skill-detail-name\">\{escape_html(first_skill.name)}</h3>\n" +
  "            </div>\n" +
  "            <div id=\"skill-detail-badges\" class=\"chip-row\"></div>\n" +
  "          </div>\n" +
  "          <p id=\"skill-detail-description\" class=\"lede skill-detail-description\">\{escape_html(first_skill.description)}</p>\n" +
  "          <div class=\"skill-detail-grid\">\n" +
  "            <article class=\"panel-item\"><strong>Path</strong><p id=\"skill-detail-path\">\{escape_html(first_skill.path)}</p><small>resolved source</small></article>\n" +
  "            <article class=\"panel-item\"><strong>Origin</strong><p id=\"skill-detail-origin\">\{escape_html(first_skill.origin)}</p><small id=\"skill-detail-extension\">\{escape_html(first_skill.extension)}</small></article>\n" +
  "            <article class=\"panel-item\"><strong>References</strong><p id=\"skill-detail-references\">\{escape_html(first_skill_references)}</p><small>bundled detail files</small></article>\n" +
  "            <article class=\"panel-item\"><strong>Overrides / Shadowing</strong><p id=\"skill-detail-overrides\">\{escape_html(first_skill_overrides)}</p><small id=\"skill-detail-shadowed\">\{escape_html(first_skill_shadowed)}</small></article>\n" +
  "          </div>\n" +
  "          <div class=\"panel-shell skill-compare-shell\">\n" +
  "            <div class=\"section-heading compact-heading\">\n" +
  "              <p class=\"eyebrow\">Override drift</p>\n" +
  "              <h3>Compare the selected skill against its nearest baseline.</h3>\n" +
  "            </div>\n" +
  "            <div class=\"skill-compare-grid\">\n" +
  "              <article class=\"panel-item\"><strong>Status</strong><p id=\"skill-compare-status\">\{escape_html(first_skill.compare_status)}</p><small id=\"skill-compare-summary\">\{escape_html(first_skill.compare_summary)}</small></article>\n" +
  "              <article class=\"panel-item\"><strong>Baseline</strong><p id=\"skill-compare-baseline-path\">\{escape_html(first_skill.compare_baseline_path)}</p><small id=\"skill-compare-baseline-scope\">\{escape_html(first_skill.compare_baseline_scope)}</small></article>\n" +
  "              <article class=\"panel-item\"><strong>Change counts</strong><p id=\"skill-compare-counts\">changed=\{first_skill.compare_changed_line_count.to_string()} | selected-only=\{first_skill.compare_selected_only_line_count.to_string()} | baseline-only=\{first_skill.compare_baseline_only_line_count.to_string()}</p><small id=\"skill-compare-anchor\">first change line: \{escape_html(first_skill.compare_first_change_line)}</small></article>\n" +
  "            </div>\n" +
  "            <div class=\"skill-compare-excerpts\">\n" +
  "              <div class=\"skill-code-shell\"><div class=\"skill-code-head\"><span class=\"panel-label\">Selected excerpt</span></div><pre class=\"preview-block skill-code-block skill-diff-block\"><code id=\"skill-compare-selected\">\{escape_html(first_skill_selected_excerpt)}</code></pre></div>\n" +
  "              <div class=\"skill-code-shell\"><div class=\"skill-code-head\"><span class=\"panel-label\">Baseline excerpt</span></div><pre class=\"preview-block skill-code-block skill-diff-block\"><code id=\"skill-compare-baseline\">\{escape_html(first_skill_baseline_excerpt)}</code></pre></div>\n" +
  "            </div>\n" +
  "          </div>\n" +
  "          <div class=\"panel-shell skill-actions-shell\">\n" +
  "            <div class=\"section-heading compact-heading\">\n" +
  "              <p class=\"eyebrow\">Actions</p>\n" +
  "              <h3>Manage the selected skill through MoonBook CLI.</h3>\n" +
  "            </div>\n" +
  "            <div class=\"skill-action-grid\">\n" +
  "              <article class=\"panel-item skill-command-card\"><strong>Show metadata</strong><p>Inspect the resolved machine-readable record for the selected skill.</p><pre class=\"preview-block\"><code id=\"skill-command-show\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"show\">Copy command</button></article>\n" +
  "              <article class=\"panel-item skill-command-card\"><strong>Compare against baseline</strong><p>Print the machine-readable drift report for the selected skill and its nearest baseline.</p><pre class=\"preview-block\"><code id=\"skill-command-compare\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"compare\">Copy command</button></article>\n" +
  "              <article class=\"panel-item skill-command-card\"><strong>Sync candidate bundle</strong><p>Stage the workspace skill and its baseline into `skill-candidates/` for review without mutating repo seeds.</p><pre class=\"preview-block\"><code id=\"skill-command-sync\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"sync\">Copy command</button></article>\n" +
  "              <article class=\"panel-item skill-command-card\"><strong>Install into workspace</strong><p>Copy a seeded skill into `skills/` so it becomes editable inside this workspace.</p><pre class=\"preview-block\"><code id=\"skill-command-install\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"install\">Copy command</button></article>\n" +
  "              <article class=\"panel-item skill-command-card\"><strong>Scaffold workspace skill</strong><p>Create a new workspace-owned skill template with the same slug as the selected capability.</p><pre class=\"preview-block\"><code id=\"skill-command-scaffold\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"scaffold\">Copy command</button></article>\n" +
  "              <article class=\"panel-item skill-command-card\"><strong>Doctor inventory</strong><p>Re-run duplicate and bundled-reference diagnostics for the whole workspace.</p><pre class=\"preview-block\"><code id=\"skill-command-doctor\"></code></pre><button class=\"button button-secondary skill-copy-command\" type=\"button\" data-skill-command=\"doctor\">Copy command</button></article>\n" +
  "            </div>\n" +
  "            <p id=\"skill-command-note\" class=\"skill-command-note\">The generated site stays static. Real writes still go through MoonBook CLI so management remains explicit and auditable.</p>\n" +
  "          </div>\n" +
  "          <div class=\"skill-code-shell\">\n" +
  "            <div class=\"skill-code-head\"><span class=\"panel-label\">SKILL.md</span><span id=\"skill-detail-lines\">\{first_skill.line_count.to_string()} lines</span></div>\n" +
  "            <pre class=\"preview-block skill-code-block\"><code id=\"skill-detail-content\">\{escape_html(first_skill.content)}</code></pre>\n" +
  "          </div>\n" +
  "        </section>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "  </main>\n" +
  "  <script id=\"skills-state-inline\" type=\"application/json\">\{skills_json}</script>\n" +
  "  <script id=\"skills-root-inline\" type=\"application/json\">\{root_json}</script>\n" +
  "  <script src=\"./app.js\"></script>\n" +
  "</body>\n" +
  "</html>\n"
}

///|
fn empty_ui_skill_item() -> UiSkillItem {
  {
    key: "empty",
    name: "No skills found",
    scope: "empty",
    origin: "none",
    extension: "-",
    description: "The inventory is empty.",
    path: "",
    references: [],
    missing_references: [],
    overrides: [],
    shadowed_by: [],
    line_count: 0,
    duplicate: false,
    compare_status: "empty",
    compare_summary: "No comparison available.",
    compare_baseline_path: "-",
    compare_baseline_scope: "-",
    compare_changed_line_count: 0,
    compare_selected_only_line_count: 0,
    compare_baseline_only_line_count: 0,
    compare_first_change_line: "-",
    compare_selected_excerpt: [],
    compare_baseline_excerpt: [],
    content: "",
  }
}

///|
fn join_lines(values : Array[String]) -> String {
  if values.is_empty() {
    "None"
  } else {
    values.join("\n")
  }
}

///|
fn join_lines_or_default(values : Array[String], fallback : String) -> String {
  if values.is_empty() {
    fallback
  } else {
    values.join("\n")
  }
}

///|
fn marketing_projection_styles() -> String {
  ":root {\n" +
  "  --paper: #fbf5ea;\n" +
  "  --ink: #10211d;\n" +
  "  --muted: #5c6a63;\n" +
  "  --forest: #173c34;\n" +
  "  --forest-deep: #0d2620;\n" +
  "  --amber: #d97706;\n" +
  "  --coral: #ea6a4b;\n" +
  "  --line: rgba(16, 33, 29, 0.12);\n" +
  "  --shadow: 0 24px 80px rgba(18, 34, 30, 0.14);\n" +
  "}\n" +
  "* { box-sizing: border-box; }\n" +
  "html { scroll-behavior: smooth; }\n" +
  "body {\n" +
  "  margin: 0;\n" +
  "  min-height: 100vh;\n" +
  "  font-family: \"Space Grotesk\", \"Avenir Next\", \"Trebuchet MS\", sans-serif;\n" +
  "  color: var(--ink);\n" +
  "  background: radial-gradient(circle at top left, rgba(234, 106, 75, 0.17), transparent 28%), linear-gradient(180deg, #fffaf3 0%, var(--paper) 54%, #f3e7d6 100%);\n" +
  "}\n" +
  "a { color: inherit; text-decoration: none; }\n" +
  ".backdrop {\n" +
  "  position: fixed;\n" +
  "  inset: 0;\n" +
  "  pointer-events: none;\n" +
  "  background-image: linear-gradient(rgba(16, 33, 29, 0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(16, 33, 29, 0.03) 1px, transparent 1px);\n" +
  "  background-size: 34px 34px;\n" +
  "  mask-image: linear-gradient(180deg, rgba(0, 0, 0, 0.88), transparent 94%);\n" +
  "}\n" +
  ".topbar {\n" +
  "  position: sticky;\n" +
  "  top: 0;\n" +
  "  z-index: 30;\n" +
  "  display: flex;\n" +
  "  justify-content: space-between;\n" +
  "  align-items: center;\n" +
  "  gap: 1rem;\n" +
  "  padding: 1rem 1.4rem;\n" +
  "  backdrop-filter: blur(18px);\n" +
  "  background: rgba(251, 245, 234, 0.78);\n" +
  "  border-bottom: 1px solid var(--line);\n" +
  "}\n" +
  ".brand { display: inline-flex; align-items: center; gap: 0.8rem; font-weight: 700; letter-spacing: -0.04em; }\n" +
  ".brand-mark { display: grid; place-items: center; width: 2.45rem; height: 2.45rem; border-radius: 0.88rem; color: #fff8ef; background: linear-gradient(135deg, var(--forest), #285c4f); box-shadow: 0 16px 38px rgba(23, 60, 52, 0.28); }\n" +
  ".nav { display: inline-flex; gap: 1rem; flex-wrap: wrap; color: var(--muted); }\n" +
  ".nav a:hover { color: var(--ink); }\n" +
  ".page-shell { width: min(1200px, calc(100% - 2.4rem)); margin: 0 auto; padding: 2.5rem 0 5rem; }\n" +
  ".hero { display: grid; grid-template-columns: 1.08fr 0.92fr; gap: 2rem; align-items: stretch; }\n" +
  ".eyebrow { margin: 0 0 1rem; color: var(--amber); font-size: 0.8rem; font-weight: 700; letter-spacing: 0.18em; text-transform: uppercase; }\n" +
  "h1, h2, h3 { margin: 0; letter-spacing: -0.05em; }\n" +
  "h1 { font-family: \"Instrument Serif\", Georgia, serif; font-size: clamp(3.4rem, 7vw, 6.3rem); line-height: 0.94; max-width: 9ch; }\n" +
  "h2 { font-family: \"Instrument Serif\", Georgia, serif; font-size: clamp(2.2rem, 5vw, 4rem); line-height: 0.98; }\n" +
  "h3 { font-size: 1.12rem; }\n" +
  ".lede { margin: 1.3rem 0 0; max-width: 39rem; font-size: 1.07rem; line-height: 1.72; color: var(--muted); }\n" +
  ".hero-actions { display: flex; flex-wrap: wrap; gap: 0.9rem; margin-top: 1.6rem; }\n" +
  ".hero-actions.stacked { align-items: flex-start; flex-direction: column; }\n" +
  ".button { display: inline-flex; align-items: center; justify-content: center; min-height: 3.15rem; padding: 0.85rem 1.2rem; border-radius: 999px; border: 1px solid transparent; font-weight: 700; }\n" +
  ".button-primary { color: #fff8ef; background: linear-gradient(135deg, var(--forest), #245b4d); box-shadow: 0 18px 36px rgba(23, 60, 52, 0.24); }\n" +
  ".button-secondary { border-color: var(--line); background: rgba(255, 255, 255, 0.56); }\n" +
  ".chip-row { display: flex; flex-wrap: wrap; gap: 0.7rem; margin-top: 1.25rem; }\n" +
  ".chip { padding: 0.5rem 0.72rem; border-radius: 999px; font-size: 0.9rem; border: 1px solid var(--line); background: rgba(255, 255, 255, 0.58); }\n" +
  ".chip-healthy { color: #1b6b4f; }\n" +
  ".chip-alert { color: #9a3e1f; }\n" +
  ".chip-review { color: #8b5b00; }\n" +
  ".hero-stage, .metric-card, .workflow-card, .panel-shell, .depth-card, .report-card, .long-report { border: 1px solid var(--line); box-shadow: var(--shadow); }\n" +
  ".hero-stage { display: grid; gap: 1rem; padding: 1.15rem; border-radius: 1.95rem; background: linear-gradient(180deg, rgba(255, 252, 246, 0.86), rgba(242, 228, 202, 0.74)); }\n" +
  ".panel-block, .metric-card, .workflow-card, .panel-shell, .depth-card, .panel-item, .report-card, .long-report { border-radius: 1.35rem; background: rgba(255,255,255,0.58); }\n" +
  ".panel-block { padding: 1rem; }\n" +
  ".panel-block-dark { background: var(--forest-deep); color: #edf5f0; }\n" +
  ".panel-label { display: inline-block; font-size: 0.76rem; font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; color: var(--muted); }\n" +
  ".panel-block-dark .panel-label { color: rgba(237, 245, 240, 0.74); }\n" +
  ".hero-panel-list { margin: 0.85rem 0 0; padding-left: 1.1rem; color: var(--muted); line-height: 1.65; }\n" +
  ".panel-block-dark .hero-panel-list, .panel-block-dark p { color: rgba(237, 245, 240, 0.78); }\n" +
  "pre { overflow: auto; margin: 0.9rem 0 0; padding: 1rem; border-radius: 1rem; background: var(--forest-deep); color: #eff7f2; }\n" +
  ".section { padding: 4rem 0 0; }\n" +
  ".section-heading { display: flex; flex-direction: column; gap: 0.7rem; max-width: 48rem; }\n" +
  ".section-heading.narrow { max-width: 39rem; }\n" +
  ".metric-grid, .workflow-grid, .triple-grid, .depth-grid, .report-grid { display: grid; gap: 1rem; margin-top: 1.7rem; }\n" +
  ".metric-grid { grid-template-columns: repeat(4, minmax(0, 1fr)); }\n" +
  ".workflow-grid { grid-template-columns: repeat(4, minmax(0, 1fr)); }\n" +
  ".journey-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; margin-top: 1.7rem; }\n" +
  ".readiness-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1rem; margin-top: 1.7rem; }\n" +
  ".triple-grid, .depth-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }\n" +
  ".report-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); align-items: stretch; }\n" +
  ".article-layout { display: grid; grid-template-columns: 16rem minmax(0, 1fr); gap: 1.2rem; align-items: start; margin-top: 1.7rem; }\n" +
  ".article-toc { position: sticky; top: 5.4rem; display: grid; gap: .35rem; padding: 1rem; border: 1px solid var(--line); border-radius: 1.2rem; background: rgba(255,255,255,.68); box-shadow: var(--shadow); }\n" +
  ".article-toc a { display: block; padding: .55rem .65rem; border-radius: .8rem; color: var(--muted); font-size: .9rem; line-height: 1.35; }\n" +
  ".article-toc a:hover, .article-toc a:focus-visible { color: var(--ink); background: rgba(23,60,52,.08); outline: none; }\n" +
  ".long-report { margin-top: 1.5rem; padding: 1.55rem; background: rgba(255,255,255,.74); }\n" +
  ".article-layout .long-report { margin-top: 0; }\n" +
  ".long-report h2 { font-family: 'Instrument Serif', Georgia, serif; font-size: clamp(2rem, 4vw, 3.3rem); line-height: .98; margin: .1rem 0 1rem; }\n" +
  ".long-report h3 { margin: 1.35rem 0 .55rem; font-size: 1.12rem; letter-spacing: -.01em; }\n" +
  ".long-report h4 { margin: 1rem 0 .4rem; color: var(--forest); }\n" +
  ".long-report p, .long-report li { color: var(--muted); font-size: .98rem; line-height: 1.75; }\n" +
  ".long-report ul { margin: .6rem 0 .75rem 1.2rem; padding: 0; }\n" +
  ".long-report .mermaid, .report-code { overflow-x: auto; margin: 1rem 0; padding: 1rem; border-radius: 1rem; border: 1px solid var(--line); background: rgba(23,60,52,.07); color: var(--ink); font-size: .88rem; line-height: 1.55; }\n" +
  ".report-mermaid { min-height: 14rem; display: grid; place-items: center; }\n" +
  ".report-table-wrap { overflow-x: auto; margin: 1rem 0; border-radius: 1rem; border: 1px solid var(--line); }\n" +
  ".report-table { width: 100%; border-collapse: collapse; min-width: 36rem; background: rgba(255,255,255,.64); }\n" +
  ".report-table th, .report-table td { padding: .7rem .8rem; text-align: left; border-bottom: 1px solid var(--line); color: var(--muted); font-size: .9rem; vertical-align: top; }\n" +
  ".report-table th { color: var(--ink); background: rgba(23,60,52,.08); }\n" +
  ".reader-shell .hero h1 { max-width: 11ch; }\n" +
  ".reader-route-section { padding-top: 2rem; }\n" +
  ".reader-view-selector { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: .8rem; padding: .7rem; border: 1px solid var(--line); border-radius: 1.45rem; background: rgba(255,255,255,.52); box-shadow: var(--shadow); }\n" +
  ".reader-view-choice { position: relative; display: grid; grid-template-columns: auto minmax(0, 1fr) auto; gap: .8rem; align-items: center; min-height: 5.4rem; padding: .9rem 1rem; border: 1px solid transparent; border-radius: 1.05rem; color: var(--muted); transition: transform 160ms ease, background 160ms ease, border-color 160ms ease; }\n" +
  ".reader-view-choice:hover, .reader-view-choice:focus-visible { transform: translateY(-1px); color: var(--ink); border-color: rgba(23,60,52,.2); outline: none; }\n" +
  ".reader-view-choice.is-selected { color: #fff8ef; background: linear-gradient(135deg, var(--forest), #245b4d); box-shadow: 0 16px 32px rgba(23,60,52,.2); }\n" +
  ".reader-view-choice strong, .reader-view-choice small { display: block; }\n" +
  ".reader-view-choice small { margin-top: .2rem; color: inherit; opacity: .72; }\n" +
  ".reader-view-icon { display: grid; place-items: center; width: 2.5rem; height: 2.5rem; border-radius: .8rem; background: rgba(23,60,52,.08); color: var(--forest); font-size: 1.2rem; font-weight: 700; }\n" +
  ".reader-view-choice.is-selected .reader-view-icon { background: rgba(255,255,255,.12); color: #fff8ef; }\n" +
  ".reader-availability { font-size: .7rem; font-style: normal; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; }\n" +
  ".reader-availability.is-ready { color: #1b6b4f; }\n" +
  ".reader-view-choice.is-selected .reader-availability.is-ready { color: #bdebd8; }\n" +
  ".reader-availability.is-draft { color: #8b5b00; }\n" +
  ".reader-view-choice.is-selected .reader-availability.is-draft { color: #ffe1a3; }\n" +
  ".reader-availability.is-missing { color: #9a3e1f; }\n" +
  ".reader-view-choice.is-selected .reader-availability.is-missing { color: #ffc6b2; }\n" +
  ".reader-panel[hidden] { display: none; }\n" +
  ".reader-panel-heading { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 1rem; align-items: end; }\n" +
  ".reader-panel-heading h2 { max-width: 18ch; }\n" +
  ".reader-source-meta { display: grid; justify-items: end; gap: .35rem; max-width: 28rem; color: var(--muted); font-size: .82rem; text-align: right; word-break: break-word; }\n" +
  ".reader-next-action { display: grid; gap: .4rem; margin-top: 1.3rem; padding: 1rem 1.2rem; border-left: .3rem solid var(--coral); border-radius: 0 1rem 1rem 0; background: rgba(234,106,75,.08); }\n" +
  ".reader-next-action strong { font-size: 1.05rem; line-height: 1.5; }\n" +
  ".reader-article-layout { margin-top: 1.3rem; }\n" +
  ".reader-article { max-width: 52rem; }\n" +
  ".reader-callout { margin: 1rem 0; padding: .9rem 1rem; border: 1px solid var(--line); border-left-width: .28rem; border-radius: 0 1rem 1rem 0; background: rgba(255,255,255,.66); }\n" +
  ".reader-callout span { display: block; margin-bottom: .35rem; color: var(--forest); font-size: .74rem; font-weight: 700; letter-spacing: .1em; text-transform: uppercase; }\n" +
  ".reader-callout p { margin: 0; color: var(--ink); }\n" +
  ".reader-callout-orientation { border-left-color: #2b7a66; }\n" +
  ".reader-callout-meaning, .reader-callout-example { border-left-color: var(--amber); }\n" +
  ".reader-callout-practice, .reader-callout-checkpoint { border-left-color: var(--coral); }\n" +
  ".reader-callout-trace { border-left-color: #64748b; background: rgba(100,116,139,.06); }\n" +
  ".reader-callout-caution { border-left-color: #a23b3b; background: rgba(162,59,59,.06); }\n" +
  ".reader-section-heading { margin-top: 1.8rem; padding: .72rem .9rem; border-left: .28rem solid var(--forest); border-radius: 0 .8rem .8rem 0; background: rgba(255,255,255,.58); }\n" +
  ".reader-section-heading-meaning, .reader-section-heading-example { border-left-color: var(--amber); }\n" +
  ".reader-section-heading-practice, .reader-section-heading-checkpoint { border-left-color: var(--coral); }\n" +
  ".reader-section-heading-caution { border-left-color: #a23b3b; }\n" +
  ".reader-answer { margin: .9rem 0; border: 1px solid var(--line); border-radius: 1rem; background: rgba(23,60,52,.05); }\n" +
  ".reader-answer summary { padding: .85rem 1rem; color: var(--forest); font-weight: 700; cursor: pointer; }\n" +
  ".reader-answer p { margin: 0; padding: 0 1rem 1rem; color: var(--ink); }\n" +
  ".reader-empty { display: flex; gap: 1rem; align-items: flex-start; margin-top: 1.3rem; padding: 1.3rem; border: 1px dashed rgba(16,33,29,.24); border-radius: 1.25rem; background: rgba(255,255,255,.48); }\n" +
  ".reader-empty h3, .reader-empty p { margin: 0; }\n" +
  ".reader-empty p { margin-top: .35rem; color: var(--muted); line-height: 1.65; }\n" +
  ".reader-empty-icon { display: grid; place-items: center; min-width: 2.5rem; height: 2.5rem; border-radius: 999px; background: rgba(23,60,52,.08); color: var(--forest); font-size: 1.5rem; }\n" +
  ".maintenance-disclosure { border: 1px solid var(--line); border-radius: 1.35rem; background: rgba(255,255,255,.48); }\n" +
  ".maintenance-disclosure summary { display: flex; justify-content: space-between; gap: 1rem; align-items: center; padding: 1.1rem 1.25rem; cursor: pointer; font-weight: 700; list-style: none; }\n" +
  ".maintenance-disclosure summary::-webkit-details-marker { display: none; }\n" +
  ".maintenance-disclosure summary small { display: block; margin-bottom: .25rem; color: var(--muted); font-size: .72rem; font-weight: 700; letter-spacing: .1em; text-transform: uppercase; }\n" +
  ".maintenance-body { padding: 0 1.25rem 1.25rem; border-top: 1px solid var(--line); }\n" +
  ".maintenance-body p { max-width: 50rem; color: var(--muted); line-height: 1.65; }\n" +
  ".reader-trace-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: .8rem; margin-top: 1rem; }\n" +
  ".reader-trace-card { min-width: 0; padding: 1rem; border: 1px solid var(--line); border-radius: 1rem; background: rgba(255,255,255,.55); }\n" +
  ".reader-trace-card > div { display: flex; justify-content: space-between; gap: .6rem; }\n" +
  ".reader-trace-card > div span { color: var(--muted); font-size: .74rem; font-weight: 700; text-transform: uppercase; }\n" +
  ".reader-trace-card > p { margin: .6rem 0; font-size: .82rem; word-break: break-word; }\n" +
  ".reader-trace-card dl { display: grid; gap: .45rem; margin: 0; }\n" +
  ".reader-trace-card dl div { display: grid; gap: .12rem; }\n" +
  ".reader-trace-card dt { color: var(--muted); font-size: .68rem; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; }\n" +
  ".reader-trace-card dd { overflow-wrap: anywhere; margin: 0; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .72rem; line-height: 1.45; }\n" +
  ".nav-maintenance { padding-left: 1rem; border-left: 1px solid var(--line); }\n" +
  ".metric-card, .workflow-card, .panel-shell, .depth-card, .report-card { padding: 1.3rem; }\n" +
  ".report-card { display: flex; flex-direction: column; gap: 1rem; min-height: 17rem; }\n" +
  ".report-card-head { display: flex; flex-direction: column; gap: 0.45rem; }\n" +
  ".report-card p { margin: 0; color: var(--muted); line-height: 1.75; }\n" +
  ".report-evidence { margin-top: auto; color: var(--forest); font-weight: 700; line-height: 1.55; }\n" +
  ".architecture-map { display: grid; grid-template-columns: 1fr auto 1fr auto 1fr auto 1fr; gap: 0.5rem; align-items: center; padding: 0.85rem; border-radius: 1rem; background: rgba(23, 60, 52, 0.07); }\n" +
  ".architecture-map span { display: block; padding: 0.65rem; border-radius: 0.8rem; background: rgba(255,255,255,0.72); font-weight: 700; text-align: center; }\n" +
  ".architecture-map small { color: var(--muted); font-weight: 500; }\n" +
  ".metric-card strong { display: block; margin-top: 0.4rem; font-size: 2rem; line-height: 1; }\n" +
  ".metric-label, .workflow-status { display: inline-block; font-size: 0.76rem; font-weight: 700; letter-spacing: 0.12em; text-transform: uppercase; color: var(--muted); }\n" +
  ".workflow-status { margin-bottom: 0.7rem; }\n" +
  ".status-active, .status-stable, .status-durable, .status-multi-surface, .status-open-boundary, .status-observable { color: #1b6b4f; }\n" +
  ".status-expanded, .status-crowded, .status-needed, .status-blocked { color: #9a3e1f; }\n" +
  ".metric-card p, .workflow-card p, .panel-item p, .panel-item small, .panel-block p { color: var(--muted); line-height: 1.66; }\n" +
  ".marketing-card ul { margin: 1rem 0 0; padding-left: 1.15rem; color: var(--muted); line-height: 1.7; }\n" +
  ".panel-item { padding: 1rem; margin-top: 0.9rem; border: 1px solid rgba(16, 33, 29, 0.08); }\n" +
  ".surface-card { display: flex; flex-direction: column; gap: 0.65rem; margin-top: 0; }\n" +
  ".surface-card a { margin-top: auto; color: var(--forest); font-weight: 700; }\n" +
  ".product-depth-grid .depth-card p { color: var(--muted); line-height: 1.7; }\n" +
  ".journey-card { padding: 1.2rem; border-radius: 1.35rem; border: 1px solid rgba(16, 33, 29, 0.08); background: rgba(255,255,255,0.62); box-shadow: var(--shadow); }\n" +
  ".journey-card ul { margin: 0.9rem 0 0; padding-left: 1.1rem; color: var(--muted); }\n" +
  ".translation-list { margin: 0; padding-left: 1.1rem; color: var(--muted); line-height: 1.7; }\n" +
  ".journey-meta { display: flex; justify-content: space-between; gap: 1rem; margin-bottom: 0.7rem; font-size: 0.76rem; font-weight: 700; letter-spacing: 0.12em; text-transform: uppercase; color: var(--muted); }\n" +
  ".journey-status { color: var(--muted); }\n" +
  ".journal-shell .hero h1 { max-width: 11ch; }\n" +
  ".quiz-grid { align-items: start; }\n" +
  ".quiz-toggle { margin-top: 1rem; min-height: 2.75rem; padding: 0.7rem 1rem; border-radius: 999px; border: 1px solid var(--line); background: rgba(23, 60, 52, 0.06); font: inherit; font-weight: 700; color: var(--ink); cursor: pointer; }\n" +
  ".quiz-answer { margin-top: 0.9rem; }\n" +
  ".chapter-stack { display: grid; gap: 0.8rem; margin-top: 1rem; }\n" +
  ".chapter-link { display: grid; grid-template-columns: auto 1fr; gap: 0.8rem; align-items: start; padding: 0.9rem 1rem; border-radius: 1rem; background: rgba(255,255,255,0.66); border: 1px solid rgba(16, 33, 29, 0.08); }\n" +
  ".chapter-number { display: inline-grid; place-items: center; min-width: 2rem; height: 2rem; border-radius: 999px; background: rgba(23, 60, 52, 0.08); font-weight: 700; }\n" +
  ".chapter-copy { display: grid; gap: 0.2rem; }\n" +
  ".chapter-copy small { color: var(--muted); }\n" +
  ".preview-block { min-height: 18rem; background: rgba(16, 33, 29, 0.95); }\n" +
  ".skill-diagnostics-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }\n" +
  ".skill-explorer { display: grid; grid-template-columns: minmax(18rem, 25rem) minmax(0, 1fr); gap: 1rem; margin-top: 1.7rem; align-items: start; }\n" +
  ".skill-sidebar, .skill-detail { padding: 1.3rem; }\n" +
  ".skill-toolbar { display: grid; gap: 0.9rem; }\n" +
  ".skill-search { width: 100%; min-height: 3rem; padding: 0.8rem 1rem; border-radius: 999px; border: 1px solid var(--line); background: rgba(255,255,255,0.76); font: inherit; color: var(--ink); }\n" +
  ".skill-filters { display: flex; flex-wrap: wrap; gap: 0.6rem; }\n" +
  ".filter-pill { min-height: 2.45rem; padding: 0.6rem 0.9rem; border-radius: 999px; border: 1px solid var(--line); background: rgba(255,255,255,0.62); font: inherit; font-weight: 700; color: var(--muted); cursor: pointer; }\n" +
  ".filter-pill.is-active { color: #fff8ef; background: linear-gradient(135deg, var(--forest), #245b4d); border-color: transparent; }\n" +
  ".skill-list { display: grid; gap: 0.75rem; margin-top: 1rem; max-height: 58rem; overflow: auto; padding-right: 0.2rem; }\n" +
  ".skill-row { display: grid; gap: 0.55rem; width: 100%; text-align: left; padding: 1rem; border-radius: 1.1rem; border: 1px solid rgba(16, 33, 29, 0.1); background: rgba(255,255,255,0.64); color: inherit; cursor: pointer; transition: transform 180ms ease, border-color 180ms ease, box-shadow 180ms ease; }\n" +
  ".skill-row:hover, .skill-row.is-selected { transform: translateY(-1px); border-color: rgba(23, 60, 52, 0.24); box-shadow: 0 16px 30px rgba(23, 60, 52, 0.12); }\n" +
  ".skill-row-head { display: flex; justify-content: space-between; gap: 1rem; align-items: flex-start; }\n" +
  ".skill-row-body, .skill-row-meta, .skill-empty, .skill-detail-description { color: var(--muted); }\n" +
  ".skill-row-meta { font-size: 0.82rem; line-height: 1.5; word-break: break-word; }\n" +
  ".skill-badges { display: inline-flex; flex-wrap: wrap; gap: 0.4rem; justify-content: flex-end; }\n" +
  ".skill-detail-head { display: flex; justify-content: space-between; gap: 1rem; align-items: flex-start; }\n" +
  ".skill-detail-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; margin-top: 1.2rem; }\n" +
  ".skill-detail-grid .panel-item p, .skill-detail-grid .panel-item small { white-space: pre-wrap; word-break: break-word; }\n" +
  ".compact-heading { margin-bottom: 0.95rem; }\n" +
  ".skill-compare-shell { margin-top: 1.2rem; }\n" +
  ".skill-compare-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 1rem; }\n" +
  ".skill-compare-excerpts { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; margin-top: 1rem; }\n" +
  ".skill-diff-block { min-height: 18rem; max-height: 26rem; }\n" +
  ".skill-actions-shell { margin-top: 1.2rem; }\n" +
  ".skill-action-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1rem; }\n" +
  ".skill-command-card { display: grid; gap: 0.85rem; align-content: start; }\n" +
  ".skill-command-card .preview-block { min-height: 5rem; margin: 0; }\n" +
  ".skill-copy-command { justify-self: start; }\n" +
  ".skill-command-note { margin: 0.2rem 0 0; color: var(--muted); }\n" +
  ".skill-code-shell { margin-top: 1.2rem; }\n" +
  ".skill-code-head { display: flex; justify-content: space-between; gap: 1rem; align-items: center; margin-bottom: 0.75rem; }\n" +
  ".skill-code-block { min-height: 32rem; max-height: 52rem; }\n" +
  "#skill-detail-content { white-space: pre-wrap; word-break: break-word; }\n" +
  ".reveal { opacity: 0; transform: translateY(18px); transition: opacity 560ms ease, transform 560ms ease; }\n" +
  ".reveal.is-visible { opacity: 1; transform: translateY(0); }\n" +
  "@media (max-width: 980px) {\n" +
  "  .hero, .metric-grid, .workflow-grid, .journey-grid, .readiness-grid, .triple-grid, .depth-grid, .report-grid, .article-layout, .reader-view-selector, .reader-panel-heading, .reader-trace-grid, .skill-explorer, .skill-detail-grid, .skill-diagnostics-grid, .skill-action-grid, .skill-compare-grid, .skill-compare-excerpts { grid-template-columns: 1fr; }\n" +
  "  .article-toc { position: static; }\n" +
  "  .reader-source-meta { justify-items: start; text-align: left; }\n" +
  "  .architecture-map { grid-template-columns: 1fr; }\n" +
  "  .page-shell { width: min(100% - 1.4rem, 1200px); }\n" +
  "}\n" +
  "@media (max-width: 640px) {\n" +
  "  .topbar { align-items: flex-start; flex-direction: column; }\n" +
  "  h1 { max-width: none; }\n" +
  "  .reader-view-choice { grid-template-columns: auto minmax(0, 1fr); }\n" +
  "  .reader-availability { grid-column: 2; }\n" +
  "  .nav-maintenance { padding-left: 0; border-left: 0; }\n" +
  "}\n" +
  "@media (prefers-reduced-motion: reduce) {\n" +
  "  html { scroll-behavior: auto; }\n" +
  "  .reveal { opacity: 1; transform: none; transition: none; }\n" +
  "  .tilt { transform: none !important; }\n" +
  "}\n"
}

///|
fn marketing_projection_script() -> String {
  "if (window.mermaid) {\n" +
  "  window.mermaid.initialize({ startOnLoad: true, theme: 'base', flowchart: { useMaxWidth: true, htmlLabels: true } });\n" +
  "}\n" +
  "const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;\n" +
  "const revealNodes = document.querySelectorAll('.reveal');\n" +
  "if (!reduceMotion && 'IntersectionObserver' in window) {\n" +
  "  const observer = new IntersectionObserver((entries) => {\n" +
  "    for (const entry of entries) {\n" +
  "      if (entry.isIntersecting) {\n" +
  "        entry.target.classList.add('is-visible');\n" +
  "        observer.unobserve(entry.target);\n" +
  "      }\n" +
  "    }\n" +
  "  }, { threshold: 0.16 });\n" +
  "  revealNodes.forEach((node) => observer.observe(node));\n" +
  "} else {\n" +
  "  revealNodes.forEach((node) => node.classList.add('is-visible'));\n" +
  "}\n" +
  "if (!reduceMotion) {\n" +
  "  document.querySelectorAll('.tilt').forEach((node) => {\n" +
  "    node.addEventListener('pointermove', (event) => {\n" +
  "      const rect = node.getBoundingClientRect();\n" +
  "      const px = (event.clientX - rect.left) / rect.width - 0.5;\n" +
  "      const py = (event.clientY - rect.top) / rect.height - 0.5;\n" +
  "      node.style.transform = `perspective(1200px) rotateX(${(-py * 5).toFixed(2)}deg) rotateY(${(px * 7).toFixed(2)}deg) translateY(-2px)`;\n" +
  "    });\n" +
  "    node.addEventListener('pointerleave', () => {\n" +
  "      node.style.transform = '';\n" +
  "    });\n" +
  "  });\n" +
  "}\n" +
  "document.querySelectorAll('.quiz-toggle').forEach((button) => {\n" +
  "  button.addEventListener('click', () => {\n" +
  "    const answer = button.parentElement && button.parentElement.querySelector('.quiz-answer');\n" +
  "    if (!answer) return;\n" +
  "    const hidden = answer.hasAttribute('hidden');\n" +
  "    if (hidden) {\n" +
  "      answer.removeAttribute('hidden');\n" +
  "      button.textContent = 'Hide answer';\n" +
  "    } else {\n" +
  "      answer.setAttribute('hidden', 'hidden');\n" +
  "      button.textContent = 'Reveal answer';\n" +
  "    }\n" +
  "  });\n" +
  "});\n" +
  "const bodyPage = document.body && document.body.dataset ? document.body.dataset.page : '';\n" +
  "if (bodyPage === 'reader') {\n" +
  "  const validViews = new Set(['learn', 'apply', 'research']);\n" +
  "  const panels = Array.from(document.querySelectorAll('[data-reader-panel]'));\n" +
  "  const choices = Array.from(document.querySelectorAll('[data-reader-choice]'));\n" +
  "  const navLinks = Array.from(document.querySelectorAll('[data-reader-nav]'));\n" +
  "  const activateReaderView = (requested, updateUrl) => {\n" +
  "    const view = validViews.has(requested) ? requested : 'learn';\n" +
  "    panels.forEach((panel) => {\n" +
  "      const selected = panel.dataset.readerPanel === view;\n" +
  "      panel.hidden = !selected;\n" +
  "      if (selected) panel.classList.add('is-visible');\n" +
  "    });\n" +
  "    choices.forEach((choice) => {\n" +
  "      const selected = choice.dataset.readerChoice === view;\n" +
  "      choice.classList.toggle('is-selected', selected);\n" +
  "      if (selected) choice.setAttribute('aria-current', 'page');\n" +
  "      else choice.removeAttribute('aria-current');\n" +
  "    });\n" +
  "    navLinks.forEach((link) => {\n" +
  "      const selected = link.dataset.readerNav === view;\n" +
  "      if (selected) link.setAttribute('aria-current', 'page');\n" +
  "      else link.removeAttribute('aria-current');\n" +
  "    });\n" +
  "    if (updateUrl) {\n" +
  "      const url = new URL(window.location.href);\n" +
  "      url.searchParams.set('view', view);\n" +
  "      window.history.pushState({}, '', url);\n" +
  "    }\n" +
  "  };\n" +
  "  const initialView = new URL(window.location.href).searchParams.get('view') || 'learn';\n" +
  "  activateReaderView(initialView, false);\n" +
  "  choices.concat(navLinks).forEach((link) => {\n" +
  "    link.addEventListener('click', (event) => {\n" +
  "      const view = link.dataset.readerChoice || link.dataset.readerNav;\n" +
  "      if (!validViews.has(view)) return;\n" +
  "      event.preventDefault();\n" +
  "      activateReaderView(view, true);\n" +
  "      const selector = document.querySelector('.reader-route-section');\n" +
  "      if (selector) selector.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth', block: 'start' });\n" +
  "    });\n" +
  "  });\n" +
  "  window.addEventListener('popstate', () => {\n" +
  "    const view = new URL(window.location.href).searchParams.get('view') || 'learn';\n" +
  "    activateReaderView(view, false);\n" +
  "  });\n" +
  "}\n" +
  "if (bodyPage === 'skills') {\n" +
  "  const inlineState = document.getElementById('skills-state-inline');\n" +
  "  const inlineRoot = document.getElementById('skills-root-inline');\n" +
  "  let parsed = null;\n" +
  "  let root = '.';\n" +
  "  if (inlineState && inlineState.textContent) {\n" +
  "    try {\n" +
  "      parsed = JSON.parse(inlineState.textContent);\n" +
  "    } catch (_) {\n" +
  "      parsed = null;\n" +
  "    }\n" +
  "  }\n" +
  "  if (inlineRoot && inlineRoot.textContent) {\n" +
  "    try {\n" +
  "      root = JSON.parse(inlineRoot.textContent);\n" +
  "    } catch (_) {\n" +
  "      root = '.';\n" +
  "    }\n" +
  "  }\n" +
  "  const statePromise = parsed ? Promise.resolve(parsed) : fetch('./skills-state.json').then((response) => response.json()).catch(() => null);\n" +
  "  statePromise.then((state) => {\n" +
  "    if (!state || !Array.isArray(state.skills)) return;\n" +
  "    const list = document.getElementById('skill-list');\n" +
  "    const empty = document.getElementById('skill-empty');\n" +
  "    const search = document.getElementById('skill-search');\n" +
  "    const filters = Array.from(document.querySelectorAll('[data-skill-filter]'));\n" +
  "    const detailName = document.getElementById('skill-detail-name');\n" +
  "    const detailDescription = document.getElementById('skill-detail-description');\n" +
  "    const detailPath = document.getElementById('skill-detail-path');\n" +
  "    const detailOrigin = document.getElementById('skill-detail-origin');\n" +
  "    const detailExtension = document.getElementById('skill-detail-extension');\n" +
  "    const detailReferences = document.getElementById('skill-detail-references');\n" +
  "    const detailOverrides = document.getElementById('skill-detail-overrides');\n" +
  "    const detailShadowed = document.getElementById('skill-detail-shadowed');\n" +
  "    const detailLines = document.getElementById('skill-detail-lines');\n" +
  "    const detailContent = document.getElementById('skill-detail-content');\n" +
  "    const detailBadges = document.getElementById('skill-detail-badges');\n" +
  "    const compareStatus = document.getElementById('skill-compare-status');\n" +
  "    const compareSummary = document.getElementById('skill-compare-summary');\n" +
  "    const compareBaselinePath = document.getElementById('skill-compare-baseline-path');\n" +
  "    const compareBaselineScope = document.getElementById('skill-compare-baseline-scope');\n" +
  "    const compareCounts = document.getElementById('skill-compare-counts');\n" +
  "    const compareAnchor = document.getElementById('skill-compare-anchor');\n" +
  "    const compareSelected = document.getElementById('skill-compare-selected');\n" +
  "    const compareBaseline = document.getElementById('skill-compare-baseline');\n" +
  "    const commandShow = document.getElementById('skill-command-show');\n" +
  "    const commandCompare = document.getElementById('skill-command-compare');\n" +
  "    const commandSync = document.getElementById('skill-command-sync');\n" +
  "    const commandInstall = document.getElementById('skill-command-install');\n" +
  "    const commandScaffold = document.getElementById('skill-command-scaffold');\n" +
  "    const commandDoctor = document.getElementById('skill-command-doctor');\n" +
  "    const commandNote = document.getElementById('skill-command-note');\n" +
  "    const commandButtons = Array.from(document.querySelectorAll('.skill-copy-command'));\n" +
  "    let activeFilter = 'all';\n" +
  "    let selectedKey = state.skills[0] ? state.skills[0].key : '';\n" +
  "    const shellQuote = (value) => {\n" +
  "      const text = String(value == null ? '' : value);\n" +
  "      return `'${text.replace(/'/g, `'\"'\"'`)}'`;\n" +
  "    };\n" +
  "    const skillSlug = (value) => {\n" +
  "      const slug = String(value || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');\n" +
  "      return slug || 'new-skill';\n" +
  "    };\n" +
  "    const skillSelector = (skill) => {\n" +
  "      if (skill && skill.scope === 'seed-extension' && skill.extension && skill.extension !== '-') {\n" +
  "        return `${skill.name}@${skill.extension}`;\n" +
  "      }\n" +
  "      return skill && skill.name ? skill.name : '';\n" +
  "    };\n" +
  "    const commandText = (skill, kind) => {\n" +
  "      const quotedRoot = shellQuote(root || '.');\n" +
  "      const quotedName = shellQuote(skillSelector(skill));\n" +
  "      if (kind === 'show') return `moonbook skill show ${quotedName} ${quotedRoot}`;\n" +
  "      if (kind === 'compare') return `moonbook skill compare ${quotedName} ${quotedRoot}`;\n" +
  "      if (kind === 'sync') {\n" +
  "        return skill && skill.scope === 'workspace'\n" +
  "          ? `moonbook skill sync ${quotedName} ${quotedRoot}`\n" +
  "          : '# sync requires a workspace-owned override';\n" +
  "      }\n" +
  "      if (kind === 'doctor') return `moonbook skill doctor ${quotedRoot}`;\n" +
  "      if (kind === 'scaffold') return `moonbook skill scaffold ${shellQuote(skillSlug(skill && skill.name ? skill.name : 'new-skill'))} ${quotedRoot}`;\n" +
  "      if (kind === 'install') {\n" +
  "        return skill && (skill.scope === 'workspace' || (Array.isArray(skill.shadowed_by) && skill.shadowed_by.length > 0))\n" +
  "          ? '# already installed in workspace'\n" +
  "          : `moonbook skill install ${quotedName} ${quotedRoot}`;\n" +
  "      }\n" +
  "      return '';\n" +
  "    };\n" +
  "    const copyText = async (value) => {\n" +
  "      if (navigator.clipboard && window.isSecureContext) {\n" +
  "        await navigator.clipboard.writeText(value);\n" +
  "        return;\n" +
  "      }\n" +
  "      const node = document.createElement('textarea');\n" +
  "      node.value = value;\n" +
  "      node.setAttribute('readonly', '');\n" +
  "      node.style.position = 'fixed';\n" +
  "      node.style.top = '-9999px';\n" +
  "      document.body.appendChild(node);\n" +
  "      node.focus();\n" +
  "      node.select();\n" +
  "      document.execCommand('copy');\n" +
  "      document.body.removeChild(node);\n" +
  "    };\n" +
  "    const renderDetail = (skill) => {\n" +
  "      if (!skill) return;\n" +
  "      detailName.textContent = skill.name;\n" +
  "      detailDescription.textContent = skill.description || 'No description.';\n" +
  "      detailPath.textContent = skill.path || '-';\n" +
  "      detailOrigin.textContent = skill.origin || '-';\n" +
  "      detailExtension.textContent = skill.extension || '-';\n" +
  "      detailReferences.textContent = (skill.references && skill.references.length ? skill.references : ['None']).join('\\n');\n" +
  "      detailOverrides.textContent = (skill.overrides && skill.overrides.length ? skill.overrides : ['None']).join('\\n');\n" +
  "      detailShadowed.textContent = (skill.shadowed_by && skill.shadowed_by.length ? skill.shadowed_by : ['Not shadowed']).join('\\n');\n" +
  "      detailLines.textContent = `${skill.line_count || 0} lines`;\n" +
  "      detailContent.textContent = skill.content || '';\n" +
  "      if (compareStatus) compareStatus.textContent = skill.compare_status || '-';\n" +
  "      if (compareSummary) compareSummary.textContent = skill.compare_summary || 'No comparison summary.';\n" +
  "      if (compareBaselinePath) compareBaselinePath.textContent = skill.compare_baseline_path || '-';\n" +
  "      if (compareBaselineScope) compareBaselineScope.textContent = skill.compare_baseline_scope || '-';\n" +
  "      if (compareCounts) compareCounts.textContent = `changed=${skill.compare_changed_line_count || 0} | selected-only=${skill.compare_selected_only_line_count || 0} | baseline-only=${skill.compare_baseline_only_line_count || 0}`;\n" +
  "      if (compareAnchor) compareAnchor.textContent = `first change line: ${skill.compare_first_change_line || '-'}`;\n" +
  "      if (compareSelected) compareSelected.textContent = (skill.compare_selected_excerpt && skill.compare_selected_excerpt.length ? skill.compare_selected_excerpt : ['No selected excerpt.']).join('\\n');\n" +
  "      if (compareBaseline) compareBaseline.textContent = (skill.compare_baseline_excerpt && skill.compare_baseline_excerpt.length ? skill.compare_baseline_excerpt : ['No baseline excerpt.']).join('\\n');\n" +
  "      if (commandShow) commandShow.textContent = commandText(skill, 'show');\n" +
  "      if (commandCompare) commandCompare.textContent = commandText(skill, 'compare');\n" +
  "      if (commandSync) commandSync.textContent = commandText(skill, 'sync');\n" +
  "      if (commandInstall) commandInstall.textContent = commandText(skill, 'install');\n" +
  "      if (commandScaffold) commandScaffold.textContent = commandText(skill, 'scaffold');\n" +
  "      if (commandDoctor) commandDoctor.textContent = commandText(skill, 'doctor');\n" +
  "      if (commandNote) {\n" +
  "        commandNote.textContent = skill.scope === 'workspace' || (Array.isArray(skill.shadowed_by) && skill.shadowed_by.length > 0)\n" +
  "          ? 'This skill is already workspace-owned. Edit the path above directly or scaffold a sibling variant if you want a clean branch.'\n" +
  "          : 'This skill currently resolves from a seeded pack. Install it into the workspace if you want local ownership and edits.';\n" +
  "      }\n" +
  "      detailBadges.innerHTML = '';\n" +
  "      const badges = [skill.scope, skill.origin];\n" +
  "      if (skill.extension && skill.extension !== '-') badges.push(skill.extension);\n" +
  "      if (skill.duplicate) badges.push('duplicate');\n" +
  "      if (Array.isArray(skill.missing_references) && skill.missing_references.length) badges.push('missing references');\n" +
  "      badges.forEach((label) => {\n" +
  "        const span = document.createElement('span');\n" +
  "        span.className = `chip ${label === 'duplicate' || label === 'missing references' ? 'chip-alert' : label === 'workspace' ? 'chip-review' : 'chip-healthy'}`;\n" +
  "        span.textContent = label;\n" +
  "        detailBadges.appendChild(span);\n" +
  "      });\n" +
  "    };\n" +
  "    const visibleSkills = () => {\n" +
  "      const query = search && search.value ? search.value.trim().toLowerCase() : '';\n" +
  "      return state.skills.filter((skill) => {\n" +
  "        const matchesFilter = activeFilter === 'all' ? true : activeFilter === 'duplicate' ? !!skill.duplicate : skill.scope === activeFilter;\n" +
  "        const haystack = [skill.name, skill.scope, skill.origin, skill.extension, skill.description, skill.path].join(' ').toLowerCase();\n" +
  "        return matchesFilter && (!query || haystack.includes(query));\n" +
  "      });\n" +
  "    };\n" +
  "    const renderList = () => {\n" +
  "      const filtered = visibleSkills();\n" +
  "      Array.from(list.querySelectorAll('.skill-row')).forEach((node) => {\n" +
  "        const skill = state.skills.find((item) => item.key === node.dataset.skillKey);\n" +
  "        const show = filtered.includes(skill);\n" +
  "        node.hidden = !show;\n" +
  "        node.classList.toggle('is-selected', show && skill && skill.key === selectedKey);\n" +
  "      });\n" +
  "      if (empty) empty.hidden = filtered.length > 0;\n" +
  "      if (!filtered.find((item) => item.key === selectedKey) && filtered[0]) {\n" +
  "        selectedKey = filtered[0].key;\n" +
  "        renderDetail(filtered[0]);\n" +
  "      }\n" +
  "    };\n" +
  "    list.addEventListener('click', (event) => {\n" +
  "      const button = event.target && event.target.closest ? event.target.closest('.skill-row') : null;\n" +
  "      if (!button) return;\n" +
  "      const skill = state.skills.find((item) => item.key === button.dataset.skillKey);\n" +
  "      if (!skill) return;\n" +
  "      selectedKey = skill.key;\n" +
  "      renderDetail(skill);\n" +
  "      renderList();\n" +
  "    });\n" +
  "    commandButtons.forEach((button) => {\n" +
  "      button.addEventListener('click', async () => {\n" +
  "        const skill = state.skills.find((item) => item.key === selectedKey);\n" +
  "        if (!skill) return;\n" +
  "        const kind = button.dataset.skillCommand || 'show';\n" +
  "        const text = commandText(skill, kind);\n" +
  "        if (!text) return;\n" +
  "        await copyText(text);\n" +
  "        const original = button.textContent;\n" +
  "        button.textContent = 'Copied';\n" +
  "        window.setTimeout(() => {\n" +
  "          button.textContent = original;\n" +
  "        }, 1400);\n" +
  "      });\n" +
  "    });\n" +
  "    filters.forEach((button) => {\n" +
  "      button.addEventListener('click', () => {\n" +
  "        activeFilter = button.dataset.skillFilter || 'all';\n" +
  "        filters.forEach((item) => item.classList.toggle('is-active', item === button));\n" +
  "        renderList();\n" +
  "      });\n" +
  "    });\n" +
  "    if (search) search.addEventListener('input', renderList);\n" +
  "    renderDetail(state.skills[0]);\n" +
  "    renderList();\n" +
  "  });\n" +
  "}\n"
}
