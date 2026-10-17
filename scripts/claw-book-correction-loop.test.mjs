import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

function production(name,globals={}){
 const source=readFileSync(new URL(`../ui/rabbita-book/main/${name}.mbt`,import.meta.url),'utf8');
 const code=source.split('\n').filter(v=>/^\s*#\|/.test(v)).map(v=>v.replace(/^\s*#\|\s?/, '')).join('\n');
 const fn=vm.runInNewContext(`(${code})`,globals,{timeout:1000});return q=>JSON.parse(fn(JSON.stringify(q)));
}
const csv=readFileSync(new URL('fixtures/claw-observed-cases.csv',import.meta.url),'utf8');
const fixtureSha256='0c7e9ff5aa119a0e3e4b52c54a1ce5c4572da559c20605db5aa7ca4eca7e57b7';
const reduce=production('lesson_revision_rehearsal_state');
const ctx=()=>({eligible:true,original_guidance:'State confident conclusions',binding:{change_id:'first-draft',rehearsal_epoch:'first-epoch',original:{record_id:'lesson',record_version:'2',record_digest:'accepted-fixture'},record:{payload:'accepted-source-fixture'},head:'human-review',current:'lesson2',accepted_reviews:['human-review'],reviews:['named-human'],fields:{guidance:'Preserve source citation and identify uncertainty',reason:'Correct unsupported certainty while retaining source quotations',applicability:'customer=fixture',invalidation:''}}});
const step=(state,kind,context,value)=>{
 const result=reduce({state,context,request_id:1,pending:false,action:{kind,value,expected_change:context.binding.change_id,expected_epoch:context.binding.rehearsal_epoch,expected_revision:state?.revision??null,expected_request:1}});
 assert.equal(result.error,undefined);return result;
};

test('actual Claw R627 CSV → Book import → saved correction → cold resume → recompare → ordinary staged report',()=>{
 assert.equal(createHash('sha256').update(csv).digest('hex'),fixtureSha256);
 let context=ctx(),s=step(null,'begin',context).state;s=step(s,'csv_edit',context,csv).state;s=step(s,'csv_preview',context).state;
 assert.equal(s.intake.preview.ready,true);assert.deepEqual(s.intake.preview.plan.map(x=>x.operation),['fill_empty','fill_empty']);
 s=step(s,'csv_import',context).state;
 assert.equal(s.cases.length,2);assert.equal(s.cases[0].original,'# Report, Q4\r\nSource: "observed" 001.20\r\nUncertainty: none\r\n');
 assert(s.cases[0].name.includes('run-fixture artifact=artifact-fixture v2 L1-3 sha256:c71cbb0ce9ee3cdc898e22e80229611097eedbc35d6dfa8c2aa30e3838920702'));
 assert(s.cases.every(c=>c.retained_from===undefined));
 const data=new Map(),storage=production('lesson_correction_draft_storage',{localStorage:{getItem:k=>data.get(k)??null,setItem:(k,v)=>data.set(k,v),removeItem:k=>data.delete(k)}});
 const q={workspace:'/books/fixture',lesson_id:'lesson',context,fields:{title:'Handle uncertainty',version:'3',...context.binding.fields},rehearsal:s,current:true,pristine:true,recovery:null};
 const saved=storage({...q,operation:'save'});assert.equal(saved.error,undefined);
 context=ctx();context.binding.change_id='reopened-draft';context.binding.rehearsal_epoch='reopened-epoch';
 const resumed=storage({...q,context,rehearsal:null,operation:'resume',recovery:saved.recovery});assert.equal(resumed.error,undefined);assert.equal(resumed.rehearsal.staged,false);assert.equal(resumed.rehearsal.preview,null);
 context.binding.fields={...resumed.rehearsal.binding.fields};s=step(resumed.rehearsal,'compare',context).state;assert.equal(s.preview.ready,true);
 assert.deepEqual(s.preview.cases.map(c=>[c.original_passed,c.revised_passed,c.total]),[[2,2,2],[2,3,3]]);
 const staged=step(s,'stage',context);assert.equal(staged.stage.guidance,context.binding.fields.guidance);
 const report=JSON.parse(staged.stage.reason.split('\n').slice(1).join('\n'));assert.equal(report.model_executed,false);assert.equal(report.factual_review_complete,false);assert.equal(report.activation_authorized,false);
 assert.equal(report.cases[1].original_output,s.cases[1].original);assert.equal(report.cases[1].revised_output,s.cases[1].revised);
 console.log(JSON.stringify({fixture_sha256:fixtureSha256,producer:'R627 production exportObservedCases',consumer:'R628 production CSV/rehearsal and correction storage functions',cases:2,result:'literal supplied-output comparison and staged unreviewed correction; no runtime learning or acceptance'}));
});
