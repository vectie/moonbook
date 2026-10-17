///|
/// Local literal rehearsal only; authority remains with the existing host review.
extern "js" fn lesson_revision_rehearsal_transition_json(
  text : String,
) -> String =
  #| text => {
  #|   const canonical = v => JSON.stringify(v, (_, x) => x && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.keys(x).sort().map(k => [k,x[k]])) : x);
  #|   const same = (a,b) => canonical(a) === canonical(b);
  #|   const str = v => typeof v === 'string' && !!v.trim();
  #|   const blank = (id,kind) => ({id,kind,name:'',input:'',original:'',revised:'',required:'',forbidden:''});
  #|   // Strict, tab-local CSV intake. It creates operator-authored cases, never evidence or authority.
  #|   const csvHeader=['kind','name','input','original','revised','required','forbidden'];
  #|   const csvLimit=131072;
  #|   const csvInputError=text=>{
  #|     if(typeof text!=='string')return 'CSV input must be text.';
  #|     if(text.length>csvLimit)return 'CSV exceeds 131072 UTF-8 bytes; nothing was truncated.';
  #|     let bytes=0;
  #|     for(let i=0;i<text.length;i++){
  #|       const c=text.charCodeAt(i);
  #|       if(c>=0xd800&&c<=0xdbff){const low=text.charCodeAt(++i);if(!(low>=0xdc00&&low<=0xdfff))return 'CSV contains an unpaired Unicode surrogate.';bytes+=4;}
  #|       else if(c>=0xdc00&&c<=0xdfff)return 'CSV contains an unpaired Unicode surrogate.';
  #|       else bytes+=c<128?1:c<2048?2:3;
  #|       if(bytes>csvLimit)return 'CSV exceeds 131072 UTF-8 bytes; nothing was truncated.';
  #|     }
  #|     return '';
  #|   };
  #|   const parseCsv=text=>{
  #|     const result={rows:[],errors:[],complete:false};
  #|     try {
  #|       const bad=csvInputError(text);if(bad)throw Error(bad);
  #|       if(text.charCodeAt(0)===0xfeff)text=text.slice(1);
  #|       if(!text.length)throw Error('Paste the exact header and 1–6 case records.');
  #|       const records=[];let row=[],field='',mode='start';
  #|       const fieldEnd=()=>{row.push(field);field='';mode='start';if(row.length>7)throw Error('Record '+(records.length+1)+' has more than 7 fields.');};
  #|       const rowEnd=()=>{fieldEnd();records.push(row);row=[];if(records.length>7)throw Error('CSV exceeds 6 case records; the whole import is rejected.');};
  #|       for(let i=0;i<text.length;i++){
  #|         const c=text[i];
  #|         if(c==='\r'&&text[i+1]!=='\n')throw Error('Bare CR at character '+(i+1)+'; use LF or CRLF.');
  #|         if(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(c))throw Error('Unsupported control character at character '+(i+1)+'.');
  #|         if(mode==='quoted'){
  #|           if(c==='"'){if(text[i+1]==='"'){field+='"';i++;}else mode='closed';}
  #|           else {field+=c;if(c==='\r'){field+='\n';i++;}}
  #|         }else if(c===',')fieldEnd();
  #|         else if(c==='\n'||c==='\r'){rowEnd();if(c==='\r')i++;}
  #|         else if(mode==='closed')throw Error('Unexpected text after a closing quote at character '+(i+1)+'.');
  #|         else if(c==='"'){if(mode!=='start')throw Error('Quote inside an unquoted field at character '+(i+1)+'.');mode='quoted';}
  #|         else {field+=c;mode='plain';}
  #|         if(field.length>8192)throw Error('Record '+(records.length+1)+' field exceeds 8192 characters; nothing was truncated.');
  #|       }
  #|       if(mode==='quoted')throw Error('Unterminated quoted field; no cases were imported.');
  #|       if(row.length||field.length||mode!=='start')rowEnd();
  #|       if(!same(records[0],csvHeader))throw Error('Header must be exactly: '+csvHeader.join(','));
  #|       if(records.length===1)throw Error('CSV needs 1–6 case records after the header.');
  #|       result.complete=true;
  #|       records.slice(1).forEach((values,index)=>{
  #|         const record=index+2, item={record,fields:values};result.rows.push(item);
  #|         const error=(field,message)=>result.errors.push({record,field,message});
  #|         if(values.length!==7){error('record','Expected exactly 7 fields, received '+values.length+'.');return;}
  #|         const c=Object.fromEntries(csvHeader.map((key,i)=>[key,values[i]]));item.value=c;
  #|         if(!['useful','adverse'].includes(c.kind))error('kind','Use exactly useful or adverse.');
  #|         for(const key of csvHeader.slice(1)){
  #|           const limit=key==='name'?256:['required','forbidden'].includes(key)?5140:8192;
  #|           if(c[key].length>limit)error(key,'Limit is '+limit+' UTF-16 code units; nothing was truncated.');
  #|           if(['name','input','original'].includes(key)&&!str(c[key]))error(key,'A nonblank value is required.');
  #|           if(key==='revised'&&c[key]!==''&&!str(c[key]))error(key,'Use an empty field for a missing revised output, or supply nonblank text.');
  #|         }
  #|         const fragments=key=>c[key]===''?[]:c[key].split(/\r?\n/);
  #|         const required=fragments('required'),forbidden=fragments('forbidden'),all=[...required,...forbidden];
  #|         if(!all.length||all.length>20)error('checks','Supply 1–20 literal fragments in total.');
  #|         for(const key of ['required','forbidden']){
  #|           const parts=fragments(key);
  #|           if(parts.some(v=>!v.length||v.trim()!==v||v.length>256))error(key,'Each fragment must be nonblank, at most 256 characters, with no surrounding whitespace or empty lines.');
  #|           if(new Set(parts).size!==parts.length)error(key,'Duplicate fragments are ambiguous.');
  #|         }
  #|         if(required.some(r=>forbidden.some(f=>r.includes(f))))error('checks','A required fragment contains a forbidden fragment.');
  #|       });
  #|     }catch(error){result.errors.push({record:null,field:'CSV',message:String(error.message||error)});}
  #|     return result;
  #|   };
  #|   let state = null;
  #|   try {
  #|     const request = JSON.parse(text), action = request.action || {kind:'inspect'}, context = request.context;
  #|     state = request.state ?? null;
  #|     const requestId=request.request_id??0;
  #|     if(action.kind.startsWith('csv_')&&action.expected_request!==requestId)throw Error('A request started after this CSV control was rendered. Preview again with the current controls.');
  #|     const revision = state === null ? null : state.revision;
  #|     if (action.kind !== 'inspect' && (request.pending || !context || action.expected_change !== context.binding.change_id || !str(context.binding.rehearsal_epoch) || action.expected_epoch !== context.binding.rehearsal_epoch || action.expected_revision !== revision)) throw Error('The draft or request changed. Use the current rehearsal controls after the pending request finishes.');
  #|     if (action.kind === 'discard') return JSON.stringify({state:null,current:false,preview_current:false});
  #|     const eligible = !!context && context.eligible === true;
  #|     const retained = request.retained_cases || {items:[],unavailable:[],notice:''};
  #|     const remembered = id => retained.items.find(c=>c.id===id);
  #|     if(action.kind==='reuse' && !remembered(action.case_id)) throw Error('That retained example is unavailable in the exact current lesson.');
  #|     if (state === null && ['begin','reuse'].includes(action.kind)) {
  #|       if (!eligible) throw Error('Rehearse only a revision of the exact currently accepted lesson. Refresh history or start a new current-version revision.');
  #|       state = {revision:0,binding:context.binding,guidance:context.binding.fields.guidance,rationale:context.binding.fields.reason,cases:[blank('case-1','useful'),blank('case-2','adverse')],next_id:3,preview:null,staged:false,intake:{text:'',preview:null,input_error:''}};
  #|     } else if (action.kind === 'begin') return JSON.stringify({state,error:'A rehearsal is already open. Continue it or discard it first.'});
  #|     if (state !== null && (!Number.isSafeInteger(state.revision) || state.revision < 0 || !Number.isSafeInteger(state.next_id) || state.next_id < 3 || typeof state.guidance !== 'string' || typeof state.rationale !== 'string' || typeof state.staged !== 'boolean' || !Array.isArray(state.cases) || state.cases.length < 2 || state.cases.length > 6 || state.cases.some(c => !c || !str(c.id) || !['useful','adverse'].includes(c.kind) || ['name','input','original','revised','required','forbidden'].some(k => typeof c[k] !== 'string')) || new Set(state.cases.map(c => c.id)).size !== state.cases.length)) throw Error('The local rehearsal is malformed. Discard it and start again.');
  #|     const current = () => !!state && eligible && same(state.binding,context.binding);
  #|     const fingerprint = () => canonical({binding:state.binding,guidance:state.guidance,rationale:state.rationale,cases:state.cases});
  #|     const previewCurrent = () => !request.pending && current() && !!state.preview && state.preview.binding === fingerprint();
  #|     const intake=()=>state?.intake||{text:'',preview:null,input_error:''};
  #|     const csvBinding=()=>canonical({rehearsal:fingerprint(),text:intake().text,request_id:requestId});
  #|     const csvCurrent=()=>!request.pending&&current()&&!intake().input_error&&!!intake().preview&&intake().preview.binding===csvBinding();
  #|     const respond = (extra={}) => JSON.stringify({state,current:current(),preview_current:previewCurrent(),csv_preview_current:csvCurrent(),eligible,retained,...extra});
  #|     if (action.kind === 'inspect' || action.kind === 'begin') return respond();
  #|     if (!current()) throw Error('The accepted lesson, current choice, reviews or revision guidance, scope or rationale changed. Your cases are kept; discard this rehearsal and restart from refreshed history.');
  #|     const edit = fields => {state={...state,intake:{...intake(),preview:null},...fields,revision:state.revision+1,preview:null,staged:false};};
  #|     const validatePractice=c=>{
  #|       const p=c?.practice_from;
  #|       if(!p||p.schema!=='moonbook.practice-correction-source.v1'||p.operator_reported!==true||p.model_executed!==false||!same(p.lesson?.reference,context.binding.original)||p.lesson?.guidance!==context.original_guidance||p.exercise!==c.input||p.first_response!==c.original)throw Error('The practice case no longer matches its exact captured lesson, exercise or first response.');
  #|       if(!Number.isSafeInteger(p.observation_index)||p.observation_index<0||p.observation_index>=12||typeof p.learner!=='string'||p.learner.length>256||['objective','exercise','first_response','after_feedback_response','feedback','next_practice'].some(k=>typeof p[k]!=='string'||p[k].length>16384)||!str(p.objective)||!str(p.exercise)||!str(p.first_response))throw Error('The practice source is malformed or exceeds the existing workbook limits.');
  #|       if(!['useful','adverse'].includes(c.kind)||!str(c.name)||c.name.length>256||[c.input,c.original].some(v=>!str(v)||v.length>8192))throw Error('Name the useful/adverse case and keep its exact input and first response within the rehearsal\'s 8192-character limit; nothing was truncated.');
  #|     };
  #|     if(action.kind==='practice_import'){
  #|       const c=action.practice_case;validatePractice(c);
  #|       if(c.revised!=='')throw Error('Observed practice begins with a blank revised-guidance output.');
  #|       if(['required','forbidden'].some(k=>typeof c[k]!=='string'||c[k].length>5140))throw Error('Use at most 5140 characters per literal-check field.');
  #|       const required=c.required.split('\n').map(v=>v.trim()).filter(Boolean),forbidden=c.forbidden.split('\n').map(v=>v.trim()).filter(Boolean),fragments=[...required,...forbidden];
  #|       if(!fragments.length||fragments.length>20||fragments.some(v=>v.length>256)||new Set(required).size!==required.length||new Set(forbidden).size!==forbidden.length)throw Error('Use 1–20 unique literal fragments per case, each at most 256 characters.');
  #|       if(required.some(r=>forbidden.some(f=>r.includes(f))))throw Error('Contradictory checks: a required fragment contains a forbidden fragment.');
  #|       if(state.cases.some(v=>v.input.trim()===c.input.trim()))throw Error('This practice input is already in the rehearsal. Existing cases were kept.');
  #|       const vacant=state.cases.find(v=>v.kind===c.kind&&!v.retained_from&&!v.practice_from&&csvHeader.slice(1).every(k=>v[k]===''));
  #|       if(!vacant&&state.cases.length===6)throw Error('Keep at most six cases. Remove an unwanted case before adding this practice.');
  #|       const value={...c,id:vacant?vacant.id:'case-'+state.next_id};
  #|       edit({cases:vacant?state.cases.map(v=>v.id===vacant.id?value:v):[...state.cases,value],next_id:vacant?state.next_id:state.next_id+1});
  #|       return respond({notice:'Added observed practice as an operator-reported case. Supply a fresh revised-guidance output, compare and stage through the existing named-review lane.'});
  #|     }
  #|     if(action.kind==='csv_edit'||action.kind==='csv_clear'){
  #|       const value=action.kind==='csv_clear'?'':action.value, error=csvInputError(value);
  #|       edit({intake:{text:error?intake().text:value,preview:null,input_error:error?error+' Previous CSV text is kept; paste a valid replacement before previewing.':''}});
  #|       return respond();
  #|     }
  #|     const prepareCsv=()=>{
  #|       const result=parseCsv(intake().text);let nextId=state.next_id;
  #|       const candidates=state.cases.map(c=>({...c})), plan=[];
  #|       for(const row of result.rows){
  #|         if(!row.value)continue;
  #|         const c=row.value;
  #|         if(candidates.some(v=>str(c.input)&&v.input.trim()===c.input.trim()))result.errors.push({record:row.record,field:'input',message:'This input duplicates a CSV or existing rehearsal case.'});
  #|         const vacant=candidates.find(v=>v.kind===c.kind&&!v.retained_from&&csvHeader.slice(1).every(k=>v[k]===''));
  #|         const id=vacant?vacant.id:'case-'+nextId++;
  #|         const value={id,...c};
  #|         if(vacant)candidates[candidates.indexOf(vacant)]=value;else candidates.push(value);
  #|         plan.push({record:row.record,id,operation:vacant?'fill_empty':'append',value});
  #|       }
  #|       if(candidates.length>6)result.errors.push({record:null,field:'capacity',message:'Import would leave '+candidates.length+' cases. Keep at most 6; remove unneeded manual cases first.'});
  #|       return {...result,plan,cases:candidates,next_id:nextId,ready:result.complete&&result.errors.length===0};
  #|     };
  #|     if(action.kind==='csv_preview'){
  #|       if(intake().input_error)throw Error(intake().input_error);
  #|       const result=prepareCsv(), binding=csvBinding();
  #|       edit({intake:{...intake(),preview:{binding,...result}}});return respond();
  #|     }
  #|     if(action.kind==='csv_import'){
  #|       if(!csvCurrent())throw Error('Preview the exact CSV and current rehearsal again before importing.');
  #|       const result=prepareCsv();
  #|       if(!result.ready||!same({binding:csvBinding(),...result},intake().preview))throw Error('CSV has validation errors or the preview changed. Preview again; no cases were imported.');
  #|       edit({cases:result.cases,next_id:result.next_id,intake:{text:intake().text,preview:null,input_error:''}});
  #|       return respond({notice:'Imported '+result.plan.length+' operator-reported cases. Existing authored and retained cases are kept. Edit, compare and stage through the ordinary revision review flow.'});
  #|     }
  #|     if(action.kind==='reuse') {
  #|       const source=remembered(action.case_id);
  #|       if(!same(source.retained_from.lesson,context.binding.original))throw Error('The remembered example belongs to another lesson.');
  #|       if(state.cases.some(c=>c.retained_from&&same(c.retained_from,source.retained_from)))throw Error('This retained example is already in the rehearsal.');
  #|       if(state.cases.some(c=>c.input.trim()===source.input.trim()))throw Error('This example input is already in the rehearsal.');
  #|       const vacant=state.cases.find(c=>c.kind==='useful'&&!c.retained_from&&['name','input','original','revised','required','forbidden'].every(k=>c[k]===''));
  #|       if(!vacant&&state.cases.length===6)throw Error('Keep 2–6 cases, including room for a new adverse case. Remove a case before reusing another.');
  #|       const value={...source,id:vacant?vacant.id:'case-'+state.next_id,kind:'useful',revised:''};
  #|       edit({cases:vacant?state.cases.map(c=>c.id===vacant.id?value:c):[...state.cases,value],next_id:vacant?state.next_id:state.next_id+1});return respond();
  #|     }
  #|     if (action.kind === 'add') {
  #|       if (state.cases.length === 6) throw Error('Keep 2–6 contrasting cases; remove a case before adding another.');
  #|       if (!['useful','adverse'].includes(action.case_kind)) throw Error('Choose a known-useful or adverse case.');
  #|       edit({cases:[...state.cases,blank('case-'+state.next_id,action.case_kind)],next_id:state.next_id+1});return respond();
  #|     }
  #|     if (action.kind === 'remove') {
  #|       if (state.cases.length === 2) throw Error('Keep at least two contrasting cases.');
  #|       if (!state.cases.some(c=>c.id===action.case_id)) throw Error('That case is no longer in this rehearsal.');
  #|       edit({cases:state.cases.filter(c=>c.id!==action.case_id)});return respond();
  #|     }
  #|     if (action.kind === 'edit') {
  #|       const limit = ['required','forbidden'].includes(action.field) ? 5140 : action.field === 'name' ? 256 : 8192;
  #|       if (typeof action.value !== 'string' || action.value.length > limit) throw Error('This field exceeds '+limit+' characters; nothing was truncated.');
  #|       if (['guidance','rationale'].includes(action.field)) edit({[action.field]:action.value});
  #|       else {
  #|         if (!['name','input','original','revised','required','forbidden'].includes(action.field) || !state.cases.some(c=>c.id===action.case_id)) throw Error('Unknown case or field.');
  #|         if(state.cases.find(c=>c.id===action.case_id)?.retained_from && action.field!=='revised')throw Error('Retained input, baseline, name and checks are read-only. Remove the case to author a separate manual example.');
  #|         if(state.cases.find(c=>c.id===action.case_id)?.practice_from && ['input','original'].includes(action.field))throw Error('Practice input and first response preserve the exact observation. Remove the case to author a separate manual example.');
  #|         edit({cases:state.cases.map(c=>c.id===action.case_id ? {...c,[action.field]:action.value} : c)});
  #|       }
  #|       return respond();
  #|     }
  #|     const evaluate = () => {
  #|       if (![state.guidance,state.rationale].every(v=>str(v)&&v.length<=8192)) throw Error('Supply revised guidance and your rationale, at most 8192 characters each.');
  #|       if (state.guidance === context.original_guidance) throw Error('Revise the guidance before rehearsing this correction.');
  #|       if (!state.cases.some(c=>c.kind==='useful') || !state.cases.some(c=>c.kind==='adverse')) throw Error('Include at least one known-useful case and one adverse case.');
  #|       if (new Set(state.cases.map(c=>c.input.trim())).size !== state.cases.length) throw Error('Use distinct contrasting example inputs.');
  #|       const cases = state.cases.map(c => {
  #|         if(c.practice_from)validatePractice(c);
  #|         if(c.retained_from){const source=retained.items.find(item=>same(item.retained_from,c.retained_from));if(!source||c.kind!=='useful'||!['name','input','original','required','forbidden'].every(k=>source[k]===c[k]))throw Error('A remembered baseline changed. Remove it and reuse the exact retained example.');}
  #|         if (!str(c.name) || c.name.length>256 || ![c.input,c.original,c.revised].every(v=>str(v)&&v.length<=8192)) throw Error('Name every case and supply its input and both outputs, at most 8192 characters each.');
  #|         const parse = text => {if(text.length>5140) throw Error('Check text exceeds 5140 characters.');return text.split('\n').map(v=>v.trim()).filter(Boolean);};
  #|         const required=parse(c.required),forbidden=parse(c.forbidden),fragments=[...required,...forbidden];
  #|         if (!fragments.length || fragments.length>20 || fragments.some(v=>v.length>256) || new Set(required).size!==required.length || new Set(forbidden).size!==forbidden.length) throw Error('Use 1–20 unique literal fragments per case, each at most 256 characters.');
  #|         if (required.some(r=>forbidden.some(f=>r.includes(f)))) throw Error('Contradictory checks: a required fragment contains a forbidden fragment.');
  #|         const checks=[...required.map(text=>({kind:'required',text})),...forbidden.map(text=>({kind:'forbidden',text}))].map(check=>({...check,original_passed:check.kind==='required'?c.original.includes(check.text):!c.original.includes(check.text),revised_passed:check.kind==='required'?c.revised.includes(check.text):!c.revised.includes(check.text)}));
  #|         return {...(c.retained_from?{retained_from:c.retained_from}:{}),...(c.practice_from?{practice_from:c.practice_from}:{}),id:c.id,kind:c.kind,name:c.name,input:c.input,original_output:c.original,revised_output:c.revised,checks,original_passed:checks.filter(c=>c.original_passed).length,revised_passed:checks.filter(c=>c.revised_passed).length,total:checks.length,regressions:checks.filter(c=>c.original_passed&&!c.revised_passed).length};
  #|       });
  #|       const ready=cases.filter(c=>c.kind==='useful').every(c=>c.original_passed===c.total)&&cases.every(c=>c.revised_passed===c.total)&&cases.some(c=>c.kind==='adverse'&&c.original_passed<c.total);
  #|       return {cases,ready,model_executed:false,factual_review_complete:false,activation_authorized:false,evaluation_kind:'operator_supplied_literal_revision_rehearsal'};
  #|     };
  #|     if (action.kind === 'compare') {
  #|       const result=evaluate();state={...state,intake:{...intake(),preview:null},revision:state.revision+1,preview:{binding:fingerprint(),...result},staged:false};return respond();
  #|     }
  #|     if (action.kind === 'stage') {
  #|       if (state.staged) return respond();
  #|       if (!previewCurrent()) throw Error('Compare this exact guidance, rationale, cases and checks before staging.');
  #|       const result=evaluate();
  #|       if (!same({...result,binding:fingerprint()},state.preview)) throw Error('Recompare the exact supplied cases before staging.');
  #|       if (!result.ready) throw Error('Preserve all known-useful baseline checks, pass every revised check, and fix at least one adverse baseline failure before staging.');
  #|       const report={...result,source_lesson:context.binding.original,original_guidance:context.original_guidance,revised_guidance:state.guidance,operator_rationale:state.rationale};
  #|       const reason='Operator-reported contrasting-case rehearsal. Supplied outputs and case labels are unverified; literal matches do not demonstrate generalization or a model run. Named-human review is still required.\n'+JSON.stringify(report,null,2);
  #|       const stage={guidance:state.guidance,reason};
  #|       state={...state,intake:{...intake(),preview:null},revision:state.revision+1,staged:true,preview:null,binding:{...context.binding,fields:{...context.binding.fields,...stage}}};
  #|       return JSON.stringify({state,stage,current:true,preview_current:false,eligible:true});
  #|     }
  #|     throw Error('Unknown rehearsal action.');
  #|   } catch(error) {return JSON.stringify({state,current:false,preview_current:false,error:String(error.message||error)});}
  #| }

