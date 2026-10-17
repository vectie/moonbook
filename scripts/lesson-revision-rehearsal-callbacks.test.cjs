// Regression harness derived from the independent R597 rendered-callback reproductions.
// Reads the unmodified compiled whitebox bundle; no browser or host side effects.
'use strict';
const fs=require('fs'),vm=require('vm'),crypto=require('crypto'),test=require('node:test'),assert=require('node:assert/strict');
const bundle=process.env.BOOK_BUNDLE,code=fs.readFileSync(bundle,'utf8');
class MouseEvent {}
class Element {constructor(value){this.value=value;this.nodeType=1;}}
class HTMLInputElement extends Element {}
class HTMLSelectElement extends Element {}
const c=vm.createContext({MouseEvent,Element,HTMLInputElement,HTMLSelectElement,exports:{},process:{argv:['node','review',JSON.stringify({file_and_index:[]})],stdout:{write:()=>{}},stderr:{write:()=>{}},exit:code=>{throw Error('exit '+code)}},console,TextEncoder,TextDecoder,URL,URLSearchParams,Uint8Array,ArrayBuffer,crypto:crypto.webcrypto});
vm.runInContext(code,c,{filename:bundle,timeout:5000});
const fn=suffix=>{const keys=Object.keys(c).filter(k=>k.endsWith(suffix));if(keys.length){assert.equal(keys.length,1,suffix);return c[keys[0]];}const lexical=[...new Set([...code.matchAll(/(?:const|function)\s+([A-Za-z_$][\w$]*)/g)].map(m=>m[1]).filter(k=>k.endsWith(suffix)))];assert.equal(lexical.length,1,suffix);return vm.runInContext(lexical[0],c);};
const json=x=>JSON.parse(c._M0MPC14json4Json17stringify_2einner(x,false,0,undefined));
const step=fn('snapshot__test__step');
const rehearse=(m,k,f='',v='',id='')=>fn('revision__rehearsal__test__step_2einner')(m,k,f,v,id);
const ready=fn('revision__rehearsal__test__ready');
const draft=m=>json(m.outcome_lessons.history.change.revision_rehearsal);
const payload=m=>{const r=fn('lesson__history__payload')(m.outcome_lessons.history);assert.equal(r.$tag,1);return json(r._0);};
const map=(m,key)=>m.entries.find(e=>e?.key===key)?.value;
const walk=n=>[n,...(Array.isArray(n?._2?._0)?n._2._0.flatMap(walk):[])];
const text=n=>n._1?((n._2?._0||[]).map(text).join('')):typeof n._0==='string'?n._0:'';
function controls(model){
 const messages=[];const tree=fn('lesson__revision__rehearsal__view')(message=>({message}),model);
 const nodes=walk(tree);
 const invoke=(node,kind,event=new MouseEvent())=>{map(node._1.handlers,kind)(event,{self:null,method_table:{method_3:(_,cmd)=>messages.push(cmd.message)}});assert.equal(messages.length,1);return messages.shift();};
 return {nodes,button(label){const node=nodes.find(n=>n._0==='button'&&text(n).startsWith(label));assert(node,label);return ()=>invoke(node,'click');},input(label){const node=nodes.find(n=>n._0==='textarea'&&map(n._1.attrs,'aria-label')===label);assert(node,label);return value=>invoke(node,'input',{target:new Element(value),currentTarget:new Element(value)});}};
}

test('actual compiled stage callback keeps exact report and duplicate callback cannot mutate it',()=>{
 let m=rehearse(ready(),'compare');const before=draft(m);const old=controls(m).button('Stage exact');m=step(m,old());const p=payload(m);const report=JSON.parse(p.reason.split('\n').slice(1).join('\n'));
 assert.equal(p.lesson.guidance,before.guidance);assert.equal(report.operator_rationale,before.rationale);assert.deepEqual(report.cases.map(x=>x.input),before.cases.map(x=>x.input));assert.equal(report.model_executed,false);assert.equal(report.activation_authorized,false);assert.equal(m.outcome_lessons.pending,false);
 assert.deepEqual(payload(step(m,old())),p);
});

test('actual detached input and stage callbacks reject a newer edit within the rehearsal',()=>{
 let m=rehearse(ready(),'compare');const stale=controls(m);const oldInput=stale.input('Guidance to rehearse · exact text staged'),oldStage=stale.button('Stage exact');
 m=step(m,controls(m).input('Guidance to rehearse · exact text staged')('New current guidance'));const before=draft(m);
 m=step(m,oldInput('Late old guidance'));assert.deepEqual(draft(m),before);m=step(m,oldStage());assert.deepEqual(draft(m),before);assert.equal(fn('lesson__history__payload')(m.outcome_lessons.history).$tag,0);
});

