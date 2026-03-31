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

### `moon run cmd/main -- serve <root> [-n hostname] [-p port] [-d dest-dir] [-o] [--watcher poll|native]`

Runs a local static HTTP server for the built book:

1. load config
2. optionally override the build directory
3. build the book into `build.build_dir`
4. optionally open the served URL in the system browser
5. bind an HTTP server
6. serve `index.html` at `/`
7. serve files directly from the build directory
8. serve `404.html` for missing paths when present
9. poll for source/config changes and rebuild the served output

Current defaults:

- hostname: `localhost`
- port: `3000`
- watcher: `poll`

Current note:

- `--watcher native` is accepted, but currently uses the polling backend

### `moon run cmd/main -- watch <root> [-d dest-dir] [-o] [--watcher poll|native]`

Runs a polling rebuild loop for the book:

1. load config
2. optionally override the build directory
3. build the book once
4. optionally open the generated `index.html` in the system browser
5. scan `book.src/` and `book.toml`
6. apply ignore rules from the book root `.gitignore`
7. poll for changes every second
8. rebuild on detected changes

Current note:

- `--watcher native` is accepted, but currently uses the polling backend

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
- copied configured `output.html.additional-css` and `output.html.additional-js` assets
- `404.html` or another configured 404 output file
- `CNAME` when `output.html.cname` is set
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
- `serve` build preparation through the shared load/build flow

### `html/`

Owns:

- navigation rendering
- page shell rendering
- markdown-to-HTML rendering
- code block post-processing
- asset collection and copying
- configured `output.html` asset injection and `CNAME` emission

### `internal/`

Contains internal filesystem/path helpers and a minimal HTTP static server adapted from MoonClaw where needed.

### `ui/`

Contains Rabbita frontend work. The shell compiles, but the UI is not yet feature-complete relative to the CLI/HTML side.