///|
fn lesson_revision_rehearsal_context(history : LessonHistoryWorkspace) -> Json {
  guard history.change is Some(change) else { return Json::null() }
  guard history.data is Some(data) else {
    return {
      "eligible": false,
      "binding": {
        "change_id": change.selection_id,
        "rehearsal_epoch": change.revision_rehearsal_epoch,
      },
    }
  }
  let accepted = data.versions.filter(v => {
    v.lesson.record == change.original.record && lesson_history_accepted(v)
  })
  let original = lesson_record_value(change.original).unwrap_or(Json::null())
  {
    "eligible": change.operation == "revise" &&
    data.current == Some(change.original.record) &&
    data.head == change.expected_head &&
    data.accepted_reviews == change.accepted_reviews &&
    accepted.length() == 1 &&
    ToJson::to_json(accepted[0].lesson) == ToJson::to_json(change.original),
    "original_guidance": lesson_task_text(original, "guidance"),
    "binding": {
      "change_id": change.selection_id,
      "rehearsal_epoch": change.revision_rehearsal_epoch,
      "original": ToJson::to_json(change.original.record),
      "record": ToJson::to_json(change.original),
      "current": lesson_nullable_reference_json(data.current),
      "head": lesson_nullable_reference_json(data.head),
      "accepted_reviews": data.accepted_reviews.to_json(),
      "reviews": accepted
      .map(v => {
        v.reviews
        .map(review => {
          "receipt": ToJson::to_json(review.receipt),
          "reviewer": Json::string(review.reviewer.reviewer_id),
          "summary": Json::string(review.summary),
        })
        .to_json()
      })
      .to_json(),
      "fields": {
        "guidance": lesson_change_field(change, "guidance"),
        "reason": lesson_change_field(change, "reason"),
        "applicability": lesson_change_field(change, "applicability"),
        "invalidation": lesson_change_field(change, "invalidation"),
      },
    },
  }
}

