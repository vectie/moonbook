///|
/// Observe one exact committed native Wenyu Book review. This does not call
/// workspace initialization, persistence, providers, or the approval writer.
///
/// ```mbt check
/// test {
///   ignore(@wiki.native_review_status)
/// }
/// ```
pub async fn native_review_status(
  root : String,
  work_id : String,
  request_digest : String,
  payload_digest : String,
  result_id : String,
) -> Json noraise {
  @native_wenyu_import.resolve_review(
    root, work_id, request_digest, payload_digest, result_id,
  ).to_json()
}
