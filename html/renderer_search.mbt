///|
// Generated from the same loaded, SUMMARY-ordered chapters as the reader.
// Kept in one file so the exact shipped browser code is exercised by Node tests.
fn static_search_data(chapters : Array[@core.Chapter]) -> String {
  let pages : Array[Json] = chapters.map(fn(chapter) {
    let output = chapter_output_path(chapter)
    Json::object({
      "title": Json::string(chapter.display()),
      "path": Json::string(chapter.source_path.unwrap_or(output)),
      "href": Json::string(relative_href("__moonbook/search.html", output)),
      "text": Json::string(chapter.content),
    })
  })
  let escaped = StringBuilder()
  for character in Json::array(pages).stringify() {
    match character {
      '<' => escaped.write_string("\\u003c")
      '>' => escaped.write_string("\\u003e")
      '&' => escaped.write_string("\\u0026")
      _ => escaped.write_char(character)
    }
  }
  escaped.to_string()
}

///|
fn static_search_script() -> String {
  let script =
    #|(function () {
    #|  "use strict";
    #|  const pages = JSON.parse(document.getElementById("book-search-data").textContent);
    #|  const form = document.getElementById("book-search-form");
    #|  const input = document.getElementById("book-search-query");
    #|  const status = document.getElementById("book-search-status");
    #|  const list = document.getElementById("book-search-results");
    #|  const previous = document.getElementById("book-search-previous");
    #|  const next = document.getElementById("book-search-next");
    #|  let matches = [], offset = 0;
    #|  const pageSize = 20;
    #|  function literal(term) {
    #|    return new RegExp(term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "iu");
    #|  }
    #|  function excerpt(text, terms) {
    #|    let position = -1;
    #|    for (const term of terms) {
    #|      const found = term.exec(text);
    #|      if (found && (position < 0 || found.index < position)) position = found.index;
    #|    }
    #|    if (position < 0) position = 0;
    #|    const before = Array.from(text.slice(0, position));
    #|    const after = Array.from(text.slice(position));
    #|    return (before.length > 60 ? "…" : "") + before.slice(-60).join("") +
    #|      after.slice(0, 180).join("") + (after.length > 180 ? "…" : "");
    #|  }
    #|  function render() {
    #|    list.replaceChildren();
    #|    previous.disabled = offset === 0;
    #|    next.disabled = offset + pageSize >= matches.length;
    #|    status.textContent = matches.length ?
    #|      "Showing " + (offset + 1) + "–" + Math.min(offset + pageSize, matches.length) +
    #|        " of " + matches.length + " matching chapters." : "No matching chapters. Try different words.";
    #|    for (const match of matches.slice(offset, offset + pageSize)) {
    #|      const item = document.createElement("li");
    #|      const link = document.createElement("a");
    #|      // All paths come from generated chapter outputs, relative to this page.
    #|      link.href = match.page.href.split("/").map(encodeURIComponent).join("/");
    #|      link.textContent = match.page.title;
    #|      const path = document.createElement("p");
    #|      path.className = "search-path";
    #|      path.textContent = match.page.path;
    #|      const preview = document.createElement("p");
    #|      preview.className = "search-excerpt";
    #|      preview.textContent = match.excerpt;
    #|      item.append(link, path, preview);
    #|      list.append(item);
    #|    }
    #|  }
    #|  function search() {
    #|    matches = []; offset = 0;
    #|    const query = input.value.trim();
    #|    if (!query || query.length > 200) {
    #|      list.replaceChildren(); previous.disabled = true; next.disabled = true;
    #|      status.textContent = query ? "Use at most 200 characters." :
    #|        "Enter words to search " + pages.length + " chapters.";
    #|      return;
    #|    }
    #|    const words = Array.from(new Set(query.split(/\s+/u)));
    #|    if (words.length > 20) {
    #|      list.replaceChildren(); previous.disabled = true; next.disabled = true;
    #|      status.textContent = "Use at most 20 search words.";
    #|      return;
    #|    }
    #|    const terms = words.map(literal);
    #|    for (let order = 0; order < pages.length; order++) {
    #|      const page = pages[order];
    #|      if (!terms.every(term => term.test(page.title) || term.test(page.text))) continue;
    #|      const score = terms.filter(term => term.test(page.title)).length;
    #|      matches.push({page, order, score, excerpt: excerpt(page.text, terms)});
    #|    }
    #|    matches.sort((a, b) => b.score - a.score || a.order - b.order);
    #|    render();
    #|  }
    #|  form.addEventListener("submit", event => { event.preventDefault(); search(); });
    #|  input.addEventListener("input", search);
    #|  previous.addEventListener("click", () => {
    #|    offset = Math.max(0, offset - pageSize); render();
    #|  });
    #|  next.addEventListener("click", () => {
    #|    if (offset + pageSize < matches.length) offset += pageSize;
    #|    render();
    #|  });
    #|  search();
    #|})();
  script
}

