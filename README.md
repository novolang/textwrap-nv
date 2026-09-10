# textwrap-nv

**Status: NOT IMPLEMENTED — interface only.**

Every public function below is published with its signature and its
effect row, and every body is `todo()`. Installing this package works;
calling it panics with `not implemented`.

## What this is

Wrapping, filling and truncating text at a **display width** rather
than a character count.

- `wrap_spans` — the primitive: lines as ranges of the source;
- `wrap` and `fill` — the same thing as strings, for callers whose text
  is not styled;
- `truncate`, `truncate_middle`, `pad` — the three things a table cell
  and a status bar need;
- `indent`, `dedent`, `break_offsets` — the small ones a program keeps
  rewriting;
- and `WrapWidth`, which is where the one thing this package cannot
  compute arrives from.

```
novo pkg add textwrap-nv
novo pkg build
novo test
```

## The one example that will work

```novo
use widths
use wrapping

fn main() [io]
    let text = "the quick brown fox jumps over the lazy dog"
    println(wrapping.fill(text, 20, widths.monospace_width(),
                          wrapping.default_options()))
    // the quick brown fox
    // jumps over the lazy
    // dog
```

And the same wrap, keeping the offsets — which is what a program that
had marked "quick" as bold needs:

```novo
use widths
use wrapping

fn main() [io]
    for s in wrapping.wrap_spans("the quick brown fox", 9,
                                 widths.monospace_width(),
                                 wrapping.default_options())
        // s.start and s.end are byte offsets into the ORIGINAL, so
        // the highlight at 4..9 is still at 4..9.
        println(str.from_int(s.start) + ".." + str.from_int(s.end))
```

## The load-bearing interface

```novo ignore
pub struct WrapSpan
    start: Int         // byte offsets into the SOURCE
    end: Int
    width: Int
    is_first: Bool

pub fn wrap_spans(text: Str, columns: Int, w: WrapWidth, opts: WrapOptions) -> [WrapSpan]
```

**The wrap returns offsets, not strings, and everything else is over
it.**

Text on a terminal is usually styled — a word in bold, a path in a
colour, a search match highlighted — and the styling is described by
offsets into the source. A wrap that returns `[Str]` has thrown those
away: the caller either re-derives them (which is the wrap again, done
worse) or gives up on styling wrapped text. Returning ranges costs
nothing and keeps both callers:

- `wrap` is `wrap_spans` plus a slice, and a caller with plain text
  never learns the difference;
- `width` rides along because the wrap has already measured it, and
  making the caller measure again is the expensive half done twice;
- `is_first` is a field rather than "index 0" because a caller
  wrapping paragraph by paragraph concatenates the lists;
- `wrapped_height` answers the layout's question — how tall is this at
  this width — without producing a list of strings that is thrown away.
  tui-nv's paragraph widget is the caller.

## The width question, and the dependency that is missing

```novo ignore
pub struct WrapWidth
    of_char: fn(Int) -> Int
```

**A monospace terminal gives one cell to most codepoints, two to a CJK
ideograph or a wide-presentation emoji, and none to a combining mark.**
So "how many characters fit in 80 columns" has no answer and "how many
columns does this text take" has one — and every function in this
package is written in terms of the second.

That answer is a Unicode table: UAX #11's East Asian Width for the wide
forms, the general categories Mn, Me and Cf for the zero-width ones,
and the emoji presentation rules for the sequences that join. It is not
arithmetic and nobody should transcribe it twice. **It belongs in
unicode-nv, which is a plan row nobody has written yet.**

Depending on a package that is not on the registry is refused at
publish and would send every consumer to a version that does not exist,
so the rule arrives as an argument instead:

- `monospace_width()` is the placeholder — 1 for everything. Correct
  for ASCII, which is most of what a command-line program wraps, and
  wrong in a way that shows: a wrapped line comes out too **long**
  rather than too short, so the failure is on the screen rather than
  hidden.
- `ascii_width()` and `fixed_width(n)` are the other two rules that can
  be written without a table.
- A caller that has a width function already passes it.

