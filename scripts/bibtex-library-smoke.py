#!/usr/bin/env python3
"""Focused ordinary CLI import → query → static rendering check, no cleanup."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

executable, fixture, evidence = map(lambda p: Path(p).resolve(), sys.argv[1:])
evidence.mkdir(parents=True, exist_ok=True)
book = evidence / "cli-book"
book.mkdir()
sequence = 0


def run(*args, cwd=None, ok=True):
    global sequence
    sequence += 1
    result = subprocess.run([str(executable), *map(str, args)], cwd=cwd,
                            text=True, capture_output=True, timeout=60)
    (evidence / f"cli-{sequence:02}.txt").write_text(
        f"args={args!r}\nexit={result.returncode}\n{result.stdout}\n{result.stderr}")
    assert (result.returncode == 0) == ok, result.stdout + result.stderr
    return result.stdout


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


run("wiki", "init", book)
raw = b"\xef\xbb\xbf" + fixture.read_bytes().replace(b"\n", b"\r\n")
(book / "library.bib").write_bytes(raw)
imports = []
for args, cwd in [(("library.bib",), book), ((".", "library.bib"), book),
                  ((book, "library.bib"), evidence)]:
    imported = json.loads(run("wiki", "import-bibtex", *args, cwd=cwd))
    assert len(imported["references"]) == 2
    assert imported["references"][0]["citation_key"] == "Aurora2026"
    assert Path(imported["raw_path"]).read_bytes() == raw
    imports.append(imported)
    # Query before deliberate repeat imports: the existing CLI returns only
    # its top three matches, which duplicate imports can legitimately crowd.
    if len(imports) == 1:
        first, second = imported["references"]
        for term, expected in [("guided setup", first), ("capacity counterstudy", second),
                               ("Aurora2026", first), ("跨团队复盘", first)]:
            query = run("wiki", "query", book, term)
            assert expected["citation"] in query, query
assert len({x["raw_path"] for x in imports}) == 3
assert len({x["references"][0]["citation"] for x in imports}) == 3
(evidence / "cli-import-results.json").write_text(json.dumps(imports, indent=2))
first, second = imports[0]["references"]

before_text = {str(p.relative_to(book)): p.read_text() for p in (book / "wiki").rglob("*") if p.is_file()}
raw_before = {str(p.relative_to(book)): digest(p) for p in (book / "raw").rglob("*") if p.is_file()}
run("build", book)
for reference in [first, second]:
    relative = Path(reference["citation"]).relative_to("wiki").with_suffix(".html")
    html = (book / "book" / relative).read_text()
    assert reference["citation_key"] in html
    assert "Supplied reference metadata and abstract" in html
    assert "<script>unsafe()</script>" not in html
    assert "Only five teams received follow-up support." in html if reference == second else "Eight teams completed guided setup." in html
after_text = {str(p.relative_to(book)): p.read_text() for p in (book / "wiki").rglob("*") if p.is_file()}
assert before_text.keys() == after_text.keys()
normalized = []
for path, original in before_text.items():
    current = after_text[path]
    if current == original:
        continue
    if path.startswith("wiki/sources/bibtex-"):
        old_meta, old_body = original.split("\n---\n", 1)
        new_meta, new_body = current.split("\n---\n", 1)
        assert old_body == new_body, path
        old_fields = dict(line.split(":", 1) for line in old_meta.splitlines() if ":" in line)
        new_fields = dict(line.split(":", 1) for line in new_meta.splitlines() if ":" in line)
        changed_fields = [key for key in old_fields if old_fields[key] != new_fields.get(key)]
        assert old_fields.keys() == new_fields.keys()
        assert set(changed_fields) <= {"tags", "updated_at"}, (path, changed_fields)
        normalized.append({"path": path, "changed_metadata_fields": changed_fields})
    else:
        assert path == "wiki/synthesis/map.md", path
        normalized.append({"path": path, "generated_coverage_map_refreshed": True})
assert raw_before == {str(p.relative_to(book)): digest(p) for p in (book / "raw").rglob("*") if p.is_file()}
(evidence / "inherited-build-normalization.json").write_text(json.dumps(normalized, indent=2) + "\n")
before = {str(p.relative_to(book)): digest(p) for p in (book / "wiki").rglob("*") if p.is_file()}
assert (book / "library.bib").read_bytes() == raw

bad = b"@article{ok,title={Good}}\n@article{bad,title={Unclosed}"
(book / "bad.bib").write_bytes(bad)
failure = run("wiki", "import-bibtex", "bad.bib", cwd=book, ok=False)
assert "original retained at" in failure and "BibTeX line" in failure
assert (book / "raw/imported/references-3.bib").read_bytes() == bad
assert before == {str(p.relative_to(book)): digest(p) for p in (book / "wiki").rglob("*") if p.is_file()}

receipt = {"cli_forms": ["omitted", "dot", "absolute"], "references_per_import": 2,
           "query_terms": 4, "static_render_verified": True, "reference_bodies_and_raw_bytes_preserved": True,
           "inherited_source_metadata_normalization_recorded": True,
           "malformed_later_entry_retained_without_partial_pages": True,
           "original_sha256": hashlib.sha256(raw).hexdigest()}
(evidence / "cli-smoke-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
