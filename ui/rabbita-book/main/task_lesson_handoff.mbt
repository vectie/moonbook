///|
fn lesson_task_field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn lesson_task_text(value : Json, key : String) -> String {
  match lesson_task_field(value, key) {
    String(text) => text
    _ => ""
  }
}

///|
fn lesson_task_sources(value : Json) -> Array[Json] {
  match lesson_task_field(value, "sources") {
    Array(values) => values
    _ => []
  }
}

///|
fn lesson_use_received_task(
  state : OutcomeLessonWorkspace,
  index : Int,
) -> OutcomeLessonWorkspace {
  guard !state.pending && state.handoff is Some(readback) else { return state }
  let handoff = lesson_task_field(readback, "handoff")
  let task = lesson_task_field(handoff, "task")
  let fields = state.fields.copy()
  fields["task-id"] = lesson_task_text(task, "record_id")
  fields["task-version"] = lesson_task_text(task, "record_version")
  fields["task-digest"] = lesson_task_text(task, "record_digest")
  let project = lesson_task_text(
    lesson_task_field(readback, "task_context"),
    "project_id",
  )
  fields["query-customer"] = ""
  fields["query-decision"] = ""
  fields["query-extra"] = if project.is_empty() {
    ""
  } else {
    "project_id=" + project
  }
  let source = lesson_task_sources(readback).get(index)
  if index >= 0 && source is None {
    return state
  }
  if source is Some(source) {
    if state.source == Some(source) && !state.lesson_id.is_blank() {
      return state
    }
    // Explicitly starting this lesson replaces the authoring draft, never a
    // persisted lesson. Query context and authored lesson state stay separate.
    for key in ["title", "guidance", "customer", "decision", "extra", "invalid"] {
      fields[key] = ""
    }
    fields["version"] = "1"
    return {
      ..state,
      fields,
      source: Some(source),
      source_label: lesson_task_text(source, "title") +
      " · " +
      lesson_task_text(lesson_task_field(source, "assessment"), "record_id"),
      lesson_id: "lesson-" + bookkeeper_nonce(),
      recorded_at: bookkeeper_unix_seconds(),
      result: None,
      request: state.request + 1,
      notice: "Exact task context and reviewed outcome selected. Write your own lesson and conditions; saving still requires the existing review process.",
    }
  }
  {
    ..state,
    fields,
    result: None,
    request: state.request + 1,
    notice: "Exact task ID, version and digest loaded for retrieval. Your existing lesson draft was kept. Add truthful task conditions before finding lessons.",
  }
}

///|
fn lesson_task_handoff_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  message : OutcomeLessonMsg,
) -> (@rabbita.Cmd, Model) {
  let state = model.outcome_lessons
  match message {
    ImportTask | ReceiveTask => {
      if state.pending {
        return (@rabbita.none, model)
      }
      let direct = message is ReceiveTask
      let request = state.request + 1
      (
        @rabbita.perform(
          result => emit(OutcomeLesson(TaskImported(request, direct, result))),
          async fn() noraise {
            let promise = if direct {
              lesson_receive_task()
            } else {
              lesson_pick_task_file()
            }
            let text : String = promise.wait().cast() catch {
                error => return Err("\{error}")
              }
            if text.is_empty() {
              Err(
                "No handoff received. Retry, or import the file exported by Proj.",
              )
            } else {
              Ok(text)
            }
          },
        ),
        {
          ..model,
          outcome_lessons: {
            ..state,
            request,
            pending: true,
            handoff: None,
            task_guidance: initial_task_guidance_workspace(),
            outcome_review: {
              ..initial_outcome_review_workspace(),
              request: state.outcome_review.request + 1,
            },
            saved_return: initial_saved_lesson_return(),
            notice: if direct {
              "Receiving the task selected in Proj…"
            } else {
              "Choose the task handoff JSON exported by Proj…"
            },
          },
        },
      )
    }
    TaskImported(request, direct, result) => {
      if !state.pending || state.request != request {
        return (@rabbita.none, model)
      }
      let payload = match result {
        Ok(text) =>
          @json.parse(text) catch {
            _ =>
              return (
                @rabbita.none,
                {
                  ..model,
                  outcome_lessons: {
                    ..state,
                    pending: false,
                    notice: "The handoff file is not readable JSON. Existing draft kept.",
                  },
                },
              )
          }
        Err(error) =>
          return (
            @rabbita.none,
            {
              ..model,
              outcome_lessons: { ..state, pending: false, notice: error, },
            },
          )
      }
      (
        @rabbita.perform(
          result => emit(OutcomeLesson(TaskResolved(request, direct, result))),
          async fn() noraise { post_outcome_lesson("task-handoff", payload) },
        ),
        {
          ..model,
          outcome_lessons: {
            ..state,
            notice: "Checking exact task/report bytes and existing reviewed outcomes in this Book…",
          },
        },
      )
    }
    TaskResolved(request, direct, result) => {
      if !state.pending || state.request != request {
        return (@rabbita.none, model)
      }
      match result {
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              outcome_lessons: {
                ..state,
                pending: false,
                notice: "Task handoff was not accepted: " +
                error +
                ". Existing draft kept.",
              },
            },
          )
        Ok(readback) =>
          (
            if direct {
              @cmd.custom_cmd(_ => {
                lesson_send_task_readback(
                  lesson_task_sender_receipt(readback).stringify(),
                )
              })
            } else {
              @rabbita.none
            },
            {
              ..model,
              outcome_lessons: {
                ..state,
                pending: false,
                handoff: Some(readback),
                saved_return: saved_lesson_return_received(
                  state.saved_return,
                  readback,
                  if direct {
                    lesson_requested_saved_reference()
                  } else {
                    ""
                  },
                  bookkeeper_unix_seconds(),
                ),
                notice: "Exact task and report read back. Inspect them below and choose whether to use the task or start a lesson. Nothing was saved or accepted.",
              },
            },
          )
      }
    }
    UseTask(index) =>
      (
        @rabbita.none,
        { ..model, outcome_lessons: lesson_use_received_task(state, index), },
      )
    _ => (@rabbita.none, model)
  }
}

