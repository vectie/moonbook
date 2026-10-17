///|
// Bounded MIME projection. Parsing uses a byte-valued string so binary attachment
// bytes never need to be decoded, and only chosen UTF-8 text enters the wiki.
priv struct EmailProjection {
  title : String
  attribution : String
  body : String
}

///|
fn email_byte_text(bytes : Bytes) -> String {
  let text = StringBuilder()
  for byte in bytes {
    text.write_char(byte.to_int().unsafe_to_char())
  }
  text.to_string().replace_all(old="\r\n", new="\n")
}

///|
fn email_bytes(text : String) -> Bytes {
  let bytes : Array[Byte] = []
  for char in text {
    bytes.push(char.to_int().to_byte())
  }
  Bytes::from_array(bytes)
}

///|
fn email_headers(text : String) -> (Map[String, String], String) raise {
  let headers : Map[String, String] = Map([])
  let mut current = ""
  let mut offset = 0
  let mut count = 0
  for part in text.split("\n") {
    let line = part.to_owned()
    offset += line.length() + 1
    if offset > 65536 {
      fail("EML headers exceed 64 KiB")
    }
    if line.is_empty() {
      return (
        headers,
        if offset <= text.length() {
          text[offset:].to_owned()
        } else {
          ""
        },
      )
    }
    if line.contains("\r") || line.contains("\u{0000}") {
      fail("EML header contains invalid control bytes")
    }
    if line.has_prefix(" ") || line.has_prefix("\t") {
      if current.is_empty() {
        fail("EML folded header has no preceding field")
      }
      headers[current] = headers.get(current).unwrap() +
        " " +
        line.trim().to_owned()
    } else {
      guard line.find(":") is Some(colon) else {
        fail("EML header is missing a colon")
      }
      let name = line[:colon].to_owned().to_lower()
      if name.is_empty() ||
        !name
        .iter()
        .all(c => {
          let value = c.to_int()
          value > 32 && value < 127 && c != ':'
        }) {
        fail("EML header field name is malformed")
      }
      let value = line[colon + 1:].trim().to_owned()
      if headers.contains(name) {
        if [
            "content-type", "content-transfer-encoding", "content-disposition", "subject",
            "from", "date", "message-id",
          ].contains(name) {
          fail("EML duplicate attribution or MIME field: " + name)
        }
        headers[name] = headers.get(name).unwrap() + ", " + value
      } else {
        headers[name] = value
      }
      current = name
      count += 1
      if count > 200 {
        fail("EML header count exceeds 200")
      }
    }
  }
  fail("EML requires a blank line between headers and body")
}

///|
fn email_hex(char : Char) -> Int32 raise {
  let value = char.to_int()
  if value >= 48 && value <= 57 {
    value - 48
  } else if value >= 65 && value <= 70 {
    value - 55
  } else if value >= 97 && value <= 102 {
    value - 87
  } else {
    fail("EML quoted-printable contains an invalid hex escape")
  }
}

///|
fn email_quoted_printable(text : String, header~ : Bool = false) -> Bytes raise {
  let bytes : Array[Byte] = []
  let mut index = 0
  while index < text.length() {
    let char = text[index].to_int()
    if char == 61 {
      if !header && index + 1 < text.length() && text[index + 1] == '\n' {
        index += 2
      } else {
        if index + 2 >= text.length() {
          fail("EML quoted-printable ends in an incomplete escape")
        }
        bytes.push(
          (email_hex(text[index + 1].unsafe_to_char()) * 16 +
          email_hex(text[index + 2].unsafe_to_char())).to_byte(),
        )
        index += 3
      }
    } else {
      bytes.push((if header && char == 95 { 32 } else { char }).to_byte())
      index += 1
    }
  }
  Bytes::from_array(bytes)
}

