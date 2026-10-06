///|
struct WikiReviewQueueWire {
  schema : String
  ok : Bool
  items : Array[WikiReviewItem]
  original_task_acceptance : String
} derive(FromJson)

///|
struct WikiReviewDetailWire {
  schema : String
  ok : Bool
  detail : WikiReviewDetail?
  error : String?
  promoted_pages : Array[String]?
} derive(FromJson)

///|
struct WikiReviewBrowserResponse {
  ok : Bool
  status : Int
  body : String
  error : String?
} derive(FromJson)

///|
fn wiki_review_decode_queue(
  text : String,
) -> Result[Array[WikiReviewItem], String] {
  let wire : WikiReviewQueueWire = @json.from_json(@json.parse(text)) catch {
    error => return Err("Invalid review queue response: \{error}")
  }
  if wire.schema != "moonbook.wiki-review-operator.v1" ||
    !wire.ok ||
    wire.original_task_acceptance != "unevaluated" {
    return Err("Unsupported review queue schema or acceptance claim.")
  }
  match wiki_review_queue_issue(wire.items) {
    Some(error) => Err(error)
    None => Ok(wire.items)
  }
}

///|
fn wiki_review_decode_detail(
  text : String,
  review_id : String,
) -> Result[WikiReviewDetail, String] {
  let wire : WikiReviewDetailWire = @json.from_json(@json.parse(text)) catch {
    error => return Err("Invalid review detail response: \{error}")
  }
  if wire.schema != "moonbook.wiki-review-operator.v1" || !wire.ok {
    return Err(
      wire.error.unwrap_or("Unsupported or rejected review detail response."),
    )
  }
  let detail = match wire.detail {
    Some(detail) => detail
    None => return Err("Review detail is missing.")
  }
  match wiki_review_detail_issue(detail, review_id) {
    Some(error) => Err(error)
    None => Ok(detail)
  }
}

///|
fn wiki_review_decode_resolution(
  text : String,
  status : Int,
  choice : WikiReviewChoice,
) -> Result[WikiReviewResolution, String] {
  let wire : WikiReviewDetailWire = @json.from_json(@json.parse(text)) catch {
    error => return Err("HTTP \{status}: invalid decision response: \{error}")
  }
  if wire.schema != "moonbook.wiki-review-operator.v1" {
    return Err("Decision response has an unsupported schema.")
  }
  match wire.detail {
    Some(detail) =>
      match wiki_review_detail_issue(detail, choice.review_id) {
        Some(error) => return Err(error)
        None => ()
      }
    None => ()
  }
  let saved = status >= 200 && status < 300 && wire.ok
  if saved {
    let expected = if choice.decision == "approve" {
      "approved"
    } else {
      "rejected"
    }
    match wire.detail {
      Some(detail) if detail.status == expected && !detail.can_resolve => ()
      _ =>
        return Err(
          "Decision response did not confirm the requested local Book status.",
        )
    }
  }
  Ok({
    saved,
    detail: wire.detail,
    message: if saved {
      "Local Book decision saved. Verifying durable readback. Updated pages: " +
      wire.promoted_pages.unwrap_or([]).join(", ")
    } else {
      "HTTP \{status}: " +
      wire.error.unwrap_or("Decision was not accepted.") +
      " Checking the exact review again; no decision will be retried automatically."
    },
  })
}

///|
fn wiki_review_resolve_body(choice : WikiReviewChoice) -> Json {
  {
    "review_id": choice.review_id,
    "decision": choice.decision,
    "expected_digest": choice.digest,
    "scope": "local-book-review",
  }
}

///|
extern "js" fn request_wiki_review_json(
  method_ : String,
  url : String,
  body : String,
) -> @js.Promise =
  #| async (method, url, body) => {
  #|   const controller = new AbortController();
  #|   const timeout = setTimeout(() => controller.abort(), 20000);
  #|   try {
  #|     const response = await fetch(url, {
  #|       method,
  #|       credentials: "same-origin",
  #|       cache: "no-store",
  #|       headers: { "Content-Type": "application/json" },
  #|       body: method === "GET" ? undefined : body,
  #|       signal: controller.signal,
  #|     });
  #|     return JSON.stringify({ ok: response.ok, status: response.status, body: await response.text() });
  #|   } catch (error) {
  #|     return JSON.stringify({ ok: false, status: 0, body: "", error: String(error) });
  #|   } finally {
  #|     clearTimeout(timeout);
  #|   }
  #| }

