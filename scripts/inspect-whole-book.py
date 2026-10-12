#!/usr/bin/env python3
"""Inspect the real generated whole-book fixture; no replacement renderer."""
import hashlib
import json
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path
import sys
from urllib.parse import unquote, urlsplit

class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids, self.links, self.assets, self.sections = [], [], [], []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.append(attrs['id'])
        if tag == 'a' and 'href' in attrs:
            self.links.append(attrs['href'])
        if tag == 'img' and 'src' in attrs:
            self.assets.append(attrs['src'])
        if tag == 'section' and attrs.get('class') == 'print-section':
            self.sections.append(attrs.get('id'))

path = Path(sys.argv[1]).resolve()
text = path.read_text()
page = Page()
page.feed(text)
assert page.sections == ['chapter-1', 'chapter-2'], page.sections
assert all(count == 1 for count in Counter(page.ids).values()), Counter(page.ids)
for href in page.links + page.assets:
    url = urlsplit(href)
    assert not url.scheme and not url.netloc, href
    if not url.path:
        assert unquote(url.fragment) in page.ids, href
    else:
        assert (path.parent / unquote(url.path)).is_file(), href
assert page.assets == ['../guide/images/chart.svg'], page.assets
assert 'six teams' in text and 'twelve teams' not in text
assert '完全な記録 😀' in text and 'Unlisted private note' not in text
assert '&lt;a href=&quot;start.html&quot;&gt;example&lt;/a&gt;' in text
assert '@media print' in text and 'break-before:page' in text
assert '<button id="print-book" type="button" hidden>' in text
print(json.dumps({
    'result': 'pass', 'sections': page.sections,
    'unique_ids': len(page.ids), 'resolved_links': len(page.links),
    'resolved_local_assets': page.assets,
    'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
    'bytes': path.stat().st_size,
    'limitations': 'Structural HTML inspection, not graphical print/PDF validation',
}, indent=2))