test('discard and restart within the same revision reject input callbacks from the prior rehearsal instance',()=>{
 let m=fn('history__test__change')(fn('history__test__model_2einner')(false),'revise');m=rehearse(m,'begin');const oldInput=controls(m).input('Guidance to rehearse · exact text staged');const oldChange=m.outcome_lessons.history.change.selection_id;
 m=step(m,controls(m).button('Discard local rehearsal')());m=step(m,controls(m).button('Start contrasting-case rehearsal')());assert.equal(m.outcome_lessons.history.change.selection_id,oldChange);const expected=draft(m);
 m=step(m,oldInput('DETACHED OLD REHEARSAL GUIDANCE'));assert.deepEqual(draft(m),expected);
});

console.log(JSON.stringify({bundle_sha256:crypto.createHash('sha256').update(code).digest('hex'),mode:'Unmodified compiled MoonBit whitebox bundle in memory, actual rendered input/click callbacks and controller; no browser or host I/O'}));

test('discard callback from old rehearsal cannot remove a restarted same-revision rehearsal',()=>{
 let m=fn('history__test__change')(fn('history__test__model_2einner')(false),'revise');m=rehearse(m,'begin');const oldDiscard=controls(m).button('Discard local rehearsal');
 m=step(m,oldDiscard());m=step(m,controls(m).button('Start contrasting-case rehearsal')());const expected=draft(m);m=step(m,oldDiscard());assert.deepEqual(draft(m),expected);
});

test('compiled rendered controls stay disabled and controller refuses retained callbacks during save',()=>{
 let m=rehearse(rehearse(ready(),'compare'),'stage');const retained=controls(m).button('Discard local rehearsal');
 const outer=new (fn('Msg13OutcomeLesson'))(new (fn('OutcomeLessonMsg19SubmitHistoryChange'))());m=step(m,outer);assert.equal(m.outcome_lessons.pending,true);const expected=draft(m);
 assert(controls(m).nodes.filter(n=>['button','textarea'].includes(n._0)).every(n=>map(n._1.props,'disabled')._0===true));m=step(m,retained());assert.deepEqual(draft(m),expected);
});

test('actual old workbench input cannot modify a separately reopened ordinary revision',()=>{
 let m=ready();const oldInput=controls(m).input('Guidance to rehearse · exact text staged');const oldId=m.outcome_lessons.history.change.selection_id;
 m=step(m,new (fn('Msg13OutcomeLesson'))(new (fn('OutcomeLessonMsg20DiscardHistoryChange'))()));m=fn('history__test__change')(m,'revise');assert.notEqual(m.outcome_lessons.history.change.selection_id,oldId);m=rehearse(m,'begin');const expected=draft(m);m=step(m,oldInput('Wrong revision'));assert.deepEqual(draft(m),expected);
});

test('retained-example actual rendered click starts attributed baseline and only fresh output is editable',()=>{
 let m=fn('retained__case__test__model')();const before=JSON.stringify(m.outcome_lessons.history.data.current);
 m=step(m,controls(m).button('Reuse retained example')());const remembered=draft(m).cases[0];
 assert.equal(remembered.revised,'');assert.equal(remembered.original,'  Source: known 東京\n exact  ');assert.equal(remembered.retained_from.source_kind,'single_example');
 const ui=controls(m),input=ui.nodes.find(n=>n._0==='textarea'&&map(n._1.attrs,'aria-label')==='Supplied output using original guidance · case-1');assert.equal(map(input._1.props,'disabled')._0,true);
 m=step(m,ui.input('Supplied output using original guidance · case-1')('Detached forged baseline'));assert.deepEqual(draft(m).cases[0],remembered);
 m=step(m,controls(m).input('Supplied output using revised guidance · case-1')('Source: known fresh'));assert.equal(draft(m).cases[0].revised,'Source: known fresh');assert.equal(JSON.stringify(m.outcome_lessons.history.data.current),before);
});

