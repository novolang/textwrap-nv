#!/usr/bin/env bash
# tests/coverage.sh — the measured line and function coverage over
# `src/`, merged across the suites.
#
# `novo test --cov` measures one suite file at a time, and a suite's
# percentage counts the suite's own lines as well as the package's.  No
# single number it prints is the one `docs/publishing.md`
# § Test coverage asks for.  This merges the per-suite LCOV and reports
# `src/` alone, which is what a release is measured on.
#
# The function count comes from the same runs.  `--cov` names the
# functions a suite did not reach, and a function no suite reached is
# the one this reports.  Both counts are over this package's own
# modules; a dependency's sources are compiled into the same unit and
# are measured by that dependency's own suites.
#
# Run from anywhere:  bash tests/coverage.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
NOVO="${NOVO:-$HOME/.novo/bin/novo}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/textwrap-nv-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

for suite in "$PKG"/tests/*_tests.nv; do
  base="$(basename "$suite" .nv)"
  ( cd "$PKG" && NOVO_LEAK_CHECK=0 timeout 1800 "$NOVO" test "tests/$base.nv" \
      --cov --report=lcov ) >"$WORK/$base.log" 2>&1
  if [ -f "$PKG/_novo/$base.lcov.info" ]; then
    cp "$PKG/_novo/$base.lcov.info" "$WORK/"
  else
    echo "  ✗ $base — no LCOV written; see $WORK/$base.log"
    exit 1
  fi
done

python3 - "$WORK" "$PKG" <<'PY'
import collections, glob, os, re, sys

work, pkg = sys.argv[1], sys.argv[2]
own = os.path.join(pkg, 'src') + os.sep
mine = set(os.path.basename(f) for f in glob.glob(os.path.join(pkg, 'src', '*.nv')))

cov = collections.defaultdict(dict)
for path in glob.glob(os.path.join(work, '*.lcov.info')):
    current = None
    for line in open(path):
        line = line.strip()
        if line.startswith('SF:'):
            current = line[3:]
        elif line.startswith('DA:'):
            n, hits = line[3:].split(',')[:2]
            n, hits = int(n), int(hits)
            cov[current][n] = cov[current].get(n, 0) + hits

# A function no suite reached.  Each run names the ones it missed, so
# the ones missed by every run are the intersection.
missed = None
total_fns = 0
for path in sorted(glob.glob(os.path.join(work, '*.log'))):
    text = open(path).read()
    here = set(f for f in re.findall(r'^\s+-\s+(\S+:\S+)\s*$', text, re.M)
               if f.split(':')[0] in mine)
    missed = here if missed is None else (missed & here)
missed = missed or set()

# Every top-level function this package declares, which is what the
# uncovered names are counted against.
for path in sorted(glob.glob(os.path.join(pkg, 'src', '*.nv'))):
    total_fns += len(re.findall(r'^(?:pub )?fn \w+\(', open(path).read(), re.M))

total = covered = 0
print('')
for path in sorted(cov):
    if not path.startswith(own):
        continue
    lines = cov[path]
    hit = sum(1 for v in lines.values() if v > 0)
    gaps = sorted(n for n, v in lines.items() if v == 0)
    total += len(lines)
    covered += hit
    print('  %-20s %3d/%-3d  %s' % (
        os.path.basename(path), hit, len(lines),
        'uncovered: ' + ' '.join(str(n) for n in gaps) if gaps else '100%'))

pct = 100.0 * covered / total if total else 0.0
fn_hit = total_fns - len(missed)
fn_pct = 100.0 * fn_hit / total_fns if total_fns else 0.0
print('')
if missed:
    print('  functions never reached: ' + ' '.join(sorted(missed)))
print('  src/ total: %d/%d lines — %.1f%%; %d/%d functions — %.1f%%' % (
    covered, total, pct, fn_hit, total_fns, fn_pct))
sys.exit(0 if covered == total and not missed else 1)
PY
