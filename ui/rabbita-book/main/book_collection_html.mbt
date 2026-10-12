///|
// Only fixed markup and position-derived fragment IDs are active. All supplied
// collection strings are text, never URLs, attributes, CSS, or executable HTML.
fn book_collection_html_escape(text : String) -> String {
  let out = StringBuilder::new()
  for character in text.iter() {
    match character {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      '\'' => out.write_string("&#39;")
      '\r' => out.write_string("&#13;")
      _ => out.write_char(character)
    }
  }
  out.to_string()
}

///|
fn book_collection_html_text(text : String) -> String {
  "<div class=\"verbatim\">" + book_collection_html_escape(text) + "</div>"
}

///|
fn book_collection_html_metadata(label : String, value : String) -> String {
  "<dt>" +
  label +
  "</dt><dd>" +
  (if value.is_empty() {
    "<span class=\"missing\">Not supplied (empty label).</span>"
  } else {
    book_collection_html_text(value)
  }) +
  "</dd>"
}

///|
fn book_collection_html(state : BookCollectionState) -> String {
  let parts = [
    "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'\">",
    "<title>" +
    book_collection_html_escape(state.title) +
    " — MoonBook research brief</title>",
    (
      #|<style>
      #|:root{color-scheme:light}*{box-sizing:border-box}body{margin:0;background:#f1f5f9;color:#172033;font:17px/1.65 system-ui,sans-serif}main{max-width:920px;margin:auto;padding:36px 28px;background:white}h1,h2,h3{line-height:1.25}h1{font-size:2rem}h2{margin-top:2rem}h3{font-size:1.05rem}.eyebrow,.missing{color:#475569}.verbatim{white-space:pre-wrap;overflow-wrap:anywhere;tab-size:4}.scope{padding:16px;border:1px solid #cbd5e1;background:#f8fafc}nav{padding:4px 18px;border-left:4px solid #475569}nav li{margin:8px 0}a{color:#174b9b;text-decoration:underline;overflow-wrap:anywhere}article{border-top:2px solid #cbd5e1;margin-top:32px;padding-top:8px}dt{font-weight:650;margin-top:12px}dd{margin:2px 0 0}.note{padding:16px;background:#eff6ff;border-left:4px solid #2563eb}.snapshot{padding:16px;border:1px solid #cbd5e1}.back{font-size:.85rem}footer{margin-top:36px;color:#475569}a:focus-visible{outline:3px solid #b45309;outline-offset:3px}@page{margin:18mm}@media print{body,main{background:white}main{max-width:none;margin:0;padding:0;font-size:11pt}nav,.back{display:none}article{break-before:page}.note,.snapshot,.scope{background:white}h1,h2,h3,dt{break-after:avoid}a{color:inherit}body{-webkit-print-color-adjust:economy;print-color-adjust:economy}}
      #|</style>
      #|</head>
      #|<body><main id="top">
      #|<header><p class="eyebrow">MoonBook · Offline research brief</p>
    ),
    "<h1 class=\"verbatim\">" +
    book_collection_html_escape(state.title) +
    "</h1></header>",
    "<section class=\"scope\" aria-label=\"Reading scope\"><p>Selected maintained-page snapshots and researcher notes. This is a personal research brief, not factual review or accepted knowledge.</p><p>Book-relative citations apply only to the Book where this collection was assembled. Snapshots come from separate inspections, not an atomic Book revision. Titles come from search and may predate inspection.</p><p>Source references and digest labels are supplied data, including imported archive metadata. They are not independently verified here. Reinspect the same live Book to check freshness. Original retained files are not embedded.</p>",
    "<p>Current selections: " +
    state.items.length().to_string() +
    ". Historical snapshots in the resumable JSON: " +
    state.history.length().to_string() +
    ". This HTML contains current selections only. Keep the JSON file to resume editing and retain history; HTML cannot resume a collection.</p><p>No external resources are needed. Use your browser's Print command to print or save a PDF. Review selected content before sharing.</p></section>",
    "<section id=\"research\"><h2>Research question and synthesis</h2><p class=\"eyebrow\">Researcher-authored</p>" +
    book_collection_html_text(state.purpose) +
    (if state.purpose.is_empty() {
      "<p class=\"missing\">No research question or synthesis supplied.</p>"
    } else {
      ""
    }) +
    "</section>",
    "<nav aria-label=\"Brief contents\"><h2>Contents</h2><p><a href=\"#research\">Research question and synthesis</a></p><ol>",
  ]
  for index, item in state.items {
    let number = (index + 1).to_string()
    parts.push(
      "<li><a href=\"#selection-" +
      number +
      "\">" +
      book_collection_html_escape(
        if item.title.is_empty() {
          "Untitled selection"
        } else {
          item.title
        },
      ) +
      "</a> · <a href=\"#note-" +
      number +
      "\">Researcher note</a> · <a href=\"#snapshot-" +
      number +
      "\">Full snapshot</a></li>",
    )
  }
  parts.push("</ol></nav>")
  if state.items.is_empty() {
    parts.push(
      "<p class=\"missing\">No current selections. Historical snapshots are not included in this reading brief.</p>",
    )
  }
  for index, item in state.items {
    let number = (index + 1).to_string()
    parts.push(
      "<article id=\"selection-" +
      number +
      "\"><h2>Selection " +
      number +
      "</h2><dl>",
    )
    parts.push(
      book_collection_html_metadata(
        "Title from search (may predate inspection)",
        item.title,
      ),
    )
    parts.push(
      book_collection_html_metadata(
        "Book-relative citation",
        item.page.citation,
      ),
    )
    parts.push(
      book_collection_html_metadata("Found with question", item.page.question),
    )
    parts.push(
      "<dt>Search results page</dt><dd>" +
      (match item.page.page {
        Some(page) => (page.to_int64() + 1L).to_string() + " (one-based)"
        None => "<span class=\"missing\">Not supplied by the inspection.</span>"
      }) +
      "</dd>",
    )
    match item.page.retained_source {
      Some(source) => {
        parts.push(
          book_collection_html_metadata(
            "Supplied maintained-page SHA-256 at inspection",
            source.page_digest,
          ),
        )
        parts.push(
          book_collection_html_metadata(
            "Supplied retained-source reference (original bytes not included)",
            source.reference,
          ),
        )
      }
      None =>
        parts.push(
          "<dt>Maintained-page digest and retained-source reference</dt><dd class=\"missing\">Not supplied by the host for this page.</dd>",
        )
    }
    parts.push(
      "<dt>Inspection time and factual review</dt><dd class=\"missing\">Not recorded in this collection. No retrieval timestamp or factual approval is inferred.</dd></dl>",
    )
    parts.push(
      "<section class=\"note\" id=\"note-" +
      number +
      "\"><h3>Researcher note</h3>" +
      book_collection_html_text(item.note) +
      (if item.note.is_empty() {
        "<p class=\"missing\">No researcher note supplied.</p>"
      } else {
        ""
      }) +
      "</section>",
    )
    parts.push(
      "<section id=\"snapshot-" +
      number +
      "\"><h3>Complete maintained-page snapshot</h3><p class=\"eyebrow\">Source content, kept as collected. Embedded markup and links are displayed as text.</p><div class=\"snapshot\">" +
      book_collection_html_text(item.page.content) +
      (if item.page.content.is_empty() {
        "<p class=\"missing\">The supplied snapshot is empty.</p>"
      } else {
        ""
      }) +
      "</div></section><p class=\"back\"><a href=\"#top\">Back to top</a></p></article>",
    )
  }
  parts.push(
    "<footer>Generated from the current MoonBook research collection. No Book files, source acceptance, review state or journals were changed.</footer></main></body></html>\n",
  )
  parts.join("\n")
}

///|
extern "js" fn book_collection_html_download(text : String) -> @js.Promise =
  #| async text => {
  #|   const blob = new Blob([text], {type:"text/html;charset=utf-8"});
  #|   const url = URL.createObjectURL(blob); let link;
  #|   try {
  #|     link=document.createElement("a"); link.href=url; link.download="moonbook-research-brief.html";
  #|     document.body.appendChild(link); link.click();
  #|   } finally { try { link?.remove(); } finally { setTimeout(()=>URL.revokeObjectURL(url),1000); } }
  #|   return "Offline HTML brief download requested. Check your browser downloads. Save JSON separately to resume editing and retain history.";
  #| }
