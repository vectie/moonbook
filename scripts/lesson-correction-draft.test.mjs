import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const source=fs.readFileSync(new URL('../ui/rabbita-book/main/lesson_correction_draft_storage.mbt',import.meta.url),'utf8');
const code=source.split('\n').filter(v=>/^\s*#\|/.test(v)).map(v=>v.replace(/^\s*#\|\s?/, '')).join('\n');
const clone=v=>JSON.parse(JSON.stringify(v));
const context=()=>({eligible:true,binding:{change_id:'first-change',rehearsal_epoch:'first-epoch',original:{record_id:'lesson',record_version:'2',record_digest:'digest'},record:{payload:'exact accepted guidance'},current:'current',head:'head',accepted_reviews:['review'],reviews:['named human'],fields:{guidance:'Original guidance',reason:'',applicability:'customer=A',invalidation:''}}});
const fields=()=>({title:'Correction 東京 <&>',version:'3',guidance:'Original guidance',reason:'',applicability:'customer=A',invalidation:''});
const rehearsal=()=>({revision:12,staged:true,preview:{ready:true,activation_authorized:true},guidance:'Revised exact rule\n',rationale:'Keep known case and fix adverse case',cases:[{id:'case-1',kind:'useful',name:'Known case',input:'Known task',original:'Source: useful',revised:'Source: useful',required:'Source:',forbidden:'invented'},{id:'case-8',kind:'adverse',name:'Adverse',input:'Uncertain task',original:'invented',revised:'Source: uncertain',required:'Source:',forbidden:'invented'}],intake:{text:'CSV not imported yet',preview:{ready:true}}});
function fixture(){
 const data=new Map();let blocked=false,writes=0;
 const storage={getItem(k){if(blocked)throw Error('Storage denied');return data.get(k)??null;},setItem(k,v){if(blocked)throw Error('Quota exceeded');writes++;data.set(k,v);},removeItem(k){if(blocked)throw Error('Storage denied');data.delete(k);}};
 const fn=vm.runInNewContext(`(${code})`,{localStorage:storage},{timeout:1000});
 const call=(operation,extra={})=>JSON.parse(fn(JSON.stringify({operation,workspace:'/books/a',lesson_id:'lesson',context:context(),fields:fields(),current:true,pristine:true,rehearsal:rehearsal(),recovery:null,retained:{items:[]},...extra})));
 return {call,data,block(v){blocked=v;},writes:()=>writes};
}
test('explicit save and reload resume exact authoring, with fresh ownership and no carried authority',()=>{
 const f=fixture(),saved=f.call('save');assert.equal(saved.error,undefined);assert.equal(f.writes(),1);
 const checked=f.call('read');assert.equal(checked.recovery.draft.fields.title,'Correction 東京 <&>');
 const ctx=context();ctx.binding.change_id='new-change';ctx.binding.rehearsal_epoch='new-epoch';
 const resumed=f.call('resume',{rehearsal:null,recovery:checked.recovery,context:ctx});
 assert.equal(resumed.error,undefined);assert.deepEqual(resumed.fields,fields());
 assert.equal(resumed.rehearsal.guidance,rehearsal().guidance);assert.equal(resumed.rehearsal.cases[1].id,'case-2');
 assert.equal(resumed.rehearsal.binding.change_id,'new-change');assert.equal(resumed.rehearsal.binding.rehearsal_epoch,'new-epoch');
 assert.equal(resumed.rehearsal.preview,null);assert.equal(resumed.rehearsal.staged,false);assert.equal(resumed.rehearsal.intake.preview,null);
 assert.equal(resumed.rehearsal.intake.text,'CSV not imported yet');assert.equal(f.writes(),1);
 const raw=[...f.data.values()][0];assert(!raw.includes('activation_authorized'));assert(!raw.includes('first-change'));assert(!raw.includes('first-epoch'));
});
test('incomplete case and Unicode remain exact and can be completed later',()=>{
 const f=fixture(),r=rehearsal();r.cases[1].revised='';r.cases[1].required='';r.guidance='  Draft 東京\n<&>  ';
 const saved=f.call('save',{rehearsal:r});const resumed=f.call('resume',{rehearsal:null,recovery:saved.recovery});
 assert.equal(resumed.rehearsal.cases[1].revised,'');assert.equal(resumed.rehearsal.guidance,r.guidance);
});
test('separate Book workspaces and lesson identities have separate slots',()=>{
 const f=fixture();f.call('save');assert.equal(f.call('read',{workspace:'/books/b'}).recovery.raw,null);assert.equal(f.call('read',{lesson_id:'other'}).recovery.raw,null);
});
test('save will not overwrite an unchecked copy; checked explicit replace works',()=>{
 const f=fixture(),saved=f.call('save'),before=[...f.data.values()][0];assert.match(f.call('save').error,/has not been checked/);assert.equal([...f.data.values()][0],before);
 const r=rehearsal();r.rationale='new rationale';const next=f.call('save',{recovery:saved.recovery,rehearsal:r});assert.equal(next.recovery.draft.rehearsal.rationale,'new rationale');assert.equal(f.writes(),2);
});
test('another tab save invalidates old resume, replace, and forget; bytes and live draft stay intact',()=>{
 const f=fixture(),saved=f.call('save'),r=rehearsal();r.guidance='another tab';const newer=f.call('save',{recovery:saved.recovery,rehearsal:r});
 for(const operation of ['save','resume','forget'])assert.match(f.call(operation,{recovery:saved.recovery,rehearsal:operation==='resume'?null:rehearsal()}).error,/changed/);
 assert.equal([...f.data.values()][0],newer.recovery.raw);
});
test('repeat checked save is idempotent and remove preserves the caller draft',()=>{
 const f=fixture(),saved=f.call('save');assert.equal(f.call('save',{recovery:saved.recovery}).recovery.raw,saved.recovery.raw);
 const before=rehearsal(),result=f.call('forget',{recovery:saved.recovery,rehearsal:before});assert.equal(result.recovery.raw,null);assert.deepEqual(before,rehearsal());assert.equal(f.data.size,0);
 assert.match(f.call('forget',{recovery:saved.recovery}).error,/changed/);
});
test('active or independently edited fresh revisions cannot be clobbered by resume',()=>{
 const f=fixture(),saved=f.call('save');for(const extra of [{rehearsal:rehearsal()},{rehearsal:null,pristine:false}])assert.match(f.call('resume',{recovery:saved.recovery,...extra}).error,/current edits were not replaced/);
});
test('changed accepted record, current selection, history or review prevents restored learning',()=>{
 for(const key of ['record','original','current','head','accepted_reviews','reviews']){
  const f=fixture(),saved=f.call('save'),ctx=context();ctx.binding[key]='changed';const result=f.call('resume',{context:ctx,rehearsal:null,recovery:saved.recovery});assert.match(result.error,/changed/);assert.equal(result.rehearsal,undefined);assert.equal(f.data.size,1);
 }
});
test('unaccepted and stale rehearsals never save',()=>{
 const f=fixture(),ctx=context();ctx.eligible=false;assert.match(f.call('save',{context:ctx}).error,/named-human/);assert.match(f.call('save',{current:false}).error,/current contrasting/);assert.equal(f.data.size,0);
});
test('malformed, unknown-version, extra authority and oversized saved drafts are kept but not resumed',()=>{
 for(const mutate of [()=>'{',d=>JSON.stringify({...d,schema:'v9'}),d=>JSON.stringify({...d,accepted:true}),d=>{d.rehearsal.preview={ready:true};return JSON.stringify(d);},d=>{d.rehearsal.cases[0].input='x'.repeat(8193);return JSON.stringify(d);},()=> 'x'.repeat(524289)]){
  const f=fixture(),saved=f.call('save'),key=[...f.data.keys()][0],raw=mutate(clone(saved.recovery.draft));f.data.set(key,raw);const checked=f.call('read');assert.equal(checked.recovery.draft,null);assert(checked.recovery.problem);assert.equal(f.call('resume',{rehearsal:null,recovery:checked.recovery}).rehearsal,undefined);assert.equal(f.data.get(key),raw);
  assert.equal(f.call('forget',{recovery:checked.recovery}).recovery.raw,null);
 }
});
test('mismatched workspace envelope cannot be resumed from a copied storage slot',()=>{
 const f=fixture(),saved=f.call('save'),key=[...f.data.keys()][0],d=clone(saved.recovery.draft);d.workspace='/books/other';f.data.set(key,JSON.stringify(d));const checked=f.call('read');assert.equal(checked.recovery.draft,null);assert.match(checked.recovery.problem,/another Book/);
});
test('storage refusal and quota failures never claim save or alter text',()=>{
 const f=fixture();f.block(true);for(const op of ['save','read','resume','forget'])assert(f.call(op).error);assert.equal(f.data.size,0);assert.equal(f.writes(),0);
});
test('retained example provenance and immutable baseline are rechecked against current evidence',()=>{
 const f=fixture(),r=rehearsal();r.cases[0].retained_from={lesson:{record_digest:'exact'},source_kind:'single_example'};const saved=f.call('save',{rehearsal:r});
 assert.match(f.call('resume',{recovery:saved.recovery,rehearsal:null}).error,/retained example/);
 const original=clone(r.cases[0]);delete original.revised;
 const ok=f.call('resume',{recovery:saved.recovery,rehearsal:null,retained:{items:[original]}});assert.equal(ok.error,undefined);
 original.original='tampered';assert.match(f.call('resume',{recovery:saved.recovery,rehearsal:null,retained:{items:[original]}}).error,/retained example/);
});
test('invalid and oversize open data rejects atomically with no silent truncation',()=>{
 for(const mutate of [r=>r.guidance='x'.repeat(8193),r=>r.cases[0].name='x'.repeat(257),r=>r.cases[0].kind='accepted',r=>r.cases.pop(),r=>r.intake.text='x'.repeat(131073)]){const f=fixture(),r=rehearsal();mutate(r);assert(f.call('save',{rehearsal:r}).error);assert.equal(f.data.size,0);}
});
