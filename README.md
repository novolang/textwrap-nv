# textwrap-nv

Wrapping, filling and truncating text to fit a **display width**: the
number of columns the text occupies on a terminal, rather than the
number of characters in it. The shape of the interface follows
[the `textwrap` crate](https://docs.rs/textwrap/), and `indent` and
`dedent` follow
[Python's `textwrap` module](https://docs.python.org/3/library/textwrap.html).
[tui-nv](https://novo-lang.org/packages/tui-nv) is built on it and uses
it for the paragraph widget.

## What it is

A monospace terminal is a grid of cells. Most characters occupy one
cell. A Chinese, Japanese or Korean ideograph occupies two, and so does
an emoji drawn in its wide form. A combining mark, such as the accent
that turns `e` into `é` when it follows one, occupies none: it is drawn
on top of the character before it. The number of cells a character
occupies is its **display width**.

This is why "how many characters fit in eighty columns" has no answer
and "how many columns does this text occupy" has one. Every function in
this package is written in terms of the second.

A **break opportunity** is a position where a line may be broken. Here
that means a space or a tab, and, when the caller asks for it, the
position after a hyphen that is already in the text. To **wrap** text is
to insert breaks at those positions so that no line exceeds a given
width. To **fill** text is to wrap it and join the lines back together.
An **indent** is a prefix put on the front of a line, and its width
counts against the column count.

The primitive is `wrap_spans`, which answers a list of **spans**: byte
offsets into the original text, one pair per line, each with the width
the wrap measured. Text on a terminal is usually styled, and the styling
is described by offsets into that same text. A wrap that answered a list
of strings would throw those offsets away, and the caller would have to
recover them by doing the wrap again. `wrap` and `fill` are `wrap_spans`
plus a slice, for a caller whose text is not styled.

The display width itself is a Unicode table: the East Asian Width
property of [UAX #11](https://www.unicode.org/reports/tr11/) for the
wide forms, the general categories Mn, Me and Cf for the zero-width
ones, and the emoji presentation rules for the sequences that join. That
table lives in
[unicode-nv](https://novo-lang.org/packages/unicode-nv). This package
takes the rule as an argument, a `WrapWidth`, which is one function from
a codepoint to a column count. Four of them are ready to pass.

| Rule | Answers |
| --- | --- |
| `unicode_width()` | UAX #11: 0 for a combining mark, 2 for a wide or fullwidth form, 1 otherwise |
| `monospace_width()` | 1 for every codepoint |
| `ascii_width()` | 1 for a printable ASCII codepoint, 0 for everything else |
| `fixed_width(n)` | `n` for every codepoint |

`unicode_width` is the one a terminal is written against.
`monospace_width` is correct for text that is entirely ASCII, which is
most of what a command-line program wraps, and it touches no table.
Where it is wrong, the wrapped line comes out too long rather than too
short, so the error is visible on the screen.

## Install

```
novo pkg add textwrap-nv
```

## Example

```novo
use std.str
use widths
use wrapping

fn main() [io]
    let text = "the quick brown fox jumps over the lazy dog"
    let rule = widths.unicode_width()

    // Wrap to twenty columns and join the lines back into one string.
    println(wrapping.fill(text, 20, rule, wrapping.default_options()))
    // the quick brown fox
    // jumps over the lazy
    // dog

    // The same wrap, as ranges of the source rather than as strings.
    for s in wrapping.wrap_spans(text, 20, rule, wrapping.default_options())
        // start and end are byte offsets into the original text, so a
        // caller that had marked "quick" bold at 4..9 still knows where
        // it is. width is the line's display width under the rule.
        println(str.from_int(s.start) + ".." + str.from_int(s.end)
                + " (" + str.from_int(s.width) + " columns)")

    // How tall this paragraph is at twenty columns, without building
    // the lines. This is the question a layout asks.
    println(str.from_int(wrapping.wrapped_height(text, 20, rule,
                                                 wrapping.default_options())))
```

Build and test with `novo pkg build` and `novo test`.

## What the package contains

| Module | Contents |
| --- | --- |
| `widths` | The display-width rule as a value, the four rules ready to pass, and the measurements taken with one: a codepoint, a whole string, a prefix, and how many bytes fit in a given number of columns. |
| `wrapping` | The wrap and everything over it: the options, the three break policies, the span, `wrap`, `fill`, `fill_aligned`, the height, the two truncations, padding, indent and dedent, and the break opportunities on their own. |

## How to choose an entry point

**`wrapping.wrap_spans` is the primitive.** Use it when the text is
styled, when you want the measured widths, or when you are going to
slice the source yourself.

**`wrapping.wrap` answers a list of strings and `fill` answers one
string.** Use them when the text is plain.

**`wrapping.wrapped_height` answers only how many lines there will be.**
A layout deciding how tall to make a box asks this, and no list of
strings is built.

**`wrapping.break_offsets` answers where a break is allowed and stops
there.** It is for a caller with its own line-breaking: a justifier, or
a diff that wants to split a long line somewhere sensible.

**`widths.str_width` measures without wrapping.** Sizing a table column
or a status bar is this question and not a wrap.

## The rules a user needs

1. **The width rule is an argument, and `monospace_width` is not the
   Unicode answer.** It answers 1 for every codepoint, including
   ideographs, emoji and combining marks. `unicode_width` is the
   Unicode answer, from UAX #11.
2. **`unicode_width` answers 1 for the ambiguous class.** A terminal
   configured for a CJK locale draws the Greek and Cyrillic letters two
   cells wide and every other terminal draws them one. Only the program
   knows which terminal it is talking to, so a program that knows it is
   the first passes
   `WrapWidth { of_char: uwidth.char_width_cjk }` instead.
3. **`WrapSpan.start` and `.end` are byte offsets into the source.**
   `end` is one past the last byte, with trimmed trailing whitespace
   already excluded.
4. **`WrapSpan.width` does not count the indent.** The indent's width
   does count against the column count during the wrap.
5. **A newline already in the text always ends a line.** `wrap_spans`
   adds breaks. It never removes one.
6. **A `columns` of zero or less answers one span covering
   everything.** A wrap to no width has no answer, and an empty list
   would lose the text silently.
7. **The break policy decides what happens to a word wider than the
   line.** `WrapAtWords` puts it on a line of its own and lets it
   overflow. `WrapBreakLongWords` cuts it at the column. `WrapNoBreak`
   does not break at all and gives one output line per input line.
8. **The wrap is greedy.** It puts as many words on a line as fit and
   breaks before the first one that does not, which is what both
   reference implementations do by default.
9. **The whitespace a line was broken at belongs to the line before
   it.** `trim_trailing` is on by default and drops it, because
   trailing spaces on a terminal line are invisible until something
   inverts them.
10. **The whitespace an input line starts with is kept.** It is the
    line's own indentation and not a break, so wrapped code and wrapped
    tables keep their shape.
11. **`collapse_whitespace` is off by default, and `wrap_spans` does
    not act on it.** A span is a range of the text it was given, and no
    range can stand for a run of three spaces rewritten as one. `wrap`,
    `fill`, `fill_aligned` and `wrapped_height` collapse the text and
    wrap the result.
12. **`initial_indent` and `subsequent_indent` are different fields
    because a bulleted list needs both.** `indented_options("- ", "  ")`
    is that shape.
13. **`truncate` counts its own ellipsis.** The result is never wider
    than `columns`. Text that already fits is returned unchanged, with
    no ellipsis appended. An ellipsis at least as wide as `columns`
    leaves no room for text, and the answer is then the text cut to
    `columns` with no ellipsis at all.
14. **`truncate_middle` keeps both ends.** For a path or an identifier,
    the start says what kind of thing it is and the end says which one.
    The end gets the odd column when the room left does not halve
    evenly.
15. **`pad` never truncates.** Text wider than the field is returned
    unchanged. A caller that wants both calls `truncate` first.
16. **`widths.fit_prefix` answers a byte count, not a codepoint
    count.** A codepoint that would straddle the edge is left out
    entirely, so a wide character with one column left does not half
    fit.
17. **`indent` leaves blank lines alone**, so the result diffs cleanly
    and no blank line gains trailing whitespace. `dedent` ignores them
    when it looks for the common prefix and answers them empty. A line
    with no character other than whitespace counts as blank for both,
    which is Python's rule.
18. **`split_on_hyphens` is not hyphenation.** It breaks after a hyphen
    that is already in the text. Nothing is inserted and no dictionary
    is consulted.
19. **`break_offsets` answers one offset per opportunity.** A break
    character contributes its own offset, and a hyphen contributes the
    offset just after it. A run of three spaces is three
    opportunities.
20. **`is_break_char` knows about spaces and tabs.** It is not the line
    breaking algorithm of
    [UAX #14](https://www.unicode.org/reports/tr14/), which needs the
    same table the width rule comes from. The spaces a line may not be
    broken at — U+00A0, U+2007 and U+202F — answer false.
21. **Text that is not valid UTF-8 is walked one byte at a time.** A
    lead byte whose continuation bytes are not there measures as one
    codepoint rather than swallowing what follows it, so a scan over
    arbitrary bytes terminates and reports something.

## What is not included

- **The Unicode width table itself.** It is unicode-nv's, and this
  package holds a rule rather than a table so that a caller measuring
  in something other than terminal cells can pass its own.
- **UAX #14 line breaking.** The same table, and a larger algorithm.
  `break_offsets` covers the space and tab cases.
- **Grapheme cluster widths.** A flag is two regional indicators and a
  family emoji is up to seven codepoints joined by a zero-width joiner,
  and a terminal places each of those in the cells the first one asked
  for. `unicode_width` measures per codepoint and gets those wrong.
  unicode-nv's `uwidth.text_width` and `uwidth.cluster_width` are the
  ones that segment; there is no `WrapWidth` shape for them, because a
  cluster is not one codepoint.
- **Hyphenation.** Breaking `international` into `inter-` and
  `national` needs a language, a dictionary and a set of patterns. See
  rule 18.
- **Justification.** It is padding inserted between words rather than at
  the end of a line, and it needs a policy. `break_offsets` gives a
  justifier what it needs.
- **Any knowledge of escape sequences.** A wrap that skipped colour
  codes while measuring would have a parser in it. Spans of offsets are
  what let a caller wrap the plain text and re-apply the styling.
- **A microcontroller build.** The whole surface takes and returns
  `Str`, and string concatenation is refused at the embedded tier. This
  package does not build for a microcontroller with no heap allocator.
  `novo pkg publish` reports the tiers as `wasm, app`.

## What allocates

`wrap`, `fill`, `fill_aligned`, the truncations, `pad`, `indent` and
`dedent` build strings, and every line they answer is a heap cell.
`wrap_spans` builds one span per line. That is what they are for.

Measuring does not. `str_width`, `prefix_width`, `fit_prefix`,
`is_break_char` and the UTF-8 walk under them answer a number over a
string the caller already holds, and put nothing on the heap. A
`WrapWidth` is one cell, built once by the function that answers it.
`bash tests/alloc_scan.sh` reads the emitted LLVM and reports that as a
check that can fail.

## Related packages

- [unicode-nv](https://novo-lang.org/packages/unicode-nv) is the
  Unicode character database: the width table this package's
  `unicode_width` reads, and also grapheme cluster segmentation,
  normalisation and case mapping.
- [tui-nv](https://novo-lang.org/packages/tui-nv) is layout, widgets and
  a cell buffer for a terminal user interface. Its paragraph widget is
  this package's caller, and its layout asks `wrapped_height`.
- [ansi-nv](https://novo-lang.org/packages/ansi-nv) builds and parses
  the escape sequences that carry the styling this package's offsets let
  a caller keep. The two do not depend on each other.
- [table-nv](https://novo-lang.org/packages/table-nv) renders tables to
  a terminal. Sizing a column is `widths.str_width`, and fitting a cell
  is `truncate`.
- `std.fmt` in the standard library pads and aligns a string by
  character count. That is the right answer for ASCII and the wrong one
  for anything wider than one cell.
- `std.str` in the standard library has `str.len`, which counts bytes. A
  two-byte `é` is one column and a three-byte `世` is two, which is the
  whole difference between that and `widths.str_width`.

## Tests

```bash
novo test --isolate tests/wrapping_tests.nv   # 26 tests: wrap, fill, truncate, pad
novo test --isolate tests/widths_tests.nv     # 10 tests: the width rules
bash tests/coverage.sh                        # the measured coverage over src/
bash tests/alloc_scan.sh                      # measuring text puts nothing on the heap
```

The expected output comes from the two reference implementations: the
`textwrap` crate for the options, the long-word policies and `fill` over
`wrap`, and Python's `textwrap` module for `dedent`, `indent` and the
blank-line rules. The Unicode cases come from UAX #11.

The cases that matter are the ones a wrap usually gets wrong: that the
spans are offsets into the source and not into a copy, that an indent's
width counts against the column count, that a truncation counts its own
ellipsis, that padding never cuts, that a word wider than the line
behaves as the break policy says, and that `dedent` ignores blank lines
when it computes the common prefix.

No test reads a file or a clock. Every line and every function under
`src/` is executed by the suites; `bash tests/coverage.sh` prints the
numbers.

## Licence

Apache-2.0. See `LICENSE`.

<!-- docs/writing-a-readme.md is the style guide for this page. -->
