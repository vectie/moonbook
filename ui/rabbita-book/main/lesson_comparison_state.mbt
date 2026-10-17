///|
/// Local comparative reuse controller. Inputs are operator-supplied outputs, not
/// model runs. The existing host rechecks exact lesson currentness on selection.
extern "js" fn lesson_comparison_transition_json(text : String) -> String =
  #| text => {
  #|   const empty = () => ({revision:0, query:null, input:'', checks:'', entries:[], preview:null});
  #|   const canonical = value => JSON.stringify(value, (key, v) => v && typeof v === 'object' && !Array.isArray(v) ? Object.fromEntries(Object.keys(v).sort().map(k => [k, v[k]])) : v);
  #|   const same = (a, b) => canonical(a) === canonical(b);
  #|   const string = v => typeof v === 'string' && !!v.trim();
  #|   const reference = r => r && ['record_id','record_version','record_digest'].every(k => string(r[k]));
  #|   const condition = c => c && string(c.key) && string(c.value);
  #|   const label = v => typeof v === 'string' ? v : null;
  #|   let state = empty();
  #|   try {
  #|     const request = JSON.parse(text);
  #|     state = request.state || empty();
  #|     if (!Number.isSafeInteger(state.revision) || state.revision < 0 || !Array.isArray(state.entries) || state.entries.length > 4 || typeof state.input !== 'string' || typeof state.checks !== 'string') throw Error('Comparison draft is unreadable. Clear it and start again.');
  #|     const action = request.action || {kind:'inspect'}, context = request.context;
  #|     if (action.kind !== 'inspect' && action.expected_revision !== state.revision) return JSON.stringify({state,error:'This comparison changed. Use its current controls.'});
  #|     if (action.kind !== 'inspect' && request.pending) return JSON.stringify({state,error:'Wait for the current lesson request before changing the comparison.'});
  #|     if (action.kind === 'clear') return JSON.stringify({state:{...empty(),revision:state.revision+1},available:[],current:false,preview_current:false});
  #|     if (action.kind === 'remove') return JSON.stringify({state:{...state,entries:state.entries.filter(v => !same(v.lesson.reference,action.reference)),revision:state.revision+1,preview:null},available:[],current:false,preview_current:false});
  #|     const available = [];
  #|     if (context) {
  #|       const {query, retrieval} = context;
  #|       if (!query || query.contract_version !== 'moonbook.outcome-lesson-query.v1' || !reference(query.target_task) || !Array.isArray(query.conditions) || !query.conditions.every(condition) || new Set(query.conditions.map(c => c.key)).size !== query.conditions.length || !retrieval || retrieval.contract_version !== 'moonbook.outcome-lesson-retrieval.v1' || !same(query, retrieval.query) || retrieval.activation_authorized !== false || retrieval.external_side_effects_applied !== false || !Array.isArray(retrieval.matches)) throw Error('Find reviewed lessons again for this exact task and conditions.');
  #|       for (const item of retrieval.matches) {
  #|         const record = item.lesson, review = item.review, lesson = record && record.payload && record.payload.outcome_lesson;
  #|         if (!record || !lesson || !['outcome_lesson.v1','outcome_lesson.v2','outcome_lesson.rehearsed.v1'].includes(record.payload.candidate_schema) || !reference(record.record) || !string(record.title) || !string(lesson.guidance) || !string(lesson.lesson_id) || label(record.stage) !== 'DeliverableAcceptance' || !review || label(review.stage) !== 'DeliverableAcceptance' || !same(review.subject, record.record) || review.disposition !== 'Accept' || review.requested !== 'Accept' || review.review_complete !== true || label(review.reviewer_kind) !== 'Human' || !review.reviewer || review.reviewer.authorized !== true || !string(review.reviewer.reviewer_id) || review.side_effects_applied !== false || !Array.isArray(review.issues) || review.issues.length || !reference(review.receipt) || (item.selection_review !== null && !reference(item.selection_review))) throw Error('A comparison candidate has no complete named-human acceptance. Reload lessons.');
  #|         if (!Array.isArray(lesson.applicability) || !lesson.applicability.length || !Array.isArray(lesson.invalidation) || ![...lesson.applicability,...lesson.invalidation].every(condition) || !lesson.applicability.every(c => query.conditions.some(q => same(c,q))) || lesson.invalidation.some(c => query.conditions.some(q => same(c,q)))) throw Error('A comparison candidate is outside this task scope or is invalidated. Reload lessons.');
  #|         if (![lesson.outcome, lesson.assessment, lesson.assessment_review].every(reference)) throw Error('A comparison candidate has incomplete source references. Reload lessons.');
  #|         const entry = {reference:record.record, lesson_id:lesson.lesson_id, title:record.title, guidance:lesson.guidance, applicability:lesson.applicability, invalidation:lesson.invalidation, reviewer:review.reviewer.reviewer_id, review:review.receipt, selection_review:item.selection_review, source:{outcome:lesson.outcome, assessment:lesson.assessment, assessment_review:lesson.assessment_review}};
  #|         if (available.some(v => same(v.reference,entry.reference))) throw Error('Duplicate exact lesson result. Reload lessons.');
  #|         available.push(entry);
  #|       }
  #|     }
  #|     const current = !!context && same(state.query, context.query) && state.entries.every(entry => available.some(v => same(v, entry.lesson)));
  #|     const fingerprint = () => canonical({query:state.query,input:state.input,checks:state.checks,entries:state.entries});
  #|     const previewCurrent = current && state.preview && state.preview.binding === fingerprint();
  #|     const respond = (extra={}) => { const fresh = !!context && same(state.query, context.query) && state.entries.every(entry => available.some(v => same(v, entry.lesson))); return JSON.stringify({state, available, current:fresh, preview_current:!!(fresh && state.preview && state.preview.binding === fingerprint()),...extra}); };
  #|     if (action.kind === 'inspect') return respond();
  #|     const change = fields => {state = {...state,...fields,revision:state.revision+1,preview:null};};
  #|     if (action.kind === 'add') {
  #|       const candidate = available.find(v => same(v.reference,action.reference));
  #|       if (!candidate) throw Error('Choose an exact reviewed lesson in the current task results.');
  #|       if (state.entries.length && !current) throw Error('The task or reviewed lessons changed. Clear this comparison before choosing fresh versions.');
  #|       if (state.entries.some(v => same(v.lesson.reference,action.reference))) return respond();
  #|       if (state.entries.length === 4) throw Error('Compare at most four reviewed approaches at once. Remove one first.');
  #|       change({query:context.query,entries:[...state.entries,{lesson:candidate,output:''}]});
  #|       return respond();
  #|     }
  #|     if (!current) throw Error('This comparison is stale. Find lessons for the current task, then clear and rebuild the shortlist if its versions changed.');
  #|     if (action.kind === 'edit') {
  #|       if (typeof action.value !== 'string' || action.value.length > (action.field === 'checks' ? 10260 : 16384)) throw Error('Comparison text exceeds its limit; nothing was truncated.');
  #|       if (action.field === 'input' || action.field === 'checks') change({[action.field]:action.value});
  #|       else if (action.field === 'output') {
  #|         if (!state.entries.some(v => same(v.lesson.reference,action.reference))) throw Error('That lesson is no longer in this comparison.');
  #|         change({entries:state.entries.map(v => same(v.lesson.reference,action.reference) ? {...v,output:action.value} : v)});
  #|       } else throw Error('Unknown comparison field.');
  #|       return respond();
  #|     }
  #|     if (action.kind === 'compare') {
  #|       if (state.entries.length < 2 || state.entries.length > 4) throw Error('Shortlist two to four reviewed lessons before comparing.');
  #|       if (!string(state.input) || state.input.length > 16384 || state.entries.some(v => !string(v.output) || v.output.length > 16384)) throw Error('Supply one fixed task/example and an output for every shortlisted lesson, at most 16384 characters each.');
  #|       const checks = state.checks.split('\n').map(v => v.trim()).filter(Boolean);
  #|       if (checks.length < 1 || checks.length > 20 || checks.some(v => v.length > 512) || new Set(checks).size !== checks.length) throw Error('Use 1–20 distinct nonblank literal checks, at most 512 characters each.');
  #|       const rows = checks.map(text => ({text,passed:state.entries.map(v => v.output.includes(text))}));
  #|       const scores = state.entries.map((entry,i) => ({reference:entry.lesson.reference,passed:rows.filter(row => row.passed[i]).length,total:checks.length}));
  #|       const allPass = scores.filter(v => v.passed === v.total).length;
  #|       state = {...state,revision:state.revision+1,preview:{binding:fingerprint(),rows,scores,all_pass_count:allPass,evaluation_kind:'operator_supplied_comparative_reuse',model_executed:false,activation_authorized:false}};
  #|       return JSON.stringify({state,available,current:true,preview_current:true});
  #|     }
  #|     if (action.kind === 'use') {
  #|       if (!previewCurrent) throw Error('Compare these exact outputs and checks again before choosing.');
  #|       const score = state.preview.scores.find(v => same(v.reference,action.reference));
  #|       const selected = state.entries.find(v => same(v.lesson.reference,action.reference)), checks = state.checks.split('\n').map(v => v.trim()).filter(Boolean);
  #|       if (!score || score.passed !== score.total || !selected || !checks.length || !checks.every(text => selected.output.includes(text))) throw Error('This supplied output does not pass every check. Revise it and compare again, or leave the comparison to reconsider the task.');
  #|       return respond({selection:action.reference});
  #|     }
  #|     throw Error('Unknown comparison action.');
  #|   } catch (error) { return JSON.stringify({state,available:[],current:false,preview_current:false,error:String(error.message || error)}); }
  #| }

