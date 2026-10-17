import {readFileSync} from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
const source=readFileSync(new URL('../ui/rabbita-book/main/lesson_repair_state.mbt',import.meta.url),'utf8');
const code=source.split('\n').filter(v=>/^\s*#\|/.test(v)).map(v=>v.replace(/^\s*#\|\s?/, '')).join('\n');
const plan=vm.runInNewContext(`(${code})`,{}, {timeout:1000});
const run=x=>JSON.parse(plan(JSON.stringify(x)));
function fixture(){return {context:{eligible:true,binding:{head:'review1',current:'lesson1'},reference:{record_id:'l',record_version:'1',record_digest:'sha256:l'},versions:['1'],lesson:{guidance:'Keep original guidance',applicability:[{key:'customer',value:'A'}],invalidation:[{key:'state',value:'superseded'}]}},draft:{binding:{head:'review1',current:'lesson1'},fields:{'task-id':'task2','task-version':'3','task-digest':'sha256:t',observation:'Failed under an unusually short deadline',evidence:'artifact://run/receipt','conditions':'customer=A\ndeadline=short\nstate=current','exclude-key':'deadline','exclude-value':'short',version:'2'}}};}
test('counterexample narrows scope and retains exact unverified task evidence',()=>{const x=fixture(),before=JSON.stringify(x),r=run(x);assert.equal(r.error,undefined);assert.equal(r.invalidation,'state=superseded\ndeadline=short');const report=JSON.parse(r.reason.slice(r.reason.indexOf('\n')+1));assert.equal(report.task.record_digest,'sha256:t');assert.equal(report.factual_review_complete,false);assert.equal(report.model_executed,false);assert.equal(r.activation_authorized,false);assert.equal(JSON.stringify(x),before);});
for(const [name,mutate,pattern] of [
 ['outside original scope',x=>x.draft.fields.conditions='customer=B\ndeadline=short',/does not meet/],
 ['already excluded',x=>x.draft.fields.conditions+='\nstate=superseded',/unique/],
 ['old invalidation matches',x=>x.draft.fields.conditions='customer=A\ndeadline=short\nstate=superseded',/already excludes/],
 ['vacuous exclusion',x=>{x.draft.fields['exclude-key']='customer';x.draft.fields['exclude-value']='A'},/disable every/],
 ['invented failure condition',x=>x.draft.fields['exclude-value']='long',/actually present/],
 ['duplicate invalidation key',x=>{x.draft.fields['exclude-key']='state';x.draft.fields['exclude-value']='current'},/already uses/],
 ['review changed',x=>x.context.binding.head='review2',/changed/],
 ['task history request changed',x=>x.context.binding.request=2,/changed/],
 ['not eligible',x=>x.context.eligible=false,/changed/],
 ['existing version',x=>x.draft.fields.version='1',/unused version/],
 ['blank evidence',x=>x.draft.fields.evidence=' ',/Complete/],
 ['oversized observation',x=>x.draft.fields.observation='x'.repeat(8193),/8192/],
 ['malformed condition',x=>x.draft.fields.conditions='customer=A\nbad',/key=value/],
 ['newline exclusion',x=>x.draft.fields['exclude-value']='short\nother',/actually present/],
 ['unrepresentable original',x=>x.context.lesson.invalidation=[{key:'a',value:'b\nc'}],/cannot be safely/],
 ['missing exact reference',x=>delete x.context.reference.record_digest,/reload complete/],
])test(name,()=>{const x=fixture();mutate(x);assert.match(run(x).error,pattern);});
test('Unicode evidence is retained and equal bindings ignore object property order',()=>{const x=fixture();x.draft.binding={current:'lesson1',head:'review1'};x.draft.fields.observation='東京 <script> never executed';assert.ok(run(x).reason.includes('東京 <script>'));});
