///|
priv struct TranscriptCue {
  start : String
  end : String
  text : String
}

///|
// A local text projection, not a media player or a complete WebVTT renderer.
// Original identifiers, settings, styling and headers remain in the raw file.
fn parse_transcript(bytes : Bytes, webvtt : Bool) -> Array[TranscriptCue] raise {
  let decoded = @utf8.decode(bytes)
  let content = decoded
    .trim_start(chars="\u{FEFF}")
    .to_owned()
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  if content.iter().any(ch => ch.to_int() < 32 && ch != '\n' && ch != '\t') {
    fail("transcript contains unsupported control characters")
  }
  let lines = content.split("\n").map(line => line.to_owned()).to_array()
  let mut cursor = 0
  if webvtt {
    let header = lines[0]
    if !(header == "WEBVTT" ||
      header.has_prefix("WEBVTT ") ||
      header.has_prefix("WEBVTT\t")) ||
      header.contains("-->") {
      fail("VTT must start with WEBVTT and a blank line before cues")
    }
    cursor = 1
    while cursor < lines.length() && !lines[cursor].trim().is_empty() {
      if lines[cursor].contains("-->") {
        fail("VTT header needs a blank line before the first cue")
      }
      cursor += 1
    }
  }
  let cues : Array[TranscriptCue] = []
  while cursor < lines.length() {
    if lines[cursor].trim().is_empty() {
      cursor += 1
      continue
    }
    let first = cursor
    while cursor < lines.length() && !lines[cursor].trim().is_empty() {
      cursor += 1
    }
    let head = lines[first]
    if webvtt &&
      (
        head == "NOTE" ||
        head.has_prefix("NOTE ") ||
        head.has_prefix("NOTE\t") ||
        head == "STYLE" ||
        head == "REGION"
      ) {
      continue
    }
    if cues.length() >= 5000 {
      fail("transcript exceeds 5000 cues; split the export")
    }
    let timing_index = if head.contains("-->") { first } else { first + 1 }
    if timing_index >= cursor ||
      (!webvtt && (timing_index == first || !transcript_digits(head))) {
      fail(
        "transcript line \{first + 1}: expected a cue identifier and timing line",
      )
    }
    let timing = lines[timing_index].split("-->").to_array()
    if timing.length() != 2 {
      fail("transcript line \{timing_index + 1}: expected start --> end")
    }
    let start_text = timing[0].trim().to_owned()
    let tail = timing[1].trim().to_owned().replace_all(old="\t", new=" ")
    let end_text = tail.split(" ").next().unwrap().to_owned()
    let (start, start_ms) = transcript_timestamp(start_text, webvtt) catch {
      error => fail("transcript line \{timing_index + 1}: \{error}")
    }
    let (end, end_ms) = transcript_timestamp(end_text, webvtt) catch {
      error => fail("transcript line \{timing_index + 1}: \{error}")
    }
    if end_ms <= start_ms {
      fail("transcript line \{timing_index + 1}: end must be after start")
    }
    if !webvtt && tail != end_text {
      fail("SRT timing settings are unsupported; export standard SRT")
    }
    let payload = lines[timing_index + 1:cursor].join("\n")
    if payload.length() > 16384 {
      fail("transcript line \{timing_index + 1}: cue exceeds 16384 code units")
    }
    let text = transcript_plain_text(payload, webvtt)
    if text.trim().is_empty() {
      fail("transcript line \{timing_index + 1}: cue needs spoken text")
    }
    cues.push({ start, end, text, })
  }
  if cues.is_empty() {
    fail("transcript contains no readable cues")
  }
  cues
}

///|
fn transcript_digits(text : String) -> Bool {
  !text.is_empty() && text.iter().all(ch => ch >= '0' && ch <= '9')
}

///|
fn transcript_number(text : String) -> Int32 {
  text.iter().fold(init=0, (value, ch) => value * 10 + ch.to_int() - 48)
}