///|
fn lesson_revision_rehearsal_transition(
  history : LessonHistoryWorkspace,
  pending : Bool,
  action : Json,
  request_id? : Int = 0,
) -> Json {
  let context = lesson_revision_rehearsal_context(history)
  let request : Json = {
    "request_id": request_id,
    "retained_cases": lesson_retained_cases(context),
    "state": match history.change {
      Some(change) => change.revision_rehearsal
      None => Json::null()
    },
    "context": context,
    "pending": pending,
    "action": action,
  }
  @json.parse(lesson_revision_rehearsal_transition_json(request.stringify())) catch {
    _ => { "error": "Rehearsal could not be read. Discard it and start again." }
  }
}

///|
fn lesson_revision_rehearsal_action(
  history : LessonHistoryWorkspace,
  kind : String,
  field? : String = "",
  value? : String = "",
  case_id? : String = "",
  case_kind? : String = "",
  request_id? : Int = 0,
) -> Json {
  let draft = match history.change {
    Some(change) => change.revision_rehearsal
    None => Json::null()
  }
  {
    "kind": kind,
    "expected_request": request_id,
    "expected_change": match history.change {
      Some(change) => Json::string(change.selection_id)
      None => Json::null()
    },
    "expected_epoch": match history.change {
      Some(change) => Json::string(change.revision_rehearsal_epoch)
      None => Json::null()
    },
    "expected_revision": lesson_task_field(draft, "revision"),
    "field": field,
    "value": value,
    "case_id": case_id,
    "case_kind": case_kind,
  }
}

