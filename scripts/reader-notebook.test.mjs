import {readFileSync, writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import test from 'node:test';

// --source executes verbatim multiline JS from production MoonBit renderer strings.
// Metadata is a fixture in this mode; this does not validate native emission.
const fromSource = process.argv[2] === '--source';
function embedded(file) {
  return readFileSync(new URL('../html/' + file, import.meta.url), 'utf8').split('\n')
    .filter(line => /^\s*#\|/.test(line)).map(line => line.replace(/^\s*#\|/, '')).join('\n');
}
const html = fromSource ? '' : readFileSync(process.argv[2], 'utf8');
const data = fromSource ? {title: 'Aurora', pages: [
  {title: 'Introduction', path: 'intro.md', href: '../intro.html'},
  {title: 'Nested chapter', path: 'nested/README.md', href: '../nested/index.html'},
]} : JSON.parse(html.match(/<script id="notebook-data" type="application\/json">([\s\S]*?)<\/script>/)[1]);
const main = fromSource ? embedded('renderer_notebook.mbt') : '';
const script = fromSource ? main.replace('  show();\n  if (persistent)',
  embedded('renderer_notebook_archive.mbt') + '\n' + embedded('renderer_notebook_markdown.mbt') + '\n' + embedded('renderer_notebook_discovery.mbt') + '\n' + embedded('renderer_notebook_progress.mbt') + '\n' + embedded('renderer_notebook_progress_archive.mbt') + '\n' + embedded('renderer_notebook_recovery.mbt') + '\n' + embedded('renderer_notebook_selected_export.mbt') + '\n  show();\n  if (persistent)') :
  html.match(/<script id="notebook-script">([\s\S]*?)<\/script>/)[1];
class Element {
  value = ''; textContent = ''; hidden = false; disabled = false;
  children = []; events = new Map(); style = {};
  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this.children = children; }
  addEventListener(name, fn) { this.events.set(name, fn); }
  fire(name, event = {}) { return this.events.get(name)?.(event); }
  click() { this.fire('click'); }
  remove() {}
  focus() { this.focused = true; }
}
function boot({store = new Map(), href = 'https://example.test/library/aurora/__moonbook/notebook.html', failRead = false, failWrite = false, payload = data} = {}) {
  const ids = new Map(['notebook-selected-review', 'notebook-selected-preview', 'notebook-selected-items', 'notebook-selected-count', 'notebook-selected-message', 'notebook-selected-all', 'notebook-selected-none', 'notebook-selected-markdown', 'notebook-selected-archive', 'notebook-selected-cancel', 'notebook-archive-items', 'notebook-archive-selection', 'notebook-archive-all', 'notebook-archive-none', 'notebook-recovery-source', 'notebook-recovery-target', 'notebook-recovery-review', 'notebook-recovery-message', 'notebook-recovery-preview', 'notebook-recovery-summary', 'notebook-recovery-original', 'notebook-recovery-current', 'notebook-recovery-mode', 'notebook-recovery-result', 'notebook-recovery-apply', 'notebook-recovery-cancel', 'notebook-progress-export', 'notebook-progress-file', 'notebook-progress-preview', 'notebook-progress-summary', 'notebook-progress-items', 'notebook-progress-position', 'notebook-progress-apply', 'notebook-progress-cancel', 'notebook-progress-message', 'notebook-progress-status', 'notebook-read-toggle', 'notebook-next-unread', 'notebook-resume', 'notebook-query', 'notebook-filter', 'notebook-query-clear', 'notebook-matches', 'notebook-matches-status', 'notebook-data', 'notebook-chapters', 'notebook-note', 'notebook-status', 'notebook-save', 'notebook-export', 'notebook-open', 'notebook-archive-export', 'notebook-archive-file', 'notebook-archive-preview', 'notebook-archive-summary', 'notebook-archive-conflicts', 'notebook-archive-apply', 'notebook-archive-cancel'].map(id => [id, new Element()]));
  ids.get('notebook-data').textContent = JSON.stringify(payload);
  const downloads = [], revoked = [], writes = [], windowEvents = new Map();
  const URLShim = class extends URL {};
  URLShim.createObjectURL = blob => { downloads.push(blob); return 'blob:reading-notes'; };
  URLShim.revokeObjectURL = url => revoked.push(url);
  const body = new Element();
  vm.runInNewContext(script, {
    document: {getElementById: id => ids.get(id), createElement: () => new Element(), body},
    location: {href}, URL: URLShim, Blob,
    localStorage: {getItem: key => { if (failRead) throw Error('denied'); return store.get(key) ?? null; }, setItem: (key, val) => { if (failWrite) throw Error('quota'); writes.push([key, val]); store.set(key, val); }},
    window: {addEventListener: (name, fn) => { const previous = windowEvents.get(name); windowEvents.set(name, event => { previous?.(event); fn(event); }); }},
    setTimeout: fn => fn(),
  }, {timeout: 1000});
  return {ids, store, downloads, body, revoked, writes, windowEvents,
    edit(text) { ids.get('notebook-note').value = text; ids.get('notebook-note').fire('input'); },
    save() { ids.get('notebook-save').click(); },
    select(path) { ids.get('notebook-chapters').value = path; ids.get('notebook-chapters').fire('change'); },
    archive() { ids.get('notebook-archive-export').click(); return downloads.at(-1)?.text(); },
    import(text, options = {}) {
      ids.get('notebook-archive-file').files = [{size: Buffer.byteLength(text), text: async () => text, ...options}];
      return ids.get('notebook-archive-file').fire('change');
    },
    apply() { ids.get('notebook-archive-apply').click(); },
    cancel() { ids.get('notebook-archive-cancel').click(); },
    choices() { return ids.get('notebook-archive-conflicts').children.map(field => field.children.at(-1).children[0]); },
    export() { ids.get('notebook-export').click(); return downloads.at(-1).text(); },
  };
}

test('emitted metadata follows SUMMARY and note text survives reload and chapter navigation', () => {
  assert.equal(data.pages.length, 2);
  assert.equal(data.pages[1].path, 'nested/README.md');
  const a = boot();
  a.edit('First note 東京 😀\nSecond line'); a.save();
  a.select(data.pages[1].path);
  assert.equal(a.ids.get('notebook-note').value, '');
  assert.equal(a.ids.get('notebook-open').href, '../nested/index.html');
  a.edit('Nested note'); a.select(data.pages[0].path);
  assert.equal(a.ids.get('notebook-note').value, 'First note 東京 😀\nSecond line');
  const b = boot({store: a.store}); b.select(data.pages[1].path);
  assert.equal(b.ids.get('notebook-note').value, 'Nested note');
  b.edit(''); b.save();
  const c = boot({store: a.store}); c.select(data.pages[1].path);
  assert.equal(c.ids.get('notebook-note').value, '');
});

test('same title at another book URL has its own notebook', () => {
  const a = boot(); a.edit('Aurora private note'); a.save();
  const b = boot({store: a.store, href: 'https://example.test/library/other/__moonbook/notebook.html'});
  assert.equal(b.ids.get('notebook-note').value, '');
  b.edit('Other book note'); b.save();
  assert.equal(a.store.size, 2);
  assert.equal(boot({store: a.store}).ids.get('notebook-note').value, 'Aurora private note');
});

test('export includes unsaved text in SUMMARY order and emits inert multiline notes', async () => {
  const a = boot(); a.select(data.pages[1].path); a.edit('Nested note'); a.save();
  a.select(data.pages[0].path); a.edit('<script>bad()</script>\n東京 & complete');
  const text = await a.export();
  assert.ok(text.includes('Source: intro.md'));
  assert.ok(text.indexOf('Source: intro.md') < text.indexOf('Source: nested/README.md'));
  assert.ok(text.includes('> &lt;script&gt;bad()&lt;/script&gt;\n> 東京 &amp; complete'));
  assert.ok(text.includes('Personal reader notes; not reviewed book claims.'));
  assert.equal(a.body.children.at(-1).download, 'reading-notes.md');
  assert.deepEqual(a.revoked, ['blob:reading-notes']);
  if (process.argv[3]) writeFileSync(process.argv[3], text);
});

test('blocked storage and quota failures retain notes for export and warn on departure', async () => {
  for (const options of [{failRead: true}, {failWrite: true}]) {
    const a = boot(options); a.edit('Keep this during failure'); a.save();
    assert.match(a.ids.get('notebook-status').textContent, /tab only/);
    assert.ok((await a.export()).includes('Keep this during failure'));
    let prevented = false; const event = {preventDefault() { prevented = true; }};
    a.windowEvents.get('beforeunload')(event);
    assert.equal(prevented, true);
    assert.equal(a.store.size, 0);
  }
});

test('malformed or newer stored notebook is preserved while a tab-only notebook remains usable', async () => {
  for (const raw of ['{broken', '{"version":2,"notes":[]}', '{"version":1,"notes":[[1,"wrong"]]}']) {
    const key = 'moonbook.reader-notebook.v1:https://example.test/library/aurora/';
    const store = new Map([[key, raw]]);
    const a = boot({store}); a.edit('Temporary note'); a.save();
    assert.equal(store.get(key), raw);
    assert.ok((await a.export()).includes('Temporary note'));
  }
});

test('rebuild retains notes for renamed or removed chapters and exports them explicitly', async () => {
  const a = boot(); a.select(data.pages[1].path); a.edit('Earlier context'); a.save();
  const b = boot({store: a.store, payload: {...data, pages: [data.pages[0]]}});
  const text = await b.export();
  assert.ok(text.includes('Removed chapter: nested/README.md'));
  assert.ok(text.includes('Earlier context'));
});

test('saving one chapter merges changes and deletions from another tab', () => {
  const a = boot(); const b = boot({store: a.store});
  a.edit('First'); a.save();
  b.select(data.pages[1].path); b.edit('Second'); b.save();
  a.edit('Updated first'); a.save();
  const c = boot({store: a.store}); c.select(data.pages[1].path);
  assert.equal(c.ids.get('notebook-note').value, 'Second');
  c.edit(''); c.save();
  a.edit('Final first'); a.save();
  const d = boot({store: a.store}); d.select(data.pages[1].path);
  assert.equal(d.ids.get('notebook-note').value, '');
});

test('empty books disable editor and export a valid empty brief', async () => {
  const a = boot({payload: {...data, pages: []}});
  assert.equal(a.ids.get('notebook-note').disabled, true);
  assert.equal(a.ids.get('notebook-save').disabled, true);
  assert.equal(a.ids.get('notebook-open').hidden, true);
  assert.ok((await a.export()).startsWith('# Reading notes:'));
});


const archive = (notes, title = 'A source book') => JSON.stringify({format: 'moonbook.reader-notebook-archive', version: 1, title, notes});
const state = app => [...app.store.entries()];
const status = app => app.ids.get('notebook-status').textContent;

test('archive round trip moves exact Unicode multiline drafts to another book URL and can be edited again', async () => {
  const a = boot();
  a.select(data.pages[1].path); a.edit('Nested 😀\r\nContext & <script>literal</script>'); a.save();
  a.select(data.pages[0].path); a.edit('Unsaved 東京\nline two');
  const before = state(a);
  const text = await a.archive();
  assert.deepEqual(state(a), before, 'archive export does not implicitly save a draft');
  const payload = JSON.parse(text);
  assert.equal(payload.format, 'moonbook.reader-notebook-archive');
  assert.equal(payload.notes.length, 2);
  assert.equal(a.body.children.at(-1).download, 'reading-notebook.json');
  assert.ok(!text.includes('https://example.test/'), 'no browser URL is exported');
  const b = boot({href: 'https://other.test/moved/__moonbook/notebook.html'});
  await b.import(text);
  assert.equal(b.store.size, 0, 'preview is non-mutating');
  assert.match(b.ids.get('notebook-archive-summary').textContent, /2 new/);
  b.apply();
  assert.equal(b.ids.get('notebook-note').value, 'Unsaved 東京\nline two');
  b.select(data.pages[1].path);
  assert.equal(b.ids.get('notebook-note').value, 'Nested 😀\r\nContext & <script>literal</script>');
  b.edit('Revised after transfer'); b.save();
  const reloaded = boot({store: b.store, href: 'https://other.test/moved/__moonbook/notebook.html'});
  reloaded.select(data.pages[1].path);
  assert.equal(reloaded.ids.get('notebook-note').value, 'Revised after transfer');
  await reloaded.import(await b.archive());
  assert.match(reloaded.ids.get('notebook-archive-summary').textContent, /0 new, 2 identical, 0 conflicting/);
  reloaded.apply();
  assert.equal(JSON.parse(await reloaded.archive()).notes.length, 2, 'repeat imports do not duplicate notes');
  if (process.argv[4]) writeFileSync(process.argv[4], text);
});

test('conflicts display inert text and default to preserving current drafts; choices replace only selected notes', async () => {
  const a = boot();
  a.edit('Current first'); a.save(); a.select(data.pages[1].path); a.edit('Current nested draft');
  const before = state(a);
  const text = archive([[data.pages[0].path, 'Imported <img onerror="bad()">'], [data.pages[1].path, 'Imported nested'], ['older.md', 'Retained old note']], '<script>not executed</script>');
  await a.import(text);
  assert.deepEqual(state(a), before);
  assert.equal(a.ids.get('notebook-note').value, 'Current nested draft');
  assert.match(a.ids.get('notebook-archive-summary').textContent, /1 new, 0 identical, 2 conflicting/);
  const fields = a.ids.get('notebook-archive-conflicts').children;
  assert.equal(fields[0].children[4].textContent, 'Imported <img onerror="bad()">');
  assert.equal(a.choices()[0].value, 'keep');
  a.choices()[0].value = 'import'; a.apply();
  assert.equal(a.ids.get('notebook-note').value, 'Current nested draft');
  a.select(data.pages[0].path); assert.equal(a.ids.get('notebook-note').value, 'Imported <img onerror="bad()">');
  a.select('older.md'); assert.equal(a.ids.get('notebook-note').value, 'Retained old note');
  assert.equal(a.ids.get('notebook-open').hidden, true);
  assert.equal(a.ids.get('notebook-note').disabled, false);
  a.edit('Old note edited'); a.save();
  assert.ok((await a.export()).includes('Removed chapter: older.md'));
  assert.ok((await a.export()).includes('Old note edited'));
});

test('cancel is non-mutating and importing does not remove unrelated local notes', async () => {
  const a = boot(); a.edit('Unrelated saved note'); a.save();
  a.select(data.pages[1].path); a.edit('Unsaved unchanged');
  const before = state(a);
  await a.import(archive([['old.md', 'Incoming']])); a.cancel();
  assert.deepEqual(state(a), before);
  assert.equal(a.ids.get('notebook-note').value, 'Unsaved unchanged');
  a.apply(); assert.deepEqual(state(a), before);
  await a.import(archive([['old.md', 'Incoming']])); a.apply();
  const notes = new Map(JSON.parse(await a.archive()).notes);
  assert.equal(notes.get(data.pages[0].path), 'Unrelated saved note');
  assert.equal(notes.get(data.pages[1].path), 'Unsaved unchanged');
  assert.equal(notes.get('old.md'), 'Incoming');
});

test('edited draft or another tab change refreshes preview before any import write', async () => {
  for (const change of ['draft', 'other tab', 'other tab deletion']) {
    const a = boot(); a.edit('Before'); a.save();
    await a.import(archive([[data.pages[0].path, 'Incoming']]));
    a.choices()[0].value = 'import';
    if (change === 'draft') a.edit('New draft');
    else { const b = boot({store: a.store}); b.edit(change === 'other tab' ? 'Other tab edit' : ''); b.save(); }
    const before = state(a);
    a.apply();
    assert.deepEqual(state(a), before);
    assert.match(a.ids.get('notebook-archive-summary').textContent, /Notes changed since the preview/);
    if (a.choices().length) assert.equal(a.choices()[0].value, 'keep');
    a.ids.get('notebook-archive-all').click();
    a.apply();
    assert.equal(a.ids.get('notebook-note').value, change === 'draft' ? 'New draft' : change === 'other tab' ? 'Other tab edit' : 'Incoming');
  }
});

test('malformed, duplicate, oversized and unsupported archives preserve notes and drafts', async () => {
  const a = boot(); a.edit('Saved'); a.save(); a.edit('Draft stays');
  const before = state(a);
  const invalid = ['{broken', 'null', '{}', JSON.stringify({format:'moonbook.reader-notebook-archive',version:2,title:'Book',notes:[]}),
    archive([['x.md','a'],['x.md','b']]), archive([[3, 'number key']]), archive([['x', {}]]), archive([['', 'empty path']]),
    archive([['x'.repeat(4097),'bad path']]), archive(Array.from({length:10001},(_,i)=>['x'+i,'note'])), archive([['x','x'.repeat(5*1024*1024)]])];
  for (const text of invalid) {
    await a.import(text);
    assert.match(status(a), /Cannot import/);
    assert.equal(a.ids.get('notebook-archive-preview').hidden, true);
    assert.deepEqual(state(a), before);
    assert.equal(a.ids.get('notebook-note').value, 'Draft stays');
  }
});

test('interrupted file reads cannot restore cancelled or superseded previews', async () => {
  const a = boot();
  let finish;
  const slow = a.import('', {size: 1, text: () => new Promise(resolve => { finish = resolve; })});
  assert.equal(a.ids.get('notebook-archive-preview').hidden, false);
  assert.equal(a.ids.get('notebook-archive-apply').disabled, true);
  a.cancel(); finish(archive([['cancelled.md', 'Must not appear']])); await slow;
  assert.equal(a.ids.get('notebook-archive-preview').hidden, true);
  const slow2 = a.import('', {size: 1, text: () => new Promise(resolve => { finish = resolve; })});
  await a.import(archive([['new.md','Newest']]));
  finish(archive([['stale.md','Stale']])); await slow2;
  a.apply();
  assert.deepEqual(JSON.parse(await a.archive()).notes, [['new.md','Newest']]);
  await a.import('', {text: async () => { throw Error('Cannot read file'); }});
  assert.match(status(a), /Cannot read file/);
});

test('storage failure imports stay exportable and corrupted stored records are not overwritten', async () => {
  const key = 'moonbook.reader-notebook.v1:https://example.test/library/aurora/';
  for (const options of [{failRead:true}, {failWrite:true}, {store:new Map([[key,'{broken']])}]) {
    const a = boot(options); const before = state(a);
    await a.import(archive([[data.pages[0].path, 'Recoverable note']])); a.apply();
    assert.match(status(a), /tab only/);
    assert.equal(a.ids.get('notebook-note').value, 'Recoverable note');
    assert.deepEqual(state(a), before);
    assert.deepEqual(JSON.parse(await a.archive()).notes, [[data.pages[0].path, 'Recoverable note']]);
  }
  const a = boot(); a.edit('Local'); a.save();
  await a.import(archive([['new.md','Incoming']]));
  a.store.set(key,'{corrupt while previewing'); a.apply();
  assert.equal(a.store.get(key),'{corrupt while previewing');
  assert.match(status(a), /tab only/);
});

test('empty and removed-chapter-only books can restore and edit notes without invented source links', async () => {
  const a = boot({payload:{...data,pages:[]}});
  await a.import(archive([])); a.apply();
  assert.equal(a.ids.get('notebook-note').disabled, true);
  await a.import(archive([['gone.md','Recover me']])); a.apply();
  assert.equal(a.ids.get('notebook-note').disabled, false);
  assert.equal(a.ids.get('notebook-note').value, 'Recover me');
  assert.equal(a.ids.get('notebook-open').hidden, true);
  const b = boot({store:a.store,payload:{...data,pages:[]}});
  assert.equal(b.ids.get('notebook-note').value, 'Recover me');
});

const rows = app => app.ids.get('notebook-matches').children;
function search(app, value, filter = 'all') {
  app.ids.get('notebook-query').value = value;
  app.ids.get('notebook-filter').value = filter;
  app.ids.get('notebook-query').fire('input');
  return rows(app);
}
test('discovery searches full notes, titles and exact paths with all-term Unicode matching', () => {
  const a = boot(); a.edit('Long context '.repeat(50) + '東京 needle'); a.save();
  a.select(data.pages[1].path); a.edit('Other note'); a.save();
  assert.equal(search(a, 'INTRO needle 東京').length, 1);
  assert.match(rows(a)[0].children[2].textContent, /needle/);
  assert.equal(search(a, 'NESTED readme.md').length, 1);
  assert.equal(search(a, 'absent').length, 0);
  assert.match(a.ids.get('notebook-matches-status').textContent, /No matches/);
  a.ids.get('notebook-query-clear').click(); assert.equal(rows(a).length, 2);
  assert.equal(a.ids.get('notebook-query').focused, true);
});
test('query and filters neither save nor discard a draft; opening another match keeps it', () => {
  const a = boot(); a.select(data.pages[1].path); a.edit('Saved destination'); a.save();
  a.select(data.pages[0].path); a.edit('Unsaved new text');
  const before = state(a);
  assert.equal(search(a, 'new', 'draft').length, 1);
  rows(a)[0].children[0].click();
  assert.deepEqual(state(a), before); assert.equal(a.ids.get('notebook-note').value, 'Unsaved new text');
  assert.equal(search(a, 'new', 'saved').length, 0);
  search(a, 'destination', 'saved')[0].children[0].click();
  assert.equal(a.ids.get('notebook-note').value, 'Saved destination');
  a.select(data.pages[0].path); assert.equal(a.ids.get('notebook-note').value, 'Unsaved new text');
});
test('deleting draft removes stale text from matches without deleting saved data', () => {
  const a = boot(); a.edit('Saved text'); a.save(); const before = state(a);
  a.edit(''); assert.equal(search(a, '').length, 0); assert.deepEqual(state(a), before);
  a.save(); assert.equal(rows(a).length, 0);
});
test('imported removed notes are discoverable, inert, editable and retain path identity', async () => {
  const a = boot(); await a.import(archive([['old/<script>.md', '<img onerror=attack()> unique']])); a.apply();
  const row = search(a, 'unique', 'removed')[0];
  assert.equal(row.children[2].textContent, '<img onerror=attack()> unique');
  row.children[0].click(); assert.equal(a.ids.get('notebook-open').hidden, true);
  assert.equal(a.ids.get('notebook-chapters').value, 'old/<script>.md');
  a.edit('Edited legacy note'); a.save();
  assert.ok((await a.archive()).includes('old/<script>.md'));
  assert.equal(search(a, 'Edited', 'removed').length, 1);
});
test('other-tab saves update matches without replacing the editor draft, stale removed results are safe', () => {
  const a = boot(); const b = boot({store: a.store});
  a.edit('My draft'); b.select(data.pages[1].path); b.edit('Other tab'); b.save();
  a.windowEvents.get('storage')({key: [...b.store.keys()][0]});
  assert.equal(search(a, '').length, 2); assert.equal(a.ids.get('notebook-note').value, 'My draft');
  const key = [...b.store.keys()][0]; b.store.set(key, JSON.stringify({version: 1, notes: [['gone.md', 'Gone']]}));
  const stale = search(a, 'Gone')[0]; b.store.set(key, JSON.stringify({version: 1, notes: []}));
  stale.children[0].click(); assert.match(status(a), /no longer available/);
  assert.equal(a.ids.get('notebook-note').value, 'My draft');
});
test('tab-only discovery preserves unreadable records and navigation drafts', () => {
  const key = 'moonbook.reader-notebook.v1:https://example.test/library/aurora/';
  const store = new Map([[key, '{bad']]); const a = boot({store});
  a.edit('Tab-only first'); a.select(data.pages[1].path); a.edit('Tab-only second');
  const row = search(a, 'first')[0]; assert.match(row.children[1].textContent, /Tab-only/);
  row.children[0].click(); assert.equal(a.ids.get('notebook-note').value, 'Tab-only first');
  assert.equal(store.get(key), '{bad'); assert.equal(search(a, '', 'saved').length, 0);
});
test('empty notebook discovery has an actionable empty state and filter changes keep editor selection', () => {
  const a = boot(); assert.match(a.ids.get('notebook-matches-status').textContent, /No notes yet/);
  a.edit('Current'); a.ids.get('notebook-filter').value = 'removed'; a.ids.get('notebook-filter').fire('change');
  assert.equal(rows(a).length, 0); assert.equal(a.ids.get('notebook-note').value, 'Current');
  assert.equal(a.ids.get('notebook-chapters').value, data.pages[0].path);
});

test('opening a refreshed current-note match loads another tab save when there is no draft', () => {
  const a = boot(); a.edit('Old text'); a.save();
  const b = boot({store: a.store}); b.edit('Updated remotely'); b.save();
  search(a, 'remotely')[0].children[0].click();
  assert.equal(a.ids.get('notebook-note').value, 'Updated remotely');
});
test('quota failure while opening a match retains both notes in this tab', async () => {
  const a = boot({failWrite: true}); a.edit('First'); a.save();
  a.select(data.pages[1].path); a.edit('Second');
  search(a, 'First')[0].children[0].click();
  const exported = JSON.parse(await a.archive());
  assert.deepEqual(exported.notes, [['intro.md', 'First'], ['nested/README.md', 'Second']]);
  assert.equal(a.store.size, 0);
});
test('production renderer composes discovery and exposes labelled controls', () => {
  const source = readFileSync(new URL('../html/renderer_notebook.mbt', import.meta.url), 'utf8');
  assert.match(source, /reader_notebook_archive_script\(\) \+\s*reader_notebook_markdown_script\(\) \+\s*reader_notebook_discovery_script\(\) \+/);
  for (const id of ['notebook-query', 'notebook-filter']) {
    assert.ok(source.includes('for="' + id + '"')); assert.ok(source.includes('id="' + id + '"'));
  }
  assert.ok(source.includes('id="notebook-matches-status" role="status" aria-live="polite"'));
});

const progressKey = 'moonbook.reader-progress.v1:https://example.test/library/aurora/';
const progressText = app => app.ids.get('notebook-progress-status').textContent;
const progress = app => JSON.parse(app.store.get(progressKey));
const mark = app => app.ids.get('notebook-read-toggle').click();
const next = app => app.ids.get('notebook-next-unread').click();

test('reading progress explicitly marks and unmarks chapters, independently of notes', () => {
  const a = boot();
  assert.match(progressText(a), /0 of 2 chapters/);
  assert.equal(a.store.size, 0, 'opening notebook does not write progress');
  a.ids.get('notebook-open').click();
  assert.deepEqual(progress(a), {version: 1, read: [], last: 'intro.md'});
  mark(a);
  assert.deepEqual(progress(a).read, ['intro.md']);
  assert.match(a.ids.get('notebook-read-toggle').textContent, /unread/);
  mark(a);
  assert.deepEqual(progress(a).read, []);
  assert.equal(a.store.has('moonbook.reader-notebook.v1:https://example.test/library/aurora/'), false);
});

test('next unread follows SUMMARY, wraps, preserves drafts and supports completion and rereading', () => {
  const a = boot(); a.edit('Keep draft when advancing'); mark(a); next(a);
  assert.equal(a.ids.get('notebook-chapters').value, 'nested/README.md');
  assert.equal(a.ids.get('notebook-note').value, '');
  mark(a);
  assert.match(progressText(a), /2 of 2.*All chapters/);
  assert.equal(a.ids.get('notebook-next-unread').disabled, true);
  a.select('intro.md'); assert.equal(a.ids.get('notebook-note').value, 'Keep draft when advancing');
  mark(a); a.select('nested/README.md'); next(a);
  assert.equal(a.ids.get('notebook-chapters').value, 'intro.md');
  assert.equal(a.ids.get('notebook-next-unread').disabled, false);
});

test('reload resumes exact path; manual resume preserves another chapter draft', () => {
  const a = boot(); a.select('nested/README.md'); a.ids.get('notebook-open').click();
  const b = boot({store: a.store});
  assert.equal(b.ids.get('notebook-chapters').value, 'nested/README.md');
  b.select('intro.md'); b.edit('Temporary introduction'); b.ids.get('notebook-resume').click();
  assert.equal(b.ids.get('notebook-chapters').value, 'nested/README.md');
  b.select('intro.md'); assert.equal(b.ids.get('notebook-note').value, 'Temporary introduction');
  assert.deepEqual(progress(b).read, [], 'resume never implicitly marks a chapter read');
});

test('same-chapter next and resume retain unsaved editor text', () => {
  const a = boot(); a.select('nested/README.md'); mark(a); a.select('intro.md');
  a.ids.get('notebook-open').click(); a.edit('Unsaved current chapter');
  a.ids.get('notebook-resume').click(); next(a);
  assert.equal(a.ids.get('notebook-note').value, 'Unsaved current chapter');
  assert.match(a.ids.get('notebook-status').textContent, /Unsaved note/);
});

test('progress remains URL-scoped, title changes retain identity, removed chapters do not affect counts', () => {
  const a = boot(); mark(a); a.select('nested/README.md'); mark(a);
  const other = boot({store: a.store, href: 'https://example.test/other/__moonbook/notebook.html'});
  assert.match(progressText(other), /0 of 2/);
  const changed = boot({store: a.store, payload: {...data, pages: [{...data.pages[0], title: 'New title'}, {title: 'New', path: 'new.md', href: '../new.html'}]}});
  assert.match(progressText(changed), /1 of 2/);
  assert.equal(changed.ids.get('notebook-chapters').value, 'intro.md');
  assert.equal(changed.ids.get('notebook-resume').disabled, true);
  next(changed); assert.equal(changed.ids.get('notebook-chapters').value, 'new.md');
  assert.ok(progress(changed).read.includes('nested/README.md'), 'removed read identity is retained');
});

test('other-tab changes merge and refresh without switching selected chapter or overwriting drafts', () => {
  const a = boot(), b = boot({store: a.store});
  mark(a); b.select('nested/README.md'); mark(b);
  assert.deepEqual(progress(b).read, ['intro.md', 'nested/README.md']);
  a.edit('Draft during remote progress');
  a.windowEvents.get('storage')({key: progressKey});
  assert.match(progressText(a), /2 of 2/);
  assert.equal(a.ids.get('notebook-chapters').value, 'intro.md');
  assert.equal(a.ids.get('notebook-note').value, 'Draft during remote progress');
  mark(a); assert.deepEqual(progress(a).read, ['nested/README.md']);
  a.store.delete(progressKey); a.windowEvents.get('storage')({key: null});
  assert.match(progressText(a), /0 of 2/);
});

test('progress storage denial and quota errors keep tab state and warn before leaving', () => {
  for (const options of [{failRead: true}, {failWrite: true}]) {
    const a = boot(options); mark(a); next(a);
    assert.match(progressText(a), /1 of 2.*tab only/);
    assert.equal(a.store.size, 0);
    let warned = false;
    a.windowEvents.get('beforeunload')({preventDefault() { warned = true; }});
    assert.equal(warned, true);
  }
});

test('unknown or malformed progress is retained while notes and tab-only reading remain useful', () => {
  for (const raw of ['broken', '{"version":2,"read":[],"last":""}', '{"version":1,"read":["intro.md","intro.md"],"last":""}']) {
    const store = new Map([[progressKey, raw]]), a = boot({store});
    a.edit('Working note'); a.save(); mark(a); next(a);
    assert.equal(store.get(progressKey), raw);
    assert.match(progressText(a), /1 of 2.*tab only/);
    a.select('intro.md'); assert.equal(a.ids.get('notebook-note').value, 'Working note');
  }
});

test('empty books and removed-note selection cannot mark or invent reading destinations', async () => {
  const a = boot({payload: {...data, pages: []}});
  for (const id of ['notebook-read-toggle', 'notebook-next-unread', 'notebook-resume']) assert.equal(a.ids.get(id).disabled, true);
  mark(a); next(a); assert.equal(a.store.size, 0);
  const b = boot(); await b.import(archive([['removed.md', 'Old note']])); b.apply(); b.select('removed.md');
  assert.equal(b.ids.get('notebook-read-toggle').disabled, true);
  mark(b); assert.equal(b.store.has(progressKey), false);
  next(b); assert.equal(b.ids.get('notebook-chapters').value, 'intro.md');
});

test('notebook archive remains notes-only and does not import another readers progress', async () => {
  const a = boot(); a.edit('A note'); mark(a);
  const exported = JSON.parse(await a.archive());
  assert.equal(Object.hasOwn(exported, 'read'), false);
  const b = boot(); await b.import(JSON.stringify(exported)); b.apply();
  assert.match(progressText(b), /0 of 2/);
});

test('progress controls are composed into the real generated notebook with inert status text', () => {
  const source = readFileSync(new URL('../html/renderer_notebook.mbt', import.meta.url), 'utf8');
  assert.match(source, /reader_notebook_progress_script\(\) \+/);
  for (const id of ['notebook-progress-status', 'notebook-read-toggle', 'notebook-next-unread', 'notebook-resume']) assert.ok(source.includes('id="' + id + '"'));
  const a = boot({payload: {...data, pages: [{...data.pages[0], title: '<img src=x onerror=bad()>'}]}});
  a.ids.get('notebook-open').click();
  assert.ok(progressText(a).includes('<img src=x onerror=bad()>'));
  assert.equal(a.ids.get('notebook-progress-status').children.length, 0);
});

test('external Markdown edit previews exact paths, selects a conflict, reloads and reexports', async () => {
  const a = boot(); a.edit('First original'); a.save();
  a.select('nested/README.md'); a.edit('Second original'); a.save();
  const original = await a.export();
  const edited = original.replace('> First original', '> Revised outside MoonBook\n> A second line')
    .replace('> Second original', '> Second external edit')
    .replace('## Introduction', '## Renamed display heading')
    .replace('Source: intro.md', 'Source: a/display-only-name.md');
  const before = state(a);
  await a.import(edited);
  assert.deepEqual(state(a), before, 'reading and previewing Markdown changes nothing');
  assert.match(a.ids.get('notebook-archive-summary').textContent, /Edited Markdown from.*0 new, 0 identical, 2 conflicting/);
  assert.deepEqual(a.choices().map(choice => choice.value), ['keep', 'keep']);
  assert.equal(a.ids.get('notebook-archive-conflicts').children[0].children[0].textContent, 'intro.md');
  a.choices()[0].value = 'import'; a.apply();
  const b = boot({store: a.store});
  assert.equal(b.ids.get('notebook-note').value, 'Revised outside MoonBook\nA second line');
  b.select('nested/README.md'); assert.equal(b.ids.get('notebook-note').value, 'Second original');
  const again = await b.export();
  assert.ok(again.includes('> Revised outside MoonBook\n> A second line'));
  assert.ok(!again.includes('a/display-only-name.md'));
  await b.import(again);
  assert.match(b.ids.get('notebook-archive-summary').textContent, /0 new, 2 identical, 0 conflicting/);
  const source = readFileSync(new URL('../html/renderer_notebook.mbt', import.meta.url), 'utf8');
  assert.match(source, /Import notebook archive or edited Markdown/);
  assert.match(source, /accept="\.json,\.md,/);
});

test('Markdown preserves LF note text and exact Unicode path identities with inert metadata', async () => {
  const path = 'notes/東京 [draft] "a" & --> <script>.md';
  const payload = {title: 'Notebook --> <script> & 東京', pages: [{title: 'Same title', path, href: '../notes/a.html'}]};
  const a = boot({payload});
  const text = '  leading spaces\n\n# Heading\n> quoted text\n<!-- /moonbook.note -->\n<script>text only</script> & &lt; &#62;\n```md\ntrailing spaces  \n```\n';
  a.edit(text);
  const exported = await a.export();
  const metadata = exported.split('\n').filter(line => line.startsWith('<!-- moonbook.'));
  assert.equal(metadata.length, 2);
  assert.ok(metadata.every(line => !line.slice(4, -3).includes('<') && !line.slice(4, -3).includes('>')));
  const b = boot({payload, href: 'https://other.test/book/__moonbook/notebook.html'});
  await b.import(exported); b.apply();
  assert.equal(b.ids.get('notebook-note').value, text);
  assert.deepEqual(JSON.parse(await b.archive()).notes, [[path, text]]);
  assert.equal(await b.export(), exported, 'supported LF text and metadata round-trip exactly');
});

test('external file section omission keeps local notes; removed paths stay explicitly unbound', async () => {
  const a = boot(); a.edit('Local note stays'); a.save();
  a.select('nested/README.md'); a.edit('Draft stays');
  const old = boot({payload: {title: 'Old book', pages: [{title: 'Introduction', path: 'old-name.md', href: '../old.html'}]}});
  old.edit('Note from before a chapter rename'); const text = await old.export();
  const before = state(a);
  await a.import(text); a.cancel();
  assert.deepEqual(state(a), before); assert.equal(a.ids.get('notebook-note').value, 'Draft stays');
  await a.import(text);
  assert.match(a.ids.get('notebook-archive-summary').textContent, /1 new.*1 notes refer to paths outside/);
  a.apply();
  const restored = new Map(JSON.parse(await a.archive()).notes);
  assert.equal(restored.get('intro.md'), 'Local note stays');
  assert.equal(restored.get('nested/README.md'), 'Draft stays');
  assert.equal(restored.get('old-name.md'), 'Note from before a chapter rename');
  a.select('old-name.md'); assert.equal(a.ids.get('notebook-open').hidden, true);
  assert.ok((await a.export()).includes('Removed chapter: old-name.md'));
});

test('a concurrent edit refreshes Markdown conflict review without changing reading progress', async () => {
  const a = boot(); a.edit('Original'); a.save(); mark(a);
  const progressBefore = a.store.get(progressKey);
  const edited = (await a.export()).replace('> Original', '> Outside change');
  await a.import(edited); a.choices()[0].value = 'import';
  const b = boot({store: a.store}); b.edit('Newer local text'); b.save();
  const before = state(a); a.apply();
  assert.deepEqual(state(a), before); assert.match(a.ids.get('notebook-archive-summary').textContent, /Notes changed since the preview/);
  assert.equal(a.choices()[0].value, 'keep');
  assert.equal(a.ids.get('notebook-archive-conflicts').children[0].children[2].textContent, 'Newer local text');
  a.ids.get('notebook-archive-all').click(); a.choices()[0].value = 'import'; a.apply();
  assert.equal(a.ids.get('notebook-note').value, 'Outside change');
  assert.equal(a.store.get(progressKey), progressBefore);
});

test('damaged edited Markdown reports a repair location with no partial note import', async () => {
  const source = boot(); source.edit('First'); source.save(); source.select('nested/README.md'); source.edit('Second');
  const text = await source.export();
  const a = boot(); a.edit('Private unsaved draft'); const before = state(a);
  const damaged = text.replace('> Second', 'Second was accidentally unquoted');
  await a.import(damaged);
  assert.match(status(a), /Markdown line \d+: Prefix every note line/);
  assert.equal(a.ids.get('notebook-archive-preview').hidden, true);
  assert.deepEqual(state(a), before); assert.equal(a.ids.get('notebook-note').value, 'Private unsaved draft');
  // A section that lost its end marker must not silently absorb the next chapter.
  await a.import(text.replace('<!-- /moonbook.note -->', ''));
  assert.match(status(a), /Cannot import notes: Markdown line/); assert.deepEqual(state(a), before);
  // Older unmarked briefs have no exact import identity and require a fresh export.
  await a.import('# Reading notes: Older export\n\nPersonal reader notes; not reviewed book claims.\n\n## Introduction\n\nSource: intro.md\n\n> Older text\n');
  assert.match(status(a), /Keep the book identity comment from a current MoonBook Markdown export/);
  await a.import(text.replace('"path":"nested/README.md"', '"path":"intro.md"'));
  assert.match(status(a), /Invalid or duplicate chapter note/); assert.deepEqual(state(a), before);
});

test('text-editor CRLF and blank-quote normalization import locally and remain exportable after storage failure', async () => {
  const a = boot(); a.edit('First\r\n\r\nLast\r\n');
  const edited = '\uFEFF' + (await a.export()).replaceAll('> \n', '>\n').replaceAll('\n', '\r\n');
  const b = boot({failWrite: true});
  await b.import(edited); b.apply();
  assert.equal(b.ids.get('notebook-note').value, 'First\n\nLast\n');
  assert.match(status(b), /this tab only/); assert.equal(b.store.size, 0);
  b.edit('Revised in tab\n');
  const savedCopy = await b.export();
  const c = boot(); await c.import(savedCopy); c.apply();
  assert.equal(c.ids.get('notebook-note').value, 'Revised in tab\n');
});

// Portable progress runs the same composed production notebook as the notes cases.
const progressStoreKey = 'moonbook.reader-progress.v1:https://example.test/library/aurora/';
const progressPacket = (read = ['intro.md'], last = 'intro.md', title = 'Aurora') => JSON.stringify({
  format: 'moonbook.reader-progress-archive', version: 1, title, read, last,
});
function importProgress(a, text, options = {}) {
  a.ids.get('notebook-progress-file').files = [{size: Buffer.byteLength(text), text: async () => text, ...options}];
  return a.ids.get('notebook-progress-file').fire('change');
}
function applyProgress(a, usePosition = false) {
  a.ids.get('notebook-progress-position').checked = usePosition;
  a.ids.get('notebook-progress-apply').click();
}
async function exportProgress(a) {
  a.ids.get('notebook-progress-export').click();
  return a.downloads.at(-1).text();
}

test('progress export moves read marks and optional resume position between ordinary sessions and reloads', async () => {
  const source = boot();
  source.ids.get('notebook-read-toggle').click();
  source.select('nested/README.md'); source.ids.get('notebook-open').click();
  source.edit('Private unsaved note is never included');
  const text = await exportProgress(source);
  assert.deepEqual(JSON.parse(text), {format: 'moonbook.reader-progress-archive', version: 1, title: 'Aurora', read: ['intro.md'], last: 'nested/README.md'});
  assert.equal(source.body.children.at(-1).download, 'reading-progress.json');
  assert.equal(source.ids.get('notebook-note').value, 'Private unsaved note is never included');
  const href = 'https://example.test/moved/book/__moonbook/notebook.html';
  const target = boot({href}); target.edit('My destination draft');
  await importProgress(target, text);
  assert.equal(target.store.size, 0);
  assert.match(target.ids.get('notebook-progress-summary').textContent, /1 new read marks/);
  assert.equal(target.ids.get('notebook-progress-position').checked, false);
  applyProgress(target, true);
  assert.equal(target.ids.get('notebook-chapters').value, 'intro.md');
  assert.equal(target.ids.get('notebook-note').value, 'My destination draft');
  assert.equal(target.store.size, 1); // Progress only, never saves the draft.
  const reopened = boot({href, store: target.store});
  assert.equal(reopened.ids.get('notebook-chapters').value, 'nested/README.md');
  assert.match(reopened.ids.get('notebook-progress-status').textContent, /1 of 2/);
  assert.deepEqual(JSON.parse(await exportProgress(reopened)), JSON.parse(text));
  reopened.ids.get('notebook-next-unread').click();
  assert.equal(reopened.ids.get('notebook-chapters').value, 'nested/README.md');
});

test('progress merge preserves existing marks, position and saved notes; repeat import is idempotent', async () => {
  const a = boot(); a.edit('Saved source note'); a.save();
  a.select('nested/README.md'); a.ids.get('notebook-read-toggle').click();
  const noteKey = [...a.store.keys()].find(key => key.includes('reader-notebook'));
  const noteBytes = a.store.get(noteKey);
  await importProgress(a, progressPacket()); applyProgress(a);
  let saved = JSON.parse(a.store.get(progressStoreKey));
  assert.deepEqual(saved, {version: 1, read: ['nested/README.md', 'intro.md'], last: 'nested/README.md'});
  await importProgress(a, progressPacket());
  assert.match(a.ids.get('notebook-progress-summary').textContent, /0 new read marks, 1 already marked/);
  applyProgress(a);
  assert.deepEqual(JSON.parse(a.store.get(progressStoreKey)), saved);
  assert.equal(a.store.get(noteKey), noteBytes);
  await importProgress(a, progressPacket([], '')); applyProgress(a);
  assert.deepEqual(JSON.parse(a.store.get(progressStoreKey)), saved);
});

test('progress preview and cancel preserve draft and exact stored bytes, including interrupted file reads', async () => {
  const a = boot(); a.ids.get('notebook-read-toggle').click(); a.edit('Unwritten draft');
  const before = [...a.store];
  await importProgress(a, progressPacket(['nested/README.md']));
  a.ids.get('notebook-progress-cancel').click(); applyProgress(a);
  assert.deepEqual([...a.store], before);
  assert.equal(a.ids.get('notebook-note').value, 'Unwritten draft');
  let release;
  const pending = importProgress(a, '{}', {text: () => new Promise(resolve => { release = resolve; })});
  assert.equal(a.ids.get('notebook-progress-preview').hidden, false);
  assert.equal(a.ids.get('notebook-progress-apply').disabled, true);
  a.ids.get('notebook-progress-cancel').click(); release(progressPacket()); await pending;
  assert.equal(a.ids.get('notebook-progress-preview').hidden, true);
  assert.deepEqual([...a.store], before);
});

test('newer progress file selection wins over an earlier slow file', async () => {
  const a = boot(); let release;
  const first = importProgress(a, '{}', {text: () => new Promise(resolve => { release = resolve; })});
  await importProgress(a, progressPacket(['nested/README.md'], 'nested/README.md', 'Newer'));
  release(progressPacket(['intro.md'], 'intro.md', 'Older')); await first;
  assert.match(a.ids.get('notebook-progress-summary').textContent, /From book: Newer/);
  applyProgress(a, true);
  assert.deepEqual(JSON.parse(a.store.get(progressStoreKey)).read, ['nested/README.md']);
});

test('removed and Unicode paths remain exact annotations with no guessed links or resume target', async () => {
  const a = boot(); const unknown = '../removed/東京 <script>.md';
  await importProgress(a, progressPacket([unknown, 'INTRO.md'], unknown, '<img onerror=bad()>'));
  assert.match(a.ids.get('notebook-progress-summary').textContent, /2 removed or unknown paths/);
  assert.ok(a.ids.get('notebook-progress-summary').textContent.includes('<img onerror=bad()>'));
  assert.equal(a.ids.get('notebook-progress-position').disabled, true);
  const item = a.ids.get('notebook-progress-items').children[0];
  assert.equal(item.children.length, 0); assert.equal(item.href, undefined);
  applyProgress(a, true);
  assert.deepEqual(JSON.parse(a.store.get(progressStoreKey)), {version: 1, read: [unknown, 'INTRO.md'], last: ''});
  assert.match(a.ids.get('notebook-progress-status').textContent, /0 of 2/);
  assert.equal(a.ids.get('notebook-resume').disabled, true);
  const archive = JSON.parse(await exportProgress(a)); assert.deepEqual(archive.read, [unknown, 'INTRO.md']);
});

test('changed reading progress refreshes import review and resets optional position choice before applying', async () => {
  const a = boot(); await importProgress(a, progressPacket());
  a.ids.get('notebook-progress-position').checked = true;
  a.store.set(progressStoreKey, JSON.stringify({version: 1, read: ['nested/README.md'], last: 'nested/README.md'}));
  a.ids.get('notebook-progress-apply').click();
  assert.match(a.ids.get('notebook-progress-message').textContent, /changed during preview/);
  assert.equal(a.ids.get('notebook-progress-position').checked, false);
  assert.deepEqual(JSON.parse(a.store.get(progressStoreKey)).read, ['nested/README.md']);
  applyProgress(a);
  assert.deepEqual(JSON.parse(a.store.get(progressStoreKey)), {version: 1, read: ['nested/README.md', 'intro.md'], last: 'nested/README.md'});
});

test('malformed progress imports never partially modify notes or read marks', async () => {
  const valid = JSON.parse(progressPacket());
  for (const text of ['broken', JSON.stringify({...valid, version: 2}), JSON.stringify({...valid, read: ['intro.md', 'intro.md']}),
    JSON.stringify({...valid, read: ['intro.md', 4]}), JSON.stringify({...valid, read: ['']}),
    JSON.stringify({...valid, last: 6}), JSON.stringify({...valid, title: 'a'.repeat(4097)}),
    JSON.stringify({...valid, read: ['a'.repeat(4097)]}), JSON.stringify({...valid, read: Array.from({length: 10001}, (_, i) => `${i}.md`)})]) {
    const a = boot(); a.edit('Keep draft'); const before = [...a.store];
    await importProgress(a, text); applyProgress(a);
    assert.match(a.ids.get('notebook-progress-message').textContent, /Could not import/);
    assert.deepEqual([...a.store], before); assert.equal(a.ids.get('notebook-note').value, 'Keep draft');
  }
  const a = boot(); await importProgress(a, progressPacket(), {size: 5 * 1024 * 1024 + 1});
  assert.match(a.ids.get('notebook-progress-message').textContent, /exceeds 5 MiB/);
  await importProgress(a, ' '.repeat(5 * 1024 * 1024 + 1), {size: 1});
  assert.match(a.ids.get('notebook-progress-message').textContent, /exceeds 5 MiB/);
});

test('unreadable progress and denied storage keep imported marks usable and exportable without overwriting originals', async () => {
  for (const options of [{failRead: true}, {failWrite: true}, {store: new Map([[progressStoreKey, '{broken']])}]) {
    const a = boot(options); const before = [...a.store];
    await importProgress(a, progressPacket()); applyProgress(a, true);
    assert.match(a.ids.get('notebook-progress-message').textContent, /tab only/);
    assert.match(a.ids.get('notebook-progress-status').textContent, /1 of 2/);
    assert.deepEqual([...a.store], before);
    assert.deepEqual(JSON.parse(await exportProgress(a)).read, ['intro.md']);
    let warned = false; a.windowEvents.get('beforeunload')({preventDefault() { warned = true; }});
    assert.equal(warned, true);
  }
});

test('progress export merges latest other-tab state, and over-limit merge leaves stored bytes intact', async () => {
  const a = boot();
  a.store.set(progressStoreKey, JSON.stringify({version: 1, read: ['nested/README.md'], last: 'nested/README.md'}));
  assert.deepEqual(JSON.parse(await exportProgress(a)).read, ['nested/README.md']);
  const full = {version: 1, read: Array.from({length: 10000}, (_, i) => `old-${i}.md`), last: ''};
  a.store.set(progressStoreKey, JSON.stringify(full));
  await importProgress(a, progressPacket()); applyProgress(a);
  assert.match(a.ids.get('notebook-progress-message').textContent, /exceeds 10,000/);
  assert.equal(a.store.get(progressStoreKey), JSON.stringify(full));
});

test('empty current book can preserve removed read marks without inventing chapters or position', async () => {
  const a = boot({payload: {title: 'Empty', pages: []}});
  await importProgress(a, progressPacket()); applyProgress(a, true);
  assert.equal(a.ids.get('notebook-chapters').value, '');
  assert.equal(a.ids.get('notebook-open').hidden, true);
  assert.equal(a.ids.get('notebook-resume').disabled, true);
  assert.match(a.ids.get('notebook-progress-status').textContent, /0 of 0/);
  assert.deepEqual(JSON.parse(await exportProgress(a)).read, ['intro.md']);
});

test('portable progress controls are wired into production renderer composition', () => {
  if (!fromSource) return;
  const renderer = readFileSync(new URL('../html/renderer_notebook.mbt', import.meta.url), 'utf8');
  assert.match(renderer, /reader_notebook_progress_script\(\) \+\s*reader_notebook_progress_archive_script\(\)/);
  for (const id of ['export', 'file', 'preview', 'summary', 'items', 'position', 'apply', 'cancel', 'message']) {
    assert.ok(renderer.includes(`id="notebook-progress-${id}"`));
  }
});

const notebookKey = 'moonbook.reader-notebook.v1:https://example.test/library/aurora/';
const recoveryId = (app, name) => app.ids.get('notebook-recovery-' + name);
function reviewRecovery(app, source = 'old-intro.md', target = 'intro.md') {
  recoveryId(app, 'source').value = source;
  recoveryId(app, 'source').fire('change');
  recoveryId(app, 'target').value = target;
  recoveryId(app, 'target').fire('change');
  recoveryId(app, 'review').click();
}
function chooseRecovery(app, mode) {
  recoveryId(app, 'mode').value = mode;
  recoveryId(app, 'mode').fire('change');
}
function recoveryStore(notes) {
  return new Map([[notebookKey, JSON.stringify({version: 1, notes})]]);
}

test('renamed-chapter recovery previews, cancels, copies, reopens and exports without deleting the old note', async () => {
  const original = 'Earlier context 東京 😀\r\nKeep exact spacing  ';
  const a = boot({store: recoveryStore([['old-intro.md', original]])});
  const before = state(a);
  assert.equal(recoveryId(a, 'source').value, '', 'no source is guessed');
  assert.equal(recoveryId(a, 'target').value, '', 'no destination is guessed');
  reviewRecovery(a);
  assert.deepEqual(state(a), before);
  assert.equal(recoveryId(a, 'original').textContent, original);
  assert.equal(recoveryId(a, 'mode').value, '');
  assert.equal(recoveryId(a, 'apply').disabled, true);
  recoveryId(a, 'apply').click(); assert.deepEqual(state(a), before);
  chooseRecovery(a, 'copy'); assert.equal(recoveryId(a, 'result').textContent, original);
  recoveryId(a, 'cancel').click(); recoveryId(a, 'apply').click();
  assert.deepEqual(state(a), before);
  reviewRecovery(a); chooseRecovery(a, 'copy'); recoveryId(a, 'apply').click();
  const after = state(a); recoveryId(a, 'apply').click(); assert.deepEqual(state(a), after);
  assert.equal(a.ids.get('notebook-note').value, original, 'selected destination refreshes to saved recovery');
  const reopened = boot({store: a.store});
  assert.equal(reopened.ids.get('notebook-note').value, original);
  reopened.select('old-intro.md'); assert.equal(reopened.ids.get('notebook-note').value, original);
  assert.equal(reopened.ids.get('notebook-open').hidden, true);
  reopened.select('intro.md'); reopened.edit(original + '\nNew chapter insight'); reopened.save();
  const text = await reopened.archive(), notes = new Map(JSON.parse(text).notes);
  assert.equal(notes.get('intro.md'), original + '\nNew chapter insight');
  assert.equal(notes.get('old-intro.md'), original);
  if (process.env.MOONBOOK_RECOVERY_EVIDENCE) {
    const dir = process.env.MOONBOOK_RECOVERY_EVIDENCE;
    writeFileSync(dir + '/recovered-notebook.json', text);
    writeFileSync(dir + '/recovered-notes.md', await reopened.export());
  }
});

test('existing destination offers exact append or replacement after explicit review', () => {
  for (const [mode, expected] of [['append', 'Current note\n\nRecovered note'], ['replace', 'Recovered note']]) {
    const a = boot({store: recoveryStore([['old-intro.md', 'Recovered note'], ['intro.md', 'Current note']])});
    reviewRecovery(a);
    assert.equal(recoveryId(a, 'current').textContent, 'Current note');
    assert.equal(recoveryId(a, 'mode').value, '');
    chooseRecovery(a, mode); assert.equal(recoveryId(a, 'result').textContent, expected);
    recoveryId(a, 'apply').click();
    const notes = new Map(JSON.parse(a.store.get(notebookKey)).notes);
    assert.equal(notes.get('intro.md'), expected); assert.equal(notes.get('old-intro.md'), 'Recovered note');
  }
});

test('recovering to another chapter keeps the current draft unsaved and reading state byte-for-byte unchanged', async () => {
  const store = recoveryStore([['old-intro.md', 'Earlier note'], ['intro.md', 'Saved intro']]);
  const progress = JSON.stringify({version: 1, read: ['old-intro.md', 'intro.md'], last: 'intro.md'});
  store.set(progressStoreKey, progress);
  const a = boot({store}); a.edit('Unrelated unsaved draft');
  reviewRecovery(a, 'old-intro.md', 'nested/README.md'); chooseRecovery(a, 'copy'); recoveryId(a, 'apply').click();
  assert.equal(a.ids.get('notebook-note').value, 'Unrelated unsaved draft');
  assert.equal(a.ids.get('notebook-chapters').value, 'intro.md');
  assert.match(status(a), /Unsaved note/);
  const notes = new Map(JSON.parse(store.get(notebookKey)).notes);
  assert.equal(notes.get('intro.md'), 'Saved intro', 'unrelated draft was not persisted');
  assert.equal(notes.get('nested/README.md'), 'Earlier note');
  assert.equal(store.get(progressStoreKey), progress);
  assert.equal(new Map(JSON.parse(await a.archive()).notes).get('intro.md'), 'Unrelated unsaved draft');
  a.save(); assert.equal(new Map(JSON.parse(store.get(notebookKey)).notes).get('intro.md'), 'Unrelated unsaved draft');
});

test('a destination draft is reviewed and saved with append while a source draft remains unsaved', () => {
  const a = boot({store: recoveryStore([['old-intro.md', 'Saved old note'], ['intro.md', 'Saved destination']])});
  a.edit('Destination draft'); reviewRecovery(a); chooseRecovery(a, 'append');
  assert.equal(recoveryId(a, 'result').textContent, 'Destination draft\n\nSaved old note');
  recoveryId(a, 'apply').click(); assert.equal(a.ids.get('notebook-note').value, 'Destination draft\n\nSaved old note');
  a.select('old-intro.md'); a.edit('Edited source draft');
  reviewRecovery(a, 'old-intro.md', 'nested/README.md'); chooseRecovery(a, 'copy'); recoveryId(a, 'apply').click();
  const notes = new Map(JSON.parse(a.store.get(notebookKey)).notes);
  assert.equal(notes.get('old-intro.md'), 'Saved old note');
  assert.equal(notes.get('nested/README.md'), 'Edited source draft');
  assert.equal(a.ids.get('notebook-note').value, 'Edited source draft');
  assert.match(status(a), /Unsaved note/);
});

test('changed notes require a fresh recovery choice and preserve another tab edits', () => {
  const a = boot({store: recoveryStore([['old-intro.md', 'Source'], ['intro.md', 'Destination']])});
  reviewRecovery(a); chooseRecovery(a, 'replace');
  const b = boot({store: a.store}); b.edit('Newer destination'); b.save();
  const before = state(a); recoveryId(a, 'apply').click();
  assert.deepEqual(state(a), before);
  assert.match(recoveryId(a, 'message').textContent, /changed during preview/);
  assert.equal(recoveryId(a, 'current').textContent, 'Newer destination');
  assert.equal(recoveryId(a, 'mode').value, '');
  assert.equal(recoveryId(a, 'apply').disabled, true);
  chooseRecovery(a, 'append'); recoveryId(a, 'apply').click();
  assert.equal(new Map(JSON.parse(a.store.get(notebookKey)).notes).get('intro.md'), 'Newer destination\n\nSource');
  reviewRecovery(a); chooseRecovery(a, 'replace'); a.edit('New destination draft');
  recoveryId(a, 'apply').click();
  assert.match(recoveryId(a, 'message').textContent, /changed during preview/);
  assert.equal(recoveryId(a, 'current').textContent, 'New destination draft');
  assert.equal(a.ids.get('notebook-note').value, 'New destination draft');
});

test('changing the destination cancels the old recovery and a deleted source cannot be recovered from a stale preview', () => {
  const a = boot({store: recoveryStore([['old-intro.md', 'Old note']])});
  reviewRecovery(a); chooseRecovery(a, 'copy');
  recoveryId(a, 'target').value = 'nested/README.md'; recoveryId(a, 'target').fire('change');
  const before = state(a); recoveryId(a, 'apply').click(); assert.deepEqual(state(a), before);
  assert.equal(recoveryId(a, 'preview').hidden, true);
  reviewRecovery(a); chooseRecovery(a, 'copy');
  const b = boot({store: a.store}); b.select('old-intro.md'); b.edit(''); b.save();
  const deleted = state(a); recoveryId(a, 'apply').click();
  assert.deepEqual(state(a), deleted); assert.match(recoveryId(a, 'message').textContent, /available removed-chapter note/);
});

test('exact Unicode paths and literal note text survive a manually chosen same-title destination', () => {
  const old = 'old/東京 <b>.md', target = 'new/東京 <b>.md', text = '<script>literal()</script> &\n# Note';
  const payload = {title: 'Book', pages: [{title: 'Same title', path: 'other.md', href: '../other.html'}, {title: 'Same title', path: target, href: '../new.html'}]};
  const a = boot({store: recoveryStore([[old, text]]), payload});
  reviewRecovery(a, old, target); chooseRecovery(a, 'copy');
  assert.equal(recoveryId(a, 'original').textContent, text); assert.equal(recoveryId(a, 'original').children.length, 0);
  assert.ok(recoveryId(a, 'summary').textContent.includes(target));
  recoveryId(a, 'apply').click();
  const notes = new Map(JSON.parse(a.store.get(notebookKey)).notes);
  assert.equal(notes.get(target), text); assert.equal(notes.get(old), text); assert.equal(notes.has('other.md'), false);
});

test('storage-denied recovery remains exportable with its original note and departure warning', async () => {
  const a = boot({store: recoveryStore([['old-intro.md', 'Keep both copies']]), failWrite: true});
  const before = state(a); reviewRecovery(a); chooseRecovery(a, 'copy'); recoveryId(a, 'apply').click();
  assert.deepEqual(state(a), before); assert.match(recoveryId(a, 'message').textContent, /tab only/);
  const notes = new Map(JSON.parse(await a.archive()).notes);
  assert.equal(notes.get('intro.md'), 'Keep both copies'); assert.equal(notes.get('old-intro.md'), 'Keep both copies');
  let warned = false; a.windowEvents.get('beforeunload')({preventDefault() { warned = true; }}); assert.equal(warned, true);
});

test('recovery needs both an available removed note and an explicitly chosen current chapter', () => {
  const empty = boot(); assert.equal(recoveryId(empty, 'review').disabled, true);
  const removedOnly = boot({payload: {title: 'No chapters', pages: []}, store: recoveryStore([['old-intro.md', 'Note']])});
  assert.equal(recoveryId(removedOnly, 'review').disabled, true);
  const a = boot({store: recoveryStore([['old-intro.md', 'Note']])}), before = state(a);
  reviewRecovery(a, 'old-intro.md', ''); assert.match(recoveryId(a, 'message').textContent, /Choose a current destination/);
  reviewRecovery(a, 'intro.md', 'nested/README.md'); assert.match(recoveryId(a, 'message').textContent, /available removed/);
  recoveryId(a, 'apply').click(); assert.deepEqual(state(a), before);
});

test('recovery controls and exact production script are composed into the ordinary notebook renderer', () => {
  if (!fromSource) return;
  const renderer = readFileSync(new URL('../html/renderer_notebook.mbt', import.meta.url), 'utf8');
  assert.match(renderer, /reader_notebook_progress_archive_script\(\) \+\s*reader_notebook_recovery_script\(\)/);
  for (const id of ['source', 'target', 'review', 'message', 'preview', 'summary', 'original', 'current', 'mode', 'result', 'apply', 'cancel']) {
    assert.ok(renderer.includes(`id="notebook-recovery-${id}"`));
  }
});

const importRows = app => app.ids.get('notebook-archive-items').children;
function includeNote(app, path, checked) {
  const row = importRows(app).find(item => item.children[0].textContent === path);
  assert.ok(row, 'incoming path is displayed: ' + path);
  const checkbox = row.children[3].children[0];
  checkbox.checked = checked; checkbox.fire('change');
}
const clearImports = app => app.ids.get('notebook-archive-none').click();
const savedNotes = app => new Map(JSON.parse(app.store.get('moonbook.reader-notebook.v1:https://example.test/library/aurora/')).notes);

test('selective restore previews all incoming notes and reopens only the chosen chapter at a moved book copy', async () => {
  const source = boot({href: 'https://other.test/source/__moonbook/notebook.html'});
  source.edit('Archive introduction'); source.save();
  source.select('nested/README.md'); source.edit('Research 東京 😀\r\nExactly retained'); source.save();
  const transfer = JSON.parse(await source.archive());
  transfer.notes.push(['removed/<old>.md', 'Private retired note <script>inert</script>']);
  const text = JSON.stringify(transfer);
  const a = boot(); a.edit('Saved destination introduction'); a.save(); mark(a);
  a.edit('Unsaved destination introduction');
  const before = state(a), writesBefore = a.writes.length, progressBefore = a.store.get(progressKey);
  await a.import(text);
  assert.deepEqual(state(a), before); assert.equal(a.writes.length, writesBefore);
  assert.equal(importRows(a).length, 3);
  assert.equal(importRows(a)[2].children[0].textContent, 'removed/<old>.md');
  assert.equal(importRows(a)[2].children[2].textContent, 'Private retired note <script>inert</script>');
  assert.match(importRows(a)[2].children[1].textContent, /Removed chapter/);
  clearImports(a); includeNote(a, 'nested/README.md', true);
  assert.match(a.ids.get('notebook-archive-selection').textContent, /1 of 3/);
  a.apply();
  assert.equal(a.writes.length, writesBefore + 1);
  assert.equal(savedNotes(a).get('intro.md'), 'Saved destination introduction');
  assert.equal(savedNotes(a).has('removed/<old>.md'), false);
  assert.equal(a.ids.get('notebook-note').value, 'Unsaved destination introduction');
  assert.equal(search(a, 'Unsaved', 'draft').length, 1);
  assert.equal(a.store.get(progressKey), progressBefore);
  const reopened = boot({store: a.store}); reopened.select('nested/README.md');
  assert.equal(reopened.ids.get('notebook-note').value, 'Research 東京 😀\r\nExactly retained');
  reopened.edit('Research after selective restore'); reopened.save();
  const result = await reopened.archive();
  assert.equal(new Map(JSON.parse(result).notes).get('nested/README.md'), 'Research after selective restore');
  assert.ok(!(await reopened.export()).includes('Private retired note'));
  const count = a.writes.length; a.apply(); assert.equal(a.writes.length, count, 'completed apply cannot repeat');
  if (process.env.MOONBOOK_SELECTION_EVIDENCE) {
    writeFileSync(process.env.MOONBOOK_SELECTION_EVIDENCE + '/incoming-notebook.json', text);
    writeFileSync(process.env.MOONBOOK_SELECTION_EVIDENCE + '/selected-restored-notebook.json', result);
    writeFileSync(process.env.MOONBOOK_SELECTION_EVIDENCE + '/selected-restored-notes.md', await reopened.export());
  }
});

test('clear and select all control incoming inclusion without writing; no selection and empty imports cannot save drafts', async () => {
  const a = boot(); a.edit('Keep this unsaved'); const before = state(a);
  await a.import(archive([['a.md', 'First'], ['b.md', 'Second']]));
  clearImports(a);
  assert.equal(a.ids.get('notebook-archive-apply').disabled, true);
  a.apply(); assert.deepEqual(state(a), before); assert.equal(a.writes.length, 0);
  assert.match(status(a), /No notes selected/);
  a.ids.get('notebook-archive-all').click();
  assert.equal(importRows(a).every(row => row.children[3].children[0].checked), true);
  assert.match(a.ids.get('notebook-archive-selection').textContent, /2 of 2/);
  a.cancel(); assert.deepEqual(state(a), before);
  await a.import(archive([]));
  for (const id of ['notebook-archive-all', 'notebook-archive-none', 'notebook-archive-apply']) assert.equal(a.ids.get(id).disabled, true);
  a.apply(); assert.equal(a.writes.length, 0);
  assert.equal(a.ids.get('notebook-note').value, 'Keep this unsaved');
});

test('unchecked conflicts ignore a replacement choice and selected conflicts require explicit replacement', async () => {
  const a = boot(); a.edit('Local intro'); a.save(); a.select('nested/README.md'); a.edit('Local nested'); a.save();
  await a.import(archive([['intro.md', 'Incoming intro'], ['nested/README.md', 'Incoming nested'], ['extra.md', 'Do not restore']]));
  a.choices()[0].value = 'import'; a.choices()[1].value = 'import';
  includeNote(a, 'intro.md', false); includeNote(a, 'extra.md', false); a.apply();
  assert.deepEqual([...savedNotes(a)], [['intro.md', 'Local intro'], ['nested/README.md', 'Incoming nested']]);
  assert.equal(a.ids.get('notebook-note').value, 'Incoming nested');
  assert.match(status(a), /1 selected notes imported/);
});

test('kept-current and identical incoming notes leave an active draft unsaved until the reader saves', async () => {
  const a = boot(); a.edit('Original saved'); a.save(); a.edit('Draft local');
  const before = state(a), count = a.writes.length;
  await a.import(archive([['intro.md', 'Different incoming']])); a.apply();
  assert.deepEqual(state(a), before); assert.equal(a.writes.length, count);
  assert.equal(search(a, 'Draft', 'draft').length, 1);
  await a.import(archive([['intro.md', 'Draft local']])); a.apply();
  assert.deepEqual(state(a), before); assert.equal(a.writes.length, count);
  assert.equal(search(a, 'Draft', 'draft').length, 1);
  await a.import(archive([['intro.md', 'Chosen replacement']]));
  a.choices()[0].value = 'import'; a.apply();
  assert.equal(savedNotes(a).get('intro.md'), 'Chosen replacement');
  assert.equal(search(a, '', 'draft').length, 0);
});

test('selectively importing another note does not persist a draft deletion or change chapter selection', async () => {
  const a = boot(); a.edit('Saved text'); a.save(); a.edit('');
  await a.import(archive([['intro.md', 'Skipped incoming'], ['nested/README.md', 'Selected incoming']]));
  includeNote(a, 'intro.md', false); a.apply();
  assert.equal(savedNotes(a).get('intro.md'), 'Saved text');
  assert.equal(a.ids.get('notebook-note').value, '');
  assert.equal(a.ids.get('notebook-chapters').value, 'intro.md');
  assert.equal(new Map(JSON.parse(await a.archive()).notes).has('intro.md'), false, 'archive still overlays unsaved deletion');
  a.save(); assert.equal(savedNotes(a).has('intro.md'), false);
});

test('edited Markdown selectively restores only the chosen sections and can be edited and exported again', async () => {
  const source = boot(); source.edit('First section'); source.save();
  source.select('nested/README.md'); source.edit('Second section');
  const text = (await source.export()).replace('> Second section', '> Edited second section');
  const a = boot(); await a.import(text);
  assert.match(a.ids.get('notebook-archive-summary').textContent, /Edited Markdown/);
  clearImports(a); includeNote(a, 'nested/README.md', true); a.apply();
  assert.deepEqual([...savedNotes(a)], [['nested/README.md', 'Edited second section']]);
  const reloaded = boot({store: a.store}); reloaded.select('nested/README.md');
  reloaded.edit('Continued after external editing'); reloaded.save();
  const result = await reloaded.export();
  assert.ok(result.includes('Continued after external editing')); assert.ok(!result.includes('First section'));
});

test('changed notes clear every incoming selection before a renewed selective restore', async () => {
  const a = boot(); a.edit('Original'); a.save();
  await a.import(archive([['intro.md', 'Incoming intro'], ['nested/README.md', 'Incoming nested'], ['gone.md', 'Skip removed']]));
  a.choices()[0].value = 'import'; includeNote(a, 'gone.md', false);
  const b = boot({store: a.store}); b.edit('Newer original'); b.save();
  const before = state(a), count = a.writes.length; a.apply();
  assert.deepEqual(state(a), before); assert.equal(a.writes.length, count);
  assert.equal(importRows(a).every(row => !row.children[3].children[0].checked), true);
  assert.equal(a.ids.get('notebook-archive-apply').disabled, true);
  assert.equal(a.choices()[0].value, 'keep');
  a.apply(); assert.deepEqual(state(a), before);
  includeNote(a, 'nested/README.md', true); a.apply();
  assert.deepEqual([...savedNotes(a)], [['intro.md', 'Newer original'], ['nested/README.md', 'Incoming nested']]);
});

test('cancel and a newly chosen file discard old inclusion choices without importing either file', async () => {
  const a = boot(); a.edit('Unsaved'); const before = state(a);
  await a.import(archive([['first.md', 'First']])); clearImports(a); a.cancel();
  assert.equal(importRows(a).length, 0); assert.deepEqual(state(a), before);
  await a.import(archive([['second.md', 'Second']]));
  assert.equal(importRows(a)[0].children[3].children[0].checked, true);
  a.cancel(); a.apply(); assert.deepEqual(state(a), before);
  assert.equal(a.ids.get('notebook-note').value, 'Unsaved');
});

test('selected removed-path notes remain editable and exportable with unavailable storage', async () => {
  const key = 'moonbook.reader-notebook.v1:https://example.test/library/aurora/';
  for (const options of [{failWrite: true}, {store: new Map([[key, '{unreadable']])}]) {
    const a = boot(options), before = state(a);
    await a.import(archive([['removed/東京.md', 'Selected old note'], ['skip.md', 'Excluded note']]));
    clearImports(a); includeNote(a, 'removed/東京.md', true); a.apply();
    assert.match(status(a), /tab only/); assert.deepEqual(state(a), before);
    a.select('removed/東京.md'); assert.equal(a.ids.get('notebook-open').hidden, true);
    a.edit('Edited recovered note'); a.save();
    assert.deepEqual(JSON.parse(await a.archive()).notes, [['removed/東京.md', 'Edited recovered note']]);
    assert.ok(!(await a.export()).includes('Excluded note'));
  }
});

test('selective import controls are composed into the real notebook and checkbox labels name exact paths', async () => {
  const source = readFileSync(new URL('../html/renderer_notebook.mbt', import.meta.url), 'utf8');
  for (const id of ['notebook-archive-items', 'notebook-archive-selection', 'notebook-archive-all', 'notebook-archive-none']) assert.ok(source.includes('id="' + id + '"'));
  assert.ok(source.includes('id="notebook-archive-selection" role="status" aria-live="polite"'));
  assert.ok(source.includes('>Import selected notes</button>'));
  const a = boot(); await a.import(archive([['chapter <img>.md', '<script>plain text</script>']]));
  const row = importRows(a)[0];
  assert.equal(row.children[3].textContent, 'Include incoming note for chapter <img>.md');
  assert.equal(row.children[3].children[0].type, 'checkbox');
  assert.equal(row.children[2].textContent, '<script>plain text</script>');
});

// Focused briefs use the same production notebook, codecs and importer as full archives.
function reviewExport(app) {
  app.ids.get('notebook-selected-review').click();
  return exportControls(app);
}
function exportControls(app) {
  return new Map(app.ids.get('notebook-selected-items').children.map(field =>
    [field.children[0].textContent, field.children[3].children[0]]));
}
function chooseExport(app, paths) {
  const controls = exportControls(app);
  for (const path of paths) { const control = controls.get(path); assert.ok(control, path); control.checked = true; control.fire('change'); }
}
async function exportChosen(app, kind = 'archive') {
  const previous = app.downloads.length;
  app.ids.get('notebook-selected-' + kind).click();
  return app.downloads.length > previous ? app.downloads.at(-1).text() : undefined;
}
const exportMessage = app => app.ids.get('notebook-selected-message').textContent;

test('selected export reviews full notes and downloads only checked exact paths without saving a draft', async () => {
  const a = boot(); a.edit('Private introduction not for this brief'); a.save();
  a.ids.get('notebook-read-toggle').click();
  a.select(data.pages[1].path); a.edit('Full selected draft 東京 😀\r\nKeep indentation:  x  ');
  const before = state(a), writes = a.writes.length;
  const controls = reviewExport(a);
  assert.equal(controls.size, 2);
  assert.ok([...controls.values()].every(control => control.checked === false));
  assert.equal(a.ids.get('notebook-selected-archive').disabled, true);
  const preview = a.ids.get('notebook-selected-items').children[1];
  assert.match(preview.children[1].textContent, /Unsaved draft/);
  assert.equal(preview.children[2].textContent, a.ids.get('notebook-note').value);
  assert.equal(await exportChosen(a), undefined);
  chooseExport(a, [data.pages[1].path]);
  const text = await exportChosen(a), exported = JSON.parse(text);
  assert.deepEqual(exported.notes, [[data.pages[1].path, 'Full selected draft 東京 😀\r\nKeep indentation:  x  ']]);
  assert.equal(exported.title, data.title);
  assert.ok(!text.includes('intro.md') && !text.includes('Private introduction') && !text.includes('https://example.test/'));
  assert.equal(a.body.children.at(-1).download, 'selected-reading-notebook.json');
  assert.deepEqual(state(a), before); assert.equal(a.writes.length, writes);
  assert.equal(a.ids.get('notebook-chapters').value, data.pages[1].path);
  let prevented = false; a.windowEvents.get('beforeunload')({preventDefault() { prevented = true; }});
  assert.equal(prevented, true, 'export did not mark a draft saved');
  const reload = boot({store: a.store}); reload.select(data.pages[1].path);
  assert.equal(reload.ids.get('notebook-note').value, '');
  if (process.env.MOONBOOK_SELECTED_EXPORT_EVIDENCE) writeFileSync(process.env.MOONBOOK_SELECTED_EXPORT_EVIDENCE + '/selected-reading-notebook.json', text);
});

test('selected archive transfers chosen current and removed notes to another notebook and supports continued editing', async () => {
  const a = boot();
  await a.import(archive([['retired.md', 'Historical context'], [data.pages[1].path, 'Nested context'], [data.pages[0].path, 'Keep private']])); a.apply();
  const before = state(a); reviewExport(a); chooseExport(a, ['retired.md', data.pages[1].path]);
  const text = await exportChosen(a);
  assert.deepEqual(JSON.parse(text).notes.map(row => row[0]), [data.pages[1].path, 'retired.md']);
  assert.deepEqual(state(a), before);
  const href = 'https://destination.test/copy/__moonbook/notebook.html';
  const b = boot({href}); await b.import(text); b.apply();
  b.select('retired.md'); assert.equal(b.ids.get('notebook-note').value, 'Historical context');
  assert.equal(b.ids.get('notebook-open').hidden, true);
  b.edit('Historical context, revised'); b.save();
  const c = boot({href, store: b.store}); c.select('retired.md');
  assert.equal(c.ids.get('notebook-note').value, 'Historical context, revised');
  const transferred = JSON.parse(await c.archive());
  assert.equal(transferred.notes.length, 2);
  assert.ok(!transferred.notes.some(row => row[0] === data.pages[0].path));
});

test('selected Markdown is an editable focused brief and imports through the existing reviewed workflow', async () => {
  const path = '資料/old --><script>.md', body = '<script>literal</script>\r\n& context\n  preserve spaces  ';
  const a = boot(); await a.import(archive([[path, body], [data.pages[0].path, 'Unselected private content']])); a.apply();
  const before = state(a); reviewExport(a); chooseExport(a, [path]);
  const text = await exportChosen(a, 'markdown');
  assert.ok(text.includes('Personal reader notes; not reviewed book claims.'));
  assert.ok(text.includes('&lt;script&gt;literal&lt;/script&gt;'));
  assert.ok(!text.includes('Unselected private content') && !text.includes('Source: intro.md'));
  assert.equal(a.body.children.at(-1).download, 'selected-reading-notes.md');
  assert.deepEqual(state(a), before);
  const b = boot(); await b.import(text.replace('literal', 'edited externally'));
  assert.equal(b.store.size, 0); b.apply(); b.select(path);
  assert.equal(b.ids.get('notebook-note').value, body.replace(/\r\n/g, '\n').replace('literal', 'edited externally'));
  b.edit('Edited again in notebook'); b.save();
  assert.ok((await b.export()).includes('Edited again in notebook'));
  if (process.env.MOONBOOK_SELECTED_EXPORT_EVIDENCE) writeFileSync(process.env.MOONBOOK_SELECTED_EXPORT_EVIDENCE + '/selected-reading-notes.md', text);
});

test('draft edits and other-tab edits or deletions require renewed selection before downloading', async () => {
  for (const change of ['draft', 'other-tab edit', 'other-tab deletion']) {
    const a = boot(); a.edit('Reviewed old text'); a.save();
    reviewExport(a); chooseExport(a, [data.pages[0].path]);
    if (change === 'draft') a.edit('New draft for review');
    else { const b = boot({store: a.store}); b.edit(change === 'other-tab edit' ? 'New saved text' : ''); b.save(); }
    const before = state(a);
    assert.equal(await exportChosen(a), undefined);
    assert.match(exportMessage(a), /Notes changed since review/);
    assert.ok([...exportControls(a).values()].every(control => !control.checked));
    assert.equal(a.ids.get('notebook-selected-archive').disabled, true);
    assert.deepEqual(state(a), before);
    if (change !== 'other-tab deletion') {
      chooseExport(a, [data.pages[0].path]);
      assert.equal(JSON.parse(await exportChosen(a)).notes[0][1], change === 'draft' ? 'New draft for review' : 'New saved text');
    } else assert.equal(exportControls(a).size, 0);
  }
});

test('unrelated changes do not silently join a selection, while both formats can be downloaded after stable review', async () => {
  const a = boot(); a.edit('Public brief'); a.save(); reviewExport(a); chooseExport(a, [data.pages[0].path]);
  const b = boot({store: a.store}); b.select(data.pages[1].path); b.edit('New private note'); b.save();
  assert.equal(await exportChosen(a, 'markdown'), undefined);
  assert.match(exportMessage(a), /selection cleared/);
  assert.equal(exportControls(a).size, 2);
  chooseExport(a, [data.pages[0].path]);
  const before = state(a), text = await exportChosen(a);
  const markdown = await exportChosen(a, 'markdown');
  assert.equal(JSON.parse(text).notes.length, 1); assert.ok(!markdown.includes('New private note'));
  assert.deepEqual(state(a), before);
});

test('all, none, cancel and reopen alter only export choices; cancelling cannot download an old selection', async () => {
  const a = boot(); a.edit('Draft only'); const before = state(a);
  reviewExport(a); a.ids.get('notebook-selected-all').click();
  assert.equal(a.ids.get('notebook-selected-archive').disabled, false);
  a.ids.get('notebook-selected-none').click(); assert.equal(await exportChosen(a), undefined);
  a.ids.get('notebook-selected-all').click(); a.ids.get('notebook-selected-cancel').click();
  assert.equal(a.ids.get('notebook-selected-preview').hidden, true);
  assert.equal(await exportChosen(a), undefined);
  reviewExport(a); assert.ok([...exportControls(a).values()].every(control => !control.checked));
  assert.deepEqual(state(a), before); assert.equal(a.ids.get('notebook-note').value, 'Draft only');
});

test('empty books and a cleared draft never export the previous saved note', async () => {
  const empty = boot({payload: {...data, pages: []}}); reviewExport(empty);
  assert.match(exportMessage(empty), /No nonempty notes/); assert.equal(await exportChosen(empty), undefined);
  const a = boot(); a.select(data.pages[1].path); a.edit('Useful retained note'); a.save();
  a.select(data.pages[0].path); a.edit('Previously saved sensitive text'); a.save(); a.edit('');
  const before = state(a); reviewExport(a);
  assert.deepEqual([...exportControls(a).keys()], [data.pages[1].path]);
  a.ids.get('notebook-selected-all').click();
  assert.ok(!(await exportChosen(a)).includes('Previously saved sensitive text'));
  assert.deepEqual(state(a), before); assert.equal(a.ids.get('notebook-note').value, '');
});

test('tab-only selected export remains recoverable and never overwrites unreadable stored bytes', async () => {
  const key = 'moonbook.reader-notebook.v1:https://example.test/library/aurora/';
  for (const options of [{failRead: true}, {store: new Map([[key, '{unreadable']])}, {failWrite: true}]) {
    const a = boot(options); a.edit('Tab-only draft to recover'); a.save();
    const before = state(a), writes = a.writes.length;
    reviewExport(a); chooseExport(a, [data.pages[0].path]);
    const text = await exportChosen(a);
    assert.deepEqual(state(a), before); assert.equal(a.writes.length, writes);
    const b = boot({href: 'https://recovery.test/book/__moonbook/notebook.html'}); await b.import(text); b.apply();
    assert.equal(b.ids.get('notebook-note').value, 'Tab-only draft to recover');
  }
});

test('selected export refuses an oversized file but a smaller chosen scope still downloads', async () => {
  const key = 'moonbook.reader-notebook.v1:https://example.test/library/aurora/';
  const store = new Map([[key, JSON.stringify({version: 1, notes: [[data.pages[0].path, 'Small useful brief'], [data.pages[1].path, 'x'.repeat(5 * 1024 * 1024)]]})]]);
  const a = boot({store}); reviewExport(a); a.ids.get('notebook-selected-all').click();
  const before = state(a); assert.equal(await exportChosen(a), undefined);
  assert.match(exportMessage(a), /exceeds 5 MiB/);
  a.ids.get('notebook-selected-none').click(); chooseExport(a, [data.pages[0].path]);
  assert.deepEqual(JSON.parse(await exportChosen(a)).notes, [[data.pages[0].path, 'Small useful brief']]);
  assert.deepEqual(state(a), before);
});

test('selected export controls and shared Markdown serializer are connected to the production renderer', () => {
  if (!fromSource) return;
  const source = readFileSync(new URL('../html/renderer_notebook.mbt', import.meta.url), 'utf8');
  assert.equal(source.split('reader_notebook_selected_export_script() +').length, 2);
  for (const id of ['review', 'preview', 'items', 'count', 'message', 'all', 'none', 'markdown', 'archive', 'cancel']) {
    assert.ok(source.includes('id="notebook-selected-' + id + '"'), id);
  }
  const exported = embedded('renderer_notebook_selected_export.mbt');
  assert.ok(exported.includes('markdownNotesText(chosen)'));
  assert.ok(!exported.includes('localStorage.setItem') && !exported.includes('innerHTML'));
});
