import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import test from 'node:test';

const html = readFileSync(process.argv[2], 'utf8');
const script = html.match(/<script id="whole-book-print-script">([\s\S]*?)<\/script>/)?.[1];
assert.ok(script, 'inspect the script actually emitted by the native renderer');

test('print is explicit and repeated clicks work without network or persistent state', () => {
  let prints = 0;
  const events = new Map();
  const button = {
    hidden: true,
    addEventListener(name, callback) {
      assert.equal(name, 'click');
      assert.equal(events.has(name), false);
      events.set(name, callback);
    },
  };
  vm.runInNewContext(script, {
    document: {getElementById(id) { assert.equal(id, 'print-book'); return button; }},
    window: {print() { prints++; }},
  }, {timeout: 1000});
  assert.equal(button.hidden, false);
  assert.equal(prints, 0);
  events.get('click')();
  events.get('click')();
  assert.equal(prints, 2);
});
