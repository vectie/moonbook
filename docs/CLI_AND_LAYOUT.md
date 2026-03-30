# CLI And Layout

## Commands

### `moon run cmd/main -- init <root>`

Creates a minimal book project:

- `<root>/book.toml`
- `<root>/.gitignore`
- `<root>/src/SUMMARY.md`
- `<root>/src/chapter_1.md`
- `<root>/book/`

Current defaults:

- source directory: `src`
- build directory: `book`
- first chapter: `chapter_1.md`

### `moon run cmd/main -- build <root>`

Build pipeline:

1. load config
2. parse `src/SUMMARY.md`
3. load chapter files
4. preprocess README chapter paths into `index.*`
5. render HTML output
6. write `book/book.json`

### `moon run cmd/main -- load <root>`

Loads the book and prints the full JSON representation of:

- root
- config
- book
- summary

This is useful for debugging the parsed chapter tree and path normalization.

### `moon run cmd/main -- test <root>`

Loads the book and reports the number of Rust fenced code blocks discovered in chapter content.

### `moon run cmd/main -- clean <root>`

Deletes the build directory and reports:

- files removed
- directories removed
- bytes removed

### `moon run cmd/main -- version`

Prints the current mdBook compatibility version from [core/book.mbt](/Users/kq/Workspace/moonbook/core/book.mbt).

## Output Files

Current build outputs:

- `index.html`
- one `.html` file per non-draft chapter
- copied local assets referenced by chapter content
- `book.json`

`book.json` contains:

- book root
- parsed config
- preprocessed book tree
- parsed summary tree

## Package Layout

### `core/`

Holds the mdBook-style data model and config parsing:

- `Book`
- `BookItem`
- `Chapter`
- `SectionNumber`
- `Config`

### `summary/`

Owns parsing `SUMMARY.md` into a typed tree that the driver can load from disk.

### `driver/`

Owns:

- initialization
- loading from disk
- missing-file generation
- build orchestration
- cleaning
- manifest writing

### `html/`

Owns:

- navigation rendering
- page shell rendering
- markdown-to-HTML rendering
- code block post-processing
- asset collection and copying

### `internal/`

Contains internal filesystem/path helpers copied and adapted from MoonClaw where needed.

### `ui/`

Contains Rabbita frontend work. The shell compiles, but the UI is not yet feature-complete relative to the CLI/HTML side.