test('retained-example detached callbacks cannot cross discard/restart ownership and pending save',()=>{
 let m=fn('retained__case__test__model')();const old=controls(m).button('Reuse retained example');m=step(m,old());const first=draft(m);m=step(m,old());assert.deepEqual(draft(m),first);
 m=step(m,controls(m).button('Discard local rehearsal')());const empty=draft(m);assert.equal(empty,null);m=step(m,old());assert.equal(draft(m),null);
 m=step(m,controls(m).button('Reuse retained example')());assert.equal(draft(m).cases[0].revised,'');
 m=fn('retained__case__test__ready')();const reuse=controls(m).button('Reuse retained example');m=rehearse(rehearse(m,'compare'),'stage');const p=payload(m);const report=JSON.parse(p.reason.split('\n').slice(1).join('\n'));assert.equal(report.cases[0].retained_from.source_kind,'single_example');
 m=step(m,new (fn('Msg13OutcomeLesson'))(new (fn('OutcomeLessonMsg19SubmitHistoryChange'))()));const expected=draft(m);m=step(m,reuse());assert.deepEqual(draft(m),expected);assert.equal(m.outcome_lessons.pending,true);
});

const csvText=()=>fn('case__csv__test__text')();
const csvPreview=()=>fn('case__csv__test__preview')();
const csvInput=m=>controls(m).input('CSV case set · exact pasted text');

test('CSV actual paste, preview, import, edit, compare and stage callbacks use normal payload lane',()=>{
 let m=fn('history__test__change')(fn('history__test__model_2einner')(false),'revise');m=step(m,controls(m).button('Start contrasting-case rehearsal')());
 const initial=JSON.stringify(m.outcome_lessons.history.data);m=step(m,csvInput(m)(csvText()));assert.equal(draft(m).cases[0].input,'');m=step(m,controls(m).button('Preview exact CSV cases')());assert.equal(draft(m).intake.preview.ready,true);assert.equal(draft(m).cases[0].input,'');
 const importOnce=controls(m).button('Import exact previewed cases');m=step(m,importOnce());const imported=draft(m);assert.equal(imported.cases.length,2);assert.equal(imported.cases[1].required,'Source:\nuncertainty');assert.equal(m.outcome_lessons.pending,false);assert.deepEqual(draft(step(m,importOnce())),imported);assert.equal(JSON.stringify(m.outcome_lessons.history.data),initial);
 m=step(m,controls(m).input('Case name · case-1')('Renamed imported example'));m=step(m,controls(m).button('Compare supplied outputs')());m=step(m,controls(m).button('Stage exact')());const p=payload(m),report=JSON.parse(p.reason.split('\n').slice(1).join('\n'));assert.equal(report.cases[0].name,'Renamed imported example');assert.equal(report.model_executed,false);assert.equal(report.activation_authorized,false);assert.equal(p.contract_version,'moonbook.outcome-lesson-revision.v1');
});

test('CSV actual invalid and oversized edits disarm the previously rendered import callback',()=>{
 for(const replacement of ['kind,name\nuseful,broken','x'.repeat(131073)]){
  let m=csvPreview();const oldImport=controls(m).button('Import exact previewed cases'),before=draft(m).cases;m=step(m,csvInput(m)(replacement));assert.equal(draft(m).intake.preview,null);const edited=draft(m);m=step(m,oldImport());assert.deepEqual(draft(m),edited);assert.deepEqual(draft(m).cases,before);
  if(replacement.length>131072){assert.equal(draft(m).intake.text,csvText());assert.match(draft(m).intake.input_error,/nothing was truncated/);}
  else {m=step(m,controls(m).button('Preview exact CSV cases')());assert.equal(draft(m).intake.preview.ready,false);const button=controls(m).nodes.find(n=>n._0==='button'&&text(n).startsWith('Import exact'));assert.equal(map(button._1.props,'disabled')._0,true);}
 }
});

test('CSV actual retained and manual case contents survive append import without granting retained status',()=>{
 let m=fn('retained__case__test__ready')();const before=draft(m).cases;m=step(m,csvInput(m)(csvText()));m=step(m,controls(m).button('Preview exact CSV cases')());assert.deepEqual(draft(m).intake.preview.plan.map(p=>p.operation),['append','append']);m=step(m,controls(m).button('Import exact previewed cases')());assert.deepEqual(draft(m).cases.slice(0,2),before);assert.equal(draft(m).cases.length,4);assert.equal(draft(m).cases[2].retained_from,undefined);
});

