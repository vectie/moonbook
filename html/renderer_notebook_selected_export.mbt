///|
// Focused reader-note output, with explicit selection and unchanged source/draft state.
fn reader_notebook_selected_export_script() -> String {
  (
    #|  const selectedExportPreview = document.getElementById("notebook-selected-preview");
    #|  const selectedExportItems = document.getElementById("notebook-selected-items");
    #|  const selectedExportCount = document.getElementById("notebook-selected-count");
    #|  const selectedExportMessage = document.getElementById("notebook-selected-message");
    #|  const selectedMarkdown = document.getElementById("notebook-selected-markdown");
    #|  const selectedArchive = document.getElementById("notebook-selected-archive");
    #|  let selectedExport = null;
    #|  function updateSelectedExport() {
    #|    if (!selectedExport) return;
    #|    const count = [...selectedExport.controls.values()].filter(control => control.checked).length;
    #|    selectedExportCount.textContent = count + " of " + selectedExport.controls.size + " notes selected. Only checked notes will be downloaded.";
    #|    selectedMarkdown.disabled = selectedArchive.disabled = count === 0;
    #|  }
    #|  function reviewSelectedExport(current, message = "") {
    #|    selectedExportItems.replaceChildren();
    #|    const pages = new Map(data.pages.map(page => [page.path, page]));
    #|    const ordered = [...pages.keys()];
    #|    for (const path of current.keys()) if (!pages.has(path)) ordered.push(path);
    #|    const controls = new Map();
    #|    for (const path of ordered) {
    #|      const text = current.get(path);
    #|      if (!text) continue;
    #|      const page = pages.get(path);
    #|      const field = document.createElement("fieldset");
    #|      const legend = document.createElement("legend"); legend.textContent = path;
    #|      const context = document.createElement("p");
    #|      context.textContent = (page ? page.title : "Removed chapter") + " · " +
    #|        (dirty && path === selected ? "Unsaved draft" : persistent ? "Saved note" : "Tab-only note");
    #|      const content = document.createElement("pre"); content.textContent = text;
    #|      const label = document.createElement("label"); label.textContent = "Include in export: " + path;
    #|      const control = document.createElement("input"); control.type = "checkbox"; control.style.width = "auto";
    #|      control.checked = false; control.addEventListener("change", updateSelectedExport);
    #|      label.append(control); field.append(legend, context, content, label);
    #|      selectedExportItems.append(field); controls.set(path, control);
    #|    }
    #|    selectedExport = {current, controls}; selectedExportPreview.hidden = false;
    #|    updateSelectedExport();
    #|    selectedExportMessage.textContent = message + (controls.size ?
    #|      "Review full text and check the notes to download. Nothing is selected automatically. Notes and drafts are unchanged." :
    #|      "No nonempty notes to export. Write a note or import an archive first.");
    #|  }
    #|  document.getElementById("notebook-selected-review").addEventListener("click", () => reviewSelectedExport(snapshotNotes()));
    #|  for (const [id, checked] of [["notebook-selected-all", true], ["notebook-selected-none", false]]) {
    #|    document.getElementById(id).addEventListener("click", () => {
    #|      if (!selectedExport) return;
    #|      for (const control of selectedExport.controls.values()) control.checked = checked;
    #|      updateSelectedExport();
    #|    });
    #|  }
    #|  document.getElementById("notebook-selected-cancel").addEventListener("click", () => {
    #|    selectedExport = null; selectedExportPreview.hidden = true; selectedExportItems.replaceChildren();
    #|    selectedMarkdown.disabled = selectedArchive.disabled = true;
    #|    selectedExportMessage.textContent = "Selected export cancelled. Notes and drafts are unchanged.";
    #|  });
    #|  function downloadSelectedNotes(kind) {
    #|    if (!selectedExport) return;
    #|    const current = snapshotNotes();
    #|    if (!sameNotes(current, selectedExport.current)) {
    #|      reviewSelectedExport(current, "Notes changed since review. Export selection cleared; review and choose again. "); return;
    #|    }
    #|    const chosen = new Map();
    #|    for (const [path, control] of selectedExport.controls) {
    #|      if (control.checked) chosen.set(path, current.get(path));
    #|    }
    #|    if (!chosen.size) { selectedExportMessage.textContent = "Choose at least one note to export."; return; }
    #|    try {
    #|      const archiveText = JSON.stringify({format: "moonbook.reader-notebook-archive", version: 1, title: data.title, notes: [...chosen]}, null, 2) + "\n";
    #|      // Validate only the chosen scope, with the existing portable format limits.
    #|      decodeArchive(archiveText);
    #|      if (kind === "markdown") {
    #|        const text = markdownNotesText(chosen); decodeMarkdownNotes(text);
    #|        downloadFile(text, "text/markdown;charset=utf-8", "selected-reading-notes.md");
    #|      } else downloadFile(archiveText, "application/json;charset=utf-8", "selected-reading-notebook.json");
    #|      selectedExportMessage.textContent = "Download requested for " + chosen.size + " selected notes. Unselected notes are excluded; drafts remain unsaved. Keep a separate full archive for backup.";
    #|    } catch (error) { selectedExportMessage.textContent = "Cannot export selected notes: " + error.message + " Choose a smaller set or shorten the note, then review again."; }
    #|  }
    #|  selectedMarkdown.addEventListener("click", () => downloadSelectedNotes("markdown"));
    #|  selectedArchive.addEventListener("click", () => downloadSelectedNotes("archive"));
  )
}