///|
fn email_decode_text(bytes : Bytes, charset : String) -> String raise {
  let normalized = charset.to_lower()
  if normalized != "utf-8" && normalized != "us-ascii" && normalized != "" {
    fail("EML unsupported charset: " + charset + "; export UTF-8 plain text")
  }
  if normalized == "us-ascii" && bytes.iter().any(byte => byte.to_int() > 127) {
    fail("EML us-ascii text contains non-ASCII bytes")
  }
  let decoded = @utf8.decode(bytes, ignore_bom=true)
  if decoded.contains("\u{0000}") {
    fail("EML text contains NUL bytes")
  }
  decoded.replace_all(old="\r\n", new="\n")
}

///|
fn email_decode_header(value : String) -> String raise {
  let result = StringBuilder()
  let mut remaining = value
  let mut previous_encoded = false
  while !remaining.is_empty() {
    match remaining.find("=?") {
      None => {
        result.write_string(email_decode_text(email_bytes(remaining), "utf-8"))
        break
      }
      Some(start) => {
        let before = remaining[:start].to_owned()
        if !previous_encoded || !before.trim().is_empty() {
          result.write_string(email_decode_text(email_bytes(before), "utf-8"))
        }
        let tail = remaining[start + 2:].to_owned()
        guard tail.find("?") is Some(charset_end) else {
          fail("EML encoded header word is incomplete")
        }
        let charset = tail[:charset_end].to_owned()
        let encoded = tail[charset_end + 1:].to_owned()
        guard encoded.find("?") is Some(encoding_end) else {
          fail("EML encoded header word is incomplete")
        }
        let encoding = encoded[:encoding_end].to_owned()
        let payload_tail = encoded[encoding_end + 1:].to_owned()
        guard payload_tail.find("?=") is Some(end) else {
          fail("EML encoded header word is incomplete")
        }
        let payload = payload_tail[:end].to_owned()
        if charset.is_empty() || payload.contains("?") {
          fail("EML encoded header word is malformed")
        }
        let bytes = match encoding.to_lower() {
          "b" => @base64.decode(payload)
          "q" => email_quoted_printable(payload, header=true)
          _ => fail("EML unsupported header encoding: " + encoding)
        }
        result.write_string(email_decode_text(bytes, charset))
        remaining = payload_tail[end + 2:].to_owned()
        previous_encoded = true
      }
    }
  }
  let decoded = result.to_string()
  if decoded.contains("\n") || decoded.contains("\r") {
    fail("EML decoded header contains a line break")
  }
  decoded
}

///|
// Parse quoted MIME parameters without treating semicolons inside quotes as
// delimiters. Only charset, boundary and filename presence affect extraction.
fn email_content_type(value : String) -> (String, Map[String, String]) raise {
  let segments : Array[String] = []
  let segment = StringBuilder()
  let mut quoted = false
  let mut escaped = false
  for char in value {
    if escaped {
      segment.write_char(char)
      escaped = false
    } else if quoted && char == '\\' {
      escaped = true
    } else if char == '"' {
      quoted = !quoted
    } else if char == ';' && !quoted {
      segments.push(segment.to_string().trim().to_owned())
      segment.reset()
    } else {
      segment.write_char(char)
    }
  }
  if quoted || escaped {
    fail("EML MIME parameter has an unterminated quote")
  }
  segments.push(segment.to_string().trim().to_owned())
  let params : Map[String, String] = Map([])
  for index in 1..<segments.length() {
    guard segments[index].find("=") is Some(equal) else {
      fail("EML MIME parameter is missing =")
    }
    let key = segments[index][:equal].trim().to_owned().to_lower()
    let entry = segments[index][equal + 1:].trim().to_owned()
    if key.is_empty() || params.contains(key) {
      fail("EML MIME parameter is empty or duplicated")
    }
    params[key] = entry
  }
  (segments[0].to_lower(), params)
}

///|
fn email_multipart(body : String, boundary : String) -> Array[String] raise {
  if boundary.is_empty() ||
    boundary.length() > 70 ||
    boundary.contains("\n") ||
    boundary.contains("\r") {
    fail("EML multipart boundary is missing or invalid")
  }
  let delimiter = "--" + boundary
  let parts : Array[String] = []
  let current = StringBuilder()
  let mut active = false
  for part in body.split("\n") {
    let line = part.to_owned()
    let marker = line.trim_end().to_owned()
    if marker == delimiter || marker == delimiter + "--" {
      if active {
        parts.push(current.to_string())
        current.reset()
        if parts.length() > 64 {
          fail("EML multipart has more than 64 parts")
        }
      }
      if marker == delimiter + "--" {
        if !active {
          fail("EML multipart closes before its first part")
        }
        return parts
      }
      active = true
    } else if active {
      current.write_string(line + "\n")
    }
  }
  fail("EML multipart is missing its closing boundary")
}