///|
fn lesson_revision_rehearsal_update(
  model : Model,
  action : Json,
) -> (@rabbita.Cmd, Model) {
  let state = model.outcome_lessons
  guard state.history.change is Some(change) else {
    return (@rabbita.none, model)
  }
  let result = lesson_revision_rehearsal_transition(
    state.history,
    state.pending,
    action,
    request_id=state.request,
  )
  if result is { "error": String(error), .. } {
    return (
      @rabbita.none,
      {
        ..model,
        outcome_lessons: {
          ..state,
          history: { ..state.history, notice: error, },
        },
      },
    )
  }
  let fields = change.fields.copy()
  let staged = lesson_task_field(result, "stage")
  if staged != Json::null() {
    fields["guidance"] = lesson_task_text(staged, "guidance")
    fields["reason"] = lesson_task_text(staged, "reason")
  }
  (
    @rabbita.none,
    {
      ..model,
      outcome_lessons: {
        ..state,
        history: {
          ..state.history,
          change: Some({
            ..change,
            fields,
            revision_rehearsal: lesson_task_field(result, "state"),
            // Retain a fresh owner even while empty. Null state and a restarted
            // revision counter cannot make detached callbacks current again.
            revision_rehearsal_epoch: if lesson_task_text(action, "kind") ==
              "discard" {
              bookkeeper_nonce()
            } else {
              change.revision_rehearsal_epoch
            },
          }),
          result: None,
          notice: if staged != Json::null() {
            "Exact revised guidance and operator-reported case rationale staged below. Save the ordinary revision for named-human review; current guidance is unchanged."
          } else if lesson_task_text(action, "kind") == "discard" {
            "Local rehearsal discarded. Revision fields and existing accepted guidance are kept."
          } else {
            lesson_task_text(result, "notice")
          },
        },
      },
    },
  )
}
