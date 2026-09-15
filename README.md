# textwrap-nv

Wrapping, filling and truncating text to fit a **display width**: the
number of columns the text occupies on a terminal, rather than the
number of characters in it. The shape of the interface follows
[the `textwrap` crate](https://docs.rs/textwrap/), and `indent` and
`dedent` follow
[Python's `textwrap` module](https://docs.python.org/3/library/textwrap.html).
[tui-nv](https://novo-lang.org/packages/tui-nv) is built on it and uses
it for the paragraph widget.

**Status: NOT IMPLEMENTED — interface only.** Every function is declared
with its full signature, but every body is a `todo()` that panics when
called. The package is published so its design can be reviewed and
depended on before it is implemented. Version 0.1.0 will be the first
working release.

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

One thing this package cannot compute is the display width itself. That
is a Unicode table: the East Asian Width property of
[UAX #11](https://www.unicode.org/reports/tr11/) for the wide forms, the
general categories Mn, Me and Cf for the zero-width ones, and the emoji
presentation rules for the sequences that join. The table belongs in a
Unicode package, and there is not one on the registry yet. So the rule
arrives as an argument: a `WrapWidth` is a function from a codepoint to
a column count, and three of them can be written without a table.

| Rule | Answers |
| --- | --- |
| `monospace_width()` | 1 for every codepoint |
| `ascii_width()` | 1 for a printable ASCII codepoint, 0 for everything else |
| `fixed_width(n)` | `n` for every codepoint |

`monospace_width` is correct for text that is entirely ASCII, which is
most of what a command-line program wraps. Where it is wrong, the
wrapped line comes out too long rather than too short, so the error is
visible on the screen.

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
    let rule = widths.monospace_width()

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

Build and test with `novo pkg build` and `novo test`. Today `novo test`
fails on purpose: every test reaches a
`not implemented: textwrap-nv.<module>.<fn>` panic. The tests are the
specification the implementation will have to satisfy.

## What the package contains

| Module | Contents |
| --- | --- |
| `widths` | The display-width rule as a value, the three rules that need no Unicode table, and the measurements taken with one: a codepoint, a whole string, a prefix, and how many bytes fit in a given number of columns. |
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
   ideographs, emoji and combining marks. A caller that has a correct
   width function passes it.
2. **`WrapSpan.start` and `.end` are byte offsets into the source.**
   `end` is one past the last byte, with trimmed trailing whitespace
   already excluded.
3. **`WrapSpan.width` does not count the indent.** The indent's width
   does count against the column count during the wrap.
4. **A newline already in the text always ends a line.** `wrap_spans`
   adds breaks. It never removes one.
5. **A `columns` of zero or less answers one span covering
   everything.** A wrap to no width has no answer, and an empty list
   would lose the text silently.
6. **The break policy decides what happens to a word wider than the
   line.** `WrapAtWords` puts it on a line of its own and lets it
   overflow. `WrapBreakLongWords` cuts it at the column. `WrapNoBreak`
   does not break at all and gives one output line per input line.
7. **`initial_indent` and `subsequent_indent` are different fields
   because a bulleted list needs both.** `indented_options("- ", "  ")`
   is that shape.
8. **`truncate` counts its own ellipsis.** The result is never wider
   than `columns`. Text that already fits is returned unchanged, with no
   ellipsis appended.
9. **`truncate_middle` keeps both ends.** For a path or an identifier,
   the start says what kind of thing it is and the end says which one.
10. **`pad` never truncates.** Text wider than the field is returned
    unchanged. A caller that wants both calls `truncate` first.
11. **`widths.fit_prefix` answers a byte count, not a codepoint
    count.** A codepoint that would straddle the edge is left out
    entirely, so a wide character with one column left does not half
    fit.
12. **`indent` leaves empty lines alone**, so the result diffs cleanly
    and no blank line gains trailing whitespace. `dedent` ignores empty
    lines when it looks for the common prefix, for the same reason.
13. **`split_on_hyphens` is not hyphenation.** It breaks after a hyphen
    that is already in the text. Nothing is inserted and no dictionary
    is consulted.
14. **`is_break_char` knows about spaces and tabs.** It is not the line
    breaking algorithm of
    [UAX #14](https://www.unicode.org/reports/tr14/), which needs the
    same table the width rule stands in for.
15. **`trim_trailing` is on by default and `collapse_whitespace` is
    off.** Trailing spaces on a terminal line are invisible until
    something inverts them. Collapsing runs of whitespace changes the
    text rather than only breaking it, which a caller wrapping code or a
    table does not want.

## What is not included

- **The Unicode width table.** See "What it is". A package for it will
  bring the rule that becomes the default, and no signature here will
  change, because a rule passed in is a rule passed in.
- **UAX #14 line breaking.** The same table, and a larger algorithm.
  `break_offsets` covers the space and tab cases.
- **Hyphenation.** Breaking `international` into `inter-` and `national`
  needs a language, a dictionary and a set of patterns. See rule 13.
- **Justification.** It is padding inserted between words rather than at
  the end of a line, and it needs a policy. `break_offsets` gives a
  justifier what it needs.
- **Any knowledge of escape sequences.** A wrap that skipped colour
  codes while measuring would have a parser in it. Spans of offsets are
  what let a caller wrap the plain text and re-apply the styling.
- **A microcontroller build.** The whole surface takes and returns
  `Str`, and string concatenation is refused at the embedded tier. This
  package makes no device claim.

## Related packages

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
novo test --isolate tests/wrapping_tests.nv   # 19 tests: wrap, fill, truncate, pad
novo test --isolate tests/widths_tests.nv     #  7 tests: the width rule
```

The expected output comes from the two reference implementations: the
`textwrap` crate for the options, the long-word policies and `fill` over
`wrap`, and Python's `textwrap` module for `dedent`, `indent` and the
blank-line rules.

The cases that matter are the ones a wrap usually gets wrong: that the
spans are offsets into the source and not into a copy, that an indent's
width counts against the column count, that a truncation counts its own
ellipsis, that padding never cuts, that a word wider than the line
behaves as the break policy says, and that `dedent` ignores blank lines
when it computes the common prefix.

No test reads a file or a clock. The tests compile today and fail at
run, each on the `not implemented: textwrap-nv.<module>.<fn>` panic that
is its body. That is the expected state of an interface release. They
turn green one at a time as bodies land.

## Implementation status

| Item | Implemented |
| --- | --- |
| `widths.monospace_width`, `.ascii_width`, `.fixed_width` | no |
| `widths.char_width`, `.str_width`, `.prefix_width`, `.fit_prefix` | no |
| `wrapping.default_options`, `.indented_options` | no |
| `wrapping.wrap_spans`, `.wrap`, `.fill`, `.fill_aligned`, `.wrapped_height` | no |
| `wrapping.truncate`, `.truncate_middle`, `.pad` | no |
| `wrapping.indent`, `.dedent` | no |
| `wrapping.break_offsets`, `.is_break_char` | no |

## Licence

Apache-2.0. See `LICENSE`.

<!-- docs/writing-a-readme.md is the style guide for this page. -->
