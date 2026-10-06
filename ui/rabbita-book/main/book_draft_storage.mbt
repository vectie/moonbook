///|
/// Only a version and user-authored summary are stored. The opaque key scopes
/// text to a Book and exact record/decision; it is not an authority source.
extern "js" fn book_summary_storage(
  operation : String,
  key : String,
  summary : String,
) -> String =
  #| (operation, key, summary) => {
  #|   const result = (value, error = null) => JSON.stringify({value, error});
  #|   try {
  #|     const name = "moonbook.review-summary.v1:" + encodeURIComponent(key);
  #|     if (operation === "discard") {
  #|       globalThis.localStorage.removeItem(name);
  #|       return result(null);
  #|     }
  #|     if (operation === "save") {
  #|       if (summary.length > 65536) return result(null, "Summary exceeds the 65,536-character local limit.");
  #|       globalThis.localStorage.setItem(name, JSON.stringify({version: 1, summary}));
  #|       return result(summary);
  #|     }
  #|     if (operation !== "read") return result(null, "Unsupported storage operation.");
  #|     const raw = globalThis.localStorage.getItem(name);
  #|     if (raw === null) return result(null);
  #|     if (raw.length > 400000) return result(null, "Saved summary is too large to restore.");
  #|     const data = JSON.parse(raw);
  #|     if (!data || data.version !== 1 || typeof data.summary !== "string" || data.summary.length > 65536) {
  #|       return result(null, "Saved summary has an unsupported format.");
  #|     }
  #|     return result(data.summary);
  #|   } catch (_) {
  #|     return result(null, "Browser storage is blocked, full, or unreadable.");
  #|   }
  #| }

///|
fn book_summary_storage_result(raw : String) -> Result[String?, String] {
  try @json.parse(raw) catch {
    _ => Err("Browser storage returned an unreadable response.")
  } noraise {
    { "error": String(error), .. } => Err(error)
    { "error": Null, "value": String(value), .. } => Ok(Some(value))
    { "error": Null, "value": Null, .. } => Ok(None)
    _ => Err("Browser storage returned an unsupported response.")
  }
}

///|
fn book_summary_storage_cmd(
  emit : @rabbita.Emit[Msg],
  request : Int,
  operation : String,
  key : String,
  summary : String,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(scheduler => {
    let result = book_summary_storage_result(
      book_summary_storage(operation, key, summary),
    )
    @cmd.Scheduler::add(
      scheduler,
      emit(DraftRecovery(StorageFinished(request, key, operation, result))),
    )
  })
}