///|
fn lesson_task_handoff_view(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.outcome_lessons
  @html.section(id="task-lesson-handoff", style=["display:grid", "gap:10px"], [
    @html.h4("Bring an accepted task from Proj"),
    @html.p(
      "Choose Prepare lesson in Proj. Receive its direct handoff here, or import the exported file. IDs and digests are read from the exact captured task/report; they are not proof of customer acceptance.",
    ),
    @html.p(
      if lesson_incoming_origin().is_empty() {
        "For a direct transfer, open this Book from Proj first. File import works independently."
      } else {
        "Receive from " +
        lesson_incoming_origin() +
        " and return only the exact binding receipt and matching-state label to that page."
      },
    ),
    @html.button(
      disabled=state.pending || lesson_incoming_origin().is_empty(),
      on_click=emit(OutcomeLesson(ReceiveTask)),
      "Receive task from Proj",
    ),
    @html.button(
      disabled=state.pending,
      on_click=emit(OutcomeLesson(ImportTask)),
      "Import Proj task handoff file",
    ),
    match state.handoff {
      None => @html.nothing
      Some(readback) => {
        let handoff = lesson_task_field(readback, "handoff")
        let task = lesson_task_field(handoff, "task")
        let report = lesson_task_field(handoff, "report")
        let context = lesson_task_field(readback, "task_context")
        let accepted = lesson_task_field(context, "acceptance_receipt")
        let sources = lesson_task_sources(readback)
        @html.div(style=["display:grid", "gap:8px", "overflow-wrap:anywhere"], [
          @html.strong(
            "Task · " +
            lesson_task_text(task, "record_id") +
            " @ " +
            lesson_task_text(task, "record_version"),
          ),
          @html.p(
            "Accepted report · " +
            lesson_task_text(report, "record_id") +
            " @ " +
            lesson_task_text(report, "record_version"),
          ),
          @html.p(lesson_task_text(context, "title")),
          @html.p(
            lesson_task_text(
              lesson_task_field(readback, "report_context"),
              "summary",
            ),
          ),
          @html.p(
            "Internal reviewer · " +
            lesson_task_text(accepted, "actor_id") +
            " · event " +
            lesson_task_text(accepted, "event_id"),
          ),
          outcome_review_view(emit, model, readback),
          @html.details([
            @html.summary("Exact captured binding and source context"),
            @html.p("Task digest · " + lesson_task_text(task, "record_digest")),
            @html.p(
              "Report digest · " + lesson_task_text(report, "record_digest"),
            ),
            @html.pre(
              style=["white-space:pre-wrap"],
              lesson_task_field(context, "source_context").stringify(indent=2),
            ),
          ]),
          @html.button(
            disabled=state.pending,
            on_click=emit(OutcomeLesson(UseTask(-1))),
            "Use task for lesson retrieval · keep current draft",
          ),
          if sources.is_empty() {
            @html.p(
              "No reviewed outcome assessment is available for this exact task and report yet. Import a completed outcome above, then use the existing named-human review controls. Start lesson appears here after the assessment is accepted.",
            )
          } else {
            @html.div(
              sources.mapi((index, source) => {
                @html.article([
                  @html.strong(lesson_task_text(source, "title")),
                  @html.p(
                    "Outcome · " + lesson_task_text(source, "outcome_summary"),
                  ),
                  @html.p(
                    "Assessment · " +
                    lesson_task_text(source, "assessment_summary"),
                  ),
                  @html.p(
                    "Reviewed by · " +
                    lesson_task_text(
                      lesson_task_field(source, "reviewer"),
                      "reviewer_id",
                    ),
                  ),
                  @html.button(
                    disabled=state.pending,
                    on_click=emit(OutcomeLesson(UseTask(index))),
                    "Start lesson from this assessment · replace unsaved lesson draft",
                  ),
                ])
              }),
            )
          },
        ])
      }
    },
  ])
}

