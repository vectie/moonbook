///|
fn wiki_review_reduce(
  state : WikiReviewState,
  msg : WikiReviewMsg,
) -> (WikiReviewState, Array[WikiReviewEffect]) {
  match msg {
    Reload | LiveRefresh => {
      if state.pending is Some(_) {
        return (state, [])
      }
      let request = state.next_request
      let effects : Array[WikiReviewEffect] = [LoadQueue(request)]
      let restore_pending = state.detail_request == 0
      if state.selected_id is Some(review_id) && !restore_pending {
        effects.push(LoadDetail(request + 1, review_id))
      }
      (
        {
          ..state,
          queue_loading: true,
          queue_loaded: false,
          queue_request: request,
          queue_error: None,
          detail: if msg is LiveRefresh {
            state.detail
          } else {
            None
          },
          detail_loading: state.selected_id is Some(_) && !restore_pending,
          detail_request: if restore_pending {
            0
          } else {
            request + 1
          },
          detail_error: None,
          confirmation: if msg is LiveRefresh {
            state.confirmation
          } else {
            None
          },
          next_request: request + 2,
        },
        effects,
      )
    }
    QueueLoaded(request, result) => {
      if request != state.queue_request || !state.queue_loading {
        return (state, [])
      }
      let checked = match result {
        Ok(items) =>
          match wiki_review_queue_issue(items) {
            Some(error) => Err(error)
            None => Ok(items)
          }
        Err(error) => Err(error)
      }
      match checked {
        Ok(items) => {
          let next = {
            ..state,
            items,
            queue_loading: false,
            queue_loaded: true,
            queue_error: None,
          }
          if state.selected_id is Some(review_id) && state.detail_request == 0 {
            (
              {
                ..next,
                detail_loading: true,
                detail_request: state.next_request,
                next_request: state.next_request + 1,
              },
              [LoadDetail(state.next_request, review_id)],
            )
          } else {
            (next, [])
          }
        }
        Err(error) =>
          (
            {
              ..state,
              queue_loading: false,
              queue_loaded: false,
              queue_error: Some(error),
              confirmation: None,
            },
            [],
          )
      }
    }
    Select(review_id) => {
      if state.pending is Some(_) ||
        state.queue_loading ||
        !state.queue_loaded ||
        state.queue_error is Some(_) ||
        !state.items.any(item => item.review_id == review_id) {
        return (state, [])
      }
      let request = state.next_request
      (
        {
          ..state,
          selected_id: Some(review_id),
          detail: None,
          detail_loading: true,
          detail_request: request,
          detail_error: None,
          confirmation: None,
          next_request: request + 1,
          notice: None,
          readback: None,
          readback_notice: None,
        },
        [RememberSelection(review_id), LoadDetail(request, review_id)],
      )
    }
    DetailLoaded(request, review_id, result) => {
      if request != state.detail_request ||
        !state.detail_loading ||
        state.selected_id != Some(review_id) {
        return (state, [])
      }
      let checked = match result {
        Ok(detail) =>
          match wiki_review_detail_issue(detail, review_id) {
            Some(error) => Err(error)
            None => Ok(detail)
          }
        Err(error) => Err(error)
      }
      match checked {
        Ok(detail) => {
          let readback_notice = match state.readback {
            Some(choice) => {
              let expected = if choice.decision == "approve" {
                "approved"
              } else {
                "rejected"
              }
              Some(
                if detail.status == expected && !detail.can_resolve {
                  "Readback verified: \{review_id} is \{expected} in this Book. Original-task/goal acceptance remains unevaluated."
                } else {
                  "Readback shows \{review_id} is \{detail.status}. The requested decision is not verified. Inspect the current content before choosing any new action."
                },
              )
            }
            None => state.readback_notice
          }
          (
            {
              ..state,
              detail: Some(detail),
              detail_loading: false,
              detail_error: None,
              confirmation: match state.confirmation {
                Some(choice) if choice.review_id == detail.review_id &&
                  choice.digest == detail.review_digest &&
                  detail.can_resolve &&
                  detail.status == "pending" => Some(choice)
                _ => None
              },
              readback: None,
              readback_notice,
            },
            [],
          )
        }
        Err(error) =>
          (
            {
              ..state,
              // Live refresh retains useful inspected text, but failed decision
              // readback must never present its response as verified evidence.
              detail: if state.readback is None {
                state.detail
              } else {
                None
              },
              detail_loading: false,
              detail_error: Some(error),
              confirmation: None,
              readback_notice: if state.readback is Some(_) {
                Some(
                  "Decision readback is unavailable. Reload the queue and inspect again before retrying; a failed response does not prove the decision was not saved.",
                )
              } else {
                state.readback_notice
              },
            },
            [],
          )
      }
    }
    Prepare(choice) =>
      if wiki_review_choice_is_current(state, choice) {
        ({ ..state, confirmation: Some(choice), }, [])
      } else {
        (state, [])
      }
    Cancel =>
      if state.pending is None {
        ({ ..state, confirmation: None, }, [])
      } else {
        (state, [])
      }
    Confirm(choice) => {
      if state.confirmation != Some(choice) ||
        !wiki_review_choice_is_current(state, choice) {
        return (state, [])
      }
      let request = state.next_request
      (
        {
          ..state,
          confirmation: None,
          pending: Some({ request, choice, }),
          next_request: request + 1,
          notice: Some("Saving the explicitly confirmed local Book decision…"),
          readback_notice: None,
        },
        [Resolve(request, choice)],
      )
    }
    Resolved(request, result) => {
      let pending = match state.pending {
        Some(pending) if pending.request == request => pending
        _ => return (state, [])
      }
      let next = state.next_request
      let (detail, notice) = match result {
        Ok(response) => (response.detail, response.message)
        Err(error) =>
          (
            None,
            "Decision response failed: \{error}. Checking current state before any retry.",
          )
      }
      (
        {
          ..state,
          pending: None,
          confirmation: None,
          selected_id: Some(pending.choice.review_id),
          detail,
          detail_loading: true,
          detail_request: next + 1,
          detail_error: None,
          queue_loading: true,
          queue_loaded: false,
          queue_request: next,
          queue_error: None,
          next_request: next + 2,
          notice: Some(notice),
          readback: Some(pending.choice),
          readback_notice: Some(
            "Refreshing the full queue and reading the exact review back…",
          ),
        },
        [
          LoadQueue(next),
          LoadDetail(next + 1, pending.choice.review_id),
          RefreshSnapshot,
        ],
      )
    }
  }
}
