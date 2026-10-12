///|
fn book_search_route(path : String) -> Bool {
  let path = request_path_without_query(path)
  path == "/api/book/query" ||
  path == "/api/book/query/inspect" ||
  path == "/api/book/query/retained-source"
}

///|
fn book_search_error(status : Int, message : String) -> (Int, Json) {
  (status, { "schema": "moonbook.search.v1", "ok": false, "error": message })
}

///|
/// Read-only route owner. The root is supplied by the host, never the body.
/// Both query and inspect use the production query with saving disabled.
pub async fn book_search_http_response(
  root : String,
  method_ : String,
  path : String,
  headers : Map[String, String],
  text : String,
) -> (Int, Json) noraise {
  if !book_search_route(path) {
    return book_search_error(404, "Unknown Book search route")
  }
  if method_ != "POST" {
    return book_search_error(405, "Use POST for Book search")
  }
  if wiki_review_http_header(headers, "sec-fetch-site") == "cross-site" {
    return book_search_error(403, "Open search in this Book's own server")
  }
  if wiki_review_http_header(headers, "content-type").split(";").to_array()[0]
    .trim()
    .to_lower() !=
    "application/json" {
    return book_search_error(415, "Book search requires application/json")
  }
  if @utf8.encode(text).length() > 16384 {
    return book_search_error(413, "Search request exceeds 16 KiB")
  }
  let payload = @json.parse(text) catch {
    _ => return book_search_error(400, "Invalid search JSON")
  }
  guard payload is { "question": String(question), .. } else {
    return book_search_error(400, "A question is required")
  }
  if question.trim().is_empty() ||
    question.length() > 1024 ||
    question.contains("\u0000") {
    return book_search_error(
      400, "Enter a question of 1–1024 UTF-16 code units",
    )
  }
  let page : Int? = match payload {
    { "page": Number(value), .. } => {
      if value < 0.0 || value >= 10.0 {
        return book_search_error(400, "Page must be an integer between 0 and 9")
      }
      let parsed = value.to_int()
      if value != parsed.to_double() || parsed < 0 || parsed >= 10 {
        return book_search_error(400, "Page must be an integer between 0 and 9")
      }
      Some(parsed)
    }
    Object(fields) if fields.contains("page") =>
      return book_search_error(400, "Page must be an integer between 0 and 9")
    _ => None
  }
  try {
    let window = match page {
      Some(page) => Some(@wiki.query_wiki_page(root, question, page))
      None => None
    }
    let result = match window {
      Some(window) => window.result
      None => @wiki.query_wiki(root, question, save=false)
    }
    if request_path_without_query(path) != "/api/book/query" {
      guard payload is { "citation": String(citation), .. } &&
        result.citations.contains(citation) else {
        return book_search_error(
          409, "This citation is no longer on this query's requested results page; fresh rankings may change. Search again",
        )
      }
      if request_path_without_query(path) == "/api/book/query/retained-source" {
        guard payload is { "page_digest": String(page_digest), .. } &&
          @wiki.executable_source_digest_is_valid(page_digest) else {
          return book_search_error(
            400, "Inspect the maintained page before reading its retained source",
          )
        }
        let retained = @wiki.query_retained_source(root, citation, page_digest) catch {
          _ =>
            return book_search_error(
              409, "Retained source unavailable or page binding changed. Inspect the maintained page again; retained files must be regular, link-free, and at most 2 MiB.",
            )
        }
        return (
          200,
          {
            "schema": "moonbook.search.v1",
            "ok": true,
            "question": question,
            "page": match page {
              Some(page) => page.to_json()
              None => Json::null()
            },
            "citation": citation,
            "source": {
              "reference": retained.reference,
              "page_digest": retained.page_digest,
              "digest": retained.digest,
              "size": retained.size,
              "bytes_base64": retained.bytes_base64,
              "text": match retained.text {
                Some(text) => text.to_json()
                None => Json::null()
              },
            },
          },
        )
      }
      let content = @wiki.query_page_text(root, citation)
      let retained_source = @wiki.query_retained_descriptor(
        root, citation, content,
      )
      return (
        200,
        {
          "schema": "moonbook.search.v1",
          "ok": true,
          "question": question,
          "page": match page {
            Some(page) => page.to_json()
            None => Json::null()
          },
          "citation": citation,
          "content": content,
          "retained_source": match retained_source {
            Some(source) => source.to_json()
            None => Json::null()
          },
        },
      )
    }
    (
      200,
      {
        "schema": "moonbook.search.v1",
        "ok": true,
        "question": result.question,
        "excerpts": result.excerpts,
        "brief": match window {
          Some(window) => @wiki.query_window_context_brief(window)
          None => @wiki.query_context_brief(result)
        },
        "paging": match window {
          Some(window) => window.paging.to_json()
          None => Json::null()
        },
        "mode": "lexical-excerpts",
        "saved": false,
      },
    )
  } catch {
    _ =>
      book_search_error(
        422, "Search could not read this Book. Use at least one searchable term of two characters; check page readability and size, then retry. No query was saved.",
      )
  }
}

///|
async fn handle_book_search_request(
  root : String,
  request : @http.Request,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let bytes = FixedArray::make(16385, b'0')
  let mut count = 0
  while count < bytes.length() {
    let read = body.read(bytes, offset=count, max_len=bytes.length() - count)
    if read == 0 {
      break
    }
    count += read
  }
  let (status, payload) = if count > 16384 {
    book_search_error(413, "Search request exceeds 16 KiB")
  } else {
    let text = @utf8.decode(bytes.unsafe_reinterpret_as_bytes()[:count]) catch {
      _ => ""
    }
    book_search_http_response(
      root,
      if request.meth is Post {
        "POST"
      } else {
        "OTHER"
      },
      request.path,
      request.headers,
      text,
    )
  }
  send_json_status(
    conn,
    status,
    if status == 200 {
      "OK"
    } else {
      "Book Search Rejected"
    },
    payload,
  )
}