///|
fn transcript_timestamp(text : String, webvtt : Bool) -> (String, Int32) raise {
  let normalized = if webvtt {
    text
  } else {
    text.replace_all(old=",", new=".")
  }
  let parts = normalized.split(":").map(part => part.to_owned()).to_array()
  if (parts.length() != 3 && !(webvtt && parts.length() == 2)) ||
    (!webvtt && (text.contains(".") || !text.contains(","))) {
    fail("invalid cue timestamp: " + text)
  }
  let hours = if parts.length() == 3 { parts[0] } else { "00" }
  let minutes = parts[parts.length() - 2]
  let seconds = parts[parts.length() - 1]
    .split(".")
    .map(part => part.to_owned())
    .to_array()
  if hours.length() != 2 ||
    !transcript_digits(hours) ||
    minutes.length() != 2 ||
    !transcript_digits(minutes) ||
    seconds.length() != 2 ||
    seconds[0].length() != 2 ||
    !transcript_digits(seconds[0]) ||
    seconds[1].length() != 3 ||
    !transcript_digits(seconds[1]) {
    fail("expected [HH:]MM:SS.mmm for VTT or HH:MM:SS,mmm for SRT: " + text)
  }
  let minute = transcript_number(minutes)
  let second = transcript_number(seconds[0])
  if minute > 59 || second > 59 {
    fail("cue minutes and seconds must be 00–59: " + text)
  }
  (
    hours + ":" + minutes + ":" + seconds.join("."),
    ((transcript_number(hours) * 60 + minute) * 60 + second) * 1000 +
    transcript_number(seconds[1]),
  )
}

///|
fn transcript_entities(text : String) -> String {
  text
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&nbsp;", new=" ")
  .replace_all(old="&lrm;", new="\u{200E}")
  .replace_all(old="&rlm;", new="\u{200F}")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&apos;", new="'")
  .replace_all(old="&amp;", new="&")
}

///|
fn transcript_plain_text(payload : String, webvtt : Bool) -> String {
  let out = StringBuilder()
  // Iterate Unicode scalar values so non-BMP interview text is never split.
  let chars = payload.to_array()
  let mut cursor = 0
  while cursor < chars.length() {
    if chars[cursor] != '<' {
      out.write_char(chars[cursor])
      cursor += 1
      continue
    }
    let mut end = cursor + 1
    while end < chars.length() && chars[end] != '>' && chars[end] != '\n' {
      end += 1
    }
    if end == chars.length() || chars[end] != '>' {
      out.write_char('<')
      cursor += 1
      continue
    }
    let tag = String::from_array(chars[cursor + 1:end].to_owned())
    let name = tag.split(" ").next().unwrap().to_owned()
    if webvtt &&
      (name == "v" || name.has_prefix("v.")) &&
      tag.length() > name.length() {
      out.write_string(" " + tag[name.length():].trim().to_owned() + ": ")
    } else if ["b", "/b", "i", "/i", "u", "/u"].contains(tag) ||
      (
        webvtt &&
        (
          ["c", "/c", "/v", "ruby", "/ruby", "rt", "/rt", "/lang"].contains(tag) ||
          tag.has_prefix("c.") ||
          tag.has_prefix("lang ") ||
          transcript_inline_timestamp(tag)
        )
      ) {
      ()
    } else {
      out.write_string("<" + tag + ">")
    }
    cursor = end + 1
  }
  // Fold visual line wraps into one searchable cue, with timing and speaker
  // alongside the quote in ordinary search snippets and research exports.
  transcript_entities(out.to_string())
  .replace_all(old="\t", new=" ")
  .replace_all(old="\n", new=" ")
  .split(" ")
  .filter(part => !part.is_empty())
  .map(part => part.to_owned())
  .to_array()
  .join(" ")
}

///|
fn transcript_inline_timestamp(tag : String) -> Bool {
  try {
    ignore(transcript_timestamp(tag, true))
    true
  } catch {
    _ => false
  }
}
