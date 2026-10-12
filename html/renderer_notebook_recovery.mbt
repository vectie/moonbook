///|
// Explicit reader-owned recovery after a chapter rename; originals are retained.
fn reader_notebook_recovery_script() -> String {
  (
    #|  const recoverySource = document.getElementById("notebook-recovery-source");
    #|  const recoveryTarget = document.getElementById("notebook-recovery-target");
    #|  const recoveryReview = document.getElementById("notebook-recovery-review");
    #|  const recoveryMessage = document.getElementById("notebook-recovery-message");
    #|  const recoveryPreview = document.getElementById("notebook-recovery-preview");
    #|  const recoverySummary = document.getElementById("notebook-recovery-summary");
    #|  const recoveryOriginal = document.getElementById("notebook-recovery-original");
    #|  const recoveryCurrent = document.getElementById("notebook-recovery-current");
    #|  const recoveryMode = document.getElementById("notebook-recovery-mode");
    #|  const recoveryResult = document.getElementById("notebook-recovery-result");
    #|  const recoveryApply = document.getElementById("notebook-recovery-apply");
    #|  let recoveryPending = null;
    #|  function recoveryOption(value, label) {
    #|    const option = document.createElement("option");
    #|    option.value = value; option.textContent = label; return option;
    #|  }
    #|  recoveryTarget.append(recoveryOption("", "Choose the current chapter…"));
    #|  for (const page of data.pages) recoveryTarget.append(recoveryOption(page.path, page.title + " · " + page.path));
    #|  recoveryTarget.value = "";
    #|  function refreshRecoverySources(current) {
    #|    const prior = recoverySource.value;
    #|    const removed = [...current].filter(([path, text]) => path && text && !data.pages.some(page => page.path === path));
    #|    recoverySource.replaceChildren(recoveryOption("", "Choose a removed-chapter note…"));
    #|    for (const [path] of removed) recoverySource.append(recoveryOption(path, path));
    #|    recoverySource.value = removed.some(([path]) => path === prior) ? prior : "";
    #|    recoverySource.disabled = !removed.length;
    #|    recoveryTarget.disabled = !data.pages.length;
    #|    recoveryReview.disabled = !removed.length || !data.pages.length;
    #|  }
    #|  function clearRecovery() {
    #|    recoveryPending = null; recoveryPreview.hidden = true; recoveryApply.disabled = true;
    #|    recoveryMode.value = ""; recoveryResult.textContent = "";
    #|  }
    #|  function prepareRecovery(source, target, current, message = "") {
    #|    clearRecovery();
    #|    if (!source || data.pages.some(page => page.path === source) || !current.get(source)) {
    #|      recoveryMessage.textContent = "Choose an available removed-chapter note. Nothing was saved."; return;
    #|    }
    #|    if (!data.pages.some(page => page.path === target)) {
    #|      recoveryMessage.textContent = "Choose a current destination chapter. Nothing was saved."; return;
    #|    }
    #|    const original = current.get(source), existing = current.get(target) || "";
    #|    recoveryPending = {source, target, current, original, existing};
    #|    recoverySummary.textContent = "From: " + source + " → To: " + target + ". The original note is retained. Only the destination note will be saved.";
    #|    recoveryOriginal.textContent = original;
    #|    recoveryCurrent.textContent = existing || "(No destination note)";
    #|    recoveryMode.replaceChildren(recoveryOption("", "Choose after reviewing both notes…"));
    #|    if (existing) {
    #|      recoveryMode.append(recoveryOption("append", "Append original after current note"), recoveryOption("replace", "Replace current note with original"));
    #|    } else recoveryMode.append(recoveryOption("copy", "Copy original into empty destination"));
    #|    recoveryMode.value = "";
    #|    recoveryPreview.hidden = false;
    #|    recoveryMessage.textContent = message + "Preview only. Choose how to recover, then review the exact resulting text before saving. Unrelated drafts stay unsaved.";
    #|  }
    #|  function recoveryText() {
    #|    if (!recoveryPending) return null;
    #|    const {existing, original} = recoveryPending;
    #|    if ((!existing && recoveryMode.value === "copy") || (existing && recoveryMode.value === "replace")) return original;
    #|    if (existing && recoveryMode.value === "append") return existing + "\n\n" + original;
    #|    return null;
    #|  }
    #|  recoveryReview.addEventListener("click", () => {
    #|    prepareRecovery(recoverySource.value, recoveryTarget.value, snapshotNotes());
    #|  });
    #|  recoveryMode.addEventListener("change", () => {
    #|    const result = recoveryText();
    #|    recoveryResult.textContent = result === null ? "" : result;
    #|    recoveryApply.disabled = result === null;
    #|  });
    #|  for (const control of [recoverySource, recoveryTarget]) control.addEventListener("change", () => {
    #|    clearRecovery(); recoveryMessage.textContent = "Selection changed. Preview the selected paths before saving.";
    #|  });
    #|  document.getElementById("notebook-recovery-cancel").addEventListener("click", () => {
    #|    clearRecovery(); recoveryMessage.textContent = "Recovery cancelled. Notes, drafts and reading progress are unchanged.";
    #|  });
    #|  recoveryApply.addEventListener("click", () => {
    #|    if (!recoveryPending) return;
    #|    const saved = snapshotNotes(false), current = new Map(saved);
    #|    if (dirty && selected) {
    #|      if (editor.value.length) current.set(selected, editor.value); else current.delete(selected);
    #|    }
    #|    if (!sameNotes(current, recoveryPending.current)) {
    #|      prepareRecovery(recoveryPending.source, recoveryPending.target, current, "Notes changed during preview. Review again. "); return;
    #|    }
    #|    const result = recoveryText();
    #|    if (result === null) return;
    #|    const {target} = recoveryPending;
    #|    saved.set(target, result); notes = saved;
    #|    if (persistent) {
    #|      try { localStorage.setItem(key, JSON.stringify({version: 1, notes: [...notes]})); }
    #|      catch (_) { persistent = false; }
    #|    }
    #|    // Do not implicitly save a different chapter's draft or change reading position.
    #|    clearRecovery(); refreshChapters(); chapters.value = selected;
    #|    if (selected === target) show(); else refreshDiscovery();
    #|    recoveryMessage.textContent = persistent ? "Recovered note saved for " + target + ". Original note retained. Select that chapter to continue editing." :
    #|      "Recovered note kept in this tab only for " + target + ". Original note retained. Export a notebook archive before leaving.";
    #|    if (selected === target) status.textContent = recoveryMessage.textContent;
    #|  });
    #|  clearRecovery();
  )
}
