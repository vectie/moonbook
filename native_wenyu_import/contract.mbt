///|
priv struct NativeWenyuImport {
  contract : String
  work_id : String
  request_digest : String
  payload_digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
fn native_wenyu_digest(text : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text)))
}

///|
fn native_wenyu_valid_digest(value : String) -> Bool {
  if value.length() != 64 {
    return false
  }
  for index in 0..<value.length() {
    let unit = value[index]
    if !((unit >= '0' && unit <= '9') || (unit >= 'a' && unit <= 'f')) {
      return false
    }
  }
  true
}

///|
fn native_wenyu_exact_fields(value : Json, names : Array[String]) -> Unit raise {
  guard value is Object(fields) else {
    fail("native Wenyu import requires an object")
  }
  for name in names {
    guard fields.contains(name) else {
      fail("native Wenyu import missing field: \{name}")
    }
  }
  for name in fields.keys() {
    guard names.contains(name) else {
      fail("native Wenyu import unexpected field: \{name}")
    }
  }
}

///|
fn decode_native_wenyu_import(
  payload : Json,
) -> (NativeWenyuImport, BookResult, String) raise {
  native_wenyu_exact_fields(payload, ["book_result", "native_import"])
  guard payload is Object(fields) else {
    fail("native Wenyu import object required")
  }
  let metadata = fields["native_import"]
  native_wenyu_exact_fields(metadata, [
    "contract", "work_id", "request_digest", "payload_digest",
  ])
  let identity : NativeWenyuImport = @json.from_json(metadata)
  guard identity.contract == "moontown.wenyu.import.v1" &&
    !identity.work_id.trim().is_empty() &&
    identity.work_id.length() <= 256 &&
    !identity.work_id.contains("\n") &&
    !identity.work_id.contains("\r") &&
    native_wenyu_valid_digest(identity.request_digest) &&
    native_wenyu_valid_digest(identity.payload_digest) else {
    fail("invalid native Wenyu import identity")
  }
  let nested = fields["book_result"]
  native_wenyu_exact_fields(nested, [
    "result_id", "summary", "artifacts", "memory_candidates", "requires_review",
    "notify_town",
  ])
  let result : BookResult = @json.from_json(nested)
  guard !result.result_id.trim().is_empty() &&
    result.memory_candidates.is_empty() &&
    result.requires_review &&
    result.notify_town else {
    fail(
      "native Wenyu import requires review, Town notification, and no memory candidates",
    )
  }
  let text = nested.stringify()
  guard native_wenyu_digest(text) == identity.payload_digest else {
    fail("native Wenyu import payload digest mismatch")
  }
  (identity, result, text)
}

///|
/// Persist only the explicit native Wenyu envelope. Returns the unchanged
/// MoonBook PersistResultOutcome wire object; wiki decodes its existing type.
///
/// ```mbt check
/// test {
///   ignore(@native_wenyu_import.persist)
/// }
/// ```
pub async fn persist(root : String, payload : Json) -> Json {
  persist_native_wenyu_import(root, payload).to_json()
}
