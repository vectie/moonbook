///|
// Reader-only note discovery, inserted into the notebook closure.
fn reader_notebook_discovery_script() -> String {
  (
    #|  const query = document.getElementById("notebook-query");
    #|  const filter = document.getElementById("notebook-filter");
    #|  const matches = document.getElementById("notebook-matches");
    #|  const matchStatus = document.getElementById("notebook-matches-status");
    #|  function refreshDiscovery() {
    #|    // Read-only snapshot overlays the current draft without saving or replacing it.
    #|    const wasPersistent = persistent;
    #|    const current = snapshotNotes();
    #|    if (wasPersistent && !persistent) status.textContent = "Browser storage is unavailable or unreadable. Notes stay in this tab; export before leaving. Existing stored data is untouched.";
    #|    refreshRecoverySources(current);
    #|    const terms = query.value.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
    #|    const pages = new Map(data.pages.map(page => [page.path, page]));
    #|    const ordered = [...pages.keys()];
    #|    for (const path of current.keys()) if (!pages.has(path)) ordered.push(path);
    #|    matches.replaceChildren();
    #|    let total = 0, count = 0;
    #|    for (const path of ordered) {
    #|      const text = current.get(path);
    #|      if (!text) continue;
    #|      total++;
    #|      const page = pages.get(path), draft = dirty && path === selected;
    #|      if (filter.value === "draft" && !draft || filter.value === "saved" && (draft || !persistent) ||
    #|          filter.value === "removed" && page) continue;
    #|      const title = page ? page.title : "Removed chapter: " + path;
    #|      const haystack = (title + "\n" + path + "\n" + text).toLocaleLowerCase();
    #|      if (!terms.every(term => haystack.includes(term))) continue;
    #|      count++;
    #|      const row = document.createElement("li");
    #|      const button = document.createElement("button"); button.type = "button";
    #|      button.textContent = "Open note: " + title;
    #|      const detail = document.createElement("p");
    #|      detail.textContent = path + " · " + (draft ? "Unsaved draft" : persistent ? "Saved note" : "Tab-only note");
    #|      const excerpt = document.createElement("p");
    #|      const lower = text.toLocaleLowerCase();
    #|      const positions = terms.map(term => lower.indexOf(term)).filter(index => index >= 0);
    #|      const start = positions.length ? Math.max(0, Math.min(...positions) - 50) : 0;
    #|      excerpt.textContent = (start ? "…" : "") + text.slice(start, start + 220) + (text.length > start + 220 ? "…" : "");
    #|      button.addEventListener("click", () => {
    #|        if (path === selected && dirty) { editor.focus(); return; }
    #|        if (dirty) keep();
    #|        else if (persistent) {
    #|          try { notes = read(); } catch (_) { persistent = false; }
    #|        }
    #|        // A removed note may have disappeared in another tab since it was listed.
    #|        if (!pages.has(path) && !notes.has(path)) {
    #|          refreshDiscovery(); status.textContent = "That note is no longer available. Search results were refreshed."; return;
    #|        }
    #|        selected = path; refreshChapters(); show(); editor.focus();
    #|      });
    #|      row.append(button, detail, excerpt); matches.append(row);
    #|    }
    #|    matchStatus.textContent = count + " of " + total + " notes. " + (count ? "Open a result to edit it." : total ? "No matches. Try different words or clear the filters." : "No notes yet. Write a chapter note below.");
    #|  }
    #|  query.addEventListener("input", refreshDiscovery);
    #|  filter.addEventListener("change", refreshDiscovery);
    #|  document.getElementById("notebook-query-clear").addEventListener("click", () => {
    #|    query.value = ""; filter.value = "all"; refreshDiscovery(); query.focus();
    #|  });
    #|  window.addEventListener("storage", event => {
    #|    if (event.key === key || event.key === null) refreshDiscovery();
    #|  });
  )
}
