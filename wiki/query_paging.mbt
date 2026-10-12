///|
/// A fresh lexical scan, bounded to ten pages of three excerpts. Counts refer
/// to readable queryable pages in this scan, not a transactional snapshot.
pub struct QueryPaging {
  page : Int
  page_size : Int
  matched_count : Int
  window_count : Int
  has_next : Bool
  truncated : Bool
  fresh_scan : Bool
} derive(Debug, ToJson)

///|
pub struct QueryWindow {
  result : QueryResult
  paging : QueryPaging
} derive(Debug, ToJson)

///|
/// Read-only paged search beside the unchanged top-three legacy query.
/// Page is zero-based, 0–9. No save option is offered.
pub async fn query_wiki_page(
  root : String,
  question : String,
  page : Int,
) -> QueryWindow {
  guard page >= 0 && page < 10 else { fail("page must be between 0 and 9") }
  guard question.length() <= 1024 else {
    fail("query exceeds 1024 UTF-16 code units")
  }
  let workspace = workspace_paths(@fs.realpath(root))
  let terms = query_terms(question)
  guard !terms.is_empty() else { fail("query must contain a searchable term") }
  let matches = rank_matches(
    collect_markdown_pages(workspace.wiki_dir),
    workspace.root,
    terms,
  )
  let window_count = if matches.length() > 30 { 30 } else { matches.length() }
  let selected : Array[QueryMatch] = []
  for index in (page * 3)..<((page + 1) * 3) {
    if index < window_count {
      selected.push(matches[index])
    }
  }
  {
    result: {
      question,
      answer: if selected.is_empty() && !matches.is_empty() {
        "No excerpts on this results page in the current scan; other pages still match."
      } else if selected.is_empty() {
        no_results_answer(question)
      } else {
        answer_text(question, selected)
      },
      citations: selected.map(item => item.relative_path),
      saved_page: None,
      related_pages: [],
      excerpts: selected.map(item => {
        citation: item.relative_path,
        title: item.title,
        excerpt: item.excerpt,
        score: item.score,
        metadata_status: item.metadata_status,
      }),
    },
    paging: {
      page,
      page_size: 3,
      matched_count: matches.length(),
      window_count,
      has_next: (page + 1) * 3 < window_count,
      truncated: matches.length() > window_count,
      fresh_scan: true,
    },
  }
}

///|
pub fn query_window_context_brief(window : QueryWindow) -> String {
  let p = window.paging
  "Results page " +
  (p.page + 1).to_string() +
  "; up to 3 excerpts per page. " +
  "Matched pages: " +
  p.matched_count.to_string() +
  "; accessible window: " +
  p.window_count.to_string() +
  "/30; truncated: " +
  p.truncated.to_string() +
  ".\nFresh scan on every search, page change and inspect; rankings can change. No snapshot is retained.\n\n" +
  query_context_brief_at(
    window.result,
    p.page * 3,
    if p.matched_count > 0 {
      "No excerpts on this results page in the current scan; other pages still match.\n"
    } else {
      "No matching maintained pages found.\n"
    },
  )
}
