///|
/// Persist the existing payload formats, or opt in to exact-once Wenyu import
/// with { book_result, native_import }. Native metadata is never silently
/// discarded or interpreted as a legacy persistence request.
///
/// ```mbt check
/// test {
///   ignore(@wiki.persist_result_payload)
/// }
/// ```
pub async fn persist_result_payload(
  root : String,
  payload : Json,
) -> PersistResultOutcome {
  if payload is Object(fields) && fields.contains("native_import") {
    return @json.from_json(@native_wenyu_import.persist(root, payload))
  }
  let decoded = decode_book_result_payload_with_metadata(payload)
  persist_result(root, decoded.result, lifecycle_proof=decoded.lifecycle_proof)
}
