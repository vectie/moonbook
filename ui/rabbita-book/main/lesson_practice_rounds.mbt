///|
priv struct LessonPracticeRound {
  learner : String
  teaching : LessonTeachingBrief
  observations : Array[LessonPracticeObservation]
} derive(Debug, Eq, ToJson, FromJson)

///|
fn lesson_practice_rounds(
  session : LessonPracticeSession,
) -> Array[LessonPracticeRound] {
  session.previous_rounds +
  [
    {
      learner: session.learner,
      teaching: session.teaching,
      observations: session.observations,
    },
  ]
}

///|
fn lesson_practice_round_validate(
  round : LessonPracticeRound,
) -> Result[Unit, String] {
  guard round.learner.length() <= 256 &&
    !round.teaching.items.is_empty() &&
    !round.teaching.objective.is_blank() &&
    round.teaching.items.all(item => !item.exercise.is_blank()) &&
    round.observations.length() == round.teaching.items.length() &&
    round.observations.all(item => {
      [item.before, item.after, item.feedback, item.next_practice].all(value => {
        value.length() <= 16384
      })
    }) else {
    return Err(
      "Every round needs its fixed objective, nonblank tasks and one observation row per task. Each observation field may contain at most 16384 characters. Nothing was truncated.",
    )
  }
  match lesson_teaching_decode(ToJson::to_json(round.teaching).stringify()) {
    Ok(_) => Ok(())
    Err(error) => Err(error)
  }
}

///|
fn lesson_practice_next_ready(
  state : LessonTeachingBriefWorkspace,
  browser : LessonBrowserWorkspace,
) -> Bool {
  state.practice.session is Some(session) &&
  session.previous_rounds.length() < 11 &&
  session.observations.any(item => !item.before.is_blank()) &&
  lesson_teaching_ready(state, browser) &&
  state.draft.items.all(item => !item.exercise.is_blank())
}
