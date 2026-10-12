#!/usr/bin/env python3
"""Retained end-to-end selected-page dossier checks; never removes fixtures."""
import hashlib, json, pathlib, re, subprocess, sys
binary,destination=sys.argv[1:]; out=pathlib.Path(destination).resolve();out.mkdir(parents=True,exist_ok=False)
book=out/'private research book';book.mkdir();calls=[]
def call(name,args,expected=0,cwd=None):
    p=subprocess.run([binary,*map(str,args)],cwd=cwd,capture_output=True)
    (out/(name+'.stdout')).write_bytes(p.stdout);(out/(name+'.stderr')).write_bytes(p.stderr)
    calls.append(dict(name=name,args=list(map(str,args)),exit=p.returncode))
    assert p.returncode==expected,(name,p.returncode,p.stdout,p.stderr)
    if expected: assert b'export-pages failed:' in p.stdout and b'"schema"' not in p.stdout
    return p.stdout.decode()
def snapshot(): return {str(p.relative_to(book)):hashlib.sha256(p.read_bytes()).hexdigest() for p in book.rglob('*') if p.is_file() and not p.is_symlink()}
call('init',['wiki','init',book]); citations=[]
for name,body in [('policy','# Travel policy\nKeep receipts\n'),('handbook','# New hire handbook\nWelcome 東京 🌙\n')]:
    path=out/(name+'.md');path.write_text(body)
    result=call('ingest-'+name,['wiki','ingest',book,path]);p=pathlib.Path(re.search(r'^wiki page: (.+)$',result,re.M)[1]);p=p if p.is_absolute() else book/p;citations.append(str(p.relative_to(book)))
call('discover',['wiki','query',book,'Travel policy'])
folder=book/'wiki/concepts';folder.mkdir(exist_ok=True)
fixtures={'literal.md':'---\nstatus: <img src=x onerror=alert(1)>\n---\n# raw\n`````\n<script>bad()</script>\r\nfinal 🌙','empty.md':'','private.md':'UNSELECTED_PRIVATE_SENTINEL','oversize.md':'x'*262145}
fixtures['long-status.md']='---\nstatus: '+('s'*191)+'\n---\nBody\n'
fixtures['crlf-status.md']='---\r\nstatus: pending review  \r\n---\r\nBody\r\n'
for name,body in fixtures.items(): (folder/name).write_bytes(body.encode())
for n in range(5): (folder/f'large{n}.md').write_text('a'*262144)
(folder/'outside.md').symlink_to(out/'policy.md')
prior=snapshot()
def export(name,selected,cwd=None,root=None):
    result=json.loads(call(name,['wiki','export-pages',root if root is not None else book,*selected,'--json'],cwd=cwd))
    assert result['schema']=='moonbook.wiki-page-dossier.v1'
    assert [p['citation'] for p in result['pages']]==selected
    for p in result['pages']:
        exact=(book/p['citation']).read_bytes().decode()
        assert p['content']==exact
        assert p['digest']=='sha256:'+hashlib.sha256(exact.encode()).hexdigest()
    return result
export('selected-imports',citations)
export('reversed',citations[::-1])
export('dot-root',citations,cwd=book,root='.')
selected=['wiki/concepts/literal.md','wiki/concepts/empty.md']
result=export('exact-content',selected); assert result['pages'][0]['metadata_status'].startswith('<img')
markdown=call('markdown',['wiki','export-pages',book,*selected]); assert '``````text\n' in markdown and 'UNSELECTED_PRIVATE_SENTINEL' not in markdown
# Every attacker-controlled line lies inside a fenced block, including metadata.
fence=None
for line in markdown.splitlines():
    if fence is None and re.fullmatch(r'`{3,}text',line): fence=line[:-4];continue
    if fence is not None and line==fence: fence=None;continue
    if '<img' in line or '<script>' in line: assert fence is not None
assert fence is None
metadata=export('full-metadata',['wiki/concepts/long-status.md','wiki/concepts/crlf-status.md'])
assert metadata['pages'][0]['metadata_status']=='s'*191
assert metadata['pages'][1]['metadata_status']=='pending review  '
export('single-boundary',['wiki/concepts/large0.md'])
export('aggregate-boundary',[f'wiki/concepts/large{i}.md' for i in range(4)])
for name,bad in [('traversal','wiki/../policy.md'),('absolute',str(out/'policy.md')),('symlink','wiki/concepts/outside.md'),('missing','wiki/concepts/missing.md'),('excluded','wiki/Home.md'),('size','wiki/concepts/oversize.md')]:
    call(name,['wiki','export-pages',book,citations[0],bad,'--json'],1)
call('duplicate',['wiki','export-pages',book,*[citations[0]]*2,'--json'],1)
call('aggregate-limit',['wiki','export-pages',book,*[f'wiki/concepts/large{i}.md' for i in range(5)],'--json'],1)
call('page-count-limit',['wiki','export-pages',book,*[f'wiki/concepts/absent{i}.md' for i in range(33)],'--json'],1)
call('empty-selection',['wiki','export-pages',book,'--json'],1)
call('no-args',['wiki','export-pages'],1)
assert snapshot()==prior
(out/'receipt.json').write_text(json.dumps(dict(result='PASS',calls=calls,book_unchanged=prior,checks=['import/query/select/export','exact content/hash/order','Unicode/CRLF/no-final-newline/empty','literal Markdown including malicious metadata/fences','unselected scope excluded','all-or-error','duplicates/path/size/count rejection','read-only entire Book']),indent=2)+'\n')
print('PASS',len(calls),'native CLI invocations')
