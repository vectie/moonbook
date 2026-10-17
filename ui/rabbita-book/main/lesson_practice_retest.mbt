///|
priv struct LessonPracticeRetest {
  revision : Int
  request : Int
  round : Int
  index : Int
  target : Int
  historical : LessonTeachingItem
  selected : LessonTeachingItem
}

///|
fn lesson_practice_same_source_family(
  a : LessonNotebookSnapshot,
  b : LessonNotebookSnapshot,
) -> Bool {
  let canonical = (snapshot : LessonNotebookSnapshot) => {
    snapshot.reference.record_id ==
    "outcome-lesson:" +
    snapshot.lesson_id +
    "@" +
    snapshot.reference.record_version
  }
  a.lesson_id == b.lesson_id &&
  a.outcome == b.outcome &&
  a.assessment == b.assessment &&
  (
    a.reference.record_id == b.reference.record_id ||
    (canonical(a) && canonical(b))
  )
}

///|
fn lesson_practice_retest_target(
  state : LessonTeachingBriefWorkspace,
  browser : LessonBrowserWorkspace,
  historical : LessonTeachingItem,
) -> Int? {
  guard browser.request > state.recheck_after else { return None }
  state.draft.items.search_by(target => {
    lesson_practice_same_source_family(historical.snapshot, target.snapshot) &&
    historical.snapshot.reference.record_version !=
    target.snapshot.reference.record_version &&
    lesson_teaching_matches(target, browser)
  })
}

///|
fn lesson_practice_retest_prepare(
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
  let historical = lesson_practice_rounds(session)[round].teaching.items[index]
  guard lesson_practice_retest_target(state, browser, historical)
    is Some(target) else {
    return {
      ..state,
      notice: "Select and recheck a different current reviewed version of this source lesson family before preparing a retest. No task or observation changed.",
    }
  }
  {
    ..state,
    revision: state.revision + 1,
    practice: {
      ..state.practice,
      retest: Some({
        revision: state.revision + 1,
        request,
        round,
        index,
        target,
        historical,
        selected: state.draft.items[target],
      }),
    },
    notice: "Inspect the exact task replacement and both guidance scopes. Preparing this retest has not changed the teaching brief or practice workbook.",
  }
}

///|
fn lesson_practice_retest_ready(
  state : LessonTeachingBriefWorkspace,
  browser : LessonBrowserWorkspace,
  prepared : LessonPracticeRetest,
) -> Bool {
  guard state.revision == prepared.revision &&
    browser.request == prepared.request &&
    state.practice.session is Some(session) &&
    lesson_practice_search(session, state.practice.search).contains(
      (prepared.round, prepared.index),
    ) &&
    lesson_practice_retest_target(state, browser, prepared.historical) ==
    Some(prepared.target) else {
    return false
  }
  lesson_practice_rounds(session)[prepared.round].teaching.items[prepared.index] ==
  prepared.historical &&
  state.draft.items[prepared.target] == prepared.selected
}

///|
fn lesson_practice_retest_apply(
  state : LessonTeachingBriefWorkspace,
  browser : LessonBrowserWorkspace,
) -> LessonTeachingBriefWorkspace {
  guard state.practice.retest is Some(prepared) &&
    lesson_practice_retest_ready(state, browser, prepared) else {
    return {
      ..state,
      notice: "Retest preview is no longer current. Recheck the selected lesson and preview again; next tasks and observations were kept.",
    }
  }
  let changed = lesson_teaching_reduce(
    state,
    browser,
    state.revision,
    Exercise(prepared.target, prepared.historical.exercise),
  )
  guard changed.draft.items[prepared.target].exercise ==
    prepared.historical.exercise else {
    return changed
  }
  {
    ..changed,
    practice: { ..changed.practice, retest: None, },
    notice: "Exact historical task placed under the selected current guidance. Inspect the teaching brief, then explicitly start the next round. Prior observations stayed unchanged; new response fields start blank.",
  }
}
