///|
// Reader-owned notes are kept in browser storage, never in authored book files.
fn reader_notebook_data(context : RenderContext) -> String {
  let pages : Array[Json] = context.book
    .chapters()
    .map(fn(chapter) {
      let output = chapter_output_path(chapter)
      Json::object({
        "title": Json::string(chapter.display()),
        "path": Json::string(chapter.source_path.unwrap_or(output)),
        "href": Json::string(relative_href("__moonbook/notebook.html", output)),
      })
    })
  Json::object({
    "title": Json::string(context_title(context.config)),
    "pages": Json::array(pages),
  })
  .stringify()
  .replace(old="<", new="\\u003c")
  .replace(old=">", new="\\u003e")
  .replace(old="&", new="\\u0026")
}

///|
fn reader_notebook_script() -> String {
  (
    #|(function () {
    #|  "use strict";
    #|  const data = JSON.parse(document.getElementById("notebook-data").textContent);
    #|  const chapters = document.getElementById("notebook-chapters");
    #|  const editor = document.getElementById("notebook-note");
    #|  const status = document.getElementById("notebook-status");
    #|  const save = document.getElementById("notebook-save");
    #|  const download = document.getElementById("notebook-export");
    #|  const open = document.getElementById("notebook-open");
    #|  // Origin plus book-output directory separates books, even with identical titles.
    #|  const scope = new URL("../", location.href).href;
    #|  const key = "moonbook.reader-notebook.v1:" + scope;
    #|  let notes = new Map(), persistent = true, dirty = false;
    #|  function read() {
    #|    const raw = localStorage.getItem(key);
    #|    if (raw === null) return new Map();
    #|    const value = JSON.parse(raw);
    #|    if (value.version !== 1 || !Array.isArray(value.notes)) throw Error("Unsupported notebook");
    #|    const result = new Map();
    #|    for (const row of value.notes) {
    #|      if (!Array.isArray(row) || row.length !== 2 || typeof row[0] !== "string" || typeof row[1] !== "string") throw Error("Invalid note");
    #|      result.set(row[0], row[1]);
    #|    }
    #|    return result;
    #|  }
    #|  try { notes = read(); } catch (_) {
    #|    persistent = false;
    #|    status.textContent = "Browser storage is unavailable or unreadable. Notes stay in this tab; export before leaving. Existing stored data is untouched.";
    #|  }
    #|  function refreshChapters() {
    #|    chapters.replaceChildren();
    #|    const paths = data.pages.map(page => page.path);
    #|    for (const path of notes.keys()) if (!paths.includes(path)) paths.push(path);
    #|    for (const path of paths) {
    #|      const page = data.pages.find(page => page.path === path);
    #|      const option = document.createElement("option");
    #|      option.value = path; option.textContent = page ? page.title : "Removed chapter: " + path;
    #|      chapters.append(option);
    #|    }
    #|  }
    #|  refreshChapters();
    #|  let selected = data.pages.length ? data.pages[0].path : (notes.keys().next().value || "");
    #|  function show() {
    #|    chapters.value = selected;
    #|    editor.value = notes.get(selected) || "";
    #|    const page = data.pages.find(p => p.path === selected);
    #|    open.hidden = !page;
    #|    if (page) open.href = page.href.split("/").map(encodeURIComponent).join("/");
    #|    dirty = false;
    #|    editor.disabled = save.disabled = !selected;
    #|    refreshDiscovery();
    #|    refreshReadingProgress();
    #|  }
    #|  function keep() {
    #|    if (!selected) return;
    #|    // Merge unrelated chapter saves from another tab; retain removed chapters too.
    #|    if (persistent) {
    #|      try {
    #|        notes = read();
    #|      } catch (_) { persistent = false; }
    #|    }
    #|    if (editor.value.length) notes.set(selected, editor.value); else notes.delete(selected);
    #|    dirty = false;
    #|    if (persistent) {
    #|      try { localStorage.setItem(key, JSON.stringify({version: 1, notes: [...notes]})); }
    #|      catch (_) { persistent = false; }
    #|    }
    #|    status.textContent = persistent ? "Saved in this browser for this book. Export to keep a portable copy." :
    #|      "Kept in this tab only. Browser storage is unavailable; export before leaving.";
    #|    refreshDiscovery();
    #|  }
    #|  editor.addEventListener("input", () => { dirty = true; status.textContent = "Unsaved note. Save, switch chapter, or export to keep it in this tab."; refreshDiscovery(); });
    #|  save.addEventListener("click", keep);
    #|  chapters.addEventListener("change", () => {
    #|    const next = chapters.value;
    #|    if (dirty) keep();
    #|    selected = next; show();
    #|  });
    #|  window.addEventListener("beforeunload", event => {
    #|    if (dirty || (!persistent && notes.size) || readingNeedsWarning()) { event.preventDefault(); event.returnValue = ""; }
    #|  });
    #|  function plain(text) { return text.replace(/[\r\n]+/g, " ").replace(/[\\`*_{}\[\]<>#]/g, "\\$&"); }
    #|  download.addEventListener("click", exportMarkdownNotes);
    #|  function downloadFile(text, type, name) {
    #|    const url = URL.createObjectURL(new Blob([text], {type}));
    #|    const link = document.createElement("a");
    #|    link.href = url; link.download = name;
    #|    document.body.append(link); link.click(); link.remove();
    #|    setTimeout(() => URL.revokeObjectURL(url), 1000);
    #|  }
  ) +
  reader_notebook_archive_script() +
  reader_notebook_markdown_script() +
  reader_notebook_discovery_script() +
  reader_notebook_progress_script() +
  reader_notebook_progress_archive_script() +
  reader_notebook_recovery_script() +
  reader_notebook_selected_export_script() +
  (
    #|  show();
    #|  if (persistent) status.textContent = data.pages.length ? "Choose a chapter and write a note. " + notes.size + " saved notes." : "No chapters in this book.";
    #|})();
  )
}