///|
fn email_named_part(params : Map[String, String], name : String) -> Bool {
  for key, _ in params {
    if key == name || key.has_prefix(name + "*") {
      return true
    }
  }
  false
}

///|
fn email_plain_part(
  headers : Map[String, String],
  body : String,
  depth : Int32,
  count : Ref[Int32],
) -> String? raise {
  count.val += 1
  if depth > 8 || count.val > 64 {
    fail("EML exceeds 8 MIME levels or 64 total parts")
  }
  let (disposition, disposition_params) = email_content_type(
    headers.get("content-disposition").unwrap_or(""),
  )
  if disposition == "attachment" ||
    email_named_part(disposition_params, "filename") {
    return None
  }
  let (kind, params) = email_content_type(
    headers.get("content-type").unwrap_or("text/plain"),
  )
  // A named part is an attachment even if its sender omits disposition.
  if email_named_part(params, "name") {
    return None
  }
  let encoding = headers
    .get("content-transfer-encoding")
    .unwrap_or("")
    .to_lower()
  if kind == "multipart/alternative" ||
    kind == "multipart/mixed" ||
    kind == "multipart/related" {
    if !["", "7bit", "8bit"].contains(encoding) {
      fail("EML transfer-encoded multipart is unsupported")
    }
    let parts = email_multipart(body, params.get("boundary").unwrap_or(""))
    let texts : Array[String] = []
    for part in parts {
      let (part_headers, part_body) = email_headers(part)
      if email_plain_part(part_headers, part_body, depth + 1, count)
        is Some(text) {
        // Alternative bodies describe the same message: take one plain version.
        if kind != "multipart/alternative" || texts.is_empty() {
          texts.push(text)
        }
      }
    }
    if texts.is_empty() {
      None
    } else {
      Some(texts.join("\n"))
    }
  } else if kind == "text/plain" {
    let bytes = match encoding {
      "" | "7bit" | "8bit" => email_bytes(body)
      "base64" => @base64.decode(body, ignore_whitespace=true)
      "quoted-printable" => email_quoted_printable(body)
      _ => fail("EML unsupported text transfer encoding: " + encoding)
    }
    Some(email_decode_text(bytes, params.get("charset").unwrap_or("utf-8")))
  } else {
    None
  }
}

///|
fn parse_email(bytes : Bytes) -> EmailProjection raise {
  if bytes.length() > 2097152 {
    fail("EML exceeds 2 MiB; export a smaller message")
  }
  let (headers, body) = email_headers(email_byte_text(bytes))
  let subject = email_decode_header(headers.get("subject").unwrap_or(""))
  let title = if subject.trim().is_empty() {
    "Email without subject"
  } else {
    subject
  }
  if title.length() > 400 {
    fail("EML subject exceeds 400 code units")
  }
  let attribution : Array[String] = []
  for
    (key, label) in [
      ("subject", "Subject"),
      ("from", "From"),
      ("to", "To"),
      ("cc", "Cc"),
      ("date", "Date"),
      ("message-id", "Message-ID"),
      ("reply-to", "Reply-To"),
      ("in-reply-to", "In-Reply-To"),
    ] {
    let value = email_decode_header(headers.get(key).unwrap_or(""))
    if !value.is_empty() {
      attribution.push(label + ": " + value)
    }
  }
  guard email_plain_part(headers, body, 0, Ref::new(0)) is Some(text) else {
    fail("EML has no supported inline text/plain body; export UTF-8 plain text")
  }
  if text.trim().is_empty() {
    fail("EML plain-text body is empty")
  }
  { title, attribution: attribution.join("\n"), body: text, }
}
