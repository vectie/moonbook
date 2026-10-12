///|
// Inserted into the private notebook script closure. Import never writes book sources.
fn reader_notebook_archive_script() -> String {
  (
    #|  // Portable archives contain reader commentary and source paths, never source bodies.
    #|  const archiveExport = document.getElementById("notebook-archive-export");
    #|  const archiveFile = document.getElementById("notebook-archive-file");
    #|  const preview = document.getElementById("notebook-archive-preview");
    #|  const summary = document.getElementById("notebook-archive-summary");
    #|  const conflicts = document.getElementById("notebook-archive-conflicts");
    #|  const importItems = document.getElementById("notebook-archive-items");
    #|  const importSelection = document.getElementById("notebook-archive-selection");
    #|  const selectAllImports = document.getElementById("notebook-archive-all");
    #|  const selectNoImports = document.getElementById("notebook-archive-none");
    #|  const apply = document.getElementById("notebook-archive-apply");
    #|  const cancel = document.getElementById("notebook-archive-cancel");
    #|  const maxBytes = 5 * 1024 * 1024;
    #|  let pending = null, loadSequence = 0;
    #|  function snapshotNotes(includeDraft = true) {
    #|    let result = new Map(notes);
    #|    if (persistent) {
    #|      try { result = read(); } catch (_) { persistent = false; }
    #|    }
    #|    if (includeDraft && dirty && selected) {
    #|      if (editor.value.length) result.set(selected, editor.value); else result.delete(selected);
    #|    }
    #|    return result;
    #|  }
    #|  function decodeArchive(text) {
    #|    if (new Blob([text]).size > maxBytes) throw Error("Archive exceeds 5 MiB.");
    #|    const value = JSON.parse(text);
    #|    if (!value || value.format !== "moonbook.reader-notebook-archive" || value.version !== 1 ||
    #|        typeof value.title !== "string" || value.title.length > 4096 ||
    #|        !Array.isArray(value.notes) || value.notes.length > 10000) {
    #|      throw Error("Expected a MoonBook notebook archive version 1 (up to 10,000 notes).");
    #|    }
    #|    const result = new Map();
    #|    for (const row of value.notes) {
    #|      if (!Array.isArray(row) || row.length !== 2 || typeof row[0] !== "string" ||
    #|          !row[0].length || row[0].length > 4096 || typeof row[1] !== "string" || result.has(row[0])) {
    #|        throw Error("Invalid or duplicate chapter note. No notes were imported.");
    #|      }
    #|      result.set(row[0], row[1]);
    #|    }
    #|    return {title: value.title, notes: result};
    #|  }
    #|  function clearPreview() {
    #|    pending = null; preview.hidden = true; conflicts.replaceChildren(); importItems.replaceChildren(); apply.disabled = true;
    #|    importSelection.textContent = ""; selectAllImports.disabled = selectNoImports.disabled = true;
    #|  }
    #|  function sameNotes(left, right) {
    #|    return left.size === right.size && [...left].every(([path, text]) => right.has(path) && right.get(path) === text);
    #|  }
    #|  function refreshImportSelection() {
    #|    if (!pending) return;
    #|    const count = [...pending.included.values()].filter(control => control.checked).length;
    #|    importSelection.textContent = count + " of " + pending.included.size + " incoming notes selected. Unselected notes and kept-current drafts stay unchanged.";
    #|    apply.disabled = count === 0;
    #|  }
    #|  for (const [button, checked] of [[selectAllImports, true], [selectNoImports, false]]) {
    #|    button.addEventListener("click", () => {
    #|      if (!pending) return;
    #|      for (const control of pending.included.values()) control.checked = checked;
    #|      refreshImportSelection();
    #|    });
    #|  }
    #|  function prepare(archive, current, message = "", initiallySelected = true) {
    #|    conflicts.replaceChildren(); importItems.replaceChildren();
    #|    const choices = new Map(), included = new Map();
    #|    let added = 0, identical = 0, changed = 0, removed = 0;
    #|    for (const [path, text] of archive.notes) {
    #|      const page = data.pages.find(page => page.path === path);
    #|      if (!page) removed++;
    #|      const kind = !current.has(path) ? "New note" : current.get(path) === text ? "Identical note" : "Conflicting note; choose below";
    #|      const item = document.createElement("fieldset");
    #|      const itemPath = document.createElement("legend"); itemPath.textContent = path;
    #|      const itemContext = document.createElement("p"); itemContext.textContent = kind + " · " + (page ? page.title : "Removed chapter");
    #|      const itemText = document.createElement("pre"); itemText.textContent = text;
    #|      const includeLabel = document.createElement("label"); includeLabel.textContent = "Include incoming note for " + path;
    #|      const include = document.createElement("input"); include.type = "checkbox"; include.style.width = "auto";
    #|      include.checked = initiallySelected; include.addEventListener("change", refreshImportSelection);
    #|      includeLabel.append(include); item.append(itemPath, itemContext, itemText, includeLabel);
    #|      importItems.append(item); included.set(path, include);
    #|      if (!current.has(path)) { added++; continue; }
    #|      if (current.get(path) === text) { identical++; continue; }
    #|      changed++;
    #|      const field = document.createElement("fieldset");
    #|      const legend = document.createElement("legend"); legend.textContent = path;
    #|      const localLabel = document.createElement("p"); localLabel.textContent = "Current note";
    #|      const localText = document.createElement("pre"); localText.textContent = current.get(path);
    #|      const incomingLabel = document.createElement("p"); incomingLabel.textContent = "Imported note";
    #|      const incomingText = document.createElement("pre"); incomingText.textContent = text;
    #|      const label = document.createElement("label"); label.textContent = "Choose note for " + path;
    #|      const choice = document.createElement("select");
    #|      const keepLocal = document.createElement("option"); keepLocal.value = "keep"; keepLocal.textContent = "Keep current note";
    #|      const useImport = document.createElement("option"); useImport.value = "import"; useImport.textContent = "Use imported note";
    #|      choice.append(keepLocal, useImport); choice.value = "keep"; label.append(choice);
    #|      field.append(legend, localLabel, localText, incomingLabel, incomingText, label);
    #|      conflicts.append(field); choices.set(path, choice);
    #|    }
    #|    summary.textContent = message + (archive.kind || "Archive") + " from “" + archive.title + "”: " + added + " new, " +
    #|      identical + " identical, " + changed + " conflicting notes. " + removed +
    #|      " notes refer to paths outside this book's current chapters. Selected imports remain available as removed-chapter notes. Inspect each incoming note and choose which to include.";
    #|    pending = {archive, current, choices, included}; preview.hidden = false;
    #|    selectAllImports.disabled = selectNoImports.disabled = !included.size; refreshImportSelection();
    #|    status.textContent = "Preview ready. Existing notes and unsaved text have not been changed.";
    #|  }
    #|  archiveExport.addEventListener("click", () => {
    #|    const text = JSON.stringify({format: "moonbook.reader-notebook-archive", version: 1, title: data.title, notes: [...snapshotNotes()]}, null, 2) + "\n";
    #|    try {
    #|      decodeArchive(text);
    #|      downloadFile(text, "application/json;charset=utf-8", "reading-notebook.json");
    #|      status.textContent = "Notebook archive exported, including unsaved text. Import it in another book copy or browser.";
    #|    } catch (error) { status.textContent = "Cannot export archive: " + error.message + " Markdown export is still available."; }
    #|  });
    #|  archiveFile.addEventListener("change", async () => {
    #|    const sequence = ++loadSequence;
    #|    clearPreview();
    #|    const file = archiveFile.files && archiveFile.files[0];
    #|    if (!file) return;
    #|    status.textContent = "Reading notebook file…";
    #|    preview.hidden = false; summary.textContent = "Reading notes. You can cancel while it loads.";
    #|    try {
    #|      if (file.size > maxBytes) throw Error("Archive exceeds 5 MiB.");
    #|      const text = await file.text();
    #|      if (sequence !== loadSequence) return;
    #|      const archive = decodeNotebookImport(text);
    #|      prepare(archive, snapshotNotes());
    #|    } catch (error) {
    #|      if (sequence === loadSequence) {
    #|        clearPreview();
    #|        status.textContent = "Cannot import notes: " + error.message + " Existing notes are unchanged.";
    #|      }
    #|    } finally {
    #|      if (sequence === loadSequence) archiveFile.value = "";
    #|    }
    #|  });
    #|  cancel.addEventListener("click", () => {
    #|    loadSequence++; clearPreview(); archiveFile.value = "";
    #|    status.textContent = "Import cancelled. Existing notes and unsaved text are unchanged.";
    #|  });
    #|  apply.addEventListener("click", () => {
    #|    if (!pending) return;
    #|    if (![...pending.included.values()].some(control => control.checked)) {
    #|      status.textContent = "No notes selected. Choose the incoming notes to import, or cancel."; return;
    #|    }
    #|    const saved = snapshotNotes(false), current = new Map(saved);
    #|    if (dirty && selected) {
    #|      if (editor.value.length) current.set(selected, editor.value); else current.delete(selected);
    #|    }
    #|    if (!sameNotes(current, pending.current)) {
    #|      prepare(pending.archive, current, "Notes changed since the preview. Selections cleared; choose notes again after reviewing. ", false);
    #|      return;
    #|    }
    #|    const merged = new Map(saved), importedPaths = new Set();
    #|    for (const [path, text] of pending.archive.notes) {
    #|      if (pending.included.get(path).checked && (!current.has(path) || pending.choices.get(path)?.value === "import")) {
    #|        merged.set(path, text); importedPaths.add(path);
    #|      }
    #|    }
    #|    notes = merged;
    #|    if (importedPaths.size && persistent) {
    #|      try { localStorage.setItem(key, JSON.stringify({version: 1, notes: [...notes]})); }
    #|      catch (_) { persistent = false; }
    #|    }
    #|    if (!selected) selected = data.pages.length ? data.pages[0].path : (notes.keys().next().value || "");
    #|    refreshChapters(); chapters.value = selected;
    #|    if (!dirty || importedPaths.has(selected)) show(); else refreshDiscovery();
    #|    clearPreview();
    #|    status.textContent = !importedPaths.size ? "No incoming changes selected. Notes and drafts are unchanged." : persistent ?
    #|      importedPaths.size + " selected notes imported and saved in this browser. Unselected notes and kept-current drafts are unchanged." :
    #|      importedPaths.size + " selected notes imported in this tab only. Browser storage is unavailable; export an archive before leaving.";
    #|  });
    #|
  )
}
