///|
// A replaceable projection of the same loaded chapters as ordinary page builds.
fn whole_book_page(context : RenderContext) -> String {
  let chapters = context.book.chapters()
  let targets : Map[String, String] = {}
  for index, chapter in chapters {
    let id = "chapter-\{index + 1}"
    targets[chapter_output_path(chapter)] = id
    // The loader maps README.md to index.html; links may still name README.md.
    if chapter.source_path is Some(source) {
      targets[@pathx.normalize(source)] = id
      targets[fix_link_path(@pathx.normalize(source))] = id
    }
  }
  let contents = StringBuilder()
  let body = StringBuilder()
  for index, chapter in chapters {
    let id = "chapter-\{index + 1}"
    let title = static_search_escape_html(chapter.display())
    contents.write_string("<li><a href=\"#\{id}\">\{title}</a></li>")
    let rendered = render_chapter_body(chapter)
    let linked = whole_book_rewrite_html(
      rendered,
      id,
      chapter_output_path(chapter),
      targets,
    )
    // A duplicated leading Markdown title is stripped by the ordinary renderer.
    // Retain its anchor here so links to that authored heading still work.
    let title_id = slugify_heading(chapter.name)
    let title_anchor = if !rendered.contains("id=\"\{title_id}\"") {
      "<span id=\"\{id}--\{static_search_escape_html(title_id)}\"></span>"
    } else {
      ""
    }
    let source = static_search_escape_html(chapter.source_path.unwrap_or(""))
    let original = static_search_escape_html(
      relative_href("__moonbook/print.html", chapter_output_path(chapter)),
    )
    body.write_string(
      "<section class=\"print-section\" id=\"\{id}\">\{title_anchor}<p class=\"chapter-origin\">Source: \{source} · <a href=\"\{original}\">Open chapter</a></p>\{linked}</section>",
    )
  }
  if chapters.is_empty() {
    body.write_string("<p>No chapters found.</p>")
  }
  let title = static_search_escape_html(context_title(context.config))
  let contents = contents.to_string()
  let body = body.to_string()
  let count = chapters.length()
  let page =
    $|<!doctype html>
    $|<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    $|<title>Whole book · \{title}</title>
    $|<style>
    $|*{box-sizing:border-box}body{font:1rem/1.65 system-ui,sans-serif;color:#1f2328;background:white;max-width:58rem;margin:auto;padding:2rem}a{color:#0969da}h1,h2,h3{line-height:1.25}h1{font-size:2rem}h2{margin-top:2rem}a:focus-visible,button:focus-visible{outline:3px solid #0969da;outline-offset:3px}.toolbar{display:flex;gap:1rem;align-items:center;flex-wrap:wrap}button{font:inherit;padding:.5rem 1rem;min-height:44px;cursor:pointer}.book-contents{padding:1rem;background:#f6f8fa}.book-contents li{margin:.35rem 0}.print-section{border-top:1px solid #d0d7de;margin-top:3rem;padding-top:1rem}.chapter-origin,.breadcrumbs{color:#59636e;font-size:.85rem;overflow-wrap:anywhere}.chapter img{max-width:100%;height:auto}.chapter pre{white-space:pre-wrap;overflow-wrap:anywhere;padding:1rem;background:#f6f8fa;border:1px solid #d0d7de}.chapter code{overflow-wrap:anywhere}.chapter table{border-collapse:collapse;width:100%;table-layout:fixed;overflow-wrap:anywhere}.chapter th,.chapter td{border:1px solid #d0d7de;padding:.4rem;text-align:left}.chapter blockquote{border-left:3px solid #d0d7de;padding-left:1rem;margin-left:0}.code-copy{display:none}.chapter a{overflow-wrap:anywhere}.print-section:target{outline:2px solid #0969da;outline-offset:.5rem}@media(max-width:600px){body{padding:1rem}}
    $|@media print{@page{margin:18mm}body{max-width:none;margin:0;padding:0;font-size:11pt;background:white;color:black}.toolbar,.screen-only,.code-copy{display:none!important}.book-contents{background:white}.print-section{break-before:page;border:0;margin:0;padding:0;outline:0!important}h1,h2,h3,h4{break-after:avoid}img,pre,tr{break-inside:avoid}a{color:inherit;text-decoration:underline}pre{white-space:pre-wrap;overflow-wrap:anywhere}.table-wrapper{overflow:visible}thead{display:table-header-group}}
    $|</style></head><body>
    $|<nav class="toolbar" aria-label="Book tools"><a href="../index.html">Back to book</a><a href="search.html">Search this Book</a><button id="print-book" type="button" hidden>Print / Save PDF</button></nav>
    $|<header><h1>\{title}</h1><p>Whole book · \{count} chapters in book order</p><p class="screen-only">Read every rendered chapter here, or use your browser’s Print command to print or save a PDF. Rebuild after source changes. Keep the complete build folder for local images and chapter links. This projection does not change or verify the source.</p></header>
    $|<nav class="book-contents" aria-label="Whole book contents"><h2>Contents</h2><ol>\{contents}</ol></nav><main>\{body}</main>
    $|<script id="whole-book-print-script">(function(){const printButton=document.getElementById("print-book");printButton.hidden=false;printButton.addEventListener("click",()=>window.print());})();</script>
    $|</body></html>
  page
}

///|
async fn write_whole_book(context : RenderContext) -> Unit {
  let destination = @pathx.join(context.build_dir, "__moonbook/print.html")
  ensure_parent_dir(destination)
  write_text_file(destination, whole_book_page(context))
}
