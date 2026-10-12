///|
// Reader-owned external editing, composed into the ordinary notebook.
fn reader_notebook_markdown_script() -> String {
  (
    #|  // This intentionally bounded Markdown exchange reuses the archive's reviewed merge.
    #|  function markdownMetadata(value) {
    #|    return JSON.stringify(value).replace(/[<>&]/g, char => ({"<": "\\u003c", ">": "\\u003e", "&": "\\u0026"})[char]);
    #|  }
    #|  function markdownNotesText(sourceNotes) {
    #|    let text = "# Reading notes: " + plain(data.title) + "\n\n";
    #|    text += "<!-- moonbook.reader-notes.v1 " + markdownMetadata({title: data.title}) + " -->\n\n";
    #|    text += "Personal reader notes; not reviewed book claims.\n\n";
    #|    const ordered = data.pages.map(p => p.path);
    #|    for (const path of sourceNotes.keys()) if (!ordered.includes(path)) ordered.push(path);
    #|    for (const path of ordered) {
    #|      if (!sourceNotes.has(path)) continue;
    #|      const page = data.pages.find(p => p.path === path);
    #|      text += "## " + plain(page ? page.title : "Removed chapter: " + path) + "\n\nSource: " + plain(path) + "\n\n";
    #|      text += "<!-- moonbook.note.v1 " + markdownMetadata({path}) + " -->\n";
    #|      // LF is the text-editor exchange newline. Encode once, decode once on import.
    #|      text += sourceNotes.get(path).replace(/\r\n?/g, "\n").split("\n").map(line => "> " + line.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")).join("\n");
    #|      text += "\n<!-- /moonbook.note -->\n\n";
    #|    }
    #|    return text;
    #|  }
    #|  function exportMarkdownNotes() {
    #|    if (dirty) keep();
    #|    downloadFile(markdownNotesText(notes), "text/markdown;charset=utf-8", "reading-notes.md");
    #|    status.textContent = "Markdown notes exported. Edit the quoted lines, keep the MoonBook comments, then import to review changes. JSON archives preserve original line endings.";
    #|  }
    #|  function decodeMarkdownNotes(text) {
    #|    if (new Blob([text]).size > maxBytes) throw Error("Markdown exceeds 5 MiB.");
    #|    const lines = text.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n").split("\n");
    #|    let i = 0;
    #|    const fail = reason => { throw Error("Markdown line " + (i + 1) + ": " + reason); };
    #|    const blanks = () => { while (i < lines.length && /^\s*$/.test(lines[i])) i++; };
    #|    const metadata = (pattern, name) => {
    #|      const match = (lines[i] || "").match(pattern);
    #|      if (!match) fail("Keep the " + name + " comment from a current MoonBook Markdown export.");
    #|      let value;
    #|      try { value = JSON.parse(match[1]); } catch (_) { fail("Invalid " + name + " JSON."); }
    #|      if (!value || typeof value !== "object" || Array.isArray(value)) fail("Invalid " + name + " metadata.");
    #|      i++; return value;
    #|    };
    #|    if (!(lines[i] || "").startsWith("# Reading notes: ")) fail("Expected a current MoonBook Markdown notes export.");
    #|    i++; blanks();
    #|    const book = metadata(/^<!-- moonbook\.reader-notes\.v1 (.*) -->$/, "book identity");
    #|    blanks();
    #|    if (lines[i] !== "Personal reader notes; not reviewed book claims.") fail("Keep the reader-commentary notice.");
    #|    i++; blanks();
    #|    const rows = [];
    #|    while (i < lines.length) {
    #|      if (!lines[i].startsWith("## ")) fail("Expected a chapter heading; edits belong in quoted note lines.");
    #|      i++; blanks();
    #|      if (!(lines[i] || "").startsWith("Source: ")) fail("Keep the displayed source path line.");
    #|      i++; blanks();
    #|      const entry = metadata(/^<!-- moonbook\.note\.v1 (.*) -->$/, "chapter identity");
    #|      const body = [];
    #|      while (i < lines.length && lines[i] !== "<!-- /moonbook.note -->") {
    #|        const line = lines[i];
    #|        if (line !== ">" && !line.startsWith("> ")) fail("Prefix every note line with > and keep the closing MoonBook comment.");
    #|        body.push((line === ">" ? "" : line.slice(2)).replace(/&(?:amp|lt|gt);/g, entity => ({"&amp;": "&", "&lt;": "<", "&gt;": ">"})[entity]));
    #|        i++;
    #|      }
    #|      if (!body.length || i >= lines.length) fail("A note needs quoted lines and a closing MoonBook comment.");
    #|      rows.push([entry.path, body.join("\n")]);
    #|      if (rows.length > 10000) fail("At most 10,000 notes can be imported.");
    #|      i++; blanks();
    #|    }
    #|    // Share exact path, title, duplicate and note-count validation with JSON imports.
    #|    const result = decodeArchive(JSON.stringify({format: "moonbook.reader-notebook-archive", version: 1, title: book.title, notes: rows}));
    #|    result.kind = "Edited Markdown";
    #|    return result;
    #|  }
    #|  function decodeNotebookImport(text) {
    #|    const clean = text.replace(/^\uFEFF/, "");
    #|    return clean.trimStart().startsWith("{") ? decodeArchive(clean) : decodeMarkdownNotes(clean);
    #|  }
  )
}
