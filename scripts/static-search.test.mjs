// Run against the actual HTML emitted by static_search_tests, not a copied script.
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {test} from 'node:test';
import vm from 'node:vm';

const html = readFileSync(process.argv[2], 'utf8');
const dataText = html.match(/<script id="book-search-data" type="application\/json">([\s\S]*?)<\/script>/)[1];
const script = html.match(/<script id="book-search-script">([\s\S]*?)<\/script>/)[1];
const generated = JSON.parse(dataText);
class Element {
  constructor(tag) { this.tag = tag; this.children = []; this.events = {}; this.textContent = ''; this.value = ''; this.disabled = false; }
  append(...items) { this.children.push(...items); }
  replaceChildren(...items) { this.children = items; }
  addEventListener(name, handler) { this.events[name] = handler; }
  set innerHTML(_) { throw new Error('Source text must never be HTML'); }
  dispatch(name) { let prevented = false; this.events[name]({preventDefault() { prevented = true; }}); return prevented; }
}
function mount(pages = generated) {
  const ids = ['data', 'form', 'query', 'status', 'results', 'previous', 'next'];
  const elements = Object.fromEntries(ids.map(id => [id, new Element(id)]));
  elements.data.textContent = JSON.stringify(pages);
  const document = {
    getElementById(id) { assert.ok(id.startsWith('book-search-')); return elements[id.slice(12)]; },
    createElement(tag) { assert.ok(['li', 'a', 'p'].includes(tag)); return new Element(tag); },
  };
  vm.runInNewContext(script, {document, fetch() { throw Error('Unexpected network'); }}, {timeout: 2000});
  return {
    ...elements,
    search(query) { elements.query.value = query; elements.query.dispatch('input'); },
    titles() { return elements.results.children.map(item => item.children[0].textContent); },
    links() { return elements.results.children.map(item => item.children[0].href); },
    excerpts() { return elements.results.children.map(item => item.children[2].textContent); },
  };
}
const page = (title, text, href = '../chapter.html') => ({title, text, href, path: href.slice(3)});

test('native build emits exact current SUMMARY-only index and inert embedded JSON', () => {
  assert.equal(generated.length, 3);
  assert.match(generated[0].text, /six onboarding teams/);
  assert.equal(generated[1].href, '../nested/index.html');
  assert.equal(generated[1].path, 'nested/README.md');
  assert.match(generated[2].text, /<\/script><script>bad\(\)<\/script>/);
  assert.ok(!dataText.includes('<'));
  assert.ok(!html.includes('Unlisted private note'));
  assert.ok(!html.includes('src='));
  assert.match(html, /<noscript>/);
});

test('actual emitted script searches generated data and produces working nested links', () => {
  const ui = mount();
  assert.match(ui.status.textContent, /Enter words to search 3 chapters/);
  ui.search('teams');
  assert.equal(ui.titles().length, 2);
  assert.deepEqual(ui.links(), ['../intro.html', '../nested/index.html']);
  ui.search('東京');
  assert.equal(ui.titles().length, 1);
  assert.equal(ui.links()[0], '../nested/index.html');
  assert.equal(ui.form.dispatch('submit'), true);
  ui.search('[a+b]');
  assert.equal(ui.titles().length, 1);
  assert.match(ui.excerpts()[0], /<\/script><script>bad\(\)<\/script>/);
});

test('all terms must match, title matches rank first, ties retain SUMMARY order', () => {
  const ui = mount([page('First', 'AURORA teams'), page('Aurora', 'teams'), page('Third', 'aurora teams'), page('Partial', 'aurora')]);
  ui.search('  aurora\nTeams  ');
  assert.deepEqual(ui.titles(), ['Aurora', 'First', 'Third']);
  ui.search('missing');
  assert.deepEqual(ui.titles(), []);
  assert.match(ui.status.textContent, /No matching chapters/);
});

test('query punctuation is literal and hostile text remains text, URLs encode filenames', () => {
  const hostile = '</script><img onerror=bad()> & " 😀';
  const ui = mount([page(hostile, 'Literal [a+b].* and a.b \\ value', '../dir/a?# &ü.html'), page('Other', 'aaab and axb')]);
  ui.search('[a+b].*');
  assert.deepEqual(ui.titles(), [hostile]);
  assert.deepEqual(ui.links(), ['../dir/a%3F%23%20%26%C3%BC.html']);
  ui.search('a.b'); assert.deepEqual(ui.titles(), [hostile]);
  ui.search('\\'); assert.deepEqual(ui.titles(), [hostile]);
});

test('every match is reachable through pages and edited queries reset pagination', () => {
  const ui = mount(Array.from({length: 43}, (_, i) => page('Page ' + i, 'needle')));
  ui.search('needle');
  assert.equal(ui.titles().length, 20);
  assert.equal(ui.previous.disabled, true);
  assert.equal(ui.next.disabled, false);
  ui.next.dispatch('click'); assert.equal(ui.titles()[0], 'Page 20');
  ui.next.dispatch('click'); assert.deepEqual(ui.titles(), ['Page 40', 'Page 41', 'Page 42']);
  assert.equal(ui.next.disabled, true);
  assert.match(ui.status.textContent, /41–43 of 43/);
  ui.previous.dispatch('click'); assert.equal(ui.titles()[0], 'Page 20');
  ui.search('Page 42'); assert.deepEqual(ui.titles(), ['Page 42']);
  assert.equal(ui.previous.disabled, true);
});

test('empty, whitespace, oversized and over-word-count input clear old matches visibly', () => {
  const ui = mount([page('x', 'match')]);
  ui.search('match'); assert.equal(ui.titles().length, 1);
  for (const [query, notice] of [['  ', /Enter words/], ['a'.repeat(201), /200 characters/], [Array.from({length: 21}, (_, i) => 'a' + i).join(' '), /20 search words/]]) {
    ui.search(query); assert.deepEqual(ui.titles(), []); assert.match(ui.status.textContent, notice);
    assert.equal(ui.previous.disabled, true); assert.equal(ui.next.disabled, true);
  }
  const empty = mount([]); empty.search('word'); assert.match(empty.status.textContent, /No matching/);
});

test('Unicode literal matches and bounded excerpts preserve code points around late hits', () => {
  const text = '😀'.repeat(1000) + 'Résumé 東京' + '🚀'.repeat(1000);
  const ui = mount([page('Unicode', text)]);
  ui.search('RÉSUMÉ');
  assert.equal(ui.titles().length, 1);
  const excerpt = ui.excerpts()[0];
  assert.ok(excerpt.startsWith('…') && excerpt.endsWith('…'));
  assert.match(excerpt, /Résumé 東京/);
  assert.ok(Array.from(excerpt).length <= 242);
  assert.equal(excerpt.isWellFormed(), true);
  ui.search('東京'); assert.equal(ui.titles().length, 1);
});
