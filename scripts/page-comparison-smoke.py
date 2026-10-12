#!/usr/bin/env python3
"""Synthetic import -> find citations -> compare complete pages, retaining evidence."""
import hashlib, json, pathlib, re, subprocess, sys
binary,destination=sys.argv[1:]; out=pathlib.Path(destination).resolve(); out.mkdir(parents=True,exist_ok=False)
book=out/'research book'; book.mkdir(); calls=[]
def call(name,args,expected=0,cwd=None):
    cp=subprocess.run([binary,*map(str,args)],capture_output=True,cwd=cwd)
    (out/(name+'.stdout')).write_bytes(cp.stdout); (out/(name+'.stderr')).write_bytes(cp.stderr)
    calls.append({'name':name,'command':[binary,*map(str,args)],'cwd':str(cwd) if cwd else None,'exit':cp.returncode})
    assert cp.returncode==expected,(name,cp.returncode,cp.stdout.decode(),cp.stderr.decode())
    if expected: assert b'compare-pages failed:' in cp.stdout
    return cp.stdout.decode()
def digest(data): return 'sha256:'+hashlib.sha256(data).hexdigest()
def snapshot(): return {str(p.relative_to(book)):hashlib.sha256(p.read_bytes()).hexdigest() for p in book.rglob('*') if p.is_file() and not p.is_symlink()}
call('init',['wiki','init',book])
raw_before=out/'policy-before.md';raw_after=out/'policy-after.md'
raw_before.write_bytes('# Aurora refund policy\nWindow: 14 days\nContact support\n'.encode())
raw_after.write_bytes('# Aurora refund policy\nWindow: 30 days\nKeep receipt\nContact support\n東京 🌙\n'.encode())
citations=[]
for name,path in [('ingest-before',raw_before),('ingest-after',raw_after)]:
    text=call(name,['wiki','ingest',book,path]); match=re.search(r'^wiki page: (.+)$',text,re.M); assert match,text
    p=pathlib.Path(match.group(1)); p=p if p.is_absolute() else book/p
    citations.append(str(p.relative_to(book)))
query=call('query',['wiki','query',book,'Aurora refund policy']); assert 'Aurora' in query
pages=book/'wiki'/'concepts'; pages.mkdir(exist_ok=True)
fixtures={'one.md':b'a\r\nb\n','two.md':b'a\nb\n','empty.md':b'','large.md':b'x'*262145,'many.md':b'x\n'*1001,'final.md':b'a','final-lf.md':b'a\n','control.md':b'<script>alert(1)</script>\x1b[31m\n'}
for name,data in fixtures.items(): (pages/name).write_bytes(data)
(pages/'outside.md').symlink_to(raw_before)
prior=snapshot()
def verify(name, before, after, args=None, cwd=None):
    text=call(name,args or ['wiki','compare-pages',book,before,after,'--json'],cwd=cwd); result=json.loads(text)
    assert result['schema']=='moonbook.wiki-page-comparison.v1'
    left=(book/before).read_bytes().decode();right=(book/after).read_bytes().decode()
    assert result['before']['citation']==before and result['after']['citation']==after
    assert result['before']['digest']==digest(left.encode()) and result['after']['digest']==digest(right.encode())
    lines=result['diff']['lines']
    assert ''.join(x['text'] for x in lines if x['kind']!='add')==left
    assert ''.join(x['text'] for x in lines if x['kind']!='remove')==right
    old=new=0
    for row in lines:
        if row['kind']!='add': old+=1; assert row['before_line']==old
        else: assert 'before_line' not in row
        if row['kind']!='remove': new+=1; assert row['after_line']==new
        else: assert 'after_line' not in row
    return result
result=verify('compare-imported',*citations); assert result['diff']['added']>=3 and result['diff']['removed']>=1
assert any('30 days' in row['text'] and row['kind']=='add' for row in result['diff']['lines'])
assert any('14 days' in row['text'] and row['kind']=='remove' for row in result['diff']['lines'])
verify('reverse',citations[1],citations[0])
same=verify('same',citations[0],citations[0]); assert same['diff']['added']==same['diff']['removed']==0
verify('implicit-root',*citations,args=['wiki','compare-pages',*citations,'--json'],cwd=book)
verify('dot-root',*citations,args=['wiki','compare-pages','.',*citations,'--json'],cwd=book)
cr=verify('newline-change','wiki/concepts/one.md','wiki/concepts/two.md'); assert cr['diff']['added']==cr['diff']['removed']==1
final=verify('final-newline','wiki/concepts/final.md','wiki/concepts/final-lf.md'); assert final['diff']['added']==final['diff']['removed']==1
empty=verify('empty','wiki/concepts/empty.md','wiki/concepts/empty.md'); assert empty['diff']['lines']==[]
control=call('text-control',['wiki','compare-pages',book,'wiki/concepts/empty.md','wiki/concepts/control.md']);assert '\x1b' not in control and '\\u001b' in control
assert 'Metadata before:' in call('text',['wiki','compare-pages',book,*citations])
for name,bad in [('traversal','wiki/../policy-before.md'),('absolute',str(raw_before)),('symlink','wiki/concepts/outside.md'),('missing','wiki/concepts/missing.md'),('excluded','wiki/Home.md'),('too-large','wiki/concepts/large.md'),('too-many-lines','wiki/concepts/many.md')]:
    call(name,['wiki','compare-pages',book,citations[0],bad,'--json'],1)
call('bad-arguments',['wiki','compare-pages'],1)
assert snapshot()==prior
assert raw_before.read_bytes()==b'# Aurora refund policy\nWindow: 14 days\nContact support\n'
(out/'receipt.json').write_text(json.dumps({'result':'PASS','calls':calls,'source_citations':citations,'book_before_and_after_sha256':prior,'checks':['ordinary ingest/query/comparison','both-sides reconstruction','line provenance','reverse/identical/empty','absolute/dot/implicit roots','Unicode','CRLF/final newline','terminal controls quoted','path refusals','size bounds','entire book unchanged']},indent=2)+'\n')
print('PASS',len(calls),'native invocations;',out)
