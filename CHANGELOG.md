# Changelog

All notable changes to textwrap-nv are recorded here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the pre-1.0 rule that a breaking change bumps the MINOR number.

## 0.1.1 — 2026-09-24

The package builds under the list rule of the next toolchain, where a
list is one list under every name that holds it and a write into it
goes through a `var` name.  No public signature changed, and nothing
changes under 0.9.2.

### Changed

- The private step that wraps a line with no break policy takes the
  spans gathered so far as a `mut` parameter, which is the spelling
  `novo fmt` gives the `var` marker, and pushes the new span onto that
  list.
- The greedy wrap pushes its last span in a statement of its own and
  then answers the list.
- Under the next toolchain the package also needs unicode-nv 0.1.1,
  which `^0.1.0` admits.

## 0.1.0 — 2026-09-18

The wrap, the fill, the truncations and the two indent functions, over a
display width the caller names.

- `wrap_spans` is the primitive and everything else is written over it.
  It answers a byte range and a measured width per line, so text
  described by offsets into the source — a word in bold, a match
  highlighted — survives the wrap. `wrap` is that plus a slice, `fill`
  is `wrap` joined, and `wrapped_height` is the count a layout asks for
  before it decides how tall to make a box.
- The wrap is greedy: as many words on a line as fit, and a break
  before the first one that does not. That is what Python's `textwrap`
  module and the `textwrap` crate both do by default, and both were the
  oracle for the expected output.
- The whitespace a line was broken at belongs to the line before it,
  and `trim_trailing` drops it. The whitespace an input line starts
  with is that line's own indentation and is kept, so wrapped code and
  wrapped tables keep their shape.
- `collapse_whitespace` is acted on by `wrap`, `fill`, `fill_aligned`
  and `wrapped_height`, and not by `wrap_spans`. A span is a range of
  the text it was given and no range can stand for a run of three
  spaces rewritten as one, so the functions that build strings collapse
  the text and wrap the result. The README says so where a reader will
  look for it.
- The three break policies behave as their names say. A word wider than
  the line overflows under `WrapAtWords`, is cut at the column under
  `WrapBreakLongWords`, and is left whole under `WrapNoBreak`. A cut
  that would fit nothing still takes one codepoint, because a cut that
  fitted nothing would go round again.
- `truncate` counts its own ellipsis and `truncate_middle` keeps both
  ends, with the odd column going to the end. An ellipsis at least as
  wide as the field leaves no room for text, and the answer is then the
  text cut to the field with no ellipsis.
- `indent` and `dedent` follow Python's `textwrap`: a line with no
  character other than whitespace is left alone by the first and
  answered empty by the second, and does not count towards the common
  prefix.
- `is_break_char` is the ASCII whitespace and the Unicode space
  separators, less the three a line may not be broken at — U+00A0,
  U+2007 and U+202F — and plus U+200B, which occupies no cell and
  exists to mark a break.
- Text is walked by codepoint. A UTF-8 lead byte whose continuation
  bytes are not there measures as one codepoint rather than swallowing
  what follows it, which is the rule `str.chars` follows and what keeps
  a walk over arbitrary bytes finite.

### Added

- `widths.unicode_width()`, the display width of UAX #11, from
  unicode-nv's table. It is one line over `uwidth.char_width`, which is
  the `fn(Int) -> Int` a `WrapWidth` holds, and no signature published
  at 0.0.2 is shaped by it.
- `unicode-nv = "^0.1.0"` in `[dependencies]`, which 0.0.1 recorded as
  the entry to add when that package landed. It costs no effect row and
  no tier: the package reports `wasm, app` with it and without it.

### Changed

- Every field of `WrapOptions` is declared `var`. The shape a caller
  writes is `default_options()` with one field set, and a field
  assigned to must be declared that way from novo 0.9.1 onwards
  (`E2034`).
- `novo = ">= 0.9.1"`, which is the oldest toolchain these bytes were
  built and tested on, and the oldest that carries the rule above.
- Two cases in `tests/wrapping_tests.nv` expected three lines from
  `"the quick brown fox"` at nine columns. Both reference
  implementations answer two — `"the quick"` and `"brown fox"` are nine
  columns each — and the cases now assert that, with the second line's
  text as well.

### Known

- **Widths are per codepoint, not per grapheme cluster.** A flag is two
  regional indicators and a family emoji is several pictographs joined
  by a zero-width joiner, and a terminal places each of those in the
  cells the first one asked for. unicode-nv's `uwidth.text_width`
  segments and gets them right; a `WrapWidth` takes one codepoint and
  cannot.
- **`novo build <file>` does not resolve the package's dependency**, so
  the allocation scan reads `_novo/textwrap-nv.ll`, which `novo test`
  writes from a build that does. A qualified reference to a dependency
  module's function under that build is an internal compiler error, and
  is filed against the toolchain.

## 0.0.2 — 2026-09-15

README rewritten to the package README style guide
(docs/writing-a-readme.md); no change to the interface.

## 0.0.1 — 2026-09-10

The **interface**: every signature and every effect row, and no bodies.
`stability = "draft"`, and the release is recorded `implemented = false`.

### Added

- `wrapping` — `wrap_spans` as the primitive, returning byte ranges of
  the source so that styled text survives the wrap, and `wrap`, `fill`
  and `fill_aligned` over it. The break policy is a named choice
  because a paragraph of prose, a column of paths and a log viewer are
  three different programs. `truncate` counts its own ellipsis;
  `truncate_middle` keeps the end, which is the half that says which
  file. `pad` never truncates, because padding and truncating are
  different requests.
- `widths` — the display width of a codepoint, as a rule the caller
  supplies. `monospace_width()`, `ascii_width()` and `fixed_width(n)`
  are the three that can be written without a Unicode table.
  `fit_prefix` answers in bytes, which is what a caller slicing the
  string needs.

### Known

- **The unicode-nv dependency is wanted and not declared.** The display
  width of a codepoint is a Unicode table and belongs there; unicode-nv
  is a plan row nobody has written, and a dependency on a package that
  is not on the registry is refused at publish. `WrapWidth` is the
  parameter that stands in for it. When unicode-nv lands, its width
  function becomes the default and no signature here changes.
- **Hyphenation is off**, and `split_on_hyphens` breaks only after a
  hyphen already in the text.
- **No `@tier(embedded)` claim.** The whole surface is `Str`, and `Str`
  concatenation is refused at that tier. A device does not wrap prose.

### Design notes

Public type and variant names are unique across a whole program, so a
package's names have to be unique across the registry too. `Line` is
declared by gof-patterns, and `Span`, `Options`, `Break`, `Align`,
`Left` and `Right` are names several packages would each want. Enum
variants collide by their bare name, which is why the variants carry the
`Wrap` prefix. The modules are `wrapping` and `widths` rather than
`wrap`, `width` or `text`, because a module may not be named after a
standard-library one and the singular forms would shadow the functions
inside them.

`WrapWidth` is a struct around one function rather than a bare function
type, so that the rule has a name a reader can look up, and so that a
future rule with more to it — a tab stop, an ambiguous-width setting for
a terminal configured East Asian — becomes a field rather than a second
parameter threaded through every function.
