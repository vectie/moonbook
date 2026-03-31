# Moonbook

> MoonBit-native mdBook port with a Rabbita frontend and an incremental compatibility layer over the original Rust implementation.

`MoonBit` `mdBook` `SUMMARY.md` `HTML Renderer` `CLI` `Rabbita`

Moonbook is a MoonBit rewrite of the mdBook toolchain currently focused on:

- loading and modeling books in MoonBit
- parsing `SUMMARY.md`
- building a static HTML output tree
- serving the built book over local HTTP
- watching source files and rebuilding on change
- preserving mdBook-style navigation and many markdown rendering behaviors
- exposing a native CLI flow for `init`, `build`, `serve`, `watch`, `load`, `test`, and `clean`

The project is not at full upstream parity yet. The current state is a working vertical slice with a growing set of mdBook-compatible cases.

## Current Capabilities

- native MoonBit book/config model
- `book.toml` loading for core book/build/rust fields
- `SUMMARY.md` parsing with numbering, nesting, parts, separators, and draft chapters
- end-to-end `init`, `build`, `serve`, `watch`, `load`, `test`, `clean`, and `version` commands
- HTML output with sidebar navigation, breadcrumbs, and previous/next links
- markdown rendering for the implemented mdBook-compatible cases listed in [docs/FEATURE_MATRIX.md](/Users/kq/Workspace/moonbook/docs/FEATURE_MATRIX.md)
- copied local asset handling for images and raw HTML references
- mdBook-style code block handling for playground and hidden-line cases
- local static hosting of the generated book
- Rabbita frontend scaffolding under `ui/`

## Quick Start

From the repo root:

```bash
moon check
moon run cmd/main -- init ./book-example
moon run cmd/main -- build ./book-example
moon run cmd/main -- serve ./book-example -n 127.0.0.1 -p 3000
moon run cmd/main -- watch ./book-example
moon run cmd/main -- load ./book-example
moon run cmd/main -- test ./book-example
moon run cmd/main -- clean ./book-example
```

Useful commands:

```bash
moon run cmd/main -- version
moon test html
moon test summary
moon test driver
```

## Project Layout

- `core/`
  mdBook-style domain model and config decoding
- `summary/`
  `SUMMARY.md` parser and numbering logic
- `driver/`
  book initialization, loading, preprocessing, and manifest writing
- `html/`
  static HTML renderer and markdown compatibility layer
- `cmd/main/`
  native CLI entrypoint
- `internal/`
  copied filesystem and path helpers adapted from MoonClaw
- `ui/`
  Rabbita frontend work

## Docs

- [docs/FEATURE_MATRIX.md](/Users/kq/Workspace/moonbook/docs/FEATURE_MATRIX.md)
  comprehensive implemented cases and renderer behavior
- [docs/CLI_AND_LAYOUT.md](/Users/kq/Workspace/moonbook/docs/CLI_AND_LAYOUT.md)
  commands, output files, and package structure
- [docs/PORT_STATUS.md](/Users/kq/Workspace/moonbook/docs/PORT_STATUS.md)
  current parity boundary, known gaps, and next major work areas

## Current Boundary

Moonbook currently behaves like a partial mdBook replacement for straightforward books. It now includes basic static `serve` and polling `watch`, but it does not yet provide full upstream behavior for live reload, watcher-mode parity, themes, search, preprocessors/plugins, print output, or the complete markdown/rendering edge-case surface of Rust mdBook.
