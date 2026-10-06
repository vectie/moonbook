///|
async fn prepare_native_wenyu_intent(
  root : String,
  identity : NativeWenyuImport,
  result : BookResult,
  payload_text : String,
) -> NativeWenyuIntent {
  let key = native_wenyu_digest(identity.work_id)
  let evidence_id = "EV-native-wenyu-\{key}"
  let review_id = "result-review-native-wenyu-\{key}"
  let import_link = "- Native work: `\{identity.work_id}`\n" +
    "- Request digest: `\{identity.request_digest}`\n" +
    "- Payload digest: `\{identity.payload_digest}`\n"
  let pages = [
    "synthesis/observations.md", "synthesis/evidence.md", "reviews/pending.md", "history/journey.md",
    "history/debug-journal.md", "SUMMARY.md", "index.md",
  ]
  let event = native_wenyu_event(root, result, evidence_id)
  let event_path = "events/native-wenyu-\{key}.json"
  let outcome : PersistResultOutcome = {
    log_path: root + "/wiki/log.md",
    updated_pages: pages,
    review_queued: true,
    notify_town: true,
    evidence_id,
    executable_event_path: event_path,
    latest_executable_event_path: "events/latest.json",
    executable_event: event,
  }
  let writes : Array[NativeWenyuWrite] = []
  native_wenyu_write_intent(
    root,
    writes,
    "wiki/synthesis/observations.md",
    "# Observations\n\n## Results\n\n_None yet._\n",
    current => {
      append_section_block(
        current,
        "## Results",
        persisted_result_block(result) + import_link + "\n",
      )
    },
  )
  let artifact_lines = result.artifacts.map(path => "  - `\{path}`\n").join("")
  let evidence = "### \{evidence_id}\n\n" +
    "- Task ID: `\{result.result_id}`\n" +
    "- Status: `pending-review`\n" +
    "- Summary: \{keeper_compact_text(result.summary)}\n" +
    import_link +
    "- Artifacts:\n" +
    artifact_lines +
    "\n"
  native_wenyu_write_intent(
    root,
    writes,
    "wiki/synthesis/evidence.md",
    "# Evidence\n\n## Records\n\n_None yet._\n",
    current => append_section_block(current, "## Records", evidence),
  )
  let review = "### Result review | \{result.result_id}\n\n" +
    "- Review ID: `\{review_id}`\n" +
    "- Result page: [\{result.result_id}](../synthesis/observations.md)\n" +
    "- Evidence ID: `\{evidence_id}`\n" +
    "- Merge policy: `promote-durable`\n" +
    "- Status: `pending`\n" +
    "- Reason: native Wenyu result requires human product review\n" +
    "- Candidate insight: \{clamp_excerpt(result.summary)}\n" +
    import_link +
    "\n"
  native_wenyu_write_intent(
    root,
    writes,
    "wiki/reviews/pending.md",
    "# Pending Review\n\n## Items\n\n_None yet._\n",
    current => append_section_block(current, "## Items", review),
  )
  let journey = "### native-wenyu-\{key}\n\n" +
    "- Stage: `native-wenyu`\n- Status: `pending-review`\n" +
    "- Summary: \{clamp_excerpt(result.summary)}\n" +
    "- Evidence: `\{evidence_id}`\n" +
    import_link +
    "\n"
  native_wenyu_write_intent(
    root,
    writes,
    "wiki/history/journey.md",
    journey_text(),
    current => append_section_block(current, "## Entries", journey),
  )
  let debug = "### native-wenyu-\{key}\n\n" +
    "- Stage: `native-wenyu`\n" +
    "- Summary: \{result.summary}\n" +
    "- Evidence: `\{evidence_id}`\n" +
    "- Review queued: `true`\n- Notify town: `true`\n" +
    import_link +
    "- Reported artifacts:\n" +
    artifact_lines +
    "\n"
  native_wenyu_write_intent(
    root,
    writes,
    "wiki/history/debug-journal.md",
    debug_journal_text(),
    current => append_section_block(current, "## Entries", debug),
  )
  let links = [
    ("Observations", "synthesis/observations.md"),
    ("Evidence", "synthesis/evidence.md"),
    ("Pending Review", "reviews/pending.md"),
    ("Journey", "history/journey.md"),
    ("Debug Journal", "history/debug-journal.md"),
  ]
  native_wenyu_write_intent(root, writes, "wiki/SUMMARY.md", "# Summary\n\n", current => {
    let mut next = current
    for pair in links {
      let (title, page) = pair
      if !next.contains("(./\{page})") && !next.contains("(\{page})") {
        next += "\n- [\{title}](./\{page})\n"
      }
    }
    next
  })
  native_wenyu_write_intent(
    root,
    writes,
    "wiki/index.md",
    "# Book\n\n## Core Pages\n\n",
    current => {
      let mut next = current
      for pair in links {
        let (title, page) = pair
        if !next.contains("(./\{page})") && !next.contains("(\{page})") {
          next = append_section_block(
            next,
            "## Core Pages",
            "- [\{title}](./\{page}): native Wenyu results and human review\n",
          )
        }
      }
      next
    },
  )
  let log = "## [native-wenyu-\{key}] persist | \{result.result_id}\n\n" +
    "- summary: \{result.summary}\n- notify_town: `true`\n" +
    import_link +
    format_related_log_lines(pages)
  native_wenyu_write_intent(root, writes, "wiki/log.md", "# Log\n", current => {
    current + "\n\n" + log
  })
  let event_text = event.to_json().stringify(indent=2)
  native_wenyu_write_intent(root, writes, event_path, "", _ => event_text)
  native_wenyu_write_intent(root, writes, "events/latest.json", "", _ => {
    return event_text
  })
  {
    contract: "moonbook.native-wenyu-intent.v1",
    root,
    identity,
    payload_text,
    outcome,
    writes,
  }
}
