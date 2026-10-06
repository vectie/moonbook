///|
// Same pure section insertion rule as wiki/ingest_semantics.mbt. This is the
// only copied append helper; all filesystem effects live in the intent store.
fn append_section_block(
  content : String,
  section_header : String,
  block : String,
) -> String {
  let cleaned = content.replace(old="_None yet._\n", new="").to_string()
  if content.contains(block.trim().to_owned()) {
    return cleaned
  }
  if cleaned.contains(section_header + "\n\n") {
    cleaned
    .replace(
      old=section_header + "\n\n",
      new=section_header + "\n\n" + block + "\n",
    )
    .to_string()
  } else if cleaned.contains(section_header + "\n") {
    cleaned
    .replace(
      old=section_header + "\n",
      new=section_header + "\n" + block + "\n",
    )
    .to_string()
  } else if cleaned.has_suffix("\n") {
    cleaned + "\n" + section_header + "\n\n" + block + "\n"
  } else {
    cleaned + "\n\n" + section_header + "\n\n" + block + "\n"
  }
}

///|
// Wenyu has no memory candidates. Field labels match
// wiki/extension_api.mbt: persisted_result_block.
fn persisted_result_block(result : BookResult) -> String {
  let builder = StringBuilder::new()
  builder.write_string("### \{result.result_id}\n\n")
  builder.write_string("- Summary: \{result.summary}\n")
  builder.write_string("- Requires review: `\{result.requires_review}`\n")
  builder.write_string("- Notify town: `\{result.notify_town}`\n")
  if !result.artifacts.is_empty() {
    builder.write_string("- Artifacts:\n")
    for artifact in result.artifacts {
      builder.write_string("  - `\{artifact}`\n")
    }
  }
  builder.write_string("\n")
  builder.to_string()
}

///|
// Same bounded display text as wiki/keeper_memory.mbt: keeper_compact_text.
fn keeper_compact_text(text : String) -> String {
  let normalized = text
    .replace(old="\n", new=" ")
    .replace(old="\r", new=" ")
    .trim()
    .to_owned()
  if normalized.length() > 180 {
    normalized[:180].to_owned() + "..."
  } else {
    normalized
  }
}

///|
// Same review excerpt rule as wiki/query.mbt: clamp_excerpt.
fn clamp_excerpt(text : String) -> String {
  if text.is_empty() {
    "No excerpt available."
  } else if text.length() > 220 {
    text[:220].to_owned() + "..."
  } else {
    text
  }
}

///|
// Same link shape as wiki/ingest_semantics.mbt: format_related_log_lines.
fn format_related_log_lines(pages : Array[String]) -> String {
  pages.map(page => "- related: `wiki/\{page}`\n").join("")
}

///|
fn journey_text() -> String {
  "# Journey\n\nA compact timeline of native Wenyu work and human review.\n\n## Entries\n\n_None yet._\n"
}

///|
fn debug_journal_text() -> String {
  "# Debug Journal\n\nNative Wenyu result and request bindings.\n\n## Entries\n\n_None yet._\n"
}
