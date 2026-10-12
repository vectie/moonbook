# Find a section inside a long chapter

Build a normal SUMMARY-based Book, then open a chapter page. Below its title,
“On this page” lists that chapter’s rendered Markdown sections in source order.
Select a section to jump to its heading. Tab reaches each link; Enter follows it.
The disclosure can be collapsed and reopened with the browser’s native control.
It works offline without JavaScript, storage, or a server.

```sh
moonbook build ./handbook
# Open ./handbook/book/nested/guide.html, for example.
```

The existing build route automatically includes the outline. No additional CLI
flag or manual table of contents is needed. Edit the chapter’s Markdown and
rebuild to refresh both text and section links. A chapter with no remaining
Markdown headings has no outline; a duplicate leading chapter title is already
removed by the renderer and is not listed again.

Navigation labels use the renderer’s plain inline text, with HTML escaped rather
than creating nested links or markup. UTF-8 fragment encoding supports Unicode.
Heading levels are visually indented; skipped levels retain their real level.
Code fences, quoted paragraphs, reference definitions, footnotes and raw HTML
headings do not become Markdown outline entries. This follows the existing
renderer’s supported Markdown syntax, not a separate CommonMark implementation.
An invisible heading receives the label “Untitled section.” Punctuation-only
headings have a nonempty `section` target. Duplicate heading targets and clashes
with generated numeric suffixes are disambiguated in source order. Ordinary
existing slugs remain unchanged; previously ambiguous/empty slugs are corrected.
Hand-authored raw HTML IDs are outside the generated-heading uniqueness contract.

The outline appears on ordinary chapter pages and is hidden for printing those
pages. Whole-book output and EPUB rendering do not receive this navigation panel.
No source, review status, permission, raw evidence or saved notebook is changed.
The outline is replaceable generated output, not a new authoritative store.

## Focused verification

The retained native test calls the production public HTML renderer with real
on-disk Markdown fixtures. It checks generated pages, repeat builds, a retained
source edit and regeneration, a sectionless chapter, whole-book exclusion, and
unchanged source files. A separate Python HTML parser verifies all ten generated
section links resolve to exactly one heading, including Unicode, inline labels,
duplicate/natural-suffix clashes, empty labels and skipped levels. All generated
pages and test inputs remain in the evidence folders.

Run `verify.sh NEW_LABEL` from the round kit to repeat into a new evidence folder.
This is focused native rendering/API qualification. The root CLI, complete suite,
interactive browser/keyboard behavior, EPUB export, live reload and other backends
were not qualified in this round. The native disclosure/link behavior is provided
by standard HTML; no browser automation was run.
