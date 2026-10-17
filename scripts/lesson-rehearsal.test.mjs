import {readFileSync} from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';

// Execute the exact production JS preview embedded in the Rabbita application.
// This tests the supplied-output rehearsal, not native journal admission or a model.
const source = readFileSync(new URL('../ui/rabbita-book/main/lesson_rehearsal_state.mbt', import.meta.url), 'utf8');
const code = source.split('\n').filter(line => /^\s*#\|/.test(line)).map(line => line.replace(/^\s*#\|\s?/, '')).join('\n');
const preview = vm.runInNewContext(`(${code})`, {}, {timeout: 1000});
const fixture = () => ({
  contract_version: 'moonbook.outcome-lesson-rehearsal.v1',
  lesson: {lesson_id: 'source-comparison', lesson_version: '1', guidance: 'Quote a contradiction and state acceptance separately.'},
  example_input: 'Compare the suppliers using the same retained source.',
  baseline_output: 'Source: retained. Supplier A is best.',
  corrected_output: 'Source: retained. Contradiction: capacities differ. Customer acceptance: not asserted.',
  required_text: ['Source:', 'Contradiction:', 'Customer acceptance: not asserted.'],
});
const run = value => JSON.parse(preview(JSON.stringify(value)));

test('one fixed example reports the exact check delta and no model or activation', () => {
  const value = fixture(), before = JSON.stringify(value), result = run(value);
  assert.deepEqual(result, {
    contract_version: 'moonbook.outcome-lesson-rehearsal-result.v1',
    evaluation_kind: 'operator_supplied_literal_rehearsal',
    checks: [
      {text: 'Source:', baseline_passed: true, corrected_passed: true},
      {text: 'Contradiction:', baseline_passed: false, corrected_passed: true},
      {text: 'Customer acceptance: not asserted.', baseline_passed: false, corrected_passed: true},
    ],
    baseline_passed: 1, corrected_passed: 3, total: 3, improved: true,
    model_executed: false, activation_authorized: false,
  });
  assert.equal(JSON.stringify(value), before);
  assert.deepEqual(run(value), result);
});

test('same outputs or an already passing baseline never count as improvement', () => {
  const value = fixture();
  assert.equal(run({...value, corrected_output: value.baseline_output}).improved, false);
  assert.equal(run({...value, baseline_output: value.corrected_output}).improved, false);
});

test('partial improvement and a regression both keep the save gate closed', () => {
  const value = fixture();
  const partial = run({...value, corrected_output: 'Source: retained. Contradiction: found.'});
  assert.equal(partial.corrected_passed, 2);
  assert.equal(partial.improved, false);
  const regression = run({...value, corrected_output: 'Contradiction: found. Customer acceptance: not asserted.'});
  assert.equal(regression.checks[0].corrected_passed, false);
  assert.equal(regression.improved, false);
});

test('case-sensitive exact Unicode fragments remain data', () => {
  const value = {...fixture(), required_text: ['東京 😀', '<script>throw Error("no")</script>'], baseline_output: '東京', corrected_output: '東京 😀 <script>throw Error("no")</script>'};
  assert.equal(run(value).improved, true);
  assert.equal(run({...fixture(), corrected_output: fixture().corrected_output.toLowerCase()}).improved, false);
});

test('missing text and malformed JSON are repairable errors', () => {
  for (const field of ['example_input', 'baseline_output', 'corrected_output']) {
    for (const value of ['', '  \n', null, 4]) assert.match(run({...fixture(), [field]: value}).error, /needs one example/);
  }
  assert.equal(typeof JSON.parse(preview('{')).error, 'string');
  assert.equal(typeof JSON.parse(preview('null')).error, 'string');
});

test('empty duplicate blank and excessive check lists are rejected without truncation', () => {
  for (const checks of [[], Array(21).fill('x')]) assert.match(run({...fixture(), required_text: checks}).error, /1 to 20/);
  for (const checks of [['Source:', 'Source:'], [' '], ['x'.repeat(513)], [false]]) assert.match(run({...fixture(), required_text: checks}).error, /non-blank, unique/);
});

test('exact output limit is accepted while over-limit text is rejected', () => {
  const value = {...fixture(), corrected_output: 'x'.repeat(16384), required_text: ['x']};
  assert.equal(run(value).improved, true);
  for (const field of ['example_input', 'baseline_output', 'corrected_output']) assert.match(run({...value, [field]: 'x'.repeat(16385)}).error, /exceeds 16384/);
});

test('a supplied pass claim cannot replace recomputed results', () => {
  const value = fixture();
  const result = run({...value, corrected_output: value.baseline_output, improved: true, model_executed: true, activation_authorized: true});
  assert.equal(result.improved, false);
  assert.equal(result.model_executed, false);
  assert.equal(result.activation_authorized, false);
});

test('changed output is evaluated independently instead of reusing an old pass', () => {
  const value = fixture();
  assert.equal(run(value).improved, true);
  assert.equal(run({...value, corrected_output: 'Changed after rehearsal.'}).improved, false);
  assert.equal(run(value).improved, true);
});
