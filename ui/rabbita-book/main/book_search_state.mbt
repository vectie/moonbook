///|
struct BookSearchExcerpt {
  citation : String
  title : String
  excerpt : String
  score : Int
  metadata_status : String
} derive(Debug, FromJson, ToJson, Eq)

///|
struct BookSearchResult {
  schema : String
  ok : Bool
  question : String
  excerpts : Array[BookSearchExcerpt]
  brief : String
  mode : String
  saved : Bool
  paging : BookSearchPaging?
} derive(Debug, FromJson, ToJson, Eq)

///|
struct BookSearchPaging {
  page : Int
  page_size : Int
  matched_count : Int
  window_count : Int
  has_next : Bool
  truncated : Bool
  fresh_scan : Bool
} derive(Debug, FromJson, ToJson, Eq)

///|
struct BookSearchPage {
  schema : String
  ok : Bool
  question : String
  citation : String
  content : String
  retained_source : BookRetainedDescriptor?
  page : Int?
} derive(Debug, FromJson, ToJson, Eq)

///|
struct BookRetainedDescriptor {
  reference : String
  page_digest : String
} derive(Debug, FromJson, ToJson, Eq)

///|
struct BookRetainedSource {
  reference : String
  page_digest : String
  digest : String
  size : Int
  bytes_base64 : String
  text : String?
} derive(Debug, FromJson, Eq)

///|
struct BookRetainedResponse {
  schema : String
  ok : Bool
  question : String
  citation : String
  source : BookRetainedSource
  page : Int?
} derive(Debug, FromJson, Eq)

///|
struct BookSearchState {
  collection : BookCollectionState
  draft : String
  request : Int
  pending : Bool
  requested_page : Int
  result : BookSearchResult?
  error : String?
  selected : String?
  page_request : Int
  page_pending : Bool
  page : BookSearchPage?
  page_error : String?
  source_request : Int
  source_pending : Bool
  source : BookRetainedSource?
  source_error : String?
  notice : String?
} derive(Debug)

///|
enum BookSearchMsg {
  RefreshCollected(Int, Int, BookCollectionItem)
  CollectPage
  Collection(BookCollectionMsg)
  Edit(String)
  Search
  Navigate(Int)
  Loaded(Int, String, Result[BookSearchResult, String])
  Inspect(String)
  Inspected(Int, String, Result[BookSearchPage, String])
  ReadRetained
  Retained(Int, String, String, String, Result[BookRetainedSource, String])
  DownloadRetained
  RetainedExported(Int, String, Result[String, String])
  Copy
  Download
  Exported(String, String, Result[String, String])
} derive(Debug)

///|
enum BookSearchEffect {
  ExportCollectionHtml(Int, String)
  ExportArchive(Int, String)
  ReadArchive(Int)
  ExportCollection(Int, String, Bool)
  Query(Int, String, Int)
  ReadPage(Int, String, String, Int?)
  Export(String, String, Bool)
  ReadSource(Int, String, String, BookRetainedDescriptor, Int?)
  ExportSource(Int, BookRetainedSource)
}

///|
fn book_search_initial() -> BookSearchState {
  {
    collection: book_collection_initial(),
    draft: "",
    request: 0,
    pending: false,
    requested_page: 0,
    result: None,
    error: None,
    selected: None,
    page_request: 0,
    page_pending: false,
    page: None,
    page_error: None,
    source_request: 0,
    source_pending: false,
    source: None,
    source_error: None,
    notice: None,
  }
}

