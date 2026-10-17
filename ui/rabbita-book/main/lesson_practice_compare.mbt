///|
fn lesson_practice_matching_rounds(
  session : LessonPracticeSession,
  item : LessonTeachingItem,
) -> Array[(Int, LessonTeachingItem, LessonPracticeObservation, String)] {
  let matches = []
  for round_index, round in lesson_practice_rounds(session) {
    for index, candidate in round.teaching.items {
      if lesson_practice_same_source_family(candidate.snapshot, item.snapshot) &&
        candidate.exercise == item.exercise {
        matches.push(
          (round_index + 1, candidate, round.observations[index], round.learner),
        )
      }
    }
  }
  matches
}

///|
fn lesson_practice_comparison_view(
  session : LessonPracticeSession,
) -> @rabbita.Html {
  @html.details([
    @html.summary("Compare the same practice task across rounds"),
    @html.p(
      "Matches require the same source lesson family, exact outcome and assessment references, and exact task text. Different version records can be compared, with their captured guidance and reviews retained. This is not proof of lineage, factual correctness or learning; imported observations remain operator reports.",
    ),
    @html.div(
      session.teaching.items.map(item => {
        let matches = lesson_practice_matching_rounds(session, item)
        @html.article([
          @html.h4(item.snapshot.title),
          @html.pre(style=["white-space:pre-wrap"], item.exercise),
          if matches.length() < 2 {
            @html.p("No earlier round has this exact lesson/task pair.")
          } else {
            @html.div(
              style=["display:flex", "flex-wrap:wrap", "gap:12px"],
              matches.map(entry => {
                let (number, captured, observation, learner) = entry
                @html.section(
                  style=[
                    "flex:1 1 280px", "min-width:0", "border:1px solid #64748b",
                    "padding:12px",
                  ],
                  [
                    @html.h4("Round " + number.to_string()),
                    @html.p("Learner / session: " + learner),
                    @html.p(
                      "Captured version: " +
                      captured.snapshot.reference.record_version +
                      " · " +
                      captured.snapshot.reference.record_id,
                    ),
                    @html.p(
                      if captured.snapshot == item.snapshot {
                        "Same lesson capture as current round."
                      } else {
                        "Different lesson capture from current round; compare guidance before interpreting responses."
                      },
                    ),
                    @html.details([
                      @html.summary("Inspect captured guidance and identity"),
                      @html.pre(
                        style=["white-space:pre-wrap", "overflow-wrap:anywhere"],
                        ToJson::to_json(captured.snapshot).stringify(indent=2),
                      ),
                    ]),
                    @html.div(
                      [
                        ("First response", observation.before),
                        ("After feedback", observation.after),
                        ("Feedback / observed difference", observation.feedback),
                        ("Next practice", observation.next_practice),
                      ].map(pair => {
                        let (label, value) = pair
                        @html.div([
                          @html.p(label),
                          @html.pre(
                            style=[
                              "white-space:pre-wrap", "overflow-wrap:anywhere",
                            ],
                            if value.is_blank() {
                              "Not recorded."
                            } else {
                              value
                            },
                          ),
                        ])
                      }),
                    ),
                  ],
                )
              }),
            )
          },
        ])
      }),
    ),
  ])
}
