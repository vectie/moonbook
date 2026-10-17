import {readFileSync} from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';

// Execute the production controller, not a duplicated test implementation.
const source = readFileSync(new URL('../ui/rabbita-book/main/lesson_comparison_state.mbt', import.meta.url), 'utf8');
const code = source.split('\n').filter(line => /^\s*#\|/.test(line)).map(line => line.replace(/^\s*#\|\s?/, '')).join('\n');
const transition = vm.runInNewContext(`(${code})`, {}, {timeout:1000});
const run = request => JSON.parse(transition(JSON.stringify(request)));
const ref = id => ({record_id:id, record_version:'1', record_digest:`sha256:${id}`});
const clone = v => JSON.parse(JSON.stringify(v));
const condition = {key:'customer_id',value:'customer-a'};
const match = id => ({
  lesson:{record:ref(id),title:`Approach ${id}`,stage:'DeliverableAcceptance',payload:{candidate_schema:'outcome_lesson.v1',outcome_lesson:{lesson_id:id,guidance:`Use ${id} then check sources.`,applicability:[condition],invalidation:[{key:'evidence_state',value:'superseded'}],outcome:ref('outcome'),assessment:ref('assessment'),assessment_review:ref('source-review')}}},
  review:{subject:ref(id),receipt:ref(`review-${id}`),stage:'DeliverableAcceptance',disposition:'Accept',requested:'Accept',review_complete:true,reviewer_kind:'Human',reviewer:{authorized:true,reviewer_id:'named-reviewer'},side_effects_applied:false,issues:[]},
  selection_review:null,
});
const context = () => {
  const query = {contract_version:'moonbook.outcome-lesson-query.v1',target_task:ref('task'),conditions:[condition]};
  return {query,retrieval:{contract_version:'moonbook.outcome-lesson-retrieval.v1',query:clone(query),matches:['a','b','c','d','e'].map(match),exclusions:[],activation_authorized:false,external_side_effects_applied:false}};
};
const empty = () => run({action:{kind:'inspect'},context:context()}).state;
const step = (state, action, ctx=context(), extra={}) => run({state,context:ctx,action:{expected_revision:state.revision,...action},...extra});
const change = (state, action, ctx) => {const result=step(state,action,ctx); assert.equal(result.error,undefined); return result.state;};
function ready(outputs=['Source: A','Source: B. Counterexample: retained.']) {
  let s=empty();
  for (const id of ['a','b']) s=change(s,{kind:'add',reference:ref(id)});
  s=change(s,{kind:'edit',field:'input',value:'Compare this fresh task, same input for both.'});
  s=change(s,{kind:'edit',field:'checks',value:' Source: \nCounterexample: retained.\n'});
  for (const [i,id] of ['a','b'].entries()) s=change(s,{kind:'edit',field:'output',reference:ref(id),value:outputs[i]});
  return s;
}

test('two accepted approaches compare exact shared checks without selecting a winner', () => {
  const input=ready(), before=JSON.stringify(input), result=step(input,{kind:'compare'});
  assert.equal(result.error,undefined);
  assert.equal(result.preview_current,true);
  assert.deepEqual(result.state.preview.rows,[{text:'Source:',passed:[true,true]},{text:'Counterexample: retained.',passed:[false,true]}]);
  assert.deepEqual(result.state.preview.scores,[{reference:ref('a'),passed:1,total:2},{reference:ref('b'),passed:2,total:2}]);
  assert.equal(result.state.preview.all_pass_count,1);
  assert.equal(result.state.preview.model_executed,false);
  assert.equal(result.state.preview.activation_authorized,false);
  assert.equal(result.selection,undefined);
  assert.equal(JSON.stringify(input),before);
});

test('explicit choice returns only exact selected reference; failing output cannot be chosen', () => {
  const state=change(ready(),{kind:'compare'});
  assert.match(step(state,{kind:'use',reference:ref('a')}).error,/does not pass/);
  const result=step(state,{kind:'use',reference:ref('b')});
  assert.deepEqual(result.selection,ref('b'));
  assert.deepEqual(result.state,state);
  assert.equal(result.selection.guidance,undefined);
  assert.equal(result.selection.output,undefined);
});

test('ties remain explicit choices; equal failure is not a winner', () => {
  const same='Source: B. Counterexample: retained.';
  const tied=change(ready([same,same]),{kind:'compare'});
  assert.equal(tied.preview.all_pass_count,2);
  for (const id of ['a','b']) assert.deepEqual(step(tied,{kind:'use',reference:ref(id)}).selection,ref(id));
  const failed=change(ready(['Source: A','Source: B']),{kind:'compare'});
  assert.equal(failed.preview.all_pass_count,0);
  assert.equal(step(failed,{kind:'use',reference:ref('b')}).selection,undefined);
});

test('all four candidates are compared; duplicate addition is idempotent and a fifth is rejected', () => {
  let state=ready();
  assert.deepEqual(change(state,{kind:'add',reference:ref('a')}),state);
  for (const id of ['c','d']) {
    state=change(state,{kind:'add',reference:ref(id)});
    state=change(state,{kind:'edit',field:'output',reference:ref(id),value:'Source: retained. Counterexample: retained.'});
  }
  assert.match(step(state,{kind:'add',reference:ref('e')}).error,/at most four/);
  state=change(state,{kind:'compare'});
  assert.equal(state.preview.rows[0].passed.length,4);
  assert.equal(state.preview.all_pass_count,3);
});

test('shortlist, input, check and output edits invalidate the exact preview', () => {
  const state=change(ready(),{kind:'compare'});
  for (const action of [{kind:'add',reference:ref('c')},{kind:'remove',reference:ref('a')},{kind:'edit',field:'input',value:'changed'},{kind:'edit',field:'checks',value:'Source:'},{kind:'edit',field:'output',reference:ref('b'),value:'changed'}]) {
    const edited=change(state,action);
    assert.equal(edited.preview,null);
    assert.equal(step(edited,{kind:'use',reference:ref('b')}).selection,undefined);
  }
});

test('changed exact task, conditions, guidance, review or current-selection reference blocks reuse and preserves outputs', () => {
  const state=change(ready(),{kind:'compare'});
  const changes=[c=>{c.query.target_task.record_digest='changed';c.retrieval.query=clone(c.query);},c=>{c.query.conditions.push({key:'new',value:'scope'});c.retrieval.query=clone(c.query);},c=>{c.retrieval.matches[1].lesson.payload.outcome_lesson.guidance='changed';},c=>{c.retrieval.matches[1].review.receipt=ref('new-review');},c=>{c.retrieval.matches[1].selection_review=ref('new-head');},c=>{c.retrieval.matches.splice(1,1);}];
  for (const alter of changes) {
    const ctx=context();alter(ctx);
    const result=step(state,{kind:'use',reference:ref('b')},ctx);
    assert.equal(result.selection,undefined);
    assert.deepEqual(result.state,state);
    assert.equal(step(state,{kind:'inspect'},ctx).preview_current,false);
  }
});

test('missing or untrusted retrieval cannot seed a shortlist', () => {
  const state=empty();
  for (const alter of [c=>{c.retrieval.activation_authorized=true;},c=>{c.retrieval.external_side_effects_applied=true;},c=>{c.retrieval.query.target_task=ref('other');},c=>{c.retrieval.matches.push(clone(c.retrieval.matches[0]));},c=>{c.query.conditions.push(condition);c.retrieval.query=clone(c.query);}]) {
    const ctx=context();alter(ctx);
    assert.ok(step(state,{kind:'add',reference:ref('a')},ctx).error);
  }
  assert.ok(step(state,{kind:'add',reference:ref('a')},null).error);
  assert.ok(step(state,{kind:'add',reference:ref('not-returned')}).error);
});

test('incomplete, rejected, automated, unauthorized and wrong-subject reviews never enter comparison', () => {
  for (const change of [r=>r.lesson.payload.candidate_schema='ordinary-artifact',r=>r.review=null,r=>r.review.disposition='Reject',r=>r.review.review_complete=false,r=>r.review.review_complete='true',r=>r.review.requested='Reject',r=>r.review.reviewer_kind='Agent',r=>r.review.reviewer.authorized=false,r=>r.review.subject=ref('other'),r=>r.review.issues=['unresolved'],r=>r.review.side_effects_applied=true,r=>r.review.receipt=null,r=>r.lesson.payload.outcome_lesson.outcome=null]) {
    const ctx=context();change(ctx.retrieval.matches[0]);
    const result=step(empty(),{kind:'add',reference:ref('a')},ctx);
    assert.ok(result.error);
    assert.equal(result.state.entries.length,0);
  }
});

test('scope and invalidation conditions are rechecked without topic broadening', () => {
  for (const alter of [c=>{c.retrieval.matches[0].lesson.payload.outcome_lesson.applicability=[{key:'customer_id',value:'other'}];},c=>{c.query.conditions.push({key:'evidence_state',value:'superseded'});c.retrieval.query=clone(c.query);}]) {
    const ctx=context();alter(ctx);
    assert.match(step(empty(),{kind:'add',reference:ref('a')},ctx).error,/outside this task scope/);
  }
});

test('repeat or stale rendered callbacks cannot remove, compare, clear or choose newer work', () => {
  const original=ready(), stale={kind:'clear',expected_revision:original.revision};
  const newer=change(original,{kind:'edit',field:'input',value:'newer'});
  assert.deepEqual(step(newer,stale).state,newer);
  assert.match(step(newer,stale).error,/changed/);
  const compared=change(newer,{kind:'compare'});
  assert.equal(step(compared,{kind:'use',reference:ref('b'),expected_revision:newer.revision}).selection,undefined);
});

test('pending host request blocks edits and duplicate use, clear, remove and compare', () => {
  const state=change(ready(),{kind:'compare'});
  for (const action of [{kind:'clear'},{kind:'remove',reference:ref('a')},{kind:'compare'},{kind:'use',reference:ref('b')},{kind:'edit',field:'input',value:'new'}]) {
    const result=step(state,action,context(),{pending:true});
    assert.deepEqual(result.state,state);
    assert.equal(result.selection,undefined);
    assert.match(result.error,/Wait/);
  }
});

test('clear and removal remain possible when context is missing or malformed', () => {
  const state=change(ready(),{kind:'compare'});
  for (const ctx of [null,{bad:true}]) {
    const cleared=change(state,{kind:'clear'},ctx);
    assert.equal(cleared.entries.length,0);
    assert.equal(cleared.input,'');
    assert.equal(cleared.preview,null);
    assert.equal(change(state,{kind:'remove',reference:ref('a')},ctx).entries.length,1);
  }
});

test('malformed checks and missing outputs fail without destroying the draft', () => {
  for (const checks of ['', '  \n', 'Source:\nSource:', Array.from({length:21},(_,i)=>String(i)).join('\n'), 'x'.repeat(513)]) {
    const draft=change(ready(),{kind:'edit',field:'checks',value:checks});
    assert.match(step(draft,{kind:'compare'}).error,/1–20/);
  }
  for (const field of ['input','output']) {
    const draft=change(ready(),{kind:'edit',field,reference:ref('a'),value:' '});
    const result=step(draft,{kind:'compare'});
    assert.match(result.error,/Supply one fixed/);
    assert.deepEqual(result.state,draft);
  }
  const one=change(ready(),{kind:'remove',reference:ref('a')});
  assert.match(step(one,{kind:'compare'}).error,/two to four/);
});

test('boundary-sized text works; oversized edits fail without truncation', () => {
  let state=ready();
  state=change(state,{kind:'edit',field:'input',value:'x'.repeat(16384)});
  assert.equal(state.input.length,16384);
  const tooLong=step(state,{kind:'edit',field:'input',value:'x'.repeat(16385)});
  assert.match(tooLong.error,/nothing was truncated/);
  assert.deepEqual(tooLong.state,state);
});

test('Unicode, inert markup and case-sensitive checks remain exact supplied data', () => {
  let state=ready(['東京 😀 <script>bad()</script>', '東京 😀 <SCRIPT>bad()</SCRIPT>']);
  state=change(state,{kind:'edit',field:'checks',value:'東京 😀\n<script>bad()</script>'});
  state=change(state,{kind:'compare'});
  assert.deepEqual(state.preview.rows[1].passed,[true,false]);
  assert.equal(state.preview.model_executed,false);
});

test('forged score cannot make a failing supplied output selectable', () => {
  const state=change(ready(),{kind:'compare'});
  state.preview.scores[0].passed=2;
  assert.equal(step(state,{kind:'use',reference:ref('a')}).selection,undefined);
});

test('identical exact retrieval reload preserves the work; key order is irrelevant', () => {
  const state=change(ready(),{kind:'compare'}), ctx=context();
  ctx.query.target_task={record_digest:'sha256:task',record_version:'1',record_id:'task'};
  assert.equal(step(state,{kind:'inspect'},ctx).preview_current,true);
  assert.deepEqual(step(state,{kind:'use',reference:ref('b')},ctx).selection,ref('b'));
});

test('bad JSON and null requests return repairable data errors', () => {
  assert.ok(JSON.parse(transition('{')).error);
  assert.ok(JSON.parse(transition('null')).error);
});
