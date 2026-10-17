///|
/// Scope repair is an operator proposal, never a factual finding or acceptance.
extern "js" fn lesson_repair_plan_json(text : String) -> String =
  #| text => {
  #|   try {
  #|     const x = JSON.parse(text), d = x.draft, c = x.context;
  #|     const canonical = v => JSON.stringify(v && typeof v === 'object' ? Array.isArray(v) ? v.map(z => JSON.parse(canonical(z))) : Object.fromEntries(Object.keys(v).sort().map(k => [k,JSON.parse(canonical(v[k]))])) : v);
  #|     const str = v => typeof v === 'string' && !!v.trim();
  #|     const ref = v => v && ['record_id','record_version','record_digest'].every(k => str(v[k]));
  #|     if (!d || !c || !c.eligible || canonical(d.binding) !== canonical(c.binding)) throw Error('The reviewed lesson or history changed. Start a fresh failure case; original guidance is untouched.');
  #|     const f = d.fields, lesson = c.lesson;
  #|     for (const k of ['task-id','task-version','task-digest','observation','evidence','conditions','exclude-key','exclude-value','version']) if (!str(f[k])) throw Error('Complete the exact later task, evidence, observation, conditions, exclusion and new version.');
  #|     if (Object.values(f).some(v => typeof v !== 'string' || v.length > 8192)) throw Error('Each failure-case field is limited to 8192 characters; nothing was truncated.');
  #|     const conditions = f.conditions.split('\n').filter(v => v.trim()).map(line => {const i=line.indexOf('=');if(i<1) throw Error('Use one key=value per task condition.');return {key:line.slice(0,i).trim(),value:line.slice(i+1).trim()};});
  #|     const valid = q => q && str(q.key) && str(q.value) && !/[=\r\n]/.test(q.key) && !/[\r\n]/.test(q.value);
  #|     if (conditions.length > 40 || !conditions.every(valid) || new Set(conditions.map(q=>q.key)).size !== conditions.length) throw Error('Use at most 40 unique, nonblank task conditions.');
  #|     if (!Array.isArray(lesson.applicability) || !lesson.applicability.length || !lesson.applicability.every(valid) || !Array.isArray(lesson.invalidation) || !lesson.invalidation.every(valid)) throw Error('The original lesson scope cannot be safely edited in this form.');
  #|     const matches = q => conditions.some(v => v.key === q.key && v.value === q.value);
  #|     if (!lesson.applicability.every(matches)) throw Error('This case does not meet the original lesson scope. Record it separately rather than repairing this lesson.');
  #|     if (lesson.invalidation.some(matches)) throw Error('The original lesson already excludes this case. No narrowing is needed.');
  #|     const exclusion={key:f['exclude-key'].trim(),value:f['exclude-value'].trim()};
  #|     if (!valid(exclusion) || !matches(exclusion)) throw Error('Choose an exclusion condition actually present in this later task.');
  #|     if (lesson.applicability.some(q=>q.key===exclusion.key && q.value===exclusion.value)) throw Error('That exclusion would disable every applicable task. Choose a distinguishing failure condition.');
  #|     if (lesson.invalidation.some(q=>q.key===exclusion.key)) throw Error('An exclusion already uses that condition name. Use the ordinary revision editor to review a broader change.');
  #|     if (!ref(c.reference) || !Array.isArray(c.versions) || c.versions.includes(f.version)) throw Error('Choose an unused version and reload complete lesson history.');
  #|     const invalidation=[...lesson.invalidation,exclusion];
  #|     const evidence={kind:'operator_reported_counterexample',task:{record_id:f['task-id'],record_version:f['task-version'],record_digest:f['task-digest']},conditions,observation:f.observation,evidence_reference:f.evidence,excluded_condition:exclusion,source_lesson:c.reference,factual_review_complete:false,model_executed:false};
  #|     return JSON.stringify({invalidation:invalidation.map(q=>q.key+'='+q.value).join('\n'),version:f.version,reason:'Narrow scope after an operator-reported later-task failure. Evidence is unverified and requires named-human review.\n'+JSON.stringify(evidence,null,2),exclusion,activation_authorized:false});
  #|   } catch (error) {return JSON.stringify({error:String(error.message||error)});}
  #| }

