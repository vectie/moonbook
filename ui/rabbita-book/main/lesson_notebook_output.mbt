///|
fn lesson_notebook_html(draft : LessonNotebookDraft) -> String {
  let text = book_collection_html_text
  let parts = [
    "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'\"><title>MoonBook decision notebook</title><style>body{font:17px/1.6 system-ui,sans-serif;color:#172033;background:#fff;margin:2rem auto;padding:0 1rem;max-width:900px}article,section{border:1px solid #94a3b8;padding:1rem;margin:1rem 0}.verbatim{white-space:pre-wrap;overflow-wrap:anywhere}h1,h2,h3{line-height:1.2}.label{font-weight:700}nav a{color:#334e88}@media print{body{margin:0;max-width:none}article{break-inside:avoid}}</style></head><body><main id=\"top\"><h1>Decision notebook</h1>",
    "<p>Authored planning document with captured prior lessons. Notes, roles and proposed decisions are the author's judgments, not accepted Book knowledge. Captured review labels are not independent verification of this file. No task, activation or customer outcome is authorized.</p>",
    "<section><h2>Decision question</h2>" +
    text(draft.question) +
    "<h3>Proposed decision and reasoning · authored</h3>" +
    text(draft.decision) +
    "<h3>Uncertainty, contradiction and next check · authored</h3>" +
    text(draft.uncertainty) +
    "</section><nav aria-label=\"Experiences\"><ol>",
  ]
  for index, item in draft.items {
    parts.push(
      "<li><a href=\"#experience-" +
      (index + 1).to_string() +
      "\">" +
      book_collection_html_escape(item.snapshot.title) +
      "</a></li>",
    )
  }
  parts.push("</ol></nav>")
  for index, item in draft.items {
    let s = item.snapshot
    parts.push(
      "<article id=\"experience-" +
      (index + 1).to_string() +
      "\"><h2>" +
      (index + 1).to_string() +
      ". " +
      book_collection_html_escape(s.title) +
      "</h2><h3>How this experience informs the question · authored</h3><p class=\"label\">" +
      book_collection_html_escape(item.stance) +
      "</p>" +
      text(item.note) +
      "<h3>Captured guidance · unchanged</h3>" +
      text(s.guidance) +
      "<h3>Required scope</h3>" +
      text(s.applicability.stringify(indent=2)) +
      "<h3>Do not use when</h3>" +
      text(s.invalidation.stringify(indent=2)) +
      "<h3>Captured review and outcome references</h3>" +
      text(s.reviewer + "\n" + s.review_summary) +
      text(
        (
          {
            "lesson": ToJson::to_json(s.reference),
            "lesson_id": s.lesson_id,
            "accepted_review": ToJson::to_json(s.accepted_review),
            "selection_review": s.selection_review,
            "outcome": s.outcome,
            "assessment": s.assessment,
          } : Json).stringify(indent=2),
      ) +
      "<p>Snapshot only. Reopen Book and recheck current guidance, source outcome and scope before reuse. Incompatible experiences remain separate; no consensus is inferred.</p><a href=\"#top\">Back to question</a></article>",
    )
  }
  parts.push(
    "<footer>Keep the separate decision-notebook JSON to resume editing. This static HTML has no network requests or active scripts. Book source files, accepted knowledge and journals were not changed.</footer></main></body></html>\n",
  )
  parts.join("\n")
}

///|
extern "js" fn lesson_notebook_download(
  text : String,
  html : Bool,
) -> @js.Promise =
  #| async (text, html) => {
  #|   const blob = new Blob([text], {type:html ? 'text/html;charset=utf-8' : 'application/json;charset=utf-8'});
  #|   const url = URL.createObjectURL(blob); let link;
  #|   try { link=document.createElement('a'); link.href=url; link.download=html?'moonbook-decision-notebook.html':'moonbook-decision-notebook.json'; document.body.appendChild(link); link.click(); }
  #|   finally { try { link?.remove(); } finally { setTimeout(()=>URL.revokeObjectURL(url),1000); } }
  #|   return html ? 'Offline decision notebook download requested. Check browser downloads. Save JSON separately to resume.' : 'Editable notebook JSON download requested. Check browser downloads before leaving this tab.';
  #| }
