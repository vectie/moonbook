import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';
const source=readFileSync(new URL('../ui/rabbita-book/main/lesson_practice_csv.mbt',import.meta.url),'utf8');
const bridge=vm.runInNewContext('('+source.split('\n').filter(l=>/^\s*#\|/.test(l)).map(l=>l.replace(/^\s*#\|\s?/, '')).join('\n')+')',{TextEncoder});
const session=()=>({previous_rounds:[{learner:'older',observations:[{before:'kept'}]}],teaching:{items:[1,2].map(i=>({snapshot:{reference:{record_id:'lesson'+i,record_version:'2',record_digest:'sha256:'+i}},exercise:'Task '+i+'\n"東京", source'}))},observations:[1,2].map(()=>({before:'',after:'',feedback:'',next_practice:''}))});
const template=s=>bridge(JSON.stringify(s),'',true);
const apply=(s,csv)=>JSON.parse(bridge(JSON.stringify(s),csv,false));
const filled=s=>template(s).replaceAll('"","","",""','"A,\n""quoted"" response","After","Check source","Try again"');
test('template round trip preserves identity, quoted multiline Unicode and history',()=>{
 const s=session(),before=JSON.stringify(s),r=apply(s,filled(s));
 assert.equal(r.workbook.observations[0].before,'A,\n"quoted" response');
 assert.deepEqual(r.workbook.teaching,s.teaching);assert.deepEqual(r.workbook.previous_rounds,s.previous_rounds);assert.equal(JSON.stringify(s),before);
});
test('partial rows fill selected observations; blank cells and exact repeats preserve authored work',()=>{
 const s=session();s.teaching.items[0].exercise='simple';s.teaching.items[1].exercise='other';s.observations[1].before='existing';
 const csv=template(s).split('\r\n').slice(0,2).join('\r\n').replace('"","","",""','"new","","",""');
 const r=apply(s,csv);assert.equal(r.workbook.observations[0].before,'new');assert.equal(r.workbook.observations[1].before,'existing');
 assert.deepEqual(apply(r.workbook,csv).workbook,r.workbook);
});
test('conflicting values refuse entire preview, without modifying original',()=>{
 const s=session();s.observations[1].after='already authored';const before=JSON.stringify(s);assert.match(apply(s,filled(s)).error,/existing response/);assert.equal(JSON.stringify(s),before);
});
test('round, exact lesson reference and task mismatches refuse',()=>{
 for(const [old,value] of [['"2","1"','"1","1"'],['lesson1','different'],['sha256:1','wrong'],['Task 1','Different task']]){const s=session();assert.match(apply(s,filled(s).replace(old,value)).error,/identity changed/);}
});
test('malformed CSV, duplicate rows and oversize observation refuse',()=>{
 const s=session();s.teaching.items=s.teaching.items.slice(0,1);s.observations=s.observations.slice(0,1);s.teaching.items[0].exercise='simple';
 for(const csv of [template(s)+'"',template(s).replace('"simple"','"simple"oops'),template(s)+template(s).split('\r\n')[1],template(s).replace('"","","",""','"'+ 'a'.repeat(16385)+'","","",""')])assert.ok(apply(s,csv).error);
});
test('BOM input accepted; header-only import is explicit refusal',()=>{
 const s=session();assert.ok(apply(s,'\ufeff'+filled(s)).workbook);assert.ok(apply(s,template(s).split('\r\n')[0]).error);
});