///|
fn book_search_reduce(
  state : BookSearchState,
  msg : BookSearchMsg,
) -> (BookSearchState, Array[BookSearchEffect]) {
  match msg {
    RefreshCollected(request, revision, candidate) =>
      (
        {
          ..state,
          collection: book_collection_refresh(
            state, request, revision, candidate,
          ),
        },
        [],
      )
    CollectPage =>
      ({ ..state, collection: book_collection_collect(state), }, [])
    Collection(message) => {
      let (collection, effects) = book_collection_reduce(
        state.collection,
        message,
      )
      ({ ..state, collection, }, effects)
    }
    Edit(draft) =>
      (
        {
          ..state,
          draft,
          request: state.request + 1,
          pending: false,
          error: None,
          notice: None,
          page_request: state.page_request + 1,
          page_pending: false,
          source_request: state.source_request + 1,
          source_pending: false,
          source: None,
          source_error: None,
        },
        [],
      )
    Search | Navigate(_) => {
      if state.draft.trim().is_empty() || state.draft.length() > 1024 {
        return (
          {
            ..state,
            error: Some("Enter a question of 1–1024 UTF-16 code units."),
          },
          [],
        )
      }
      let request = state.request + 1
      let target_page = match msg {
        Navigate(page) => {
          guard !state.pending &&
            state.result is Some(result) &&
            state.draft == result.question &&
            result.paging is Some(paging) &&
            page >= 0 &&
            page < 10 &&
            (
              page == paging.page - 1 ||
              (page == paging.page + 1 && paging.has_next)
            ) else {
            return (state, [])
          }
          page
        }
        _ => 0
      }
      (
        {
          ..state,
          request,
          pending: true,
          requested_page: target_page,
          error: None,
          notice: None,
          page_request: state.page_request + 1,
          page_pending: false,
          page: None,
          selected: None,
          page_error: None,
          source_request: state.source_request + 1,
          source_pending: false,
          source: None,
          source_error: None,
        },
        [Query(request, state.draft, target_page)],
      )
    }
    Loaded(request, question, result) => {
      if request != state.request || !state.pending || question != state.draft {
        return (state, [])
      }
      match result {
        Ok(result) if result.question == question &&
          result.paging.map(paging => paging.page).unwrap_or(0) ==
          state.requested_page =>
          (
            {
              ..state,
              pending: false,
              result: Some(result),
              error: None,
              selected: None,
              page: None,
              page_pending: false,
              page_request: state.page_request + 1,
              page_error: None,
              source_request: state.source_request + 1,
              source_pending: false,
              source: None,
              source_error: None,
            },
            [],
          )
        Ok(_) =>
          (
            {
              ..state,
              pending: false,
              error: Some("Search response belongs to a different question."),
            },
            [],
          )
        Err(error) => ({ ..state, pending: false, error: Some(error), }, [])
      }
    }
    Inspect(citation) => {
      guard !state.pending &&
        state.result is Some(result) &&
        state.draft == result.question &&
        result.excerpts.any(item => item.citation == citation) else {
        return (state, [])
      }
      let request = state.page_request + 1
      (
        {
          ..state,
          selected: Some(citation),
          page_request: request,
          page_pending: true,
          page_error: None,
          page: None,
          source_request: state.source_request + 1,
          source_pending: false,
          source: None,
          source_error: None,
          notice: None,
        },
        [
          ReadPage(
            request,
            result.question,
            citation,
            result.paging.map(paging => paging.page),
          ),
        ],
      )
    }
    Inspected(request, citation, result) => {
      if request != state.page_request ||
        !state.page_pending ||
        state.selected != Some(citation) {
        return (state, [])
      }
      match result {
        Ok(page) if page.citation == citation &&
          state.result is Some(found) &&
          page.question == found.question &&
          page.page == found.paging.map(paging => paging.page) =>
          (
            {
              ..state,
              page_pending: false,
              page: Some(page),
              page_error: None,
            },
            [],
          )
        Ok(_) =>
          (
            {
              ..state,
              page_pending: false,
              page_error: Some(
                "Page response does not match the selected citation.",
              ),
            },
            [],
          )
        Err(error) =>
          ({ ..state, page_pending: false, page_error: Some(error), }, [])
      }
    }
    ReadRetained => {
      guard !state.pending &&
        !state.page_pending &&
        state.result is Some(result) &&
        state.page is Some(page) &&
        page.question == result.question &&
        state.draft == result.question &&
        state.selected == Some(page.citation) &&
        page.retained_source is Some(descriptor) else {
        return (state, [])
      }
      let request = state.source_request + 1
      (
        {
          ..state,
          source_request: request,
          source_pending: true,
          source: None,
          source_error: None,
          notice: None,
        },
        [
          ReadSource(
            request,
            page.question,
            page.citation,
            descriptor,
            page.page,
          ),
        ],
      )
    }
    Retained(request, question, citation, page_digest, result) => {
      guard request == state.source_request &&
        state.source_pending &&
        !state.pending &&
        !state.page_pending &&
        state.draft == question &&
        state.page is Some(page) &&
        page.question == question &&
        page.citation == citation &&
        state.selected == Some(citation) &&
        page.retained_source is Some(descriptor) &&
        descriptor.page_digest == page_digest else {
        return (state, [])
      }
      match result {
        Ok(source) if source.page_digest == page_digest &&
          source.reference == descriptor.reference =>
          (
            {
              ..state,
              source_pending: false,
              source: Some(source),
              source_error: None,
            },
            [],
          )
        Ok(_) =>
          (
            {
              ..state,
              source_pending: false,
              source_error: Some(
                "Retained source response does not match this page.",
              ),
            },
            [],
          )
        Err(error) =>
          ({ ..state, source_pending: false, source_error: Some(error), }, [])
      }
    }
    DownloadRetained => {
      guard !state.pending &&
        !state.page_pending &&
        !state.source_pending &&
        state.page is Some(page) &&
        page.question == state.draft &&
        state.selected == Some(page.citation) &&
        page.retained_source is Some(descriptor) &&
        state.source is Some(source) &&
        descriptor.page_digest == source.page_digest &&
        descriptor.reference == source.reference else {
        return (state, [])
      }
      (state, [ExportSource(state.source_request, source)])
    }
    RetainedExported(request, digest, result) => {
      guard request == state.source_request &&
        state.source is Some(source) &&
        source.digest == digest else {
        return (state, [])
      }
      (
        {
          ..state,
          notice: Some(
            match result {
              Ok(text) => text
              Err(error) => error
            },
          ),
        },
        [],
      )
    }
    Copy | Download => {
      guard state.result is Some(result) else { return (state, []) }
      (state, [Export(result.question, result.brief, msg is Download)])
    }
    Exported(question, brief, result) => {
      guard state.result is Some(data) &&
        data.question == question &&
        data.brief == brief else {
        return (state, [])
      }
      (
        {
          ..state,
          notice: Some(
            match result {
              Ok(message) => message
              Err(error) => error
            },
          ),
        },
        [],
      )
    }
  }
}
