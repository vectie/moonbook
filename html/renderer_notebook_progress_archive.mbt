///|
// Portable reader annotations remain separate from notes and authored knowledge.
fn reader_notebook_progress_archive_script() -> String {
  (
    #|  const progressExport = document.getElementById("notebook-progress-export");
    #|  const progressFile = document.getElementById("notebook-progress-file");
    #|  const progressPreview = document.getElementById("notebook-progress-preview");
    #|  const progressSummary = document.getElementById("notebook-progress-summary");
    #|  const progressItems = document.getElementById("notebook-progress-items");
    #|  const progressPosition = document.getElementById("notebook-progress-position");
    #|  const progressApply = document.getElementById("notebook-progress-apply");
    #|  const progressCancel = document.getElementById("notebook-progress-cancel");
    #|  const progressMessage = document.getElementById("notebook-progress-message");
    #|  const progressLimit = 5 * 1024 * 1024;
    #|  let pendingProgress = null, progressFileToken = 0;
    #|  function progressArchive(value) {
    #|    if (!value || value.format !== "moonbook.reader-progress-archive" || value.version !== 1 ||
    #|        typeof value.title !== "string" || value.title.length > 4096 ||
    #|        !Array.isArray(value.read) || value.read.length > 10000 ||
    #|        typeof value.last !== "string" || value.last.length > 4096) throw Error("Invalid reading-progress archive");
    #|    const paths = new Set();
    #|    for (const path of value.read) {
    #|      if (typeof path !== "string" || !path || path.length > 4096 || paths.has(path)) throw Error("Invalid or duplicate chapter path");
    #|      paths.add(path);
    #|    }
    #|    return {title: value.title, read: paths, last: value.last};
    #|  }
    #|  function syncProgress() {
    #|    if (progressPersistent) {
    #|      try { reading = readProgress(); } catch (_) { progressPersistent = false; }
    #|    }
    #|    refreshReadingProgress();
    #|  }
    #|  function progressFingerprint() {
    #|    return JSON.stringify({read: [...reading.read].sort(), last: reading.last, persistent: progressPersistent});
    #|  }
    #|  function clearProgressPreview() {
    #|    pendingProgress = null; progressPreview.hidden = true;
    #|    progressItems.replaceChildren(); progressPosition.checked = false;
    #|  }
    #|  function showProgressPreview() {
    #|    const imported = pendingProgress.value;
    #|    let added = 0, existing = 0, removed = 0;
    #|    progressItems.replaceChildren();
    #|    for (const path of imported.read) {
    #|      const page = data.pages.find(page => page.path === path);
    #|      const already = reading.read.has(path);
    #|      if (already) existing++; else added++;
    #|      if (!page) removed++;
    #|      const item = document.createElement("li");
    #|      item.textContent = (page ? page.title : "Removed or unknown chapter") + " — " + path +
    #|        (already ? " (already marked read)" : " (add read mark)");
    #|      progressItems.append(item);
    #|    }
    #|    const position = data.pages.find(page => page.path === imported.last);
    #|    progressSummary.textContent = "From book: " + imported.title + ". " + added + " new read marks, " +
    #|      existing + " already marked, " + removed + " removed or unknown paths. " +
    #|      "Exact paths only; verify this is the same book. Existing read marks are kept. " +
    #|      (position ? "Imported position: " + position.title + " — " + position.path + "." :
    #|        imported.last ? "Imported position is not in this book: " + imported.last + ". It will not replace your position." : "No imported reading position.");
    #|    progressPosition.checked = false; progressPosition.disabled = !position;
    #|    pendingProgress.fingerprint = progressFingerprint();
    #|    progressPreview.hidden = false;
    #|  }
    #|  progressExport.addEventListener("click", () => {
    #|    try {
    #|      syncProgress();
    #|      const archive = {format: "moonbook.reader-progress-archive", version: 1, title: data.title,
    #|        read: [...reading.read], last: reading.last};
    #|      progressArchive(archive);
    #|      const text = JSON.stringify(archive, null, 2) + "\n";
    #|      if (new Blob([text]).size > progressLimit) throw Error("Archive exceeds 5 MiB");
    #|      downloadFile(text, "application/json;charset=utf-8", "reading-progress.json");
    #|      progressMessage.textContent = "Reading progress exported. Notes are not included; export a notebook archive separately.";
    #|    } catch (error) { progressMessage.textContent = "Could not export reading progress: " + error.message; }
    #|  });
    #|  progressFile.addEventListener("change", async () => {
    #|    const token = ++progressFileToken;
    #|    clearProgressPreview();
    #|    const file = progressFile.files && progressFile.files[0];
    #|    if (!file) return;
    #|    // Show Cancel during asynchronous reads as well as during preview.
    #|    progressPreview.hidden = false; progressApply.disabled = true;
    #|    progressSummary.textContent = "Reading progress archive…";
    #|    try {
    #|      if (file.size > progressLimit) throw Error("Archive exceeds 5 MiB");
    #|      const text = await file.text();
    #|      if (token !== progressFileToken) return;
    #|      if (new Blob([text]).size > progressLimit) throw Error("Archive exceeds 5 MiB");
    #|      const value = progressArchive(JSON.parse(text));
    #|      syncProgress();
    #|      pendingProgress = {value}; showProgressPreview();
    #|      progressMessage.textContent = "Preview only. No reading progress or notes have changed.";
    #|    } catch (error) {
    #|      if (token !== progressFileToken) return;
    #|      clearProgressPreview(); progressMessage.textContent = "Could not import reading progress: " + error.message;
    #|    } finally {
    #|      if (token === progressFileToken) { progressFile.value = ""; progressApply.disabled = false; }
    #|    }
    #|  });
    #|  progressCancel.addEventListener("click", () => {
    #|    ++progressFileToken; clearProgressPreview(); progressFile.value = ""; progressApply.disabled = false;
    #|    progressMessage.textContent = "Progress import cancelled. Reading progress and notes are unchanged.";
    #|  });
    #|  progressApply.addEventListener("click", () => {
    #|    if (!pendingProgress) return;
    #|    syncProgress();
    #|    if (pendingProgress.fingerprint !== progressFingerprint()) {
    #|      showProgressPreview();
    #|      progressMessage.textContent = "Reading progress changed during preview. Review the refreshed preview and choose Import read marks again.";
    #|      return;
    #|    }
    #|    const merged = new Set([...reading.read, ...pendingProgress.value.read]);
    #|    if (merged.size > 10000) {
    #|      progressMessage.textContent = "Merged progress exceeds 10,000 paths. No progress was imported."; return;
    #|    }
    #|    const last = progressPosition.checked && currentPaths.has(pendingProgress.value.last) ? pendingProgress.value.last : reading.last;
    #|    reading = {read: merged, last}; progressChanged = true;
    #|    if (progressPersistent) {
    #|      try { localStorage.setItem(progressKey, JSON.stringify({version: 1, read: [...merged], last})); }
    #|      catch (_) { progressPersistent = false; }
    #|    }
    #|    clearProgressPreview(); refreshReadingProgress();
    #|    progressMessage.textContent = progressPersistent ?
    #|      "Read marks imported. Your editor and notes are unchanged. Use Resume reading to open the chosen position." :
    #|      "Read marks imported in this tab only. Export reading progress before leaving; existing stored data is untouched.";
    #|  });
  )
}
