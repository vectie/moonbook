///|
fn book_search_safe_citation(citation : String) -> Bool {
  citation.has_prefix("wiki/") &&
  citation.has_suffix(".md") &&
  !citation.contains("\\") &&
  !citation.contains("\u0000") &&
  citation.split("/").all(part => part != "" && part != "." && part != "..")
}

///|
fn book_search_decode(
  text : String,
  question : String,
) -> Result[BookSearchResult, String] {
  let data : BookSearchResult = @json.from_json(
    book_search_optional_field(@json.parse(text), "paging"),
  ) catch {
    _ => return Err("Invalid Book search response.")
  }
  if data.schema != "moonbook.search.v1" ||
    !data.ok ||
    data.saved ||
    data.mode != "lexical-excerpts" ||
    data.question != question ||
    data.excerpts.length() > 3 ||
    data.brief.is_empty() {
    return Err("Unsupported Book search response or question mismatch.")
  }
  let seen : Map[String, Bool] = Map([])
  if data.paging is Some(p) &&
    (
      p.page < 0 ||
      p.page >= 10 ||
      p.page_size != 3 ||
      p.matched_count < 0 ||
      p.matched_count > 10000 ||
      p.window_count !=
      (if p.matched_count > 30 { 30 } else { p.matched_count }) ||
      p.has_next != ((p.page + 1) * 3 < p.window_count) ||
      p.truncated != (p.matched_count > 30) ||
      !p.fresh_scan ||
      data.excerpts.length() !=
      (if p.window_count <= p.page * 3 {
        0
      } else if p.window_count >= (p.page + 1) * 3 {
        3
      } else {
        p.window_count - p.page * 3
      })
    ) {
    return Err("Invalid bounded search paging metadata.")
  }
  for item in data.excerpts {
    if !book_search_safe_citation(item.citation) ||
      item.score <= 0 ||
      seen.contains(item.citation) {
      return Err("Invalid or repeated Book citation.")
    }
    seen[item.citation] = true
  }
  Ok(data)
}

///|
async fn book_search_post(
  route : String,
  body : Json,
  send? : (String, String, String) -> @js.Promise = request_wiki_review_json,
) -> Result[String, String] noraise {
  let text : String = send("POST", route, body.stringify()).wait().cast() catch {
      error => return Err("Search unavailable: \{error}")
    }
  let response : WikiReviewBrowserResponse = @json.from_json(@json.parse(text)) catch {
    _ => return Err("Invalid search transport response.")
  }
  if response.ok {
    return Ok(response.body)
  }
  let json = @json.parse(response.body) catch { _ => Json::null() }
  Err(
    match json {
      { "error": String(error), .. } => error
      _ =>
        "Search unavailable. Open a live MoonBook server and retry. " +
        response.error.unwrap_or("")
    },
  )
}

///|
async fn book_search_fetch(
  question : String,
  page : Int,
) -> Result[BookSearchResult, String] noraise {
  match
    book_search_post("/api/book/query", { "question": question, "page": page }) {
    Ok(text) =>
      match book_search_decode(text, question) {
        Ok(result) if result.paging is Some(paging) && paging.page == page =>
          Ok(result)
        Ok(_) =>
          Err("Search response does not match the requested results page.")
        Err(error) => Err(error)
      }
    Err(error) => Err(error)
  }
}

///|
fn book_search_decode_page(
  text : String,
  question : String,
  citation : String,
  results_page? : Int,
) -> Result[BookSearchPage, String] {
  let page : BookSearchPage = @json.from_json(
    book_search_optional_field(
      book_search_optional_field(@json.parse(text), "retained_source"),
      "page",
    ),
  ) catch {
    _ => return Err("Invalid maintained page response.")
  }
  if page.schema != "moonbook.search.v1" ||
    !page.ok ||
    page.question != question ||
    page.citation != citation ||
    page.page != results_page ||
    !book_search_safe_citation(page.citation) ||
    (
      page.retained_source is Some(source) &&
      (
        !book_search_safe_reference(source.reference) ||
        !book_search_digest(source.page_digest)
      )
    ) {
    Err("Maintained page response does not match this citation.")
  } else {
    Ok(page)
  }
}

///|
async fn book_search_read(
  question : String,
  citation : String,
  page : Int?,
) -> Result[BookSearchPage, String] noraise {
  let body : Map[String, Json] = {
    "question": question.to_json(),
    "citation": citation.to_json(),
  }
  if page is Some(page) {
    body["page"] = page.to_json()
  }
  match book_search_post("/api/book/query/inspect", body.to_json()) {
    Ok(text) =>
      book_search_decode_page(text, question, citation, results_page?=page)
    Err(error) => Err(error)
  }
}