///|
extern "js" fn lesson_pick_task_file() -> @js.Promise =
  #| () => new Promise(resolve => { const input=document.createElement('input'); input.type='file';input.accept='.json,application/json';let ended=false;const done=text=>{if(ended)return;ended=true;clearTimeout(timer);resolve(text);}; const timer=setTimeout(()=>done(''),120000);input.oncancel=()=>done('');input.onchange=async()=>{const file=input.files?.[0];if(!file||file.size>2097152){done('');return;}try{done(await file.text());}catch(_){done('');}};input.click(); })

///|
#external
type LessonReceiverBrowser

///|
extern "js" fn lesson_receiver_browser() -> LessonReceiverBrowser =
  #| () => globalThis

///|
fn lesson_receive_task() -> @js.Promise {
  lesson_receive_task_on(lesson_receiver_browser())
}

///|
extern "js" fn lesson_receive_task_on(
  browser : LessonReceiverBrowser,
) -> @js.Promise =
  #| browser => new Promise(resolve => {
  #|   const params=new URLSearchParams(browser.location.search), nonce=params.get('proj_lesson_nonce'), source=params.get('proj_lesson_source');
  #|   let origin;try{const url=new URL(source);if(!['https:','http:'].includes(url.protocol)||url.origin!==source)throw Error();origin=url.origin;}catch(_){resolve('');return;}
  #|   if(!nonce||!browser.opener){resolve('');return;}const opener=browser.opener;let timer;let ended=false;
  #|   const finish=text=>{if(ended)return;ended=true;browser.clearTimeout(timer);browser.removeEventListener('message',receive);resolve(text);};
  #|   const receive=event=>{if(event.source!==opener||event.origin!==origin||event.data?.nonce!==nonce||event.data?.kind!=='moonproj.lesson-handoff.v1')return;const text=event.data.payload;if(typeof text==='string'&&text.length<=2097152){browser.__moonbookRequestedLesson=JSON.stringify(event.data.selected_lesson??null);finish(text);}};
  #|   browser.addEventListener('message',receive);timer=browser.setTimeout(()=>finish(''),15000);opener.postMessage({kind:'moonbook.lesson-ready.v1',nonce},origin);
  #| })

///|
extern "js" fn lesson_send_task_readback(text : String) =
  #| text => { const params=new URLSearchParams(location.search),nonce=params.get('proj_lesson_nonce'),source=params.get('proj_lesson_source');try{const url=new URL(source);if(window.opener&&nonce&&['http:','https:'].includes(url.protocol)&&url.origin===source)window.opener.postMessage({kind:'moonbook.lesson-readback.v1',nonce,payload:text},url.origin);}catch(_){} }

///|
fn lesson_task_sender_receipt(readback : Json) -> Json {
  {
    "contract_version": "moonbook.task-lesson-readback.v1",
    "handoff": lesson_task_field(readback, "handoff"),
    "state": lesson_task_field(readback, "state"),
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
}

///|
extern "js" fn lesson_incoming_origin() -> String =
  #| () => { try{const params=new URLSearchParams(globalThis.location?.search||'');const source=params.get('proj_lesson_source');const url=new URL(source);return params.get('proj_lesson_nonce')&&['http:','https:'].includes(url.protocol)&&url.origin===source?source:'';}catch(_){return '';} }
