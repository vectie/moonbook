///|
/// Planning search needs no invented target task. Text narrows discovery only;
/// it never proves applicability or authorizes attachment to a task.
pub(all) struct OutcomeLessonBrowseQuery {
  contract_version : String
  text : String
} derive(Debug, Eq, ToJson, FromJson)

///|
fn lesson_browser_matches(
  snapshot : BookkeeperStoreSnapshot,
  record : DurableBookkeeperRecord,
  draft : OutcomeLessonDraft,
  text : String,
) -> Bool {
  let terms = text
    .to_lower()
    .split(" ")
    .filter(term => !term.is_empty())
    .collect()
  let parts = [draft.title, draft.guidance, draft.lesson_id]
  for condition in draft.applicability + draft.invalidation {
    parts.push(condition.key)
    parts.push(condition.value)
  }
  for review in snapshot.reviews {
    if review.subject == record.record &&
      review.reviewer_kind == @bookkeeper.Human {
      parts.push(review.reviewer.reviewer_id)
    }
  }
  let haystack = parts.join("\n").to_lower()
  terms.all(term => haystack.contains(term))
}

///|
fn outcome_lesson_browser(
  snapshot : BookkeeperStoreSnapshot,
  query : OutcomeLessonBrowseQuery,
) -> Json raise {
  if query.contract_version != "moonbook.outcome-lesson-browse-query.v1" {
    fail("lesson browsing requires its versioned query contract")
  }
  if !snapshot.replay_issues.is_empty() {
    fail("Bookkeeper journal has replay issues")
  }
  let lessons : Array[Json] = []
  let exclusions : Array[Json] = []
  let text = query.text
    .trim()
    .to_owned()
    .replace_all(old="\t", new=" ")
    .replace_all(old="\n", new=" ")
    .replace_all(old="\r", new=" ")
  for record in snapshot.records {
    let draft = match outcome_lesson_draft(record) {
      Some(value) => value
      None => continue
    }
    if !lesson_browser_matches(snapshot, record, draft, text) {
      continue
    }
    // Reuse source and acceptance validation. Browsing cannot repair, accept,
    // select, or silently promote a proposed or historical artifact.
    ignore(outcome_lesson_source(snapshot, draft))
    let review = lesson_accepted_review(snapshot, record)
    let (head, current, _) = lesson_version_state(snapshot, draft.lesson_id)
    let reason = if review is None {
      Some("This version has no accepted named-human review")
    } else if current is None {
      Some(
        "Accepted versions exist, but this lesson family has no selected current version; inspect its history",
      )
    } else if current != Some(record.record) {
      Some(
        "This accepted version is historical; inspect the current version or history",
      )
    } else {
      None
    }
    if reason is Some(reason) {
      exclusions.push({
        "lesson": record.to_json(),
        "lesson_id": draft.lesson_id,
        "reason": reason,
      })
      continue
    }
    lessons.push({
      "lesson": record.to_json(),
      "review": review.unwrap().to_json(),
      "selection_review": lesson_nullable_reference(head),
    })
  }
  {
    "contract_version": "moonbook.outcome-lesson-browser.v1",
    "query": query.to_json(),
    "lessons": lessons.to_json(),
    "exclusions": exclusions.to_json(),
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
}

///|
/// Browse the exact currently reviewed lessons before a later task exists.
/// Search covers human text, conditions and reviewer names, not task scope.
/// Other versions remain discoverable as history links, never current cards.
/// An empty store is read without creating journal or projection files.
///
/// ```mbt nocheck
/// async fn planning_lessons(root : String) -> Json {
///   @bookkeeper_store.browse_outcome_lessons(root, {
///     contract_version: "moonbook.outcome-lesson-browse-query.v1",
///     text: "vendor comparison",
///   })
/// }
/// ```
pub async fn browse_outcome_lessons(
  root : String,
  query : OutcomeLessonBrowseQuery,
) -> Json {
  let snapshot = if @fs.exists(journal_root(root)) {
    replay_bookkeeper_store(root)
  } else {
    empty_snapshot()
  }
  outcome_lesson_browser(snapshot, query)
}
