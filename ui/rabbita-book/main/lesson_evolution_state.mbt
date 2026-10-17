///|
priv struct LessonEvolutionWorkspace {
  baseline : BookkeeperRecordReference?
  target : BookkeeperRecordReference?
  revision : Int
  downloading : Bool
  notice : String
}

///|
priv enum LessonEvolutionMsg {
  Choose(String, BookkeeperRecordReference)
  Swap
  Download(Bool)
  Downloaded(Result[String, String])
}

///|
fn initial_lesson_evolution() -> LessonEvolutionWorkspace {
  { baseline: None, target: None, revision: 0, downloading: false, notice: "", }
}

///|
fn lesson_evolution_selected(
  workspace : OutcomeLessonWorkspace,
) -> Result[Json, String] {
  guard !workspace.pending &&
    workspace.history.read_ready &&
    workspace.history.data is Some(history) else {
    return Err(
      "Refresh lesson history successfully before comparing its saved versions.",
    )
  }
  guard workspace.evolution.baseline is Some(baseline) &&
    workspace.evolution.target is Some(target) else {
    return Err("Choose a baseline and a target from the saved versions below.")
  }
  lesson_evolution_report(history, baseline, target)
}

///|
fn lesson_evolution_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  request : Int,
  revision : Int,
  action : LessonEvolutionMsg,
) -> (@rabbita.Cmd, Model) {
  let workspace = model.outcome_lessons
  let state = workspace.evolution
  guard revision == state.revision else { return (@rabbita.none, model) }
  if action is Downloaded(result) {
    guard state.downloading else { return (@rabbita.none, model) }
    return (
      @rabbita.none,
      {
        ..model,
        outcome_lessons: {
          ..workspace,
          evolution: {
            ..state,
            downloading: false,
            notice: match result {
              Ok(text) => text
              Err(error) =>
                "Download failed: " + error + ". The comparison is still open."
            },
          },
        },
      },
    )
  }
  guard request == workspace.request else { return (@rabbita.none, model) }
  guard !workspace.pending &&
    workspace.history.read_ready &&
    workspace.history.data is Some(history) else {
    return (@rabbita.none, model)
  }
  let next = match action {
    Choose(side, reference) => {
      guard lesson_history_record(history, Some(reference)) is Some(_) else {
        return (@rabbita.none, model)
      }
      match side {
        "baseline" =>
          {
            ..state,
            baseline: Some(reference),
            revision: revision + 1,
            downloading: false,
            notice: "",
          }
        "target" =>
          {
            ..state,
            target: Some(reference),
            revision: revision + 1,
            downloading: false,
            notice: "",
          }
        _ => return (@rabbita.none, model)
      }
    }
    Swap =>
      {
        baseline: state.target,
        target: state.baseline,
        revision: revision + 1,
        downloading: false,
        notice: "",
      }
    Download(html) => {
      guard !state.downloading else { return (@rabbita.none, model) }
      let report = match lesson_evolution_selected(workspace) {
        Ok(report) => report
        Err(error) =>
          return (
            @rabbita.none,
            {
              ..model,
              outcome_lessons: {
                ..workspace,
                evolution: { ..state, notice: error, },
              },
            },
          )
      }
      let text = if html {
        lesson_evolution_html(report)
      } else {
        report.stringify(indent=2) + "\n"
      }
      if !lesson_notebook_fits(text) {
        return (
          @rabbita.none,
          {
            ..model,
            outcome_lessons: {
              ..workspace,
              evolution: {
                ..state,
                notice: "Output exceeds 1 MiB. Nothing was truncated; inspect the comparison in Book.",
              },
            },
          },
        )
      }
      return (
        @rabbita.perform(
          result => {
            emit(
              OutcomeLesson(Evolution(request, revision, Downloaded(result))),
            )
          },
          async fn() noraise {
            let message : String = lesson_evolution_download(text, html)
              .wait()
              .cast() catch {
                error => return Err("\{error}")
              }
            Ok(message)
          },
        ),
        {
          ..model,
          outcome_lessons: {
            ..workspace,
            evolution: {
              ..state,
              downloading: true,
              notice: "Preparing selected comparison download…",
            },
          },
        },
      )
    }
    Downloaded(_) => return (@rabbita.none, model)
  }
  (
    @rabbita.none,
    { ..model, outcome_lessons: { ..workspace, evolution: next, }, },
  )
}

///|
fn lesson_evolution_html(report : Json) -> String {
  "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'\"><title>MoonBook lesson evolution</title><style>body{font:17px/1.55 system-ui,sans-serif;color:#172033;background:#fff;max-width:1100px;margin:2rem auto;padding:0 1rem}section,article{margin:1rem 0;padding:1rem;border:1px solid #94a3b8}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:inherit}h1,h2,h3,h4{line-height:1.2}@media print{body{max-width:none;margin:0}details{display:block}article{break-inside:avoid}}</style></head><body><main><h1>Lesson evolution comparison</h1>" +
  @rabbita.render_to_string(
    @rabbita.static_cell(lesson_evolution_report_view(report)),
  ) +
  "<footer>Read-only captured comparison. No scripts, network resources, review, version selection or activation. Reopen Book for current history.</footer></main></body></html>\n"
}

///|
extern "js" fn lesson_evolution_download(
  text : String,
  html : Bool,
) -> @js.Promise =
  #| async (text, html) => {
  #|   const blob = new Blob([text], {type:html?'text/html;charset=utf-8':'application/json;charset=utf-8'});
  #|   const url = URL.createObjectURL(blob); let link;
  #|   try { link=document.createElement('a'); link.href=url; link.download=html?'moonbook-lesson-evolution.html':'moonbook-lesson-evolution.json'; document.body.appendChild(link); link.click(); }
  #|   finally { try { link?.remove(); } finally { setTimeout(()=>URL.revokeObjectURL(url),1000); } }
  #|   return 'Lesson evolution download requested. Check browser downloads. This captured comparison does not establish current guidance or authority.';
  #| }
