///|
fn lesson_practice_reuse_target(
  state : LessonTeachingBriefWorkspace,
  browser : LessonBrowserWorkspace,
  item : LessonTeachingItem,
) -> Int? {
  guard browser.request > state.recheck_after else { return None }
  state.draft.items.search_by(target => {
    target.snapshot == item.snapshot &&
    target.examples == item.examples &&
    target.example_notice == item.example_notice &&
    lesson_teaching_matches(target, browser)
  })
}

///|
fn lesson_practice_reuse_task(
  state : LessonTeachingBriefWorkspace,
  browser : LessonBrowserWorkspace,
  request : Int,
  round : Int,
  index : Int,
) -> LessonTeachingBriefWorkspace {
  guard request == browser.request &&
    state.practice.session is Some(session) &&
    lesson_practice_search(session, state.practice.search).contains(
      (round, index),
    ) else {
    return state
  }
  let item = lesson_practice_rounds(session)[round].teaching.items[index]
  guard lesson_practice_reuse_target(state, browser, item) is Some(target) else {
    return {
      ..state,
      notice: "Select and recheck the exact compatible lesson in the teaching brief before reusing this task. Historical observations remain unchanged.",
    }
  }
  let changed = lesson_teaching_reduce(
    state,
    browser,
    state.revision,
    Exercise(target, item.exercise),
  )
  guard changed.draft.items[target].exercise == item.exercise else {
    return changed
  }
  {
    ..changed,
    notice: "Exact task copied to the selected lesson's teaching brief. Inspect or edit it above, then use the existing next-round control. No observations were copied; no learning improvement is established.",
  }
}