///|
async fn write_reader_notebook(context : RenderContext) -> Unit {
  let title = escape_html(context_title(context.config))
  let data = reader_notebook_data(context)
  let script = reader_notebook_script()
  let page =
    $|<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Reader notebook — \{title}</title>
    $|<style>body{font:1rem/1.6 system-ui,sans-serif;max-width:52rem;margin:auto;padding:1.5rem;color:#1f2328;background:white}select,textarea,input{box-sizing:border-box;width:100%;font:inherit;padding:.7rem}textarea{min-height:18rem}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f6f8fa;padding:.7rem}fieldset{margin-top:1rem;border:1px solid #8c959f}input{max-width:100%}label{display:block;font-weight:600;margin-top:1rem}button{font:inherit;min-height:44px;margin:1rem .6rem 0 0;padding:.4rem 1rem}a{color:#0969da}a:focus-visible,button:focus-visible,select:focus-visible,textarea:focus-visible{outline:3px solid #0969da;outline-offset:3px}</style></head><body>
    $|<p><a href="../index.html">Back to book</a></p><h1>Reader notebook</h1><h2>\{title}</h2><p>Personal chapter notes, separate from authored or reviewed book content. Stored only in this browser for this book URL. Export a notebook archive to restore notes after moving the book or changing browsers. Direct file storage varies by browser; serving the book locally is more reliable.</p>
    $|<section aria-label="Find your notes"><h2>Find your notes</h2><label for="notebook-query">Search note text, chapter title or source path</label><input id="notebook-query" type="search" placeholder="Search your notes"><label for="notebook-filter">Show notes</label><select id="notebook-filter"><option value="all">All notes</option><option value="saved">Saved notes</option><option value="draft">Unsaved draft</option><option value="removed">Removed chapters</option></select><button id="notebook-query-clear" type="button">Clear search and filters</button><p id="notebook-matches-status" role="status" aria-live="polite"></p><ul id="notebook-matches"></ul></section>
    $|<section aria-label="Reading progress"><h2>Reading progress</h2><p>Mark chapters read yourself. Opening a chapter does not mark it read. Progress is personal to this browser and book URL, separate from your notes and reviewed book claims.</p><p id="notebook-progress-status" role="status" aria-live="polite"></p><button id="notebook-read-toggle" type="button">Mark selected chapter read</button><button id="notebook-next-unread" type="button">Next unread chapter</button><button id="notebook-resume" type="button">Resume reading</button></section>
    $|<section aria-label="Move or restore reading progress"><h2>Move or restore reading progress</h2><p>Export read marks and reading position separately from notes. Import merges exact source paths, never clears existing read marks, and does not verify book identity. Review the source title and paths before applying. No file is uploaded.</p><button id="notebook-progress-export" type="button">Export reading progress</button><label for="notebook-progress-file">Import reading progress (.json, up to 5 MiB)</label><input id="notebook-progress-file" type="file" accept=".json,application/json"><p id="notebook-progress-message" role="status" aria-live="polite"></p><section id="notebook-progress-preview" hidden aria-label="Reading progress import preview"><p id="notebook-progress-summary"></p><ul id="notebook-progress-items"></ul><label><input id="notebook-progress-position" type="checkbox" style="width:auto">Use imported reading position</label><button id="notebook-progress-apply" type="button">Import read marks</button><button id="notebook-progress-cancel" type="button">Cancel progress import</button></section></section>
    $|<label for="notebook-chapters">Chapter</label><select id="notebook-chapters"></select><p><a id="notebook-open" hidden>Read selected chapter</a></p>
    $|<label for="notebook-note">Your note</label><textarea id="notebook-note" disabled></textarea><button id="notebook-save" type="button" disabled>Save note</button><button id="notebook-export" type="button">Export Markdown notes</button><p id="notebook-status" role="status" aria-live="polite"></p>
    $|<section aria-label="Recover a removed-chapter note"><h2>Recover a removed-chapter note</h2><p>If a chapter was renamed or reorganized, choose its old note and the current destination yourself. Preview before copying or appending. The original note stays available; no chapter match is inferred and reading progress is unchanged.</p><label for="notebook-recovery-source">Removed chapter note</label><select id="notebook-recovery-source"></select><label for="notebook-recovery-target">Current destination chapter</label><select id="notebook-recovery-target"></select><button id="notebook-recovery-review" type="button">Preview note recovery</button><p id="notebook-recovery-message" role="status" aria-live="polite"></p><section id="notebook-recovery-preview" hidden aria-label="Note recovery preview"><p id="notebook-recovery-summary"></p><h3>Original note (retained)</h3><pre id="notebook-recovery-original"></pre><h3>Current destination note</h3><pre id="notebook-recovery-current"></pre><label for="notebook-recovery-mode">How to recover the note</label><select id="notebook-recovery-mode"></select><h3>Resulting destination note</h3><pre id="notebook-recovery-result"></pre><button id="notebook-recovery-apply" type="button" disabled>Save recovered note</button><button id="notebook-recovery-cancel" type="button">Cancel recovery</button></section></section>
    $|<section aria-label="Export selected notes"><h2>Export selected notes</h2><p>Prepare a focused brief or portable archive without including unrelated notes. Review full note text and select exact paths. A current draft is included for review but never saved by this export. Files contain the book title and selected chapter paths; inspect before sharing.</p><button id="notebook-selected-review" type="button">Choose notes for export</button><p id="notebook-selected-message" role="status" aria-live="polite"></p><section id="notebook-selected-preview" hidden aria-label="Selected notes export review"><button id="notebook-selected-all" type="button">Select all export notes</button><button id="notebook-selected-none" type="button">Clear export selection</button><p id="notebook-selected-count" role="status" aria-live="polite"></p><div id="notebook-selected-items"></div><button id="notebook-selected-markdown" type="button" disabled>Download selected Markdown</button><button id="notebook-selected-archive" type="button" disabled>Download selected archive</button><button id="notebook-selected-cancel" type="button">Cancel selected export</button></section></section>
    $|<h2>Move, restore or edit your notes</h2><p>Export an archive to move notes, or export Markdown to edit the quoted note lines in a text editor. Keep the MoonBook comments and structure, then import the edited file for review. Import matches exact chapter paths. Preview every incoming note, include only the ones you want, and choose replacements for conflicts. Unselected notes and kept-current drafts stay unchanged. No file is uploaded.</p>
    $|<button id="notebook-archive-export" type="button">Export notebook archive</button><label for="notebook-archive-file">Import notebook archive or edited Markdown (.json or .md, up to 5 MiB)</label><input id="notebook-archive-file" type="file" accept=".json,.md,application/json,text/markdown,text/plain">
    $|<section id="notebook-archive-preview" hidden aria-label="Notebook import preview"><p id="notebook-archive-summary"></p><button id="notebook-archive-all" type="button">Select all incoming notes</button><button id="notebook-archive-none" type="button">Clear note selection</button><p id="notebook-archive-selection" role="status" aria-live="polite"></p><div id="notebook-archive-items"></div><div id="notebook-archive-conflicts"></div><button id="notebook-archive-apply" type="button">Import selected notes</button><button id="notebook-archive-cancel" type="button">Cancel import</button></section>
    $|<noscript>Enable JavaScript to write and export notes. The book remains readable.</noscript>
    $|<script id="notebook-data" type="application/json">\{data}</script><script id="notebook-script">\{script}</script></body></html>
  write_text_file(
    @pathx.join(context.build_dir, "__moonbook/notebook.html"),
    page,
  )
}
