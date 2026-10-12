#!/usr/bin/env python3
"""Inspect the actual native driver output, including edit/rebuild snapshots."""
import json
import sys
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


@dataclass
class Node:
    tag: str
    attrs: dict = field(default_factory=dict)
    children: list = field(default_factory=list)

    def text(self):
        return "".join(x if isinstance(x, str) else x.text() for x in self.children)

    def find(self, tag=None, class_name=None):
        result = []
        for child in self.children:
            if not isinstance(child, Node):
                continue
            if (tag is None or child.tag == tag) and (
                class_name is None or class_name in child.attrs.get("class", "").split()
            ):
                result.append(child)
            result.extend(child.find(tag, class_name))
        return result


class Document(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.root = Node("document")
        self.stack = [self.root]
        self.feed(text)
        self.close()

    def handle_starttag(self, tag, attrs):
        node = Node(tag, dict(attrs))
        self.stack[-1].children.append(node)
        if tag not in {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}:
            self.stack.append(node)

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                self.stack = self.stack[:i]
                break

    def handle_data(self, text):
        self.stack[-1].children.append(text)


def parsed(path):
    return Document(path.read_text()).root


def target(href, base, book):
    url = urlsplit(href)
    assert not url.scheme and not url.netloc, href
    result = (base.parent / unquote(url.path)).resolve()
    assert result.is_relative_to(book.resolve()), href
    assert result.is_file(), result
    if url.fragment:
        ids = [n.attrs["id"] for n in parsed(result).find() if "id" in n.attrs]
        assert unquote(url.fragment) in ids, (href, ids)
    return str(result.relative_to(book.resolve()))


def connections(section, base, book):
    result = {"Referenced by": [], "Links to": []}
    heading = None
    for child in section.children:
        if not isinstance(child, Node):
            continue
        if child.tag == "h3":
            heading = child.text()
            assert heading in result, heading
        if child.tag == "ul":
            assert heading, section.text()
            result[heading] = [target(a.attrs["href"], base, book) for a in child.find("a")]
    return result


def graph(path, base, book):
    root = parsed(path)
    ids = [n.attrs["id"] for n in root.find() if "id" in n.attrs]
    assert len(ids) == len(set(ids)), ids
    result = {}
    for entry in root.find("section", "connection-entry"):
        heading = entry.find("h2")[0].find("a")[0]
        chapter = target(heading.attrs["href"], base, book)
        assert chapter not in result
        result[chapter] = connections(entry, base, book)
    return result


def main(evidence):
    root = Path(evidence) / "book"
    book = root / "book"
    page = book / "__moonbook/connections.html"
    expected = {
        "start.html": {"Referenced by": ["guide/index.html"], "Links to": ["guide/index.html", "résumé 東京.html"]},
        "guide/index.html": {"Referenced by": ["start.html"], "Links to": ["start.html"]},
        "résumé 東京.html": {"Referenced by": ["start.html"], "Links to": []},
        "alone.html": {"Referenced by": [], "Links to": []},
    }
    actual = graph(page, page, book)
    assert actual == expected, actual
    assert graph(root / "connections-before.html", page, book) == expected
    for chapter, links in expected.items():
        chapter_path = book / chapter
        document = parsed(chapter_path)
        panels = document.find("section", "chapter-connections")
        assert len(panels) == 1, chapter
        assert connections(panels[0], chapter_path, book) == links, chapter
        for a in panels[0].find("a"):
            target(a.attrs["href"], chapter_path, book)
        assert any(a.text() == "Chapter connections" for a in document.find("a")), chapter
    changed = {key: {"Referenced by": [], "Links to": []} for key in expected}
    changed["start.html"]["Links to"] = ["alone.html"]
    changed["alone.html"]["Referenced by"] = ["start.html"]
    assert graph(root / "connections-after-edit.html", page, book) == changed
    after_panel = parsed(root / "alone-after-edit.html").find("section", "chapter-connections")[0]
    assert connections(after_panel, book / "alone.html", book) == changed["alone.html"]
    assert (root / "missing-chapter-error.txt").read_text()
    assert (Path(evidence) / "collision/book/__moonbook/connections.html").read_text() == "prior output"
    print(json.dumps({
        "status": "passed", "chapter_count": len(actual),
        "directed_connections": sum(len(x["Links to"]) for x in actual.values()),
        "rebuild_directed_connections": 1,
        "all_generated_connection_links_resolve": True,
        "exact_reverse_panels_verified": 4,
        "rendered_graph": actual,
        "no_browser_visual_qualification": True,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main(sys.argv[1])
