import {readFileSync} from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
const source=readFileSync(new URL('../ui/rabbita-book/main/lesson_revision_rehearsal_state.mbt',import.meta.url),'utf8');
const code=source.split('\n').filter(v=>/^\s*#\|/.test(v)).map(v=>v.replace(/^\s*#\|\s?/, '')).join('\n');
const transition=vm.runInNewContext(`(${code})`,{}, {timeout:1000});
const run=x=>JSON.parse(transition(JSON.stringify(x)));
const clone=x=>JSON.parse(JSON.stringify(x));
const ctx=()=>({eligible:true,original_guidance:'Original rule',binding:{change_id:'draft-1',rehearsal_epoch:'epoch-1',original:{record_id:'lesson',record_version:'2',record_digest:'exact'},head:'review2',current:'lesson2',reviews:['human2'],accepted_reviews:['human1','human2'],fields:{guidance:'Revised rule',reason:'Improve adverse behavior',applicability:'customer=A',invalidation:'state=stale'}}});
const step=(state,action,{context=ctx(),pending=false,request_id=1,retained_cases}={})=>run({state,action:{expected_change:context?.binding?.change_id,expected_epoch:context?.binding?.rehearsal_epoch,expected_revision:state?.revision??null,expected_request:request_id,...action},context,pending,request_id,retained_cases});
const change=(s,a,o)=>{const r=step(s,a,o);assert.equal(r.error,undefined);return r.state;};
const initial=()=>change(null,{kind:'begin'});
const header='kind,name,input,original,revised,required,forbidden';
const useful={kind:'useful',name:'Useful <&> 東京',input:'Known task',original:'Source: retained',revised:'Source: retained',required:'Source:',forbidden:'invented'};
const adverse={kind:'adverse',name:'Adverse',input:'Ambiguous task',original:'invented',revised:'Source: uncertainty',required:'Source:\nuncertainty',forbidden:'invented'};
const quote=v=>'"'+v.replaceAll('"','""')+'"';
const csv=(rows=[useful,adverse],newline='\n')=>header+newline+rows.map(r=>Object.keys(useful).map(k=>quote(r[k])).join(',')).join(newline);
const preview=(text=csv(),state=initial(),o)=>change(change(state,{kind:'csv_edit',value:text},o),{kind:'csv_preview'},o);
const errors=s=>s.intake.preview.errors.map(e=>`${e.field}: ${e.message}`).join('\n');

test('exact production CSV flows preview, explicit atomic import, compare, and ordinary staged report',()=>{
 const base=initial(),p=preview(csv(),base);assert.deepEqual(p.cases,base.cases);assert.equal(p.intake.preview.ready,true);assert.deepEqual(p.intake.preview.plan.map(p=>[p.id,p.operation]),[['case-1','fill_empty'],['case-2','fill_empty']]);
 const imported=change(p,{kind:'csv_import'});assert.deepEqual(imported.cases.map(({id,...c})=>c),[useful,adverse]);assert.equal(imported.intake.preview,null);assert.equal(imported.preview,null);assert.equal(imported.staged,false);
 const compared=change(imported,{kind:'compare'});assert.equal(compared.preview.ready,true);const staged=step(compared,{kind:'stage'});assert.ok(staged.stage);
 const report=JSON.parse(staged.stage.reason.split('\n').slice(1).join('\n'));assert.deepEqual(report.cases.map(c=>c.input),[useful.input,adverse.input]);assert.equal(report.model_executed,false);assert.equal(report.factual_review_complete,false);assert.equal(report.activation_authorized,false);assert.deepEqual(report.source_lesson,ctx().binding.original);
});

test('BOM, CRLF, embedded multiline, escaped quotes, commas, Unicode and exact whitespace survive',()=>{
 const row={...useful,name:'  "Useful", 東京 😀  ',input:'line one,\r\n"line two"',original:'  Source:\r\n retained  ',revised:''};
 const p=preview('\ufeff'+csv([row],'\r\n')+'\r\n');assert.equal(p.intake.preview.ready,true,errors(p));assert.deepEqual(p.intake.preview.rows[0].value,row);const s=change(p,{kind:'csv_import'});assert.deepEqual(s.cases[0],{id:'case-1',...row});assert.match(step(s,{kind:'compare'}).error,/supply/);
});

test('revised output is optional at intake and stays editable through existing authoring',()=>{
 const p=preview(csv([{...useful,revised:''},adverse]));let s=change(p,{kind:'csv_import'});assert.equal(s.cases[0].revised,'');s=change(s,{kind:'edit',case_id:'case-1',field:'revised',value:'Source: retained'});assert.equal(change(s,{kind:'compare'}).preview.ready,true);
});

test('filled manual cases and retained baselines are preserved; only empty same-kind slots are used',()=>{
 const retained={id:'case-1',...useful,retained_from:{lesson:ctx().binding.original,source_case_id:'old',review_receipts:['review2']}};
 const s=initial();s.cases[0]=retained;s.cases[1]={id:'case-2',...adverse};const before=clone(s.cases);
 const p=preview(csv([{...useful,input:'Another task'},{...adverse,input:'Another adverse'}]),s);assert.equal(p.intake.preview.ready,true);assert.deepEqual(p.intake.preview.plan.map(p=>p.operation),['append','append']);const r=change(p,{kind:'csv_import'});assert.deepEqual(r.cases.slice(0,2),before);assert.equal(r.cases.length,4);
 assert.match(step(r,{kind:'edit',case_id:'case-1',field:'original',value:'changed'}).error,/read-only/);
});

test('one invalid record blocks the entire import and preserves all prior cases and guidance',()=>{
 const p=preview(csv([useful,{...adverse,kind:'typo'}]));assert.equal(p.intake.preview.ready,false);assert.match(errors(p),/exactly useful or adverse/);const failed=step(p,{kind:'csv_import'});assert.ok(failed.error);assert.deepEqual(failed.state,p);assert.equal(failed.stage,undefined);assert.deepEqual(p.cases,initial().cases);
});

for(const [label,text,pattern] of [
 ['wrong header',csv().replace('kind,name','label,name'),/Header must be exactly/],
 ['reordered header',csv().replace('kind,name','name,kind'),/Header must be exactly/],
 ['space in header',' '+csv(),/Header must be exactly/],
 ['extra header column',header+',extra\n'+csv().split('\n').slice(1).join('\n'),/more than 7/],
 ['missing column',header+'\nuseful,name,input,old,new,check',/exactly 7/],
 ['extra column',header+'\nuseful,name,input,old,new,check,,extra',/more than 7/],
 ['empty input','',/exact header/],
 ['header only',header+'\r\n',/needs 1–6/],
 ['unterminated quoted field',header+'\nuseful,"oops',/Unterminated/],
 ['junk after close quote',header+'\nuseful,"oops" x,a,b,c,d,e',/after a closing quote/],
 ['quote inside plain field',header+'\nuseful,op"ps,a,b,c,d,e',/inside an unquoted/],
 ['bare CR',csv().replace('\n','\r'),/Bare CR/],
 ['quoted bare CR',csv([{...useful,input:'a\rb'}]),/Bare CR/],
 ['extra blank record',csv()+'\n\n',/exactly 7/],
 ['null control',csv([{...useful,input:'a\0b'}]),/control character/],
 ['seven data rows',csv(Array.from({length:7},(_,i)=>({...useful,input:'task '+i}))),/exceeds 6/],
 ['8K field exceeded',csv([{...useful,input:'a'.repeat(8193)}]),/8192/],
])test('CSV rejects '+label,()=>{const p=preview(text);assert.equal(p.intake.preview.ready,false);assert.match(errors(p),pattern);assert.ok(step(p,{kind:'csv_import'}).error);});

for(const [label,fields,pattern] of [
 ['blank name',{name:'  '},/nonblank/],['long name',{name:'a'.repeat(257)},/256/],
 ['blank original',{original:''},/nonblank/],['blank input',{input:''},/nonblank/],['whitespace revised',{revised:' '},/nonblank/],
 ['unknown kind',{kind:'Useful'},/exactly/],['empty checks',{required:'',forbidden:''},/1–20/],
 ['contradictory checks',{required:'Source:',forbidden:'Source'},/contains a forbidden/],
 ['duplicate checks',{required:'Source:\nSource:'},/Duplicate/],['blank fragment',{required:'Source:\n\nnext'},/nonblank/],
 ['untrimmed fragment',{required:' Source:'},/surrounding whitespace/],['long fragment',{required:'x'.repeat(257)},/256/],
 ['21 checks',{required:Array.from({length:20},(_,i)=>'c'+i).join('\n')},/1–20/],
 ['long check field',{required:'x'.repeat(5141)},/5140/],
])test('semantic validation rejects '+label,()=>{const p=preview(csv([{...useful,...fields}]));assert.equal(p.intake.preview.ready,false);assert.match(errors(p),pattern);});

test('all row errors are visible rather than accepting valid rows from a failed batch',()=>{
 const p=preview(csv([{...useful,kind:'other',name:'',original:'',required:'',forbidden:''},{...adverse,input:''}]));assert.ok(p.intake.preview.errors.length>=5);assert.equal(p.intake.preview.rows.length,2);assert.ok(step(p,{kind:'csv_import'}).error);
});

test('duplicate CSV or existing inputs use the same trimmed identity as comparison',()=>{
 for(const rows of [[useful,{...adverse,input:' '+useful.input+' '}],[useful,useful]]){const p=preview(csv(rows));assert.match(errors(p),/duplicates/);assert.equal(p.intake.preview.ready,false);}
 const s=initial();s.cases[0]={id:'case-1',...useful};const p=preview(csv([useful]),s);assert.match(errors(p),/duplicates/);
});

test('capacity, six-row acceptance, stable IDs, and repeated import remain bounded',()=>{
 const rows=Array.from({length:6},(_,i)=>({...i%2?adverse:useful,input:'task '+i}));const p=preview(csv(rows));assert.equal(p.intake.preview.ready,true,errors(p));const s=change(p,{kind:'csv_import'});assert.equal(s.cases.length,6);assert.deepEqual(s.cases.map(c=>c.id),['case-1','case-2','case-3','case-4','case-5','case-6']);assert.ok(step(s,{kind:'csv_import'}).error);
 const excess=preview(csv([{...useful,input:'new task'}]),s);assert.match(errors(excess),/at most 6/);assert.deepEqual(step(excess,{kind:'csv_import'}).state,excess);
});

test('oversized or invalid-Unicode edit keeps prior text and cases, invalidates every approval, and requires a fresh valid edit',()=>{
 const p=preview();
 for(const value of ['x'.repeat(131073),'😀'.repeat(32769),'\ud800','\udc00']){
  const s=change(p,{kind:'csv_edit',value});assert.equal(s.intake.text,p.intake.text);assert.equal(s.intake.preview,null);assert.ok(s.intake.input_error);assert.equal(s.preview,null);assert.equal(s.staged,false);assert.deepEqual(s.cases,p.cases);assert.ok(step(s,{kind:'csv_preview'}).error);assert.ok(step(s,{kind:'csv_import'}).error);
  assert.equal(preview(csv(),s).intake.preview.ready,true);
 }
});

test('UTF8 byte bound is exact and independent of decoded field limits',()=>{
 // A valid exact-128KiB file: sixteen 8192-ish fields across six rows.
 const rows=Array.from({length:6},(_,i)=>({...i%2?adverse:useful,input:'i'+i,original:'x',revised:'x',required:'x',forbidden:''}));
 for(let i=0;i<5;i++)for(const k of ['input','original','revised'])rows[i][k]=(k==='input'?String(i):'x')+'a'.repeat(8191);
 const base=csv(rows);const remaining=131072-Buffer.byteLength(base);rows[5].original='x'.repeat(remaining+1);const exact=csv(rows);assert.equal(Buffer.byteLength(exact),131072);assert.equal(preview(exact).intake.preview.ready,true);
 const over=change(initial(),{kind:'csv_edit',value:exact+'x'});assert.match(over.intake.input_error,/131072/);assert.equal(over.intake.text,'');
});

test('edit, clear, pending, new request, stale context and old detached callbacks cannot import a prior preview',()=>{
 const p=preview(),before=clone(p);
 for(const action of [{kind:'edit',field:'guidance',value:'Changed rule'},{kind:'edit',field:'rationale',value:'New reason'},{kind:'add',case_kind:'adverse'},{kind:'csv_edit',value:csv([adverse])},{kind:'csv_clear'}]){
  const s=change(p,action);assert.equal(s.intake.preview,null);assert.ok(step(s,{kind:'csv_import'}).error);assert.ok(step(s,{kind:'csv_import',expected_revision:p.revision}).error);
 }
 assert.deepEqual(p,before);
 for(const kind of ['csv_edit','csv_preview','csv_import','csv_clear'])assert.deepEqual(step(p,{kind,value:'x'},{pending:true}).state,p);
 assert.equal(step(p,{kind:'inspect'},{pending:true}).csv_preview_current,false);
 assert.equal(step(p,{kind:'inspect'},{request_id:2}).csv_preview_current,false);
 assert.ok(step(p,{kind:'csv_import'},{request_id:2}).error);assert.ok(step(p,{kind:'csv_import',expected_request:1},{request_id:2}).error);
 assert.equal(change(p,{kind:'csv_preview'},{request_id:2}).intake.preview.ready,true);
 for(const mutate of [c=>c.eligible=false,c=>c.binding.head='new',c=>c.binding.fields.applicability='changed',c=>c.binding.rehearsal_epoch='new',c=>c.binding.original.record_digest='new']){const context=ctx();mutate(context);assert.ok(step(p,{kind:'csv_import'},{context}).error);}
});

test('forged ready flag, row text, placement plan and case values are revalidated at import',()=>{
 for(const mutate of [s=>s.intake.preview.cases[0].original='forged',s=>s.intake.preview.plan[0].operation='replace',s=>s.intake.preview.rows[0].value.name='forged',s=>s.intake.text=csv([adverse]),s=>s.intake.preview.binding='forged']){
  const s=clone(preview());mutate(s);const r=step(s,{kind:'csv_import'});assert.ok(r.error);assert.deepEqual(r.state,s);
 }
 const s=preview(csv([{...useful,kind:'bad'}]));s.intake.preview.ready=true;s.intake.preview.errors=[];assert.ok(step(s,{kind:'csv_import'}).error);
});

test('CSV clear preserves cases and exact revision text; discard/restart requires new ownership',()=>{
 const imported=change(preview(),{kind:'csv_import'}),cleared=change(imported,{kind:'csv_clear'});assert.deepEqual(cleared.cases,imported.cases);assert.equal(cleared.guidance,imported.guidance);assert.equal(cleared.intake.text,'');
 const fresh=ctx();fresh.binding.rehearsal_epoch='new';const restarted=change(null,{kind:'begin'},{context:fresh});assert.ok(step(restarted,{kind:'csv_edit',value:csv(),expected_epoch:'epoch-1'},{context:fresh}).error);
});

test('exact boundary field lengths and formula-looking markup are inert imported text',()=>{
 const fragment='x'.repeat(256),row={...useful,name:'n'.repeat(256),input:'=<script>alert("quoted")</script>\t'+'z'.repeat(8100),original:fragment,revised:fragment,required:fragment,forbidden:''};
 const p=preview(csv([row]));assert.equal(p.intake.preview.ready,true,errors(p));assert.deepEqual(change(p,{kind:'csv_import'}).cases[0],{id:'case-1',...row});
});

test('deterministic quoted-field round trips preserve all operator characters without interpretation',()=>{
 const chars=['a','東京','😀','"',',','\n','\r\n','\t','<b>',' ','=1+1'];let seed=622;
 const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed;};
 for(let n=0;n<80;n++){
  const text=()=>Array.from({length:20},()=>chars[random()%chars.length]).join('');
  const row={...useful,name:'Case '+n+' '+text(),input:'input '+text(),original:'Source: '+text(),revised:'Source: '+text()};
  const p=preview(csv([row],n%2?'\n':'\r\n'));assert.equal(p.intake.preview.ready,true,errors(p));assert.deepEqual(p.intake.preview.rows[0].value,row);
 }
});
