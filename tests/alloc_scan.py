#!/usr/bin/env python3
"""Read the emitted LLVM for textwrap-nv and say whether any function
that walks and measures text can put a cell on the heap.

Run by tests/alloc_scan.sh twice: once on the package as it stands, and
once on a copy with an allocation spliced into the walk, because a
check that cannot fail is not a check.

The file is `_novo/textwrap-nv.ll`, which `novo test` writes when it
compiles the package and its suites as one unit.  Every function is a
separate `define` in it, which is what the scan needs: at a level where
the walk had been inlined into its callers there would be no function
left to attribute an allocation to, and the scan would pass over
nothing.  `FLOOR` is what catches that.
"""
import re
import sys

# Every way a function can put a cell on the heap.  `novo_alloc*` is the
# direct one.  The other four allocate inside the runtime, so a search
# for the first alone would call a per-character boxing loop
# allocation-free.
BOXERS = ['novo_alloc', 'novo_some_int', 'novo_some_float',
          'novo_str_byte_at(', 'novo_bytes_byte_at(']

# The walk and the measurement loops.  A caller sizing a table column
# or deciding where a status bar ends runs these once per codepoint per
# frame, and they answer a number over a string the caller already
# holds.
#
# The four rule constructors are not here.  A `WrapWidth` is a heap
# cell, and a caller builds one and keeps it.  `char_width` is not here
# either: it calls the rule through the struct, and the generic arm of
# an indirect call boxes its argument.  No rule this package builds
# takes that arm — a named function takes the flat one and a closure
# takes the typed one — and a scan over text cannot tell one branch
# from another.
WALK = re.compile(r'^novo_user_(widths_(?!tests_)(seq_len|cp_at|range_width|'
                  r'fit_range|fit_suffix|str_width|prefix_width|fit_prefix|'
                  r'one_column|printable_ascii_column|unicode_column)|'
                  r'wrapping_is_break_char)$')

FNS = re.compile(r'^define[^\n]*?@([A-Za-z0-9_.]+)\([^\n]*\{\n(.*?)\n\}',
                 re.S | re.M)

# The twelve functions named above.  Fewer than this in the IR means
# the naming scheme moved, or the unit was built at a level that
# inlined them away, and that the scan was measuring nothing.
FLOOR = 12


def main(path):
    src = open(path, encoding='utf-8', errors='replace').read()
    seen, offenders = 0, []
    for m in FNS.finditer(src):
        name, body = m.group(1), m.group(2)
        if not WALK.match(name):
            continue
        seen += 1
        for boxer in BOXERS:
            if 'call' in body and ('@' + boxer) in body:
                offenders.append('%s: %s' % (name, boxer.rstrip('(')))
    if seen < FLOOR:
        print('FAIL only %d walk function(s) in the IR, expected %d — the '
              'naming scheme moved or the unit was inlined, and this check '
              'was measuring nothing' % (seen, FLOOR))
    elif offenders:
        print('FAIL ' + '; '.join(sorted(set(offenders))))
    else:
        print('OK %d function(s) walk and measure, zero heap cells' % seen)


if __name__ == '__main__':
    main(sys.argv[1])
