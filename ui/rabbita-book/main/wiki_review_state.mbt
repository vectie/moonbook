///|
struct WikiReviewItem {
  review_id : String
  kind : String
  title : String
  status : String
} derive(Debug, FromJson)

///|
struct WikiReviewDetail {
  review_id : String
  kind : String
  title : String
  status : String
  review_digest : String
  review_text : String
  result_text : String
  evidence_text : String
  review_scope : String
  original_task_acceptance : String
  can_resolve : Bool
  native_binding : Json?
} derive(Debug, FromJson)

///|
struct WikiReviewChoice {
  review_id : String
  digest : String
  decision : String
} derive(Debug, Eq)

///|
struct WikiReviewPending {
  request : Int
  choice : WikiReviewChoice
} derive(Debug)

///|
struct WikiReviewResolution {
  saved : Bool
  detail : WikiReviewDetail?
  message : String
} derive(Debug)

///|
struct WikiReviewState {
  items : Array[WikiReviewItem]
  queue_loading : Bool
  queue_loaded : Bool
  queue_request : Int
  queue_error : String?
  selected_id : String?
  detail : WikiReviewDetail?
  detail_loading : Bool
  detail_request : Int
  detail_error : String?
  confirmation : WikiReviewChoice?
  pending : WikiReviewPending?
  next_request : Int
  notice : String?
  readback : WikiReviewChoice?
  readback_notice : String?
} derive(Debug)

///|
enum WikiReviewMsg {
  Reload
  LiveRefresh
  QueueLoaded(Int, Result[Array[WikiReviewItem], String])
  Select(String)
  DetailLoaded(Int, String, Result[WikiReviewDetail, String])
  Prepare(WikiReviewChoice)
  Cancel
  Confirm(WikiReviewChoice)
  Resolved(Int, Result[WikiReviewResolution, String])
} derive(Debug)

///|
enum WikiReviewEffect {
  LoadQueue(Int)
  LoadDetail(Int, String)
  Resolve(Int, WikiReviewChoice)
  RefreshSnapshot
  RememberSelection(String)
} derive(Debug)

///|
fn wiki_review_initial_state(restore_id? : String = "") -> WikiReviewState {
  {
    items: [],
    queue_loading: true,
    queue_loaded: false,
    queue_request: 1,
    queue_error: None,
    selected_id: wiki_review_restore_id(restore_id),
    detail: None,
    detail_loading: false,
    detail_request: 0,
    detail_error: None,
    confirmation: None,
    pending: None,
    next_request: 2,
    notice: None,
    readback: None,
    readback_notice: None,
  }
}

///|
fn wiki_review_restore_id(hint : String) -> String? {
  if hint.trim().is_empty() || hint.length() > 4096 {
    None
  } else {
    Some(hint)
  }
}

///|
fn wiki_review_queue_issue(items : Array[WikiReviewItem]) -> String? {
  let seen : Map[String, Bool] = Map([])
  for item in items {
    if item.review_id.trim().is_empty() {
      return Some(
        "Queue contains a blank review ID. Reload after repairing the queue.",
      )
    }
    if seen.contains(item.review_id) {
      return Some(
        "Queue contains duplicate review ID: \{item.review_id}. No decision is enabled.",
      )
    }
    seen[item.review_id] = true
  }
  None
}

///|
fn wiki_review_detail_issue(
  detail : WikiReviewDetail,
  review_id : String,
) -> String? {
  if detail.review_id != review_id || review_id.trim().is_empty() {
    Some("Review response does not match the exact selected review ID.")
  } else if detail.review_scope != "local-book-review" ||
    detail.original_task_acceptance != "unevaluated" {
    Some("Review response has an unsupported scope or acceptance claim.")
  } else if detail.review_digest.trim().is_empty() {
    Some("Review response is missing its exact-content digest.")
  } else if detail.can_resolve && detail.status != "pending" {
    Some(
      "Review response incorrectly enables a decision for a non-pending review.",
    )
  } else {
    None
  }
}

///|
fn wiki_review_choice_is_current(
  state : WikiReviewState,
  choice : WikiReviewChoice,
) -> Bool {
  if state.pending is Some(_) ||
    state.detail_loading ||
    state.detail_error is Some(_) ||
    state.queue_loading ||
    state.queue_error is Some(_) ||
    !state.queue_loaded ||
    state.selected_id != Some(choice.review_id) ||
    (choice.decision != "approve" && choice.decision != "reject") {
    return false
  }
  match state.detail {
    Some(detail) =>
      detail.review_id == choice.review_id &&
      detail.review_digest == choice.digest &&
      detail.can_resolve &&
      detail.status == "pending" &&
      wiki_review_detail_issue(detail, choice.review_id) is None
    None => false
  }
}