///|
fn lesson_repair_context(state : OutcomeLessonWorkspace) -> Json {
  guard state.history.data is Some(data) &&
    lesson_history_selected_accepted(state.history) is Some(record) &&
    lesson_record_value(record) is Some(lesson) else {
    return Json::null()
  }
  {
    "eligible": !state.pending &&
    state.history.change is None &&
    data.current == Some(record.record) &&
    lesson_history_can_revise(state.history),
    "binding": {
      "record": ToJson::to_json(record),
      "current": lesson_nullable_reference_json(data.current),
      "head": lesson_nullable_reference_json(data.head),
      "reviews": data.accepted_reviews.to_json(),
      "request": state.request,
    },
    "lesson": lesson,
    "reference": ToJson::to_json(record.record),
    "versions": data.versions.map(v => v.lesson.record.record_version).to_json(),
  }
}

///|
fn lesson_repair_plan(state : OutcomeLessonWorkspace) -> Json {
  let request : Json = {
    "draft": state.repair,
    "context": lesson_repair_context(state),
  }
  @json.parse(lesson_repair_plan_json(request.stringify())) catch {
    _ => { "error": "The failure case could not be read." }
  }
}

///|
fn lesson_repair_update(
  model : Model,
  action : String,
  key : String,
  value : String,
) -> (@rabbita.Cmd, Model) {
  let state = model.outcome_lessons
  if state.pending {
    return (@rabbita.none, model)
  }
  let next = if action == "discard" {
    { ..state, repair: Json::null(), }
  } else if action == "begin" {
    let context = lesson_repair_context(state)
    if lesson_task_field(context, "eligible") != Json::boolean(true) ||
      state.repair != Json::null() {
      return (@rabbita.none, model)
    }
    {
      ..state,
      repair: {
        "binding": lesson_task_field(context, "binding"),
        "fields": {},
        "preview": Json::null(),
      },
    }
  } else if action == "edit" {
    guard state.repair is Object(draft) else { return (@rabbita.none, model) }
    guard lesson_task_field(state.repair, "fields") is Object(fields) else {
      return (@rabbita.none, model)
    }
    let fields = fields.copy()
    fields[key] = Json::string(value)
    let draft = draft.copy()
    draft["fields"] = Json::object(fields)
    draft["preview"] = Json::null()
    { ..state, repair: Json::object(draft), }
  } else if action == "preview" || action == "stage" {
    let plan = lesson_repair_plan(state)
    if plan is { "error": String(error), .. } {
      return (
        @rabbita.none,
        { ..model, outcome_lessons: { ..state, notice: error, }, },
      )
    }
    guard state.repair is Object(draft) else { return (@rabbita.none, model) }
    if action == "preview" {
      let draft = draft.copy()
      draft["preview"] = plan
      {
        ..state,
        repair: Json::object(draft),
        notice: "Preview ready. Inspect the narrower scope before staging a revision.",
      }
    } else {
      if lesson_task_field(state.repair, "preview") != plan {
        return (
          @rabbita.none,
          {
            ..model,
            outcome_lessons: {
              ..state,
              notice: "Preview this exact failure case before staging it.",
            },
          },
        )
      }
      let history = lesson_history_begin(
        state.history,
        "revise",
        bookkeeper_nonce(),
        bookkeeper_unix_seconds(),
      )
      guard history.change is Some(change) else {
        return (@rabbita.none, model)
      }
      let fields = change.fields.copy()
      for key in ["invalidation", "version", "reason"] {
        fields[key] = lesson_task_text(plan, key)
      }
      {
        ..state,
        history: { ..history, change: Some({ ..change, fields, }), },
        repair: Json::null(),
        notice: "Narrowed revision staged below. Review and save it through the existing named-human review workflow; current guidance is unchanged.",
      }
    }
  } else {
    state
  }
  (@rabbita.none, { ..model, outcome_lessons: next, })
}