test('CSV pending refresh disables actual controls and request generation requires repreview after failure',()=>{
 let m=csvPreview();const oldImport=controls(m).button('Import exact previewed cases'),oldInput=csvInput(m);const pending=step(m,new (fn('Msg13OutcomeLesson'))(new (fn('OutcomeLessonMsg14RefreshHistory'))()));assert.equal(pending.outcome_lessons.pending,true);assert(controls(pending).nodes.filter(n=>['button','textarea'].includes(n._0)).every(n=>map(n._1.props,'disabled')._0===true));assert.deepEqual(draft(step(pending,oldImport())),draft(pending));
 m=fn('case__csv__test__failed__refresh')(m);const before=draft(m);assert.deepEqual(draft(step(m,oldImport())),before);assert.deepEqual(draft(step(m,oldInput('detached data'))),before);assert.deepEqual(draft(step(m,controls(m).button('Import exact previewed cases')())),before);m=step(m,controls(m).button('Preview exact CSV cases')());m=step(m,controls(m).button('Import exact previewed cases')());assert.equal(draft(m).cases[0].input,'Known task');
});

test('CSV old input, preview and import callbacks cannot cross discard/restart ownership',()=>{
 let m=csvPreview();const old=[csvInput(m)('detached data'),controls(m).button('Preview exact CSV cases')(),controls(m).button('Import exact previewed cases')()];m=step(m,controls(m).button('Discard local rehearsal')());m=step(m,controls(m).button('Start contrasting-case rehearsal')());const before=draft(m);for(const action of old)m=step(m,action);assert.deepEqual(draft(m),before);assert.equal(draft(m).intake.text,'');
});

test('correction rendered save and cold resume lead back to ordinary compare and review payload',()=>{
 fn('draft__storage__fixture__install')();try {
  let m=ready();const original=draft(m);m=step(m,controls(m).button('Save correction on this browser')());assert.match(m.outcome_lessons.history.notice,/saved on this browser/);
  m=fn('correction__test__fresh')(fn('history__test__model_2einner')(false));m=step(m,controls(m).button('Check saved correction')());m=step(m,controls(m).button('Resume saved correction')());
  assert.deepEqual(draft(m).cases,original.cases);assert.equal(draft(m).preview,null);assert.equal(draft(m).staged,false);assert.equal(fn('lesson__history__payload')(m.outcome_lessons.history).$tag,0);
  m=step(m,controls(m).button('Compare supplied outputs')());m=step(m,controls(m).button('Stage exact')());assert.equal(payload(m).lesson.guidance,original.guidance);
 }finally {fn('draft__storage__fixture__restore')();}
});

test('correction detached save and resume callbacks cannot overwrite later edits or restart ownership',()=>{
 fn('draft__storage__fixture__install')();try {
  let m=ready(),oldSave=controls(m).button('Save correction on this browser');m=step(m,controls(m).input('Guidance to rehearse · exact text staged')('New correction'));m=step(m,oldSave());assert.equal(fn('draft__storage__fixture__contents')(),'[]');
  m=step(m,controls(m).button('Save correction on this browser')());m=fn('correction__test__fresh')(m);m=step(m,controls(m).button('Check saved correction')());const oldResume=controls(m).button('Resume saved correction');
  m=step(m,controls(m).button('Start contrasting-case rehearsal')());const before=draft(m);m=step(m,oldResume());assert.deepEqual(draft(m),before);
 }finally {fn('draft__storage__fixture__restore')();}
});

test('correction repeated rendered save/remove is harmless and close keeps durable browser copy',()=>{
 fn('draft__storage__fixture__install')();try {
  let m=ready();const once=controls(m).button('Save correction on this browser');m=step(m,once());const raw=fn('draft__storage__fixture__contents')();m=step(m,once());assert.equal(fn('draft__storage__fixture__contents')(),raw);
  m=fn('correction__test__fresh')(m);assert.equal(fn('draft__storage__fixture__contents')(),raw);m=step(m,controls(m).button('Check saved correction')());m=step(m,controls(m).button('Resume saved correction')());const before=draft(m),remove=controls(m).button('Remove checked browser copy');m=step(m,remove());assert.equal(fn('draft__storage__fixture__contents')(),'[]');m=step(m,remove());assert.deepEqual(draft(m),before);
 }finally {fn('draft__storage__fixture__restore')();}
});

test('correction actual saved text is rendered inertly and quota failure preserves editable examples',()=>{
 fn('draft__storage__fixture__install')();try {
  let m=ready();m=step(m,controls(m).input('Your reason for the correction · operator reported')('<script>alert(1)</script>'));m=step(m,controls(m).button('Save correction on this browser')());
  const html=fn('history__test__html')(m);assert(html.includes('&lt;script&gt;'));assert(!html.includes('<script>alert(1)</script>'));
  fn('draft__storage__fixture__block')(true);const before=draft(m);m=step(m,controls(m).button('Replace checked browser copy')());assert.deepEqual(draft(m),before);assert.match(m.outcome_lessons.history.notice,/Browser correction/);
 }finally {fn('draft__storage__fixture__restore')();}
});
