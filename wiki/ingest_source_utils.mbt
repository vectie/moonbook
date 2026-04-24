///|
// Source classification, path, slug, and link utilities for wiki ingest.

fn source_signal_text(
  title : String,
  path : String,
  content : String,
) -> String {
  title + "\n" + file_stem(path) + "\n" + content
}

///|
fn detect_source_type(
  title : String,
  path : String,
  content : String,
) -> String {
  let title_lowered = (title + "\n" + file_stem(path)).to_lower()
  let lowered = source_signal_text(title, path, content).to_lower()
  if title_lowered.contains("install") ||
    title_lowered.contains("安装") ||
    title_lowered.contains("部署") ||
    title_lowered.contains("onboard") {
    "installation guide"
  } else if title_lowered.contains("troubleshoot") ||
    title_lowered.contains("常见问题") ||
    title_lowered.contains("验证") ||
    lowered.contains("troubleshoot") ||
    lowered.contains("常见问题") ||
    lowered.contains("验证") {
    "troubleshooting guide"
  } else if title_lowered.contains("reference") ||
    title_lowered.contains("api") ||
    lowered.contains("reference") ||
    lowered.contains("api") {
    "reference"
  } else if lowered.contains("install") ||
    lowered.contains("部署") ||
    lowered.contains("onboard") {
    "installation guide"
  } else {
    "source summary"
  }
}

///|
fn detect_source_scope(
  title : String,
  path : String,
  content : String,
) -> String {
  let title_lowered = (title + "\n" + file_stem(path)).to_lower()
  let lowered = source_signal_text(title, path, content).to_lower()
  let environment = if title_lowered.contains("macos") {
    "macOS"
  } else if title_lowered.contains("wsl") {
    "Windows + WSL2"
  } else if title_lowered.contains("windows") {
    "Windows"
  } else if lowered.contains("macos") {
    "macOS"
  } else if lowered.contains("wsl") {
    "Windows + WSL2"
  } else if lowered.contains("windows") {
    "Windows"
  } else {
    "mixed environments"
  }
  let focus = if title_lowered.contains("troubleshoot") ||
    title_lowered.contains("验证") ||
    title_lowered.contains("常见问题") ||
    lowered.contains("troubleshoot") ||
    lowered.contains("验证") ||
    lowered.contains("常见问题") {
    "verification and recovery"
  } else if title_lowered.contains("install") ||
    title_lowered.contains("安装") ||
    title_lowered.contains("部署") ||
    title_lowered.contains("onboard") {
    "installation and onboarding"
  } else if title_lowered.contains("gateway") ||
    title_lowered.contains("config") ||
    title_lowered.contains("token") ||
    lowered.contains("gateway") ||
    lowered.contains("config") ||
    lowered.contains("token") {
    "configuration and operations"
  } else if lowered.contains("install") ||
    lowered.contains("部署") ||
    lowered.contains("onboard") {
    "installation and onboarding"
  } else {
    "general operational guidance"
  }
  "\{environment}; \{focus}"
}

///|
fn detect_source_signals(
  title : String,
  path : String,
  content : String,
) -> Array[String] {
  let lowered = source_signal_text(title, path, content).to_lower()
  let signals : Array[String] = []
  if lowered.contains("wsl") {
    signals.push("WSL2 is a first-class path in this source.")
  }
  if lowered.contains("gateway") && lowered.contains("restart") {
    signals.push("Gateway restart is part of the operational flow.")
  }
  if lowered.contains("feishu") || lowered.contains("imessage") {
    signals.push(
      "Channel integration appears in the source and should stay separate from base installation.",
    )
  }
  if lowered.contains("token") ||
    lowered.contains("api key") ||
    lowered.contains("model") {
    signals.push(
      "Configuration secrets and model settings are operationally important.",
    )
  }
  if lowered.contains("install script") ||
    lowered.contains("npm") ||
    lowered.contains("pnpm") {
    signals.push("Multiple installation methods are described.")
  }
  signals
}

///|
fn render_source_signals(signals : Array[String]) -> String {
  if signals.is_empty() {
    ""
  } else {
    "## Key Signals\n\n" +
    signals.map(signal => "- " + signal + "\n").join("") +
    "\n"
  }
}

///|
fn is_salient_concept_word(word : String) -> Bool {
  has_any_suffix(word, [
    "tion", "ment", "ness", "ity", "ism", "ship", "ance", "ence", "ing",
  ]) ||
  [
    "runtime", "pipeline", "synthesis", "confidence", "ingestion", "integration",
    "workflow", "state", "memory", "evidence", "claims", "claim", "contradiction",
    "support", "query", "queries", "entity", "concept",
  ].contains(word)
}

///|
fn has_any_suffix(text : String, suffixes : Array[String]) -> Bool {
  for suffix in suffixes {
    if text.has_suffix(suffix) {
      return true
    }
  }
  false
}

