# Changelog

All notable changes to textwrap-nv are recorded here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the pre-1.0 rule that a breaking change bumps the MINOR number.

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
