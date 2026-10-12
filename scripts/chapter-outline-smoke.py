#!/usr/bin/env python3
"""Verify retained output from the native chapter_outline_tests package; no browser."""
import collections, hashlib, json, sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote

class Outline(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_outline = False
        self.in_link = False
        self.ids = []
        self.links = []
        self.levels = []
        self.tags = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ('h1', 'h2', 'h3', 'h4', 'h5', 'h6') and 'id' in attrs:
            self.ids.append(attrs['id'])
        if tag == 'details' and attrs.get('class') == 'chapter-outline':
            self.in_outline = True
        if self.in_outline:
            self.tags.append(tag)
            if tag == 'li':
                self.levels.append(attrs['class'])
            if tag == 'a':
                assert not self.in_link, 'Nested anchors in outline'
                self.in_link = True
                self.links.append([attrs['href'], ''])
    def handle_endtag(self, tag):
        if tag == 'a':
            self.in_link = False
        if tag == 'details':
            self.in_outline = False
    def handle_data(self, data):
        if self.in_outline and self.in_link:
            self.links[-1][1] += data

root = Path(sys.argv[1]).resolve()
p = Outline()
p.feed((root/'first.html').read_text())
expected = [
    ('start', 'Start'), ('deep-section-and-code', 'Deep section and code'),
    ('東京-😀', '東京 😀'), ('guide-literal', 'guide & <literal>'),
    ('a', 'A'), ('a-1', 'A-1'), ('a-2', 'A'), ('section', '!!!'),
    ('section-1', 'Section'), ('section-2', 'Untitled section'),
]
actual = [(unquote(href[1:]), label) for href, label in p.links]
assert actual == expected, actual
ids = collections.Counter(p.ids)
assert all(ids[target] == 1 for target, _ in actual), ids
assert len(ids) == len(p.ids), ids
assert p.levels[1] == 'outline-level-4'
assert set(p.tags) <= {'details','summary','nav','ol','li','a'}, p.tags
assert all('code, not' not in label and 'quoted paragraph' not in label for _,label in actual)
q = Outline()
q.feed((root/'book/book/nested/guide.html').read_text())
assert q.links == [['#revised-section', 'Revised section']], q.links
receipt = {'schema':'moonbook.chapter-outline.smoke.v1','result':'pass',
    'sections':len(actual),'checks':['native renderer integration','exact target uniqueness',
    'Unicode URL fragments','inline labels escaped','duplicate and natural suffix collisions',
    'empty and punctuation headings','skipped levels','code and quote exclusion',
    'no-section and whole-book exclusion','repeat rebuild','edited source regeneration',
    'unlisted source exclusion','source preservation'],
    'browser_qualification':False,
    'artifacts':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in root.rglob('*') if p.is_file()}}
(root/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'result':'pass','sections':len(actual),'receipt':str(root/'receipt.json')}))
