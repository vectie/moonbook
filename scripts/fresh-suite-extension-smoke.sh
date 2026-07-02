#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
moon_bin="${MOON_BIN:-/Users/kq/.moon/bin/moon}"
tmp_parent="${TMPDIR:-/tmp}"
tmp_parent="${tmp_parent%/}"
suite_root="$(mktemp -d "$tmp_parent/moonbook-fresh-suite-extension.XXXXXX")"
suite_root="$(cd "$suite_root" && pwd)"

cleanup() {
  rm -rf "$suite_root"
}
trap cleanup EXIT

book_root="$suite_root/books/research-wiki"
product_home="$suite_root/.moonsuite/products/moonclaw"

mkdir -p "$suite_root/.moonsuite" "$suite_root/.tmp" "$suite_root/books"

run_moonbook() {
  "$moon_bin" run cmd/main --target native -- "$@"
}

assert_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "expected file missing: $path" >&2
    exit 1
  fi
}

assert_absent() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "legacy path should not exist: $path" >&2
    exit 1
  fi
}

assert_contains() {
  local path="$1"
  local needle="$2"
  if ! /usr/bin/grep -Fq "$needle" "$path"; then
    echo "expected $path to contain: $needle" >&2
    exit 1
  fi
}

cd "$repo_root"

run_moonbook wiki init "$book_root" >/dev/null
run_moonbook wiki enable moonclaw "$book_root" >/dev/null

assert_file "$book_root/extensions/moonclaw.json"
assert_file "$book_root/moonclaw.jobs.json"
assert_file "$product_home/moonclaw.json"
assert_file "$product_home/providers.json"
assert_file "$book_root/IDENTITY.md"
assert_file "$book_root/USER.md"
assert_file "$book_root/ROUTINES.md"
assert_file "$book_root/MEMORY.md"
assert_file "$book_root/KEEPER.md"
assert_file "$book_root/skills/wiki-maintainer/SKILL.md"
assert_file "$book_root/skills/wiki-review/SKILL.md"

assert_contains "$book_root/extensions/moonclaw.json" ".moonsuite/products/moonclaw/moonclaw.json"
assert_contains "$book_root/extensions/moonclaw.json" "\"jobs\": \"moonclaw.jobs.json\""
assert_contains "$product_home/moonclaw.json" "\"workspace\": \"$book_root\""
assert_contains "$product_home/providers.json" "\"name\": \"moonbook\""
assert_contains "$product_home/providers.json" "\"workspace_root\": \"$book_root\""

assert_absent "$book_root/moonclaw.json"
assert_absent "$book_root/.moonclaw"
assert_absent "$suite_root/moonclaw.json"
assert_absent "$suite_root/.moonclaw"
assert_absent "$suite_root/moonclaw-jobs"

echo "MoonBook fresh-suite extension smoke passed on $suite_root"
