import {readFileSync} from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
const source=readFileSync(new URL('../ui/rabbita-book/main/lesson_revision_rehearsal_state.mbt',import.meta.url),'utf8');
const code=source.split('\n').filter(v=>/^\s*#\|/.test(v)).map(v=>v.replace(/^\s*#\|\s?/, '')).join('\n');
const transition=vm.runInNewContext(`(${code})`,{}, {timeout:1000});
const run=x=>JSON.parse(transition(JSON.stringify(x)));
const clone=x=>JSON.parse(JSON.stringify(x));
const ctx=()=>({eligible:true,original_guidance:'Original rule',binding:{change_id:'draft-1',rehearsal_epoch:'epoch-1',original:{record_id:'lesson',record_version:'2',record_digest:'exact'},head:'review2',current:'lesson2',reviews:['human2'],accepted_reviews:['human1','human2'],fields:{title:'Title',version:'3',guidance:'Revised rule',reason:'Improve the adverse case',applicability:'customer=A',invalidation:'state=stale'}}});
const step=(state,action,context=ctx(),pending=false)=>run({state,action:{expected_change:context?.binding?.change_id,expected_epoch:context?.binding?.rehearsal_epoch,expected_revision:state?.revision??null,...action},context,pending});
const change=(s,a,c)=>{const r=step(s,a,c);assert.equal(r.error,undefined);return r.state;};
function ready(){
 let s=change(null,{kind:'begin'});
 for(const [id,fields] of [['case-1',{name:'Useful <&> 東京',input:'Routine task',original:'Source: correct',revised:'Source: correct',required:'Source:',forbidden:'invented'}],['case-2',{name:'Adverse',input:'Ambiguous task',original:'invented',revised:'Source: uncertainty',required:'Source:\nuncertainty',forbidden:'invented'}]]) for(const [field,value] of Object.entries(fields)) s=change(s,{kind:'edit',case_id:id,field,value});
 return s;
}
test('real production reducer compares contrasting outputs and stages exact ordinary fields',()=>{
 const input=ready(),before=JSON.stringify(input),preview=change(input,{kind:'compare'});
 assert.equal(JSON.stringify(input),before);assert.equal(preview.preview.ready,true);
 assert.deepEqual(preview.preview.cases.map(c=>[c.original_passed,c.revised_passed,c.total]),[[2,2,2],[0,3,3]]);
 assert.equal(preview.preview.model_executed,false);assert.equal(preview.preview.activation_authorized,false);
 const result=step(preview,{kind:'stage'});assert.equal(result.stage.guidance,'Revised rule');
 const report=JSON.parse(result.stage.reason.split('\n').slice(1).join('\n'));
 assert.equal(report.operator_rationale,'Improve the adverse case');assert.equal(report.factual_review_complete,false);
 assert.equal(report.cases[0].input,'Routine task');assert.equal(report.cases[1].original_output,'invented');assert.deepEqual(report.source_lesson,ctx().binding.original);
 const c=ctx();c.binding.fields={...c.binding.fields,...result.stage};
 assert.equal(step(result.state,{kind:'inspect'},c).current,true);
 assert.equal(step(result.state,{kind:'stage'},c).stage,undefined);
});
test('guidance, checks, outputs, case edits and rationale invalidate prior preview',()=>{
 for(const a of [{field:'guidance',value:'  Exact new <&> 東京\n '},{field:'rationale',value:'More context'},{case_id:'case-1',field:'input',value:'New task'},{case_id:'case-1',field:'revised',value:'Source: retained'},{case_id:'case-1',field:'required',value:'Source:'}]){
  const s=change(change(ready(),{kind:'compare'}),{kind:'edit',...a});assert.equal(s.preview,null);assert.match(step(s,{kind:'stage'}).error,/Compare this exact/);
 }
});
test('iterative correction shows regression, blocks stage, then accepts exact corrected guidance',()=>{
 let s=change(ready(),{kind:'edit',case_id:'case-1',field:'revised',value:'invented'});
 s=change(s,{kind:'compare'});assert.equal(s.preview.ready,false);assert.equal(s.preview.cases[0].regressions,2);assert.match(step(s,{kind:'stage'}).error,/Preserve all/);
 s=change(s,{kind:'edit',case_id:'case-1',field:'revised',value:'Source: correct'});
 s=change(s,{kind:'edit',field:'guidance',value:'  Exact revised\n東京 <&>  '});
 s=change(s,{kind:'compare'});assert.equal(step(s,{kind:'stage'}).stage.guidance,'  Exact revised\n東京 <&>  ');
});
test('unknown-useful baseline and no adverse improvement cannot be staged',()=>{
 for(const [id,value] of [['case-1','invented'],['case-2','Source: uncertainty']]){
  let s=change(ready(),{kind:'edit',case_id:id,field:'original',value});s=change(s,{kind:'compare'});assert.equal(s.preview.ready,false);assert.equal(step(s,{kind:'stage'}).stage,undefined);
 }
});
test('stale lesson, history, current, review, fields and reopened draft block stage without losing edits',()=>{
 const s=change(ready(),{kind:'compare'});
 for(const mutate of [c=>c.eligible=false,c=>c.binding.original.record_digest='changed',c=>c.binding.current='old',c=>c.binding.head='head3',c=>c.binding.reviews=['other'],c=>c.binding.fields.version='4',c=>c.binding.change_id='new']){
  const c=ctx();mutate(c);const r=step(s,{kind:'stage'},c);assert.ok(r.error);assert.deepEqual(r.state,s);assert.equal(r.stage,undefined);
 }
});
test('old controls, duplicate starts, pending actions and interruptions preserve ownership',()=>{
 const s=ready();assert.deepEqual(step(s,{kind:'begin'}).state,s);assert.match(step(s,{kind:'edit',expected_revision:0,field:'guidance',value:'stale'}).error,/draft or request changed/);
 for(const kind of ['edit','compare','stage','discard']) assert.deepEqual(step(s,{kind},ctx(),true).state,s);
 assert.equal(step(s,{kind:'discard'},ctx()).state,null);
 assert.equal(step(s,{kind:'discard'},{eligible:false,binding:{change_id:'draft-1',rehearsal_epoch:'epoch-1'}}).state,null);
 assert.equal(step(s,{kind:'stage',expected_change:'closed-draft'}).stage,undefined);
});
test('six-case bound and remove permit continued work with stable identities',()=>{
 let s=ready();assert.match(step(s,{kind:'remove',case_id:'case-1'}).error,/at least two/);
 for(let n=0;n<4;n++)s=change(s,{kind:'add',case_kind:n%2?'useful':'adverse'});
 assert.equal(s.cases.length,6);assert.match(step(s,{kind:'add',case_kind:'useful'}).error,/2–6/);
 s=change(s,{kind:'remove',case_id:'case-3'});s=change(s,{kind:'add',case_kind:'adverse'});assert.equal(s.cases[5].id,'case-7');
 assert.match(step(s,{kind:'remove',case_id:'case-3'}).error,/no longer/);
});
for(const [name,mutate,pattern] of [
 ['contradictory exact',s=>s.cases[0].forbidden='Source:',/Contradictory/],
 ['contradictory substring',s=>s.cases[0].forbidden='Source',/Contradictory/],
 ['duplicate checks',s=>s.cases[0].required='Source:\nSource:',/unique/],
 ['no checks',s=>{s.cases[0].required='';s.cases[0].forbidden='';},/1–20/],
 ['too many checks',s=>s.cases[0].required=Array.from({length:21},(_,i)=>'check'+i).join('\n'),/1–20/],
 ['long fragment',s=>s.cases[0].required='x'.repeat(257),/256/],
 ['oversized stored output',s=>s.cases[0].original='x'.repeat(8193),/8192/],
 ['blank input',s=>s.cases[0].input=' ',/supply/],
 ['duplicate inputs',s=>s.cases[1].input=s.cases[0].input,/distinct/],
 ['no useful case',s=>s.cases[0].kind='adverse',/known-useful/],
 ['no adverse case',s=>s.cases[1].kind='useful',/known-useful/],
 ['unchanged guidance',s=>s.guidance='Original rule',/Revise the guidance/],
 ['blank rationale',s=>s.rationale=' ',/rationale/],
 ['bad shape',s=>s.cases[0].input=null,/malformed/],
 ['too few cases',s=>s.cases.pop(),/malformed/],
])test(name,()=>{const s=ready();mutate(s);assert.match(step(s,{kind:'compare'}).error,pattern);});
test('edits reject oversize without truncation and unknown fields or cases',()=>{
 const s=ready();for(const a of [{field:'guidance',value:'x'.repeat(8193)},{case_id:'case-1',field:'required',value:'x'.repeat(5141)},{case_id:'case-1',field:'name',value:'x'.repeat(257)},{field:'invented',value:'x'},{case_id:'missing',field:'input',value:'x'}]){const r=step(s,{kind:'edit',...a});assert.ok(r.error);assert.deepEqual(r.state,s);}
});
test('malformed JSON and forged previews fail closed',()=>{
 assert.ok(JSON.parse(transition('{')).error);
 let s=change(ready(),{kind:'compare'});s.preview.cases[0].original_passed=0;assert.match(step(s,{kind:'stage'}).error,/Recompare/);
 const malformed={...ready(),cases:null};assert.equal(step(malformed,{kind:'discard'}).state,null);
});
test('object key order is immaterial and original input remains immutable',()=>{
 const s=ready(),c=ctx();c.binding.fields=Object.fromEntries(Object.entries(c.binding.fields).reverse());assert.equal(step(s,{kind:'compare'},c).state.preview.ready,true);
});
test('all six cases are evaluated and exact boundary text is retained',()=>{
 let s=ready();
 for(let i=3;i<=6;i++){
   s=change(s,{kind:'add',case_kind:'adverse'});
   for(const [field,value] of Object.entries({name:'Extra '+i,input:'Input '+i,original:'invented',revised:'Source: fixed',required:'Source:',forbidden:'invented'}))s=change(s,{kind:'edit',case_id:'case-'+i,field,value});
 }
 s=change(s,{kind:'edit',case_id:'case-6',field:'revised',value:'Source: '+'x'.repeat(8184)});
 s=change(s,{kind:'compare'});assert.equal(s.preview.cases.length,6);assert.equal(s.preview.ready,true);
 const result=step(s,{kind:'stage'});assert.ok(result.stage);assert.equal(JSON.parse(result.stage.reason.split('\n').slice(1).join('\n')).cases[5].revised_output.length,8192);
});

test('rehearsal owner epoch rejects old input, discard, stage and begin despite matching ordinary revision and reset counter',()=>{
 const old=ctx(), first=change(null,{kind:'begin'},old), fresh=ctx();fresh.binding.rehearsal_epoch='epoch-2';
 const next=change(null,{kind:'begin'},fresh);assert.equal(first.revision,next.revision);
 for(const kind of ['edit','discard','stage','compare','add','remove','begin']){
  const result=step(next,{kind,expected_epoch:old.binding.rehearsal_epoch,field:'guidance',value:'detached'},fresh);
  assert.match(result.error,/draft or request changed/);assert.deepEqual(result.state,next);assert.equal(result.stage,undefined);
 }
 const delayedStart=step(null,{kind:'begin',expected_epoch:old.binding.rehearsal_epoch},fresh);assert.ok(delayedStart.error);assert.equal(delayedStart.state,null);
});
