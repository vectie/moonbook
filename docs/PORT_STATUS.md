# Port Status

Moonbook is a partial mdBook port, not a finished drop-in replacement.

## What Is Solid Right Now

- native MoonBit model for books/config
- `SUMMARY.md` parsing for the currently documented cases
- end-to-end local CLI flow for `init`, `build`, `serve`, `watch`, `load`, `test`, and `clean`
- static HTML generation for normal chapter trees
- broad markdown coverage for common book content
- mdBook-style heading/link behavior for many inline cases
- mdBook-style playground and hidden-line treatment for code blocks
- local static HTTP serving of the built book
- local polling watcher that rebuilds on source/config changes

## What Is Still Missing

### CLI/Workflow Gaps

- `serve` live reload websocket
- `serve --open`
- `serve --dest-dir`
- `watch --watcher` parity with upstream poll/native selection
- `serve`/`watch` `.gitignore` behavior
- `test` parity with upstream behavior
- `init` parity beyond the current minimal skeleton
- plugin/preprocessor command execution
- renderer extensibility surface

### Config Gaps

- full `output.html.*` compatibility
- full `preprocessor.*` compatibility
- theme/search/playground config parity
- redirect and print-specific config support

### Rendering Gaps

- full CommonMark and pulldown-cmark parity
- search output generation
- print renderer
- complete theme assets and theming behavior
- syntax highlighting integration
- more mdBook edge cases around HTML trees, escapes, and markdown nesting

### Frontend Gaps

- Rabbita is still a shell rather than a complete operator/book-reading frontend
- no integrated live preview with rebuild-triggered browser refresh

## Suggested Next Work

High-value next steps:

1. expand `book.toml` compatibility, especially `output.html.*`
2. continue renderer parity with more mdBook rendering tests
3. add theme/static asset support beyond the current inline stylesheet
4. add live reload parity on top of the new static `serve` and polling `watch` commands
5. connect Rabbita to real built-book state and navigation

## Documentation Rule

When new compatibility work lands, update [docs/FEATURE_MATRIX.md](/Users/kq/Workspace/moonbook/docs/FEATURE_MATRIX.md) first. If the change affects command behavior or repo structure, also update [docs/CLI_AND_LAYOUT.md](/Users/kq/Workspace/moonbook/docs/CLI_AND_LAYOUT.md). If it changes the parity boundary, update this file.