///|
fn initial_lesson_comparison() -> Json {
  {
    "revision": 0,
    "query": Json::null(),
    "input": "",
    "checks": "",
    "entries": [],
    "preview": Json::null(),
  }
}

///|
fn lesson_comparison_context(state : OutcomeLessonWorkspace) -> Json {
  match (lesson_ui_payload(state, "retrieve"), state.result) {
    (Ok(query), Some(result)) => { "query": query, "retrieval": result }
    _ => Json::null()
  }
}

///|
fn lesson_comparison_transition(
  state : OutcomeLessonWorkspace,
  action : Json,
) -> Json {
  let request : Json = {
    "state": state.comparison,
    "context": lesson_comparison_context(state),
    "action": action,
    "pending": state.pending,
  }
  @json.parse(lesson_comparison_transition_json(request.stringify())) catch {
    _ =>
      {
        "state": state.comparison,
        "error": "Comparison could not be read. Clear it and try again.",
      }
  }
}

///|
fn lesson_comparison_action(
  state : OutcomeLessonWorkspace,
  kind : String,
  reference? : Json = Json::null(),
  field? : String = "",
  value? : String = "",
) -> Json {
  {
    "kind": kind,
    "expected_revision": lesson_task_field(state.comparison, "revision"),
    "reference": reference,
    "field": field,
    "value": value,
  }
}

///|
fn lesson_comparison_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  action : Json,
) -> (@rabbita.Cmd, Model) {
  let result = lesson_comparison_transition(model.outcome_lessons, action)
  if result is { "error": String(error), .. } {
    return (
      @rabbita.none,
      { ..model, outcome_lessons: { ..model.outcome_lessons, notice: error, }, },
    )
  }
  if result is { "selection": reference, .. } {
    let reference : BookkeeperRecordReference = @json.from_json(reference) catch {
      _ => return (@rabbita.none, model)
    }
    // Keep destination confirmation, exact host revalidation, bounded wire and
    // Proj acknowledgement in the existing selection path. Comparison data is
    // intentionally not exported as accepted knowledge or evaluation evidence.
    return task_guidance_update(emit, model, Use(reference))
  }
  (
    @rabbita.none,
    {
      ..model,
      outcome_lessons: {
        ..model.outcome_lessons,
        comparison: lesson_task_field(result, "state"),
        notice: "",
      },
    },
  )
}
