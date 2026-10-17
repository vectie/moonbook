#!/usr/bin/env bash
# Cwd-independent focused check. No dependency installation or source substitution.
set -euo pipefail
SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUND="$(dirname "$SOURCE")"
ENVIRONMENT=/workspace/scratch/665adc5202cf/.moonsuite-background/build-readiness-20261011T131950/environment.sh
CACHE=/workspace/scratch/665adc5202cf/.moonsuite-background/release-blockers-20261012T095200/sources/moonproj/.mooncakes/moonbit-community/rabbita
export WORKER_ROOT="${MOONBOOK_TEST_ROOT:-$ROUND/focused-check-$(date -u +%Y%m%dT%H%M%S)-$$}"
case "$WORKER_ROOT" in "$ROUND"/*) ;; *) echo 'MOONBOOK_TEST_ROOT must be an absolute new directory under this round.' >&2; exit 2;; esac
if [ -e "$WORKER_ROOT" ]; then echo "Refusing to overwrite prior evidence: $WORKER_ROOT" >&2; exit 2; fi
mkdir -p "$WORKER_ROOT/logs"
# Production JS controller can also run alone on any machine with Node:
# node --test /absolute/source/scripts/lesson-comparison.test.mjs
node --test "$SOURCE/scripts/lesson-comparison.test.mjs" "$SOURCE/scripts/lesson-rehearsal.test.mjs" | tee "$WORKER_ROOT/logs/node.log"
if [ ! -f "$ENVIRONMENT" ] || [ ! -f "$CACHE/moon.mod" ]; then echo 'Pinned toolchain or exact approved Rabbita cache unavailable; compiled checks not run.' >&2; exit 2; fi
[ "$(sha256sum "$CACHE/moon.mod" | cut -d ' ' -f1)" = 446a668ba69b288b1ed8af62c2efd4aa579eba7f976221a06614108507b4cb9f ] || { echo 'Rabbita cache manifest differs from the approved 0.12.4 receipt.' >&2; exit 2; }
[ "$(df -Pk "$ROUND" | awk 'NR==2 {print $4}')" -ge 4194304 ] || { echo 'Less than 4 GiB free; compiled checks not run.' >&2; exit 2; }
. "$ENVIRONMENT"
cp -a "$SOURCE/ui/rabbita-book" "$WORKER_ROOT/ui"
mkdir -p "$WORKER_ROOT/ui/.mooncakes/moonbit-community"
cp -a "$CACHE" "$WORKER_ROOT/ui/.mooncakes/moonbit-community/rabbita"
# This is the unchanged current UI module, isolated from root moon.work's absent
# ../moonleaf. It does not qualify that root workspace or substitute a Leaf.
moon -C "$WORKER_ROOT/ui" check --target js --frozen --target-dir "$WORKER_ROOT/build" -j 1 > "$WORKER_ROOT/logs/check.log" 2>&1
for name in lesson_comparison lesson_rehearsal outcome_lesson_state lesson_browser; do
  moon -C "$WORKER_ROOT/ui" test "main/${name}_wbtest.mbt" --target js --frozen --target-dir "$WORKER_ROOT/build" -j 1 > "$WORKER_ROOT/logs/$name.log" 2>&1
  tail -1 "$WORKER_ROOT/logs/$name.log"
done
# The fifth pre-existing guidance test requires an external native wire. Exclude
# its fixture-gated body instead of counting an early return as runtime coverage.
moon -C "$WORKER_ROOT/ui" test main/task_guidance_wbtest.mbt --index 0-4 --target js --frozen --target-dir "$WORKER_ROOT/build" -j 1 > "$WORKER_ROOT/logs/task_guidance.log" 2>&1
tail -1 "$WORKER_ROOT/logs/task_guidance.log"
moon -C "$WORKER_ROOT/ui" info --target js --frozen --target-dir "$WORKER_ROOT/build" > "$WORKER_ROOT/logs/info.log" 2>&1
moon -C "$WORKER_ROOT/ui" fmt --target-dir "$WORKER_ROOT/build" > "$WORKER_ROOT/logs/fmt.log" 2>&1
printf 'Focused checks passed. Evidence: %s\n' "$WORKER_ROOT/logs"
