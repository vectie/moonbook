///|
/// An observed Book review disposition, never task or product acceptance.
pub(all) enum NativeWenyuReviewStatus {
  Pending
  Approved
  Rejected
  Unresolved
} derive(Debug, Eq)

///|
pub impl ToJson for NativeWenyuReviewStatus with fn to_json(self) {
  let value = match self {
    Pending => "pending"
    Approved => "approved"
    Rejected => "rejected"
    Unresolved => "unresolved"
  }
  value.to_json()
}

///|
/// Identity fields echo the requested binding. Only pending/approved/rejected
/// establish that the complete binding and committed import were verified.
/// A resolution is observed from local Book records, not authenticated reviewer
/// identity, engineering completion, or original-task/product acceptance.
pub struct NativeWenyuReviewResolution {
  contract : String
  status : NativeWenyuReviewStatus
  root : String
  work_id : String
  request_digest : String
  payload_digest : String
  result_id : String
  review_id : String
  evidence_id : String
  resolution_timestamp : String?
  original_task_acceptance : String
  reason : String
} derive(Debug, ToJson)

///|
/// Read the exact native Wenyu review without initializing, importing, locking,
/// repairing, approving, or changing any Book file. Missing, malformed, partial,
/// conflicting or changing records produce Unresolved, never approval.
///
/// ```mbt check
/// test {
///   ignore(@native_wenyu_import.resolve_review)
/// }
/// ```
pub async fn resolve_review(
  root : String,
  work_id : String,
  request_digest : String,
  payload_digest : String,
  result_id : String,
) -> NativeWenyuReviewResolution noraise {
  let key = native_wenyu_digest(work_id)
  let binding : NativeWenyuReviewResolution = {
    contract: "moonbook.native-wenyu-review.v1",
    status: Unresolved,
    root,
    work_id,
    request_digest,
    payload_digest,
    result_id,
    review_id: "result-review-native-wenyu-\{key}",
    evidence_id: "EV-native-wenyu-\{key}",
    resolution_timestamp: None,
    original_task_acceptance: "unevaluated",
    reason: "native Wenyu review has not been verified",
  }
  read_native_wenyu_review(binding, key) catch {
    error => { ..binding, reason: "native Wenyu review unresolved: \{error}", }
  }
}
