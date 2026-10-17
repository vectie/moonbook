import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';
const compile=file=>{const s=readFileSync(new URL('../ui/rabbita-book/main/'+file,import.meta.url),'utf8');return vm.runInNewContext('('+s.split('\n').filter(l=>/^\s*#\|/.test(l)).map(l=>l.replace(/^\s*#\|\s?/,'')).join('\n')+')',{}, {timeout:1000});};
const extract=compile('lesson_retained_cases.mbt'),reduce=compile('lesson_revision_rehearsal_state.mbt');
const clone=x=>JSON.parse(JSON.stringify(x));
const catalog=c=>JSON.parse(extract(JSON.stringify(c)));
const reference=n=>({record_id:'lesson',record_version:String(n),record_digest:'exact-'+n});
function context(){
 const lesson={guidance:'Current guidance',lesson_id:'family'},r={contract_version:'moonbook.outcome-lesson-rehearsal.v1',lesson,example_input:'Example <&> 東京\n original ',baseline_output:'unsupported',corrected_output:'  Source: known 東京\n exact  ',required_text:['Source:','known']};
 return {eligible:true,original_guidance:lesson.guidance,binding:{change_id:'draft1',rehearsal_epoch:'owner1',original:reference(1),record:{record:reference(1),payload:{candidate_schema:'outcome_lesson.rehearsed.v1',outcome_lesson:lesson,rehearsal:r}},current:reference(1),head:reference('review'),accepted_reviews:[reference('review')],reviews:[[{receipt:reference('review'),reviewer:'Named person',summary:'Accepted'}]],fields:{guidance:'New guidance',reason:'Improve adverse behavior',applicability:'scope=A',invalidation:''}}};
}
const step=(s,a,c=context(),pending=false)=>JSON.parse(reduce(JSON.stringify({state:s,context:c,retained_cases:catalog(c),pending,action:{expected_change:c?.binding?.change_id,expected_epoch:c?.binding?.rehearsal_epoch,expected_revision:s?.revision??null,...a}})));
function change(s,a,c){const r=step(s,a,c);assert.equal(r.error,undefined);return r.state;}
function ready(c=context()){
 let s=change(null,{kind:'reuse',case_id:'retained-1'},c);
 s=change(s,{kind:'edit',case_id:'case-1',field:'revised',value:'Source: known new output'},c);
 for(const [field,value] of Object.entries({name:'New adverse example',input:'A new task',original:'unsupported',revised:'Source: uncertainty',required:'Source:\nuncertainty',forbidden:'invented'}))s=change(s,{kind:'edit',case_id:'case-2',field,value},c);
 return s;
}
function nextContext(){const c=context(),staged=step(change(ready(c),{kind:'compare'},c),{kind:'stage'},c),next=clone(c);const lesson={...c.binding.record.payload.outcome_lesson,guidance:staged.stage.guidance};next.original_guidance=lesson.guidance;next.binding.original=reference(2);next.binding.record={record:reference(2),payload:{candidate_schema:'outcome_lesson.v2',outcome_lesson:lesson,revision:{contract_version:'moonbook.outcome-lesson-revision.v1',lesson,supersedes:c.binding.original,reason:staged.stage.reason}}};next.binding.current=reference(2);next.binding.change_id='draft2';next.binding.fields.guidance='Third guidance';return next;}

test('reuse accepted v1 example preserves exact source/output, leaves fresh output blank and requires compare',()=>{
 const c=context(),before=JSON.stringify(c),r=step(null,{kind:'reuse',case_id:'retained-1'},c);assert.equal(r.error,undefined);assert.equal(r.state.cases.length,2);const first=r.state.cases[0];assert.equal(first.input,c.binding.record.payload.rehearsal.example_input);assert.equal(first.original,c.binding.record.payload.rehearsal.corrected_output);assert.equal(first.revised,'');assert.deepEqual(first.retained_from.lesson,c.binding.original);assert.deepEqual(first.retained_from.review_receipts,[reference('review')]);assert.equal(first.kind,'useful');assert.equal(r.state.cases[1].kind,'adverse');assert.equal(JSON.stringify(c),before);assert.ok(step(r.state,{kind:'compare'},c).error);assert.equal(step(r.state,{kind:'stage'},c).stage,undefined);
});
test('connected comparison and stage persist attribution through normal revision rationale',()=>{
 const c=context(),s=ready(c),r=step(change(s,{kind:'compare'},c),{kind:'stage'},c);assert.equal(r.error,undefined);const report=JSON.parse(r.stage.reason.slice(r.stage.reason.indexOf('\n')+1));assert.deepEqual(report.cases[0].retained_from,catalog(c).items[0].retained_from);assert.equal(report.cases[0].original_output,c.binding.record.payload.rehearsal.corrected_output);assert.equal(report.cases[0].revised_output,'Source: known new output');assert.equal(report.model_executed,false);assert.equal(report.factual_review_complete,false);assert.equal(report.activation_authorized,false);
});
test('reopened accepted v2 revision supplies newly successful outputs, preserving prior record and avoiding recursive report copying',()=>{
 const c=nextContext(),before=JSON.stringify(c),items=catalog(c).items;assert.equal(items.length,2);assert.equal(items[0].original,'Source: known new output');assert.equal(items[1].original,'Source: uncertainty');assert.deepEqual(items[0].retained_from.lesson,reference(2));assert.equal(items[0].retained_from.source_kind,'contrasting_revision');assert.equal(items[0].retained_from.source_case_id,'case-1');assert.equal(items[0].retained_from.prior_retained_from,undefined);assert.equal(change(null,{kind:'reuse',case_id:'retained-2'},c).cases[0].revised,'');assert.equal(JSON.stringify(c),before);
});
test('remembered old fields cannot be edited, duplicate import rejected, explicit removal permits manual work',()=>{
 const c=context(),s=ready(c);for(const field of ['name','input','original','required','forbidden']){const r=step(s,{kind:'edit',case_id:'case-1',field,value:'changed'},c);assert.match(r.error,/read-only/);assert.deepEqual(r.state,s);}assert.match(step(s,{kind:'reuse',case_id:'retained-1'},c).error,/already/);let more=change(s,{kind:'add',case_kind:'useful'},c);more=change(more,{kind:'remove',case_id:'case-1'},c);assert.equal(more.cases.some(x=>x.retained_from),false);more=change(more,{kind:'reuse',case_id:'retained-1'},c);assert.equal(more.cases.filter(x=>x.retained_from).length,1);
});
test('tampered remembered state cannot be compared or staged as retained experience',()=>{
 const c=context();for(const field of ['name','input','original','required','forbidden','kind']){const s=ready(c);s.cases[0][field]='forged';assert.match(step(s,{kind:'compare'},c).error,/remembered baseline|malformed/);}const s=ready(c);s.cases[0].retained_from.lesson.record_digest='changed';assert.match(step(s,{kind:'compare'},c).error,/remembered baseline/);
});
test('editing a fresh revised output invalidates preview and a regression must be repaired',()=>{
 const c=context();let s=change(ready(c),{kind:'compare'},c);s=change(s,{kind:'edit',case_id:'case-1',field:'revised',value:'forgot prior behavior'},c);assert.equal(s.preview,null);s=change(s,{kind:'compare'},c);assert.equal(s.preview.ready,false);assert.ok(step(s,{kind:'stage'},c).error);s=change(s,{kind:'edit',case_id:'case-1',field:'revised',value:'Source: known fixed'},c);assert.ok(step(change(s,{kind:'compare'},c),{kind:'stage'},c).stage);
});
test('stale source, current, reviews, epoch and pending controls retain cases but refuse reuse',()=>{
 const c=nextContext(),s=change(null,{kind:'reuse',case_id:'retained-1'},c);for(const mutate of [x=>x.eligible=false,x=>x.binding.original.record_digest='changed',x=>x.binding.current=reference(0),x=>x.binding.reviews[0][0].receipt=reference('other'),x=>x.binding.rehearsal_epoch='other']){const newer=clone(c);mutate(newer);const r=step(s,{kind:'reuse',case_id:'retained-2'},newer);assert.ok(r.error);assert.deepEqual(r.state,s);}assert.ok(step(s,{kind:'reuse',case_id:'retained-2'},c,true).error);assert.ok(step(s,{kind:'reuse',case_id:'retained-2',expected_revision:-1},c).error);
});
test('same-input manual example prevents accidental duplicate retained baseline',()=>{
 const c=context();let s=change(null,{kind:'begin'},c);s=change(s,{kind:'edit',case_id:'case-1',field:'input',value:c.binding.record.payload.rehearsal.example_input},c);assert.match(step(s,{kind:'reuse',case_id:'retained-1'},c).error,/already/);
});
test('five remembered cases and one new adverse case fit; a sixth remembered case cannot evict work',()=>{
 const c=nextContext(),revision=c.binding.record.payload.revision,report=JSON.parse(revision.reason.split('\n').slice(1).join('\n'));for(let i=2;i<6;i++){report.cases.push({...clone(report.cases[0]),id:'case-'+(i+1),name:'Old '+i,input:'Retained example '+i});}revision.reason=revision.reason.split('\n')[0]+'\n'+JSON.stringify(report);assert.equal(catalog(c).items.length,6);let s=null;for(let i=1;i<=5;i++)s=change(s,{kind:'reuse',case_id:'retained-'+i},c);assert.equal(s.cases.length,6);assert.equal(s.cases.filter(v=>v.retained_from).length,5);const r=step(s,{kind:'reuse',case_id:'retained-6'},c);assert.ok(r.error);assert.deepEqual(r.state,s);
});
test('v1 larger legacy limits or line-changing checks are visibly unavailable, never truncated',()=>{
 for(const mutate of [r=>r.example_input='x'.repeat(8193),r=>r.corrected_output='Source: known'+'x'.repeat(8193),r=>{r.required_text=['x'.repeat(257)];r.corrected_output=r.required_text[0];},r=>{r.required_text=[' a '];r.corrected_output=' a ';},r=>{r.required_text=['a\nb'];r.corrected_output='a\nb';}]){const c=context();mutate(c.binding.record.payload.rehearsal);const before=JSON.stringify(c),r=catalog(c);assert.equal(r.items.length,0);assert.equal(r.unavailable.length,1);assert.equal(JSON.stringify(c),before);}
});
test('malformed, rejected, unlinked, unsupported and incompatible retained records have no reusable cases',()=>{
 const mutators=[c=>c.eligible=false,c=>c.binding.record.record=reference(9),c=>c.binding.reviews=[],c=>c.original_guidance='different',c=>c.binding.record.payload.rehearsal.lesson={guidance:'wrong'},c=>c.binding.record.payload.rehearsal.corrected_output='failed',c=>c.binding.record.payload.rehearsal.baseline_output='Source: known',c=>c.binding.record.payload.rehearsal.required_text=['Source:','Source:'],c=>c.binding.record.payload.candidate_schema='outcome_lesson.v1'];for(const mutate of mutators){const c=context();mutate(c);assert.equal(catalog(c).items.length,0);}assert.equal(JSON.parse(extract('{')).items.length,0);
});
test('v2 report recomputation rejects forged results, different guidance, missing predecessor and absent marker',()=>{
 for(const mutate of [r=>r.ready=false,r=>r.model_executed=true,r=>r.factual_review_complete=true,r=>r.activation_authorized=true,r=>r.revised_guidance='other',r=>r.source_lesson=reference(9),r=>r.cases[0].checks[0].revised_passed=false,r=>r.cases[0].total=99,r=>r.cases[0].revised_output='failed',r=>r.cases[1].input=r.cases[0].input,r=>r.cases[1].kind='useful']){const c=nextContext(),v=c.binding.record.payload.revision,lines=v.reason.split('\n'),r=JSON.parse(lines.slice(1).join('\n'));mutate(r);v.reason=lines[0]+'\n'+JSON.stringify(r);assert.equal(catalog(c).items.length,0);}const c=nextContext();c.binding.record.payload.revision.reason='Ordinary authored reason';assert.equal(catalog(c).items.length,0);
});
