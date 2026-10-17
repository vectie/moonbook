///|
/// Explicit browser-local authoring only. Recovered text never supplies review
/// authority, request identities, staged state, or an evaluation result.
extern "js" fn lesson_correction_draft_storage_json(text : String) -> String =
  #| text => {
  #|   const canonical=v=>JSON.stringify(v,(_,x)=>x&&typeof x==='object'&&!Array.isArray(x)?Object.fromEntries(Object.keys(x).sort().map(k=>[k,x[k]])):x);
  #|   const same=(a,b)=>canonical(a)===canonical(b), object=v=>!!v&&typeof v==='object'&&!Array.isArray(v);
  #|   const fields=['title','version','guidance','reason','applicability','invalidation'];
  #|   const texts=['name','input','original','revised','required','forbidden'];
  #|   const limit=524288;
  #|   const checkText=(v,n)=>typeof v==='string'&&v.length<=n;
  #|   const exact=(v,keys)=>object(v)&&Object.keys(v).every(k=>keys.includes(k))&&keys.every(k=>Object.hasOwn(v,k));
  #|   const source=context=>{
  #|     const {original,record,current,head,accepted_reviews,reviews}=context.binding;
  #|     return canonical({original,record,current,head,accepted_reviews,reviews});
  #|   };
  #|   const validate=d=>{
  #|     if(!exact(d,['schema','workspace','lesson_id','source','fields','rehearsal'])||d.schema!=='moonbook.correction-draft.v1'||!checkText(d.workspace,8192)||!d.workspace.trim()||!checkText(d.lesson_id,1024)||!d.lesson_id.trim()||!checkText(d.source,262144)||!d.source.length)throw Error('Saved correction has an unsupported format. It was not restored.');
  #|     if(!exact(d.fields,fields)||fields.some(k=>!checkText(d.fields[k],k==='reason'?262144:8192)))throw Error('Saved revision fields are malformed or oversized. Nothing was truncated.');
  #|     const r=d.rehearsal;
  #|     if(!exact(r,['guidance','rationale','cases','intake'])||!checkText(r.guidance,8192)||!checkText(r.rationale,8192)||!checkText(r.intake,131072)||!Array.isArray(r.cases)||r.cases.length<2||r.cases.length>6)throw Error('Saved rehearsal is malformed or oversized. Nothing was truncated.');
  #|     for(const c of r.cases){
  #|       if(!object(c)||Object.keys(c).some(k=>!['kind',...texts,'retained_from','practice_from'].includes(k))||!['useful','adverse'].includes(c.kind)||texts.some(k=>!checkText(c[k],k==='name'?256:['required','forbidden'].includes(k)?5140:8192)))throw Error('Saved case is malformed or oversized. Nothing was truncated.');
  #|       if(Object.hasOwn(c,'retained_from')&&(!object(c.retained_from)||canonical(c.retained_from).length>32768))throw Error('Saved retained-example reference is malformed.');
  #|       if(Object.hasOwn(c,'practice_from')){const p=c.practice_from;if(!object(p)||p.schema!=='moonbook.practice-correction-source.v1'||p.operator_reported!==true||p.model_executed!==false||p.exercise!==c.input||p.first_response!==c.original||!object(p.lesson)||!checkText(p.learner,256)||['objective','exercise','first_response','after_feedback_response','feedback','next_practice'].some(k=>!checkText(p[k],16384))||canonical(p).length>limit)throw Error('Saved practice source is malformed or no longer matches its exact input and first response.');}
  #|     }
  #|     if(canonical(d).length>limit)throw Error('Correction exceeds the 524288-character browser draft limit. Nothing was truncated.');
  #|     return d;
  #|   };
  #|   const parse=raw=>{if(typeof raw!=='string'||raw.length>limit)throw Error('Saved correction is oversized or unreadable.');return validate(JSON.parse(raw));};
  #|   try {
  #|     const q=JSON.parse(text), {operation,workspace,lesson_id,context}=q;
  #|     if(!checkText(workspace,8192)||!workspace.trim()||!checkText(lesson_id,1024)||!lesson_id.trim())throw Error('Open a saved Book workspace and exact lesson before using browser drafts.');
  #|     const key='moonbook.correction-draft.v1:'+encodeURIComponent(canonical({workspace,lesson_id}));
  #|     const storage=globalThis.localStorage;
  #|     if(!storage)throw Error('Browser storage is unavailable. Keep this tab open; nothing was saved.');
  #|     const raw=storage.getItem(key);
  #|     const inspect=()=>{
  #|       if(raw===null)return {raw:null,draft:null,problem:'',notice:'No correction is saved for this Book and lesson on this browser.'};
  #|       try {const draft=parse(raw);if(draft.workspace!==workspace||draft.lesson_id!==lesson_id)throw Error('Saved correction belongs to another Book or lesson.');return {raw,draft,problem:'',notice:'Saved correction found. Resume only into a fresh revision of the same current lesson, or replace it explicitly.'};}
  #|       catch(error){return {raw,draft:null,problem:String(error.message||error),notice:'The saved correction cannot be resumed. Your open work and saved bytes are kept.'};}
  #|     };
  #|     if(operation==='read')return JSON.stringify({recovery:inspect()});
  #|     const expected=q.recovery?.raw??null;
  #|     if(raw!==expected)throw Error('The saved correction changed or has not been checked. Check saved correction again before replacing, resuming or removing it. Your open work is kept.');
  #|     if(operation==='forget'){
  #|       if(raw===null)throw Error('There is no checked saved correction to remove.');
  #|       storage.removeItem(key);
  #|       if(storage.getItem(key)!==null)throw Error('Browser storage did not confirm removal. Check saved correction again.');
  #|       return JSON.stringify({recovery:{raw:null,draft:null,problem:'',notice:'Saved browser copy removed. Your open correction and accepted guidance are unchanged.'}});
  #|     }
  #|     if(!context||context.eligible!==true)throw Error('Refresh history and revise the exact current, named-human accepted lesson first.');
  #|     if(operation==='save'){
  #|       if(!q.current||!q.rehearsal)throw Error('Start a current contrasting-case rehearsal before saving a browser correction draft.');
  #|       const r=q.rehearsal;
  #|       // Whitelist authored values. Do not retain preview/staged flags or old
  #|       // callback/request identities; they cannot become current on reload.
  #|       const draft=validate({schema:'moonbook.correction-draft.v1',workspace,lesson_id,source:source(context),fields:Object.fromEntries(fields.map(k=>[k,q.fields[k]])),rehearsal:{guidance:r.guidance,rationale:r.rationale,cases:r.cases.map(c=>({kind:c.kind,...Object.fromEntries(texts.map(k=>[k,c[k]])),...(c.retained_from?{retained_from:c.retained_from}:{}),...(c.practice_from?{practice_from:c.practice_from}:{})})),intake:r.intake?.text??''}});
  #|       const saved=canonical(draft);
  #|       storage.setItem(key,saved);
  #|       if(storage.getItem(key)!==saved)throw Error('Browser storage did not confirm this save. Keep this tab open and check the saved copy.');
  #|       return JSON.stringify({recovery:{raw:saved,draft,problem:'',notice:'Correction draft saved on this browser. Resume from this lesson history after reload; compare and stage again before named-human review.'}});
  #|     }
  #|     if(operation==='resume'){
  #|       if(!q.pristine||q.rehearsal!==null)throw Error('Close your open change draft and start a fresh revision before resuming. Your current edits were not replaced.');
  #|       if(raw===null)throw Error('There is no saved correction to resume.');
  #|       const d=parse(raw);
  #|       if(d.workspace!==workspace||d.lesson_id!==lesson_id||d.source!==source(context))throw Error('The lesson, current version, history or reviews changed. Saved correction is kept, but cannot be resumed against different accepted guidance.');
  #|       const retained=q.retained?.items??[];
  #|       for(const c of d.rehearsal.cases)if(c.retained_from){const original=retained.find(v=>same(v.retained_from,c.retained_from));if(!original||c.kind!=='useful'||!['name','input','original','required','forbidden'].every(k=>original[k]===c[k]))throw Error('A saved retained example no longer matches current lesson evidence. Nothing was restored.');}
  #|       for(const c of d.rehearsal.cases)if(c.practice_from&&(!same(c.practice_from.lesson.reference,context.binding.original)||c.practice_from.lesson.guidance!==context.original_guidance))throw Error('Saved practice belongs to different original guidance. Nothing was restored.');
  #|       const binding={...context.binding,fields:Object.fromEntries(['guidance','reason','applicability','invalidation'].map(k=>[k,d.fields[k]]))};
  #|       const rehearsal={revision:0,binding,guidance:d.rehearsal.guidance,rationale:d.rehearsal.rationale,cases:d.rehearsal.cases.map((c,i)=>({id:'case-'+(i+1),...c})),next_id:d.rehearsal.cases.length+1,preview:null,staged:false,intake:{text:d.rehearsal.intake,preview:null,input_error:''}};
  #|       return JSON.stringify({fields:d.fields,rehearsal,recovery:{raw,draft:d,problem:'',notice:'Correction resumed as editable text. Compare the supplied cases and stage again before saving for named-human review. The saved browser copy remains available.'}});
  #|     }
  #|     throw Error('Unsupported correction draft operation.');
  #|   }catch(error){return JSON.stringify({error:'Browser correction: '+String(error.message||error)});}
  #| }
