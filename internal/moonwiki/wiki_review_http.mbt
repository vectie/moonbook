///|
fn wiki_review_http_route(path : String) -> Bool {
  let path = request_path_without_query(path)
  path == "/api/wiki/reviews" || path.has_prefix("/api/wiki/reviews/")
}

///|
fn wiki_review_http_header(
  headers : Map[String, String],
  name : String,
) -> String {
  for key, value in headers {
    if key.to_lower() == name {
      return value
    }
  }
  ""
}

///|
fn wiki_review_http_error(status : Int, error : String) -> (Int, Json) {
  (
    status,
    {
      "schema": "moonbook.wiki-review-operator.v1",
      "ok": false,
      "error": error,
    },
  )
}

///|
/// Socket-free application-route owner used by the ordinary Book host.
/// The root comes from serve options, never browser input. JSON-only POSTs
/// retain the same-origin browser boundary without modifying Bookkeeper routes.
pub async fn wiki_review_http_response(
  root : String,
  method_ : String,
  path : String,
  headers : Map[String, String],
  text : String,
) -> (Int, Json) noraise {
  if !wiki_review_http_route(path) {
    return wiki_review_http_error(404, "Unsupported wiki review route")
  }
  if wiki_review_http_header(headers, "sec-fetch-site") == "cross-site" {
    return wiki_review_http_error(
      403, "Open this review in its own Book server",
    )
  }
  let body = if method_ == "POST" {
    let content_type = wiki_review_http_header(headers, "content-type")
      .split(";")
      .to_array()[0]
      .trim()
      .to_owned()
      .to_lower()
    if content_type != "application/json" {
      return wiki_review_http_error(
        415, "Wiki review requests require application/json",
      )
    }
    @json.parse(text) catch {
      _ => return wiki_review_http_error(400, "Invalid wiki review JSON")
    }
  } else {
    Json::null()
  }
  @wiki.review_operator_request(
    root,
    method_,
    request_path_without_query(path),
    body,
  )
}

///|
async fn handle_wiki_review_request(
  workspace_root : String,
  request : @http.Request,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let method_ = match request.meth {
    Get => "GET"
    Post => "POST"
    _ => "OTHER"
  }
  let text = if method_ == "POST" { body.read_all().text() } else { "" }
  let (status, payload) = wiki_review_http_response(
    workspace_root,
    method_,
    request.path,
    request.headers,
    text,
  )
  send_json_status(
    conn,
    status,
    if status == 200 {
      "OK"
    } else {
      "Wiki Review Request Rejected"
    },
    payload,
  )
}
