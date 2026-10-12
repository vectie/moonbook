///|
// Explicit reader progress stays separate from notes and accepted book truth.
fn reader_notebook_progress_script() -> String {
  (
    #|  const progressKey = "moonbook.reader-progress.v1:" + scope;
    #|  const progressStatus = document.getElementById("notebook-progress-status");
    #|  const readToggle = document.getElementById("notebook-read-toggle");
    #|  const nextUnread = document.getElementById("notebook-next-unread");
    #|  const resume = document.getElementById("notebook-resume");
    #|  const currentPaths = new Set(data.pages.map(page => page.path));
    #|  let reading = {read: new Set(), last: ""}, progressPersistent = true, progressChanged = false;
    #|  function readProgress() {
    #|    const raw = localStorage.getItem(progressKey);
    #|    if (raw === null) return {read: new Set(), last: ""};
    #|    const value = JSON.parse(raw);
    #|    if (!value || value.version !== 1 || !Array.isArray(value.read) || value.read.length > 10000 ||
    #|        typeof value.last !== "string" || value.last.length > 4096) throw Error("Invalid reading progress");
    #|    const read = new Set();
    #|    for (const path of value.read) {
    #|      if (typeof path !== "string" || !path || path.length > 4096 || read.has(path)) throw Error("Invalid chapter path");
    #|      read.add(path);
    #|    }
    #|    return {read, last: value.last};
    #|  }
    #|  try { reading = readProgress(); } catch (_) { progressPersistent = false; }
    #|  if (currentPaths.has(reading.last)) selected = reading.last;
    #|  function readingNeedsWarning() { return !progressPersistent && progressChanged; }
    #|  function refreshReadingProgress() {
    #|    const count = data.pages.filter(page => reading.read.has(page.path)).length;
    #|    const current = currentPaths.has(selected);
    #|    readToggle.disabled = !current;
    #|    readToggle.textContent = reading.read.has(selected) && current ? "Mark selected chapter unread" : "Mark selected chapter read";
    #|    nextUnread.disabled = count === data.pages.length;
    #|    resume.disabled = !currentPaths.has(reading.last);
    #|    const last = data.pages.find(page => page.path === reading.last);
    #|    progressStatus.textContent = count + " of " + data.pages.length + " chapters marked read. " +
    #|      (count === data.pages.length && count ? "All chapters marked read. " : "") +
    #|      (last ? "Reading position: " + last.title + ". " : "Open a chapter to save your reading position. ") +
    #|      (progressPersistent ? "Saved in this browser only; export reading progress to move it. Notebook archives contain notes only." :
    #|        "Progress stays in this tab only. Browser storage is unavailable or unreadable; existing stored data is untouched.");
    #|  }
    #|  function updateProgress(path, readValue) {
    #|    if (!currentPaths.has(path)) return;
    #|    // Merge other-tab progress before changing one exact chapter and the reading position.
    #|    if (progressPersistent) {
    #|      try { reading = readProgress(); } catch (_) { progressPersistent = false; }
    #|    }
    #|    if (readValue === true) reading.read.add(path);
    #|    if (readValue === false) reading.read.delete(path);
    #|    reading.last = path; progressChanged = true;
    #|    if (progressPersistent) {
    #|      try {
    #|        if (reading.read.size > 10000 || path.length > 4096) throw Error("Progress limit exceeded");
    #|        localStorage.setItem(progressKey, JSON.stringify({version: 1, read: [...reading.read], last: reading.last}));
    #|      } catch (_) { progressPersistent = false; }
    #|    }
    #|    refreshReadingProgress();
    #|  }
    #|  function chooseReadingChapter(path) {
    #|    if (!currentPaths.has(path)) return;
    #|    if (dirty && selected !== path) keep();
    #|    if (selected !== path) { selected = path; refreshChapters(); show(); }
    #|    updateProgress(path);
    #|  }
    #|  readToggle.addEventListener("click", () => {
    #|    updateProgress(selected, !reading.read.has(selected));
    #|  });
    #|  nextUnread.addEventListener("click", () => {
    #|    if (progressPersistent) {
    #|      try { reading = readProgress(); } catch (_) { progressPersistent = false; }
    #|    }
    #|    const start = data.pages.findIndex(page => page.path === selected);
    #|    for (let step = 1; step <= data.pages.length; step++) {
    #|      const page = data.pages[(start + step) % data.pages.length];
    #|      if (!reading.read.has(page.path)) { chooseReadingChapter(page.path); return; }
    #|    }
    #|    refreshReadingProgress();
    #|  });
    #|  resume.addEventListener("click", () => chooseReadingChapter(reading.last));
    #|  open.addEventListener("click", () => updateProgress(selected));
    #|  window.addEventListener("storage", event => {
    #|    if (progressPersistent && (event.key === progressKey || event.key === null)) {
    #|      try { reading = readProgress(); } catch (_) { progressPersistent = false; }
    #|      // Another tab's reading position never switches this tab or discards its draft.
    #|      refreshReadingProgress();
    #|    }
    #|  });
  )
}
