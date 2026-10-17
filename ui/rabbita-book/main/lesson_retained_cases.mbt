///|
/// Read-only extraction from the exact accepted-current record already bound by
/// history. Recomputes stored literal results; no new evidence or review is made.
extern "js" fn lesson_retained_cases_json(text : String) -> String =
  #| text => {
  #|   const canonical=v=>JSON.stringify(v,(_,x)=>x&&typeof x==='object'&&!Array.isArray(x)?Object.fromEntries(Object.keys(x).sort().map(k=>[k,x[k]])):x);
  #|   const same=(a,b)=>canonical(a)===canonical(b), str=v=>typeof v==='string'&&!!v.trim();
  #|   const empty=notice=>JSON.stringify({items:[],unavailable:[],notice});
  #|   try {
  #|     const context=JSON.parse(text);
  #|     if(!context || context.eligible!==true) return empty('Open a revision of the exact accepted-current lesson to reuse its teaching examples.');
  #|     const binding=context.binding, record=binding?.record, payload=record?.payload, lesson=payload?.outcome_lesson;
  #|     if(!record || !same(record.record,binding.original) || !lesson || lesson.guidance!==context.original_guidance) throw Error('The retained lesson identity or guidance does not match current history.');
  #|     const reviews=(binding.reviews||[]).flat().map(r=>r.receipt);
  #|     if(!reviews.length) throw Error('The retained lesson has no captured named-review receipt.');
  #|     const candidates=[];
  #|     if(payload.candidate_schema==='outcome_lesson.rehearsed.v1') {
  #|       const r=payload.rehearsal;
  #|       if(!r || r.contract_version!=='moonbook.outcome-lesson-rehearsal.v1' || !same(r.lesson,lesson) || ![r.example_input,r.baseline_output,r.corrected_output].every(v=>str(v)&&v.length<=16384) || !Array.isArray(r.required_text) || !r.required_text.length || r.required_text.length>20 || r.required_text.some(v=>!str(v)||v.length>512) || new Set(r.required_text).size!==r.required_text.length) throw Error('The retained single-example rehearsal is incomplete or incompatible.');
  #|       if(!r.required_text.every(v=>r.corrected_output.includes(v)) || r.required_text.every(v=>r.baseline_output.includes(v))) throw Error('The retained corrected output does not recompute as an improvement.');
  #|       candidates.push({id:'retained-1',name:'Original teaching example',input:r.example_input,original:r.corrected_output,required:r.required_text,forbidden:[],source_case_id:'single-example',source_kind:'single_example'});
  #|     } else if(payload.candidate_schema==='outcome_lesson.v2') {
  #|       const revision=payload.revision, marker='Operator-reported contrasting-case rehearsal. Supplied outputs and case labels are unverified; literal matches do not demonstrate generalization or a model run. Named-human review is still required.\n';
  #|       if(!revision || typeof revision.reason!=='string' || !revision.reason.startsWith(marker)) return empty('This accepted revision has no supported retained contrasting-case report.');
  #|       if(revision.contract_version!=='moonbook.outcome-lesson-revision.v1' || !same(revision.lesson,lesson) || revision.reason.length>250000) throw Error('The retained revision report is incompatible.');
  #|       const r=JSON.parse(revision.reason.slice(marker.length));
  #|       if(r.evaluation_kind!=='operator_supplied_literal_revision_rehearsal' || r.model_executed!==false || r.factual_review_complete!==false || r.activation_authorized!==false || r.ready!==true || r.revised_guidance!==lesson.guidance || !same(r.source_lesson,revision.supersedes) || !Array.isArray(r.cases) || r.cases.length<2 || r.cases.length>6 || !r.cases.some(c=>c.kind==='useful') || !r.cases.some(c=>c.kind==='adverse') || new Set(r.cases.map(c=>c.id)).size!==r.cases.length || new Set(r.cases.map(c=>typeof c.input==='string'?c.input.trim():null)).size!==r.cases.length) throw Error('The retained report does not describe this accepted guidance and its exact predecessor.');
  #|       let improved=false;
  #|       r.cases.forEach((c,i)=>{
  #|         if(!str(c.id) || !['useful','adverse'].includes(c.kind) || !str(c.name) || ![c.input,c.original_output,c.revised_output].every(str) || !Array.isArray(c.checks) || !c.checks.length || c.checks.length>20 || c.checks.some(k=>!['required','forbidden'].includes(k.kind)||!str(k.text))) throw Error('A retained case or its checks is unreadable.');
  #|         const required=c.checks.filter(k=>k.kind==='required').map(k=>k.text), forbidden=c.checks.filter(k=>k.kind==='forbidden').map(k=>k.text);
  #|         if(new Set(required).size!==required.length || new Set(forbidden).size!==forbidden.length || required.some(r=>forbidden.some(f=>r.includes(f)))) throw Error('Retained checks are duplicated or contradictory.');
  #|         let before=0,after=0,regressions=0;
  #|         for(const k of c.checks){const a=k.kind==='required'?c.original_output.includes(k.text):!c.original_output.includes(k.text),b=k.kind==='required'?c.revised_output.includes(k.text):!c.revised_output.includes(k.text);if(k.original_passed!==a||k.revised_passed!==b)throw Error('Stored case results do not match the retained output.');before+=Number(a);after+=Number(b);regressions+=Number(a&&!b);}
  #|         if(c.original_passed!==before||c.revised_passed!==after||c.total!==c.checks.length||c.regressions!==regressions||after!==c.checks.length||(c.kind==='useful'&&before!==c.checks.length)) throw Error('The retained case totals do not recompute as a passing correction.');
  #|         if(c.kind==='adverse'&&before<c.checks.length)improved=true;
  #|         candidates.push({id:'retained-'+(i+1),name:c.name,input:c.input,original:c.revised_output,required,forbidden,source_case_id:c.id,source_kind:'contrasting_revision'});
  #|       });
  #|       if(!improved)throw Error('The retained report has no improved adverse case.');
  #|     } else return empty('This accepted lesson has no retained teaching examples. Manual rehearsal is available.');
  #|     const items=[],unavailable=[];
  #|     for(const c of candidates){
  #|       const fragments=[...c.required,...c.forbidden];
  #|       if(c.name.length>256||c.input.length>8192||c.original.length>8192||fragments.some(v=>v.length>256||v.trim()!==v||v.includes('\n')||v.includes('\r'))){unavailable.push({id:c.id,name:c.name,reason:'The retained text or literal fragments do not fit this revision workbench without alteration. The original is kept unchanged; use manual cases if appropriate.'});continue;}
  #|       items.push({id:c.id,name:c.name,input:c.input,original:c.original,required:c.required.join('\n'),forbidden:c.forbidden.join('\n'),retained_from:{lesson:binding.original,review_receipts:reviews,source_case_id:c.source_case_id,source_kind:c.source_kind}});
  #|     }
  #|     return JSON.stringify({items,unavailable,notice:'Remembered outputs are operator reports, not fresh execution. Supply a new revised output and an adverse case before comparing.'});
  #|   } catch(error){return empty('Retained examples unavailable: '+String(error.message||error));}
  #| }

///|
fn lesson_retained_cases(context : Json) -> Json {
  @json.parse(lesson_retained_cases_json(context.stringify())) catch {
    _ =>
      {
        "items": [],
        "unavailable": [],
        "notice": "Retained examples could not be read.",
      }
  }
}