///|
fn likely_claim_line(line : String) -> Bool {
  line.contains(" is ") ||
  line.contains(" integrates with ") ||
  line.contains(" uses ") ||
  line.contains(" supports ") ||
  line.contains(" improves ") ||
  line.contains(" keeps ")
}

///|
fn rank_phrase_counts(counts : Map[String, Int]) -> Array[String] {
  let pairs : Array[(String, Int)] = []
  for key, value in counts {
    pairs.push((key, value))
  }
  pairs.sort_by(fn(left, right) {
    if left.1 == right.1 {
      left.0.compare(right.0)
    } else {
      right.1.compare(left.1)
    }
  })
  let ranked : Array[String] = []
  for pair in pairs {
    ranked.push(pair.0)
  }
  ranked
}

///|
fn title_case(text : String) -> String {
  if text.is_empty() {
    return text
  }
  let builder = StringBuilder::new()
  let mut capitalize = true
  for c in text {
    if c == ' ' || c == '-' {
      builder.write_char(c)
      capitalize = true
    } else if capitalize {
      let value = c.to_int()
      if value >= 'a'.to_int() && value <= 'z'.to_int() {
        builder.write_char(Int::unsafe_to_char(value - 32))
      } else {
        builder.write_char(c)
      }
      capitalize = false
    } else {
      builder.write_char(c)
    }
  }
  builder.to_string()
}

///|
fn relative_to_root(path : String, root : String) -> String {
  let normalized_path = @pathx.normalize(path)
  let normalized_root = @pathx.normalize(root)
  if normalized_path == normalized_root {
    "."
  } else if normalized_path.has_prefix(normalized_root + "/") {
    normalized_path[normalized_root.length() + 1:].to_string()
  } else {
    normalized_path
  }
}

///|
fn relative_from_page(
  page_relative : String,
  target_relative : String,
) -> String {
  let from_dir = @path.Path(page_relative).dirname().to_string()
  let from_parts = split_segments(from_dir)
  let to_parts = split_segments(target_relative)
  let mut shared = 0
  while shared < from_parts.length() &&
        shared < to_parts.length() &&
        from_parts[shared] == to_parts[shared] {
    shared += 1
  }
  let pieces : Array[String] = []
  for back = shared; back < from_parts.length(); back = back + 1 {
    pieces.push("..")
  }
  for i = shared; i < to_parts.length(); i = i + 1 {
    pieces.push(to_parts[i])
  }
  if pieces.is_empty() {
    "."
  } else {
    pieces.join("/")
  }
}

///|
fn split_segments(path : String) -> Array[String] {
  let parts : Array[String] = []
  let normalized = @pathx.normalize(path)
  if normalized == "." || normalized.is_empty() {
    return parts
  }
  for piece in normalized.split("/") {
    let text = piece.to_string()
    if !text.is_empty() && text != "." {
      parts.push(text)
    }
  }
  parts
}

///|
fn slugify_title(title : String) -> String {
  let builder = StringBuilder::new()
  let mut wrote_dash = false
  for c in title {
    let value = c.to_int()
    if (value >= 'a'.to_int() && value <= 'z'.to_int()) ||
      (value >= '0'.to_int() && value <= '9'.to_int()) {
      builder.write_char(c)
      wrote_dash = false
    } else if value >= 'A'.to_int() && value <= 'Z'.to_int() {
      builder.write_char(Int::unsafe_to_char(value + 32))
      wrote_dash = false
    } else if !wrote_dash {
      builder.write_char('-')
      wrote_dash = true
    }
  }
  let slug = builder
    .to_string()
    .trim()
    .to_string()
    .replace(old="--", new="-")
    .to_string()
  let slug = if slug.has_suffix("-") {
    slug[:slug.length() - 1].to_string()
  } else {
    slug
  }
  if slug.is_empty() {
    "source"
  } else {
    slug
  }
}

///|
async fn unique_source_slug(sources_dir : String, slug : String) -> String {
  let mut index = 0
  while true {
    let candidate = if index == 0 { slug } else { "\{slug}-\{index}" }
    let path = @path.Path(sources_dir)
      .join(@path.Path(candidate + ".md"))
      .to_string()
    if !@fsx.exists(path) {
      return candidate
    }
    index += 1
  }
  slug
}

///|
fn file_stem(path : String) -> String {
  let base = @path.Path(path).basename().to_string()
  let ext = @pathx.ext(base).to_string()
  if ext.is_empty() {
    base
  } else {
    base[:base.length() - ext.length()].to_string()
  }
}

///|
fn escape_link_label(text : String) -> String {
  text
  .replace(old="[", new="(")
  .to_string()
  .replace(old="]", new=")")
  .to_string()
}

///|
fn is_text_source(path : String) -> Bool {
  match @pathx.ext(path).to_string().to_lower() {
    ".md"
    | ".markdown"
    | ".txt"
    | ".html"
    | ".htm"
    | ".json"
    | ".yaml"
    | ".yml"
    | ".csv" => true
    _ => false
  }
}