///|
extern "js" fn book_search_export(
  text : String,
  download : Bool,
) -> @js.Promise =
  #| async (text, download) => {
  #|   if (!download) { await navigator.clipboard.writeText(text); return "Context brief copied."; }
  #|   const blob = new Blob([text], { type: "text/plain;charset=utf-8" });
  #|   const url = URL.createObjectURL(blob);
  #|   const link = document.createElement("a");
  #|   link.href = url; link.download = "moonbook-context.txt";
  #|   document.body.appendChild(link);
  #|   try { link.click(); } finally { link.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
  #|   return "Context brief download requested.";
  #| }

///|
fn book_search_effect(
  emit : @rabbita.Emit[Msg],
  effect : BookSearchEffect,
) -> @rabbita.Cmd {
  match effect {
    ExportCollectionHtml(revision, text) =>
      @rabbita.perform(
        result => emit(BookSearch(Collection(ExportedBrief(revision, result)))),
        async fn() noraise {
          let message : String = book_collection_html_download(text)
            .wait()
            .cast() catch {
              _ =>
                return Err(
                  "HTML download unavailable. Your collection is intact; try again or save resumable JSON.",
                )
            }
          Ok(message)
        },
      )
    ExportArchive(revision, text) =>
      @rabbita.perform(
        result => emit(BookSearch(Collection(ExportedBrief(revision, result)))),
        async fn() noraise {
          let message : String = book_collection_archive_download(text)
            .wait()
            .cast() catch {
              _ =>
                return Err(
                  "Collection download unavailable. Your collection is intact; copy the JSON preview instead.",
                )
            }
          Ok(message)
        },
      )
    ReadArchive(request) =>
      @rabbita.perform(
        result => emit(BookSearch(Collection(ArchiveRead(request, result)))),
        async fn() noraise {
          let text : String = book_collection_archive_open().wait().cast() catch {
              _ =>
                return Err(
                  "Could not read collection file. Choose a JSON file no larger than 16 MiB or paste its text.",
                )
            }
          Ok(text)
        },
      )
    ExportCollection(revision, text, download) =>
      @rabbita.perform(
        result => emit(BookSearch(Collection(ExportedBrief(revision, result)))),
        async fn() noraise {
          let message : String = book_collection_export(text, download)
            .wait()
            .cast() catch {
              _ =>
                return Err(
                  "Export unavailable. Your collection is intact; try Download or select the exact preview text.",
                )
            }
          Ok(message)
        },
      )
    ReadSource(request, question, citation, descriptor, page) =>
      @rabbita.perform(
        result => {
          emit(
            BookSearch(
              Retained(
                request,
                question,
                citation,
                descriptor.page_digest,
                result,
              ),
            ),
          )
        },
        async fn() noraise {
          book_search_read_source(
            question,
            citation,
            descriptor,
            results_page?=page,
          )
        },
      )
    ExportSource(request, source) =>
      @rabbita.perform(
        result => {
          emit(BookSearch(RetainedExported(request, source.digest, result)))
        },
        async fn() noraise {
          let _ : Bool = book_search_verify_source(
              source.bytes_base64,
              source.digest,
              source.size,
              source.text,
            )
            .wait()
            .cast() catch {
              _ =>
                return Err(
                  "Retained bytes failed validation; no download was created.",
                )
            }
          let message : String = book_search_download_source(
              source.bytes_base64,
              source.reference,
            )
            .wait()
            .cast() catch {
              _ =>
                return Err(
                  "Retained source download unavailable. Inspect again and retry.",
                )
            }
          Ok(message)
        },
      )
    Query(request, question, page) =>
      @rabbita.perform(
        result => emit(BookSearch(Loaded(request, question, result))),
        async fn() noraise { book_search_fetch(question, page) },
      )
    ReadPage(request, question, citation, page) =>
      @rabbita.perform(
        result => emit(BookSearch(Inspected(request, citation, result))),
        async fn() noraise { book_search_read(question, citation, page) },
      )
    Export(question, text, download) =>
      @rabbita.perform(
        result => emit(BookSearch(Exported(question, text, result))),
        async fn() noraise {
          let message : String = book_search_export(text, download)
            .wait()
            .cast() catch {
              _ =>
                return Err(
                  "Export unavailable. Use Download context or select the readable brief below.",
                )
            }
          Ok(message)
        },
      )
  }
}