///|
async fn wiki_review_response(
  method_ : String,
  route : String,
  body : String,
) -> WikiReviewBrowserResponse noraise {
  let text : String = request_wiki_review_json(method_, route, body)
    .wait()
    .cast() catch {
      error =>
        return { ok: false, status: 0, body: "", error: Some("\{error}"), }
    }
  @json.from_json(@json.parse(text)) catch {
    error => { ok: false, status: 0, body: "", error: Some("\{error}"), }
  }
}

///|
fn wiki_review_http_error(response : WikiReviewBrowserResponse) -> String {
  if response.error is Some(error) {
    return error
  }
  let parsed = @json.parse(response.body) catch {
    _ =>
      return "HTTP \{response.status}: the review API is unavailable. Use a live MoonBook server and reload."
  }
  match parsed {
    { "error": String(error), .. } => "HTTP \{response.status}: \{error}"
    _ =>
      "HTTP \{response.status}: the review API is unavailable. Use a live MoonBook server and reload."
  }
}

///|
async fn wiki_review_fetch_queue() -> Result[Array[WikiReviewItem], String] noraise {
  let response = wiki_review_response("GET", "/api/wiki/reviews", "")
  if response.ok {
    wiki_review_decode_queue(response.body)
  } else {
    Err(wiki_review_http_error(response))
  }
}

///|
async fn wiki_review_fetch_detail(
  review_id : String,
) -> Result[WikiReviewDetail, String] noraise {
  let body : Json = { "review_id": review_id }
  let response = wiki_review_response(
    "POST",
    "/api/wiki/reviews/inspect",
    body.stringify(),
  )
  if response.ok {
    wiki_review_decode_detail(response.body, review_id)
  } else {
    Err(wiki_review_http_error(response))
  }
}

///|
async fn wiki_review_resolve(
  choice : WikiReviewChoice,
) -> Result[WikiReviewResolution, String] noraise {
  let response = wiki_review_response(
    "POST",
    "/api/wiki/reviews/resolve",
    wiki_review_resolve_body(choice).stringify(),
  )
  if response.status == 0 {
    Err(wiki_review_http_error(response))
  } else {
    wiki_review_decode_resolution(response.body, response.status, choice)
  }
}

///|
fn wiki_review_effect_cmd(
  emit : @rabbita.Emit[Msg],
  effect : WikiReviewEffect,
) -> @rabbita.Cmd {
  match effect {
    LoadQueue(request) =>
      @rabbita.perform(
        result => emit(WikiReview(QueueLoaded(request, result))),
        async fn() noraise { wiki_review_fetch_queue() },
      )
    LoadDetail(request, review_id) =>
      @rabbita.perform(
        result => emit(WikiReview(DetailLoaded(request, review_id, result))),
        async fn() noraise { wiki_review_fetch_detail(review_id) },
      )
    Resolve(request, choice) =>
      @rabbita.perform(result => emit(WikiReview(Resolved(request, result))), async fn() noraise {
        wiki_review_resolve(choice)
      })
    RefreshSnapshot => emit(RefreshSnapshot)
    RememberSelection(review_id) =>
      @cmd.custom_cmd(
        _ => {
          write_wiki_review_browser_url(
            wiki_review_url_with_hint(wiki_review_browser_url(), review_id),
          )
        },
        kind=@cmd.after_render,
      )
  }
}

///|
extern "js" fn wiki_review_url_hint(url : String) -> String =
  #| (url) => {
  #|   try { return new URL(url).searchParams.get("wiki_review") || ""; }
  #|   catch (_) { return ""; }
  #| }

///|
extern "js" fn wiki_review_url_with_hint(
  url : String,
  review_id : String,
) -> String =
  #| (url, reviewId) => {
  #|   try {
  #|     const next = new URL(url);
  #|     next.searchParams.set("wiki_review", reviewId);
  #|     next.hash = "reviews";
  #|     return next.href;
  #|   } catch (_) { return url; }
  #| }

///|
extern "js" fn wiki_review_browser_url() -> String =
  #| () => typeof window === "undefined" ? "" : window.location.href

///|
extern "js" fn write_wiki_review_browser_url(url : String) -> Unit =
  #| (url) => {
  #|   try { window.history.replaceState(window.history.state, "", url); }
  #|   catch (_) { /* Readback still works in the current page if URL hints are unavailable. */ }
  #| }
