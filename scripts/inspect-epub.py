#!/usr/bin/env python3
"""Inspect actual MoonBook EPUB artifacts using only the Python standard library."""
import argparse
import hashlib
import json
import posixpath
import re
import struct
import urllib.parse
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

NS = {"opf": "http://www.idpf.org/2007/opf", "x": "http://www.w3.org/1999/xhtml", "dc": "http://purl.org/dc/elements/1.1/", "c": "urn:oasis:names:tc:opendocument:xmlns:container"}
EPUB = "{http://www.idpf.org/2007/ops}type"

def inspect(path):
    raw = path.read_bytes()
    with zipfile.ZipFile(path) as z:
        infos = z.infolist()
        assert infos[0].filename == "mimetype"
        assert infos[0].compress_type == zipfile.ZIP_STORED
        assert not infos[0].extra
        assert z.read("mimetype") == b"application/epub+zip"
        assert raw[:4] == b"PK\x03\x04"
        assert struct.unpack_from("<HH", raw, 26) == (8, 0), "mimetype local extra field"
        assert z.testzip() is None
        names = z.namelist()
        assert len(names) == len(set(names))
        container = ET.fromstring(z.read("META-INF/container.xml"))
        rootfile = container.find("c:rootfiles/c:rootfile", NS)
        assert rootfile.attrib["full-path"] == "EPUB/package.opf"
        assert rootfile.attrib["media-type"] == "application/oebps-package+xml"
        package = ET.fromstring(z.read(rootfile.attrib["full-path"]))
        assert package.tag == "{" + NS["opf"] + "}package"
        assert package.attrib["version"] == "3.0"
        title = package.findtext("opf:metadata/dc:title", namespaces=NS)
        identifier = package.find("opf:metadata/dc:identifier", NS)
        assert title and identifier.attrib["id"] == package.attrib["unique-identifier"]
        assert re.fullmatch(r"urn:moonbook:sha256:[0-9a-f]{64}", identifier.text)
        language = package.findtext("opf:metadata/dc:language", namespaces=NS)
        assert language
        modified = next(n.text for n in package.findall("opf:metadata/opf:meta", NS) if n.attrib.get("property") == "dcterms:modified")
        assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", modified)
        manifest = {n.attrib["id"]: n.attrib for n in package.findall("opf:manifest/opf:item", NS)}
        listed = {"EPUB/" + item["href"] for item in manifest.values()}
        assert listed | {"mimetype", "META-INF/container.xml", "EPUB/package.opf"} == set(names)
        assert manifest["nav"]["properties"] == "nav"
        spine = [manifest[n.attrib["idref"]]["href"] for n in package.findall("opf:spine/opf:itemref", NS)]
        docs = {n: ET.fromstring(z.read(n)) for n in names if n.endswith(".xhtml")}
        ids = {}
        for name, doc in docs.items():
            assert doc.tag == "{" + NS["x"] + "}html"
            all_ids = [el.attrib["id"] for el in doc.iter() if "id" in el.attrib]
            assert len(all_ids) == len(set(all_ids)), (name, "duplicate ids")
            ids[name] = set(all_ids)
        local_links = 0
        for name, doc in docs.items():
            for el in doc.iter():
                for attr in ("href", "src"):
                    if attr not in el.attrib:
                        continue
                    url = urllib.parse.urlsplit(el.attrib[attr])
                    if url.scheme:
                        assert attr == "href" and url.scheme in {"http", "https", "mailto"}
                        continue
                    assert not url.netloc and not url.query
                    target = posixpath.normpath(posixpath.join(posixpath.dirname(name), urllib.parse.unquote(url.path))) if url.path else name
                    assert target in names, (name, el.attrib[attr], "missing resource")
                    if url.fragment:
                        assert urllib.parse.unquote(url.fragment) in ids[target], (name, el.attrib[attr], "missing fragment")
                    local_links += 1
        nav = docs["EPUB/nav.xhtml"]
        toc = next(n for n in nav.iter() if n.attrib.get(EPUB) == "toc")
        toc_order = [n.attrib["href"] for n in toc.findall(".//x:a", NS)]
        assert toc_order == spine, (toc_order, spine)
        image_names = [n for n in names if n.startswith("EPUB/images/")]
        return {"file": str(path), "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw), "title": title, "language": language, "modified": modified, "identifier": identifier.text, "chapter_order": spine, "toc_matches_spine": True, "local_links_checked": local_links, "images": [{"path": n, "sha256": hashlib.sha256(z.read(n)).hexdigest()} for n in image_names], "entries": len(names), "zip_crc_xml_and_resources": "pass"}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="+", type=Path)
    args = parser.parse_args()
    print(json.dumps([inspect(path) for path in args.files], ensure_ascii=False, indent=2))
