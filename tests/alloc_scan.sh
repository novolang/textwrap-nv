#!/usr/bin/env bash
# tests/alloc_scan.sh — measuring text allocates nothing, as a check
# that can fail.
#
# This package builds strings, and `wrap`, `fill` and the truncations
# put every line they answer on the heap.  That is what they are for.
# The other half answers a number over a string the caller already
# holds — how wide is this, how many bytes fit in eight columns — and a
# terminal asks it once per codepoint per frame.  Nothing in the
# language enforces that the walk stays off the heap, and the emitted
# LLVM is where it is true or false, so this reads it.
#
# There are two runs, because a check that cannot fail is not a check.
#
#   1. The twelve functions that walk and measure appear in the IR, and
#      none of them calls the allocator, directly or through a runtime
#      entry point that allocates on the caller's behalf.
#   2. The scan still sees an allocation.  A heap list literal is
#      spliced into `range_width` on a copy of the tree, and the scan
#      has to name it.  Without this run, a scan that quietly stopped
#      matching would pass forever.
#
# The IR is `_novo/textwrap-nv.ll`, which `novo test` writes when it
# compiles the package and its suites as one unit.  `novo build` is the
# other way to reach it and does not resolve the package's dependency.
#
# Run from anywhere:  bash tests/alloc_scan.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
NOVO="${NOVO:-$HOME/.novo/bin/novo}"
SCAN="$HERE/alloc_scan.py"

PASS=0; FAIL=0
pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; [ -n "${2:-}" ] && echo "$2" | sed 's/^/      /'; FAIL=$((FAIL + 1)); }

echo ""
echo "══════════════════════════════════════════"
echo "  textwrap-nv — measuring text allocates nothing"
echo "══════════════════════════════════════════"

[ -x "$NOVO" ] || { fail "novo present at $NOVO"; echo "pass=$PASS fail=$FAIL"; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/textwrap-nv-alloc.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# The splice is a heap list literal bound in `range_width`, and read, so
# it cannot be folded away.
splice() {  # splice <src/widths.nv>
  python3 - "$1" <<'PY'
import sys
path = sys.argv[1]
s = open(path).read()
anchor = ("fn range_width(w: WrapWidth, text: Str, from: Int, to: Int) -> Int\n"
          "    var total = 0\n")
if anchor not in s:
    sys.exit("anchor not found — alloc_scan.sh's splice is measuring nothing")
s = s.replace(anchor, anchor.rstrip('\n') + "\n    let probe = [1, 2, 3]\n"
              "    total = total + probe[0] - 1\n")
open(path, 'w').write(s)
PY
}

emit_ir() {  # emit_ir <tree>
  ( cd "$1" && rm -f _novo/textwrap-nv.ll \
      && NOVO_LEAK_CHECK=0 timeout 1800 "$NOVO" test tests/widths_tests.nv ) \
      >"$1/build.log" 2>&1
  [ -s "$1/_novo/textwrap-nv.ll" ]
}

# ── 1. nothing in the walk allocates ─────────────────────────────────

cp -r "$PKG" "$WORK/ok" 2>/dev/null
rm -rf "$WORK/ok/_novo"
if emit_ir "$WORK/ok"; then
  report="$(python3 "$SCAN" "$WORK/ok/_novo/textwrap-nv.ll")"
  if [ "${report#OK}" != "$report" ]; then
    pass "nothing in the walk allocates — ${report#OK }"
  else
    fail "nothing in the walk allocates" "${report#FAIL }"
  fi
else
  fail "the package compiles to LLVM" "$(grep -E 'error' "$WORK/ok/build.log" | head -5)"
fi

# ── 2. the scan still sees an allocation ─────────────────────────────

cp -r "$PKG" "$WORK/neg" 2>/dev/null
rm -rf "$WORK/neg/_novo"
if splice "$WORK/neg/src/widths.nv" >"$WORK/splice.log" 2>&1 && emit_ir "$WORK/neg"; then
  neg="$(python3 "$SCAN" "$WORK/neg/_novo/textwrap-nv.ll")"
  if [ "${neg#FAIL}" != "$neg" ] && printf '%s' "$neg" | grep -q 'range_width'; then
    pass "the scan still sees an allocation spliced into the walk"
  else
    fail "the scan still sees an allocation spliced into the walk" \
         "expected a finding naming range_width; got: $neg"
  fi
else
  fail "the negative control builds" \
       "$(cat "$WORK/splice.log"; grep -E 'error' "$WORK/neg/build.log" | head -5)"
fi

echo ""
echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