**When unicode-nv lands**, its width function becomes the default,
`[dependencies]` gains `unicode-nv = "^0.0.1"`, and **no signature
here changes** — a rule passed in is a rule passed in. That is a MINOR
bump with a changelog line, not a redesign, and it is the whole reason
the width is a value rather than something this package computes: a
package that had guessed would have to break its callers to stop
guessing.

`WrapWidth` is a struct around one function rather than a bare function
type so that the rule has a name a reader can look up, and so that a
future rule with more to it — a tab stop, an ambiguous-width setting
for a terminal configured East Asian — is a field rather than a second
parameter threaded through every function.

## Hyphenation is off, and that is a decision

Breaking `international` into `inter-` and `national` needs a language,
a dictionary and a set of patterns. Getting it wrong produces text that
is harder to read than a ragged margin, and getting it right is a
package of its own.

`WrapOptions.split_on_hyphens` breaks after a hyphen that is **already
in the text**, which is arithmetic. Nothing is inserted and no
dictionary is consulted. That is the whole of it, and the field name
says so.

Line breaking is the same story one level up: `is_break_char` knows
about spaces and tabs, not about UAX #14, whose algorithm needs the
same table `WrapWidth` is standing in for.

## The layer, and why

`core` — no effects. Text in, text out.

**No `@tier(embedded)` claim, and none is intended.** A device does not
wrap prose: the whole surface is `Str`, and `Str` concatenation is
refused at that tier. The audit's `core-embedded` row passes as "makes
no device claim", which is the honest reading rather than a dodge. The
two packages beside this one that a device genuinely wants — ansi-nv
and keymap-nv — make the claim and build it.

## Where the names come from, and the ones that were taken

Public type and variant names are unique across the whole assembly.

| here | the obvious name | why not |
| --- | --- | --- |
| `WrapSpan` | `Line`, `Span` | gof-patterns declares `Line`; `Span` is the noun four packages will want |
| `WrapWidth` | `Width`, `WidthFn` | too generic to survive a registry, and the second is not a name for a value |
| `WrapOptions`, `WrapBreak`, `WrapAlign` | `Options`, `Break`, `Align` | all three are certain to collide |
| `WrapAtWords`, `WrapAlignLeft`, … | `AtWords`, `Left`, … | enum **variants** collide by bare name across the assembly, and `Left`/`Right` are exactly the kind that bites |
| module `wrapping`, `widths` | `wrap`, `width`, `text` | `text` is a standard-library module; the other two would shadow the functions inside them |

## The reference implementation

**textwrap** (the Rust crate) for the shape: the options struct, the
two indents, `fill` over `wrap`, the long-word policies, and the
insistence that width is a display width. **Python's `textwrap`** for
`dedent`, `indent` and the blank-line rules — its treatment of empty
lines is the one that diffs cleanly, and it is copied deliberately.
**`unicode-width`** for what `WrapWidth` will eventually be, and for
the observation that the ambiguous-width characters need a setting
rather than an answer.

Deliberately left out, and where it went instead:

- **The Unicode width table itself.** unicode-nv, when it exists.
- **UAX #14 line breaking.** The same table, and a larger algorithm;
  `break_offsets` covers the ASCII cases and says so.
- **Hyphenation.** Above.
- **Justification.** It is padding between words rather than at the
  end, it needs a policy nobody agrees on, and `break_offsets` gives a
  justifier what it needs to write its own.
- **Anything that knows about escape sequences.** A wrap that skipped
  ANSI sequences when measuring would be a wrap with a parser in it;
  `wrap_spans` returning offsets is what lets a caller wrap the plain
  text and re-apply the styling itself.

## Status

Every function is `todo()`. Two suites, both red, both for the same
reason — every assertion reaches `not implemented: textwrap-nv.<fn>`,
which is the expected result until the bodies land.

```
novo test --isolate tests/wrapping_tests.nv   # the wrap, the fill, the truncation
novo test --isolate tests/widths_tests.nv     # the width rule, and what it cannot yet say
```

`novo doc` renders and its three examples compile.