///|
fn static_search_page(context : RenderContext) -> String {
  let title = static_search_escape_html(context_title(context.config))
  let data = static_search_data(context.book.chapters())
  let script = static_search_script()
  let page =
    $|<!doctype html>
    $|<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    $|<title>Search this Book · \{title}</title>
    $|<style>body{font:1rem/1.6 system-ui,sans-serif;max-width:52rem;margin:auto;padding:1.5rem;color:#1f2328;background:#fff}a{color:#0969da}input{box-sizing:border-box;width:100%;font:inherit;padding:.7rem}button{font:inherit;min-height:44px;margin:.6rem .6rem .6rem 0;padding:.4rem 1rem}li{margin:1.5rem 0}li>a{font-size:1.15rem;font-weight:600}.search-path{font-size:.85rem;color:#59636e;overflow-wrap:anywhere}.search-excerpt{white-space:pre-wrap;overflow-wrap:anywhere}label{display:block;font-weight:600}button:focus-visible,a:focus-visible,input:focus-visible{outline:3px solid #0969da;outline-offset:3px}</style>
    $|</head><body><a href="../index.html">Back to book</a><h1>Search this Book</h1><p>\{title}</p>
    $|<p>Search the titles and complete Markdown of rendered chapters in this build. All words must match; title matches come first, then book order. Excerpts may include Markdown, code and metadata. Rebuild the book to update these results. Search does not verify claims.</p>
    $|<form id="book-search-form"><label for="book-search-query">Words to find</label><input id="book-search-query" type="search" maxlength="200" autocomplete="off"><button type="submit">Search</button></form>
    $|<p id="book-search-status" role="status" aria-live="polite"></p><ol id="book-search-results"></ol>
    $|<button id="book-search-previous" type="button" disabled>Previous results</button><button id="book-search-next" type="button" disabled>Next results</button>
    $|<noscript>Search requires JavaScript. Use the book contents to read chapters.</noscript>
    $|<script id="book-search-data" type="application/json">\{data}</script>
    $|<script id="book-search-script">\{script}</script></body></html>
  page
}

///|
async fn write_static_search(context : RenderContext) -> Unit {
  let directory = moonbook_html_path(context.build_dir)
    .join(moonbook_html_path("__moonbook"))
    .to_string()
  ensure_dir(directory)
  write_text_file(
    moonbook_html_path(directory)
    .join(moonbook_html_path("search.html"))
    .to_string(),
    static_search_page(context),
  )
}

///|
fn is_static_search_reserved(path : String) -> Bool {
  let normalized = @pathx.normalize(path)
  normalized == "__moonbook" || normalized.has_prefix("__moonbook/")
}

///|
fn check_static_search_paths(context : RenderContext) -> Unit raise {
  if not_found_output_path(context.config) is Some(path) &&
    is_static_search_reserved(path) {
    fail("404 output uses reserved static-search directory: " + path)
  }
  for chapter in context.book.chapters() {
    if is_static_search_reserved(chapter_output_path(chapter)) {
      fail(
        "Chapter output uses reserved static-search directory: " +
        chapter_output_path(chapter),
      )
    }
    let directory = match chapter.source_path {
      Some(path) => path_dirname(path)
      None => "."
    }
    for asset in collect_markdown_assets(chapter.content) {
      if is_local_asset(asset) &&
        is_static_search_reserved(
          @pathx.join(directory, strip_link_anchor(asset)),
        ) {
        fail("Chapter asset uses reserved static-search directory: " + asset)
      }
    }
  }
  for asset in configured_html_assets(context.config) {
    if is_static_search_reserved(asset) {
      fail("Configured asset uses reserved static-search directory: " + asset)
    }
  }
}

///|
fn static_search_escape_html(text : String) -> String {
  let escaped = StringBuilder()
  for character in text {
    match character {
      '&' => escaped.write_string("&amp;")
      '<' => escaped.write_string("&lt;")
      '>' => escaped.write_string("&gt;")
      '"' => escaped.write_string("&quot;")
      _ => escaped.write_char(character)
    }
  }
  escaped.to_string()
}
