# string research: Elixir

Elixir's distinct text model: a **binary** (an arbitrary byte sequence) and a
**string** are the *same runtime value*; `String` is not a type but a module that
adds Unicode meaning on top of the binary. The byte-vs-text split is therefore
not in the type system, it is in the **function name you choose**.

## 1. Standard library support

- `String` module (Elixir): full Unicode-aware text API. `String.t() :: binary()`
  is documented as "A UTF-8 encoded binary"; `String.t()` and `binary()` are
  "equivalent to analysis tools" — `String.t()` only *implies* UTF-8
  ([hexdocs.pm/elixir/String.html](https://hexdocs.pm/elixir/String.html), type `t/0`).
- Byte-level primitives live in `Kernel` (`byte_size/1`, `bit_size/1`,
  `binary_part/3`, `binary_slice/2,3`, `is_binary/1`, `is_bitstring/1`,
  `<>/2`) ([hexdocs.pm/elixir/Kernel.html](https://hexdocs.pm/elixir/Kernel.html)).
- Erlang's `:binary` module (byte-oriented, callable from Elixir) adds
  `at/2`, `part/3`, `bin_to_list/2`, `copy/1`, `first/1`, `last/1`,
  `match/3`, `matches/3`, `split/3`, `replace/4`, `compile_pattern/1`,
  `encode_hex/2`, `decode_hex/1`, `longest_common_prefix/1`
  ([erlang.org/doc/apps/stdlib/binary.html](https://www.erlang.org/doc/apps/stdlib/binary.html)).
- Erlang's `:unicode` module converts between encodings (`latin1`, `utf8`,
  `utf16`, `utf32`) and performs NFC/NFD/NFKC/NFKD normalization
  ([erlang.org/doc/apps/stdlib/unicode.html](https://www.erlang.org/doc/apps/stdlib/unicode.html)).
- `IO` module owns the byte-vs-text bridge data types: `iodata`/`iolist`,
  `chardata`, `IO.iodata_to_binary/1`, `IO.chardata_to_string/1`,
  `IO.iodata_length/1`, `IO.iodata_empty?/1`
  ([hexdocs.pm/elixir/IO.html](https://hexdocs.pm/elixir/IO.html)).
- `String.Chars` protocol (`to_string/1`) converts arbitrary terms to a binary
  and powers string interpolation ([hexdocs.pm/elixir/String.Chars.html](https://hexdocs.pm/elixir/String.Chars.html)).

(Assessment: derived from the module docs above — Elixir ships text and byte
APIs in *different modules*, and the type name carries no guarantee.)

## 2. Relevant community libraries

- **`unicode`** (`elixir-unicode/unicode`) — codepoint/string introspection:
  script, block, category, general properties, `alphabetic?`, `digits?`,
  `emoji?`, `unaccent/1`. It states: "The Elixir standard library does not
  provide introspection beyond that required to support casing"
  ([unicode.hexdocs.pm/1.16.2/readme.html](https://unicode.hexdocs.pm/1.16.2/readme.html)).
- **`unicode_string`** — UAX #29 / UAX #14 segmentation (grapheme, word,
  sentence, line), locale tailoring from CLDR, dictionary-based segmentation
  for Thai/Lao/Khmer/Burmese/Chinese/Japanese, locale-aware casing. Its own
  framing: "Elixir's own `String` module covers the common cases well. This
  library exists for the cases it doesn't"
  ([hex.pm/packages/unicode_string/2.4.1/files/guides/introduction.md](https://hex.pm/packages/unicode_string/2.4.1/files/guides/introduction.md)).
- **`unicode_transform`** — CLDR Transform rules (UTS #35 §10): transliteration
  between scripts, normalization and case mappings at runtime
  ([hex.pm/packages/unicode_transform](https://hex.pm/packages/unicode_transform)).
- **`codepagex`** — encoding conversion to/from UTF-8, "like iconv but pure
  Elixir" ([github.com/tallakt/codepagex](https://github.com/tallakt/codepagex)).
- **`unicode_set`**, **`unicode_guards`** — unicode-set parsing/matching and
  guard helpers built on `unicode` (listed in the `unicode` README, link above).

(Assessment: derived from the sources above — the ecosystem's split matches
Elixir's own split: byte/encoding conversion, codepoint introspection, and
segmentation/locale are *three separate third-party concerns*.)

## 3. Exposed APIs

Text layer (`String`), selection ([hexdocs.pm/elixir/String.html](https://hexdocs.pm/elixir/String.html)):

- measurement: `length/1` (graphemes), `byte_slice/3`; byte count via
  `Kernel.byte_size/1`.
- positions: `at/2`, `first/1`, `last/1`, `slice/2`, `slice/3`,
  `split_at/2`, `next_codepoint/1`, `next_grapheme/1`, `next_grapheme_size/1`.
- decomposition: `codepoints/1`, `graphemes/1`, `to_charlist/1`,
  `split/1`, `split/3`, `splitter/3`, `chunk/2`.
- search/compare: `contains?/2`, `starts_with?/2`, `ends_with?/2`,
  `match?/2`, `equivalent?/2`, `jaro_distance/2`, `bag_distance/2`,
  `myers_difference/2`, `count/2`.
- transform: `replace/4`, `replace_prefix/3`, `replace_suffix/3`,
  `replace_leading/3`, `replace_trailing/3`, `replace_invalid/2`,
  `trim/1`, `trim/2`, `trim_leading/1,2`, `trim_trailing/1,2`,
  `pad_leading/3`, `pad_trailing/3`, `duplicate/2`, `reverse/1`,
  `capitalize/2`, `downcase/2`, `upcase/2`, `normalize/2`.
- validate/convert: `valid?/2`, `printable?/2`, `to_integer/1,2`,
  `to_float/1`, `to_atom/1`, `to_existing_atom/1`.

Byte layer (`Kernel`/`:binary`):
`byte_size/1`, `bit_size/1`, `binary_part/3`, `binary_slice/2,3`,
`<>/2`, `is_binary/1`, `is_bitstring/1`; `:binary.at/2`, `:binary.part/3`,
`:binary.bin_to_list/2`, `:binary.copy/1,2`, `:binary.first/1`,
`:binary.last/1`, `:binary.match/3`, `:binary.matches/3`, `:binary.split/3`,
`:binary.replace/4`, `:binary.longest_common_prefix/1`,
`:binary.longest_common_suffix/1`
([hexdocs.pm/elixir/Kernel.html](https://hexdocs.pm/elixir/Kernel.html),
[erlang.org/doc/apps/stdlib/binary.html](https://www.erlang.org/doc/apps/stdlib/binary.html)).

Structural operators: `<>/2` binary concat, `==`/`===`/`<`/`>` term
comparison, `=~/2` regex/string match
([hexdocs.pm/elixir/Kernel.html](https://hexdocs.pm/elixir/Kernel.html)).

## 4. Error representation

Three mechanisms, deliberately different:

- **Raise** (`ArgumentError`, `UnicodeConversionError`, Erlang `badarg`) — when
  the caller violated a documented precondition. Examples: `Kernel.binary_part/3`
  raises `ArgumentError` if start/size fall outside; `String.replace_leading/3`
  and `replace_trailing/3` raise `ArgumentError` when `match` is `""`;
  `IO.chardata_to_string/1` raises `UnicodeConversionError` on failure;
  `:binary.at/2` raises `badarg` when `Pos >= byte_size`
  ([Kernel.html#binary_part/3](https://hexdocs.pm/elixir/Kernel.html),
  [String.html#replace_leading/3](https://hexdocs.pm/elixir/String.html),
  [binary.html#at/2](https://www.erlang.org/doc/apps/stdlib/binary.html)).
- **Return a sentinel** — `nil` or `""` for "nothing there". `String.at/2`,
  `String.first/1`, `String.last/1`, `next_codepoint/1`, `next_grapheme/1`
  return `nil` at the end; `String.slice/2,3` returns `""` when the start is out
  of range ([String.html](https://hexdocs.pm/elixir/String.html)).
- **Return a tagged tuple** — `:unicode.characters_to_binary/3` returns
  `{error, Converted, Rest}` or `{incomplete, Converted, Rest}` instead of
  raising, separating "invalid byte" from "truncated multi-byte character at
  end of chunk" ([unicode.html#characters_to_binary/3](https://www.erlang.org/doc/apps/stdlib/unicode.html)).

Boolean predicates never raise on "no match": `contains?`, `starts_with?`,
`ends_with?`, `match?`, `valid?` return `false`.

(Assessment: derived from the four sources above — Elixir has no single error
convention; it picks raise vs `nil` vs tagged tuple per family.)

## 5. Ownership semantics

- **Everything is immutable.** There is no user-visible mutation of a string or
  binary. `"a" <> "b"` constructs a new binary; binary concatenation "will copy
  the concatenated binaries into a new binary"
  ([hexdocs.pm/elixir/IO.html](https://hexdocs.pm/elixir/IO.html)).
- `String` and `binary` are the **same value**; ownership is not a type-level
  distinction. `String.t() :: binary()`
  ([String.html, type t/0](https://hexdocs.pm/elixir/String.html)).
- **Borrowing exists only implicitly at runtime.** Taking a binary apart
  (`binary_part`, `binary_slice`, the `<<head, rest::binary>>` match) returns a
  **sub-binary** that references the original, giving O(1) decomposition and
  data sharing; `:binary.referenced_byte_size/1` exposes the size of the
  referenced binary and `:binary.copy/1` is the explicit escape hatch to
  detach it ([binary.html#referenced_byte_size/1](https://www.erlang.org/doc/apps/stdlib/binary.html)).
- **No explicit lifetime.** The BEAM garbage collector keeps the larger binary
  alive while any sub-binary references it; the docs warn explicit copying "can
  lead to the creation of significantly more binary data than needed"
  ([binary.html#copy/1](https://www.erlang.org/doc/apps/stdlib/binary.html)).

(Assessment: derived from the two sources — Elixir gives Mojo the *opposite*
starting point: no borrow checker, sharing hidden in the runtime.)

## 6. Blocking / non-blocking

- String/binaries are **pure in-memory values**. `String` and `:binary`
  functions are synchronous, CPU-bound transformations with no I/O, no timeout
  argument and no async variant
  ([String.html](https://hexdocs.pm/elixir/String.html),
  [binary.html](https://www.erlang.org/doc/apps/stdlib/binary.html)).
- Unicode correctness costs time: "many functions in this module run in linear
  time, as they need to traverse the whole string", e.g. `String.length/1`,
  while `byte_size/1` "always runs in constant time"
  ([String.html, "String and binary operations"](https://hexdocs.pm/elixir/String.html)).
- Laziness exists where a full result is not needed: `String.splitter/3`
  "returns an enumerable that splits a string on demand. This is in contrast to
  `split/3` which splits the entire string upfront"; `IO.stream/2` and
  `IO.binstream/2` are lazy wrappers over a device
  ([String.html#splitter/3](https://hexdocs.pm/elixir/String.html),
  [IO.html#stream/2](https://hexdocs.pm/elixir/IO.html)).
- Laziness is *pull-based*, not concurrent: `splitter` and `IO.stream` are
  `Enumerable`s consumed by `Enum`/`Stream`, not background tasks
  ([String.html#splitter/3](https://hexdocs.pm/elixir/String.html)).

(Assessment: derived from the sources above — the blocking question for a text
library reduces to "linear scan vs constant-time access", not to I/O waiting.
Whether a long scan can starve a BEAM process is a scheduler property outside
these docs: `GUESS:` — no source fetched for reduction-based preemption here.)

## 7. Text model (encoding, length, indexing)

**Encoding: UTF-8, variable width, 1–4 bytes per codepoint.** "Elixir uses UTF-8
to encode its strings"; the `String` module acts per "The Unicode Standard,
Version 17.0.0" ([String.html](https://hexdocs.pm/elixir/String.html)).
`String` functions are locale-free by design: "the functions in this module rely
on the Unicode Standard, but do not contain any of the locale specific behavior"
([String.html](https://hexdocs.pm/elixir/String.html)).

**Three nested notions of "character", all explicit:**

| notion | what it is | API | source |
| --- | --- | --- | --- |
| byte | raw 8-bit unit | `byte_size/1`, `binary_slice/3` | [Kernel.html](https://hexdocs.pm/elixir/Kernel.html) |
| codepoint | one Unicode scalar | `String.codepoints/1`, `String.to_charlist/1`, `?a` | [String.html](https://hexdocs.pm/elixir/String.html) |
| grapheme | user-perceived character, per UAX #29 | `String.graphemes/1`, `String.length/1` | [String.html](https://hexdocs.pm/elixir/String.html) |

`String.length/1` returns **graphemes**, not codepoints and not bytes
([String.html#length/1](https://hexdocs.pm/elixir/String.html)). The documented
disagreement: `"héllo"` → `String.length/1` = 5, `byte_size/1` = 6; and
`"\u0065\u0301"` ("e" + combining acute) → `byte_size` 3, `String.length` 1,
`String.codepoints` `["e","́"]`, `String.graphemes` `["é"]`
([String.html](https://hexdocs.pm/elixir/String.html)).

**Indexing defines a position differently per function:**

- `String.at/2` — index counts **graphemes**, negative indexes count from the
  end, out of range returns `nil`; explicitly linear ("has to linearly traverse
  the string") ([String.html#at/2](https://hexdocs.pm/elixir/String.html)).
- `String.slice/2,3` — offsets in **graphemes**; out-of-range start → `""`;
  a range with start > stop must be marked increasing (`2..-1//1`)
  ([String.html#slice/3](https://hexdocs.pm/elixir/String.html)).
- `String.byte_slice/3` — offsets in **bytes**, then truncated codepoints at
  both ends are removed ([String.html#byte_slice/3](https://hexdocs.pm/elixir/String.html)).
- `binary_slice/2,3` / `binary_part/3` — offsets in **bytes**, codepoint-unaware
  ([Kernel.html](https://hexdocs.pm/elixir/Kernel.html)).
- `:binary.at/2` — single **byte** at a zero-based byte position
  ([binary.html#at/2](https://www.erlang.org/doc/apps/stdlib/binary.html)).

**Pattern matching on bytes:** `<<0, 1, x::binary>>` matches bytes by default;
without a modifier "each entry in the binary pattern is expected to match a
single byte". `<<x, rest::binary>> = "über"` binds `x` to the *first byte* of
`ü` (`x == ?ü` is `false`); the `utf8` modifier is required to match a codepoint:
`<<x::utf8, rest::binary>> = "über"` → `x == ?ü` is `true`
([hexdocs.pm/elixir/binaries-strings-and-charlists.html](https://hexdocs.pm/elixir/binaries-strings-and-charlists.html)).

**Bitstring vs binary:** "A **bitstring** is a contiguous sequence of bits in
memory"; "A **binary** is a bitstring where the number of bits is divisible by
8" — every binary is a bitstring, not vice versa
([binaries-strings-and-charlists.html](https://hexdocs.pm/elixir/binaries-strings-and-charlists.html)).

**Comparison is byte-wise, not linguistic.** "`<` compares the underlying bytes
that form the string", so `"álien" > "office"`; bitstrings are compared "byte by
byte, incomplete bytes … bit by bit". Canonical equivalence is a separate,
explicit call: `String.equivalent?/2` performs NFD on both sides before
comparing ([Kernel.html, "Structural comparison"](https://hexdocs.pm/elixir/Kernel.html),
[String.html#equivalent?/2](https://hexdocs.pm/elixir/String.html)).

**Legacy alternative representations:** a `charlist` is "a list of integers
where all the integers are valid code points" (`~c"hello"`), used mainly for
older Erlang interop; `to_string/1` and `to_charlist/1` convert
([binaries-strings-and-charlists.html](https://hexdocs.pm/elixir/binaries-strings-and-charlists.html),
[String.html#to_charlist/1](https://hexdocs.pm/elixir/String.html)).

## 8. Bounds, invalid input and errors

**Out-of-range index — contract depends on the function:**

- `String.at/2`: out of range → `nil` (`String.at("elixir", 10)` → `nil`,
  `String.at("elixir", -10)` → `nil`)
  ([String.html#at/2](https://hexdocs.pm/elixir/String.html)).
- `String.slice/3`: "If the offset is greater than string length, then it
  returns `""`"; negative start is normalized and clamped to 0; empty start
  beyond end → `""` ([String.html#slice/3](https://hexdocs.pm/elixir/String.html)).
- `binary_slice/3`: clips — "if `start + size` is greater than the binary size,
  it automatically clips it to the binary size instead of raising"
  ([Kernel.html#binary_slice/3](https://hexdocs.pm/elixir/Kernel.html)).
- `binary_part/3`: **raises** `ArgumentError` when start/size fall outside;
  allowed in guards ([Kernel.html#binary_part/3](https://hexdocs.pm/elixir/Kernel.html)).
- `:binary.at/2`: raises `badarg` if `Pos >= byte_size(Subject)`;
  `:binary.first/1` / `:binary.last/1` raise `badarg` on a zero-sized binary
  ("a zero-sized binary is not allowed")
  ([binary.html#at/2](https://www.erlang.org/doc/apps/stdlib/binary.html)).
- `String.split_at/2`: never fails — "The offset is capped to the length of the
  string" ([String.html#split_at/2](https://hexdocs.pm/elixir/String.html)).

**Slicing on a non-boundary.** `binary_slice("héllo", 0, 2)` returns
`<<104, 195>>`, "unsafe … an invalid string" because it cut `é` in half;
`String.slice("héllo", 0, 2)` returns `"hé"` (3 bytes) because it slices
graphemes; `String.byte_slice("héllo", 0, 2)` returns `"h"` — a slice capped at
2 bytes with truncated codepoints removed
([String.html#byte_slice/3](https://hexdocs.pm/elixir/String.html)). The
hybrid's guarantee is explicitly limited: "it only guarantees to remove
truncated codepoints immediately at the beginning or the end of the slice"
([String.html#byte_slice/3](https://hexdocs.pm/elixir/String.html)).

**Invalid encoding on input — tolerated, not rejected.** "This module relies on
this [self-synchronizing] behavior to ignore such invalid characters. For
example, `length/1` will return a correct result even if an invalid code point
is fed into it." Validity is expected to be checked at the system boundary:
"this module expects invalid data to be detected elsewhere, usually when
retrieving data from the external source"
([String.html, "Self-synchronization"](https://hexdocs.pm/elixir/String.html)).

Consequences that are explicitly defined:

- `next_codepoint/1` on an invalid leading byte returns that single byte as a
  binary: `String.next_codepoint("\x80\x80OK")` → `{<<128>>, <<128, 79, 75>>}`
  ([String.html#next_codepoint/1](https://hexdocs.pm/elixir/String.html)).
- `String.valid?/2` detects invalid binaries, e.g. `<<0xFFFF::16>>` → `false`;
  it "raises" if the argument is not a string
  ([String.html#valid?/2](https://hexdocs.pm/elixir/String.html)).
- `String.replace_invalid/2` replaces invalid bytes, default `"�"`
  ([String.html#replace_invalid/2](https://hexdocs.pm/elixir/String.html)).
- `String.chunk(string, :valid | :printable)` splits a string into
  valid/invalid or printable/non-printable chunks
  ([String.html#chunk/2](https://hexdocs.pm/elixir/String.html)).
- `String.normalize/2` **skips** invalid codepoints and continues
  ([String.html#normalize/2](https://hexdocs.pm/elixir/String.html)).

**Encoding conversion distinguishes invalid from truncated.**
`:unicode.characters_to_binary/3` returns `{error, Encoded, Rest}` for genuine
invalid data but `{incomplete, Encoded, Rest}` when the chunk ends inside a
multi-byte character — the case you must retry after reading more bytes
([unicode.html#characters_to_binary/3](https://www.erlang.org/doc/apps/stdlib/unicode.html)).

**Empty / zero-length edges, all documented:**

- empty haystack: `String.contains?("elixir of life", "")` → `true`; an empty
  list never matches, and `String.contains?("", [])` → `false`
  ([String.html#contains?/2](https://hexdocs.pm/elixir/String.html)).
- empty prefix/suffix always matches: `String.starts_with?("elixir", "")` →
  `true`, `String.ends_with?("language", "")` → `true`
  ([String.html#starts_with?/2](https://hexdocs.pm/elixir/String.html)).
- empty pattern in `split/3`: `String.split("abc", "")` → `["", "a", "b", "c", ""]`
  ([String.html#split/3](https://hexdocs.pm/elixir/String.html)).
- empty pattern in `replace/4` intersperses: `String.replace("ELIXIR", "", ".")`
  → `".E.L.I.X.I.R."`; empty *replacement* returns the subject unchanged
  ([String.html#replace/4](https://hexdocs.pm/elixir/String.html)).
- `replace_leading/3`, `replace_trailing/3` with `match == ""` **raise**
  `ArgumentError`, because "it's impossible to replace 'multiple' occurrences of
  `""`" ([String.html#replace_leading/3](https://hexdocs.pm/elixir/String.html)).
- `String.split/1` groups whitespace, ignores leading/trailing, removes empty
  strings, and does **not** split on non-breaking whitespace:
  `String.split("no\u00a0break")` → `["no\u00a0break"]`
  ([String.html#split/1](https://hexdocs.pm/elixir/String.html)).

(Assessment: derived from the sources above — Elixir's rule is not "safe by
default" but "each function documents its own edge contract", and the grapheme
vs byte vs codepoint choice determines whether a boundary is legal.)

## 9. Owned type, borrowed view and builder layer

**Owned type: `String`, which *is* `binary()`.** `String.t() :: binary()`;
there is no wrapper struct, no capacity field, no mutability. "Strings in Elixir
are UTF-8 encoded binaries"
([String.html](https://hexdocs.pm/elixir/String.html)). At runtime a binary is a
heap object; small binaries are copied into the process heap, larger ones are
reference-counted and shared — but that is not exposed as a language type
`(Assessment: derived from :binary.referenced_byte_size/1, which documents
sub-binaries referencing a larger binary)`
([binary.html#referenced_byte_size/1](https://www.erlang.org/doc/apps/stdlib/binary.html)).

**Borrowed view: implicit, has no type and no lifetime.** The view role is
played by the *sub-binary* returned from decomposition. "Binary sharing occurs
whenever binaries are taken apart. This is the fundamental reason why binaries
are efficient; decomposition always has *O(1)* complexity." `binary:split/3`
"return[s] a list of binaries that are all referencing `Subject` … the data in
`Subject` is not copied to new binaries, and … `Subject` cannot be garbage
collected until the results … are no longer referenced." `:binary.part/3` is
also available as `erlang:binary_part/2,3`, which is guard-allowed
([binary.html#split/3](https://www.erlang.org/doc/apps/stdlib/binary.html),
[binary.html#part/3](https://www.erlang.org/doc/apps/stdlib/binary.html)).
There is no `&str`-style view type and no way to express "borrows from" in a
signature.

**Builder: not a type — a data shape plus one final conversion.** The builder is
**IO data / iodata**: "a binary or a list containing bytes (integers within the
`0..255` range) or nested IO data. The type is recursive." The idiom:

- accumulate nested lists: `[username, ?@, domain]`;
- because "IO data can be arbitrarily nested … that's a cheap and efficient
  operation";
- convert once at the end with `IO.iodata_to_binary/1`, "reasonably efficient
  since it's implemented natively in C";
- measure without converting via `IO.iodata_length/1`, test emptiness via
  `IO.iodata_empty?/1`;
- most IO APIs "receive IO data and write it to the socket directly without
  converting it to binary"
  ([hexdocs.pm/elixir/IO.html, "IO data"](https://hexdocs.pm/elixir/IO.html)).

Documented trade-off: "you can't do things like pattern match on the first part
of a piece of IO data like you can with a binary, because you usually don't know
the shape of the IO data" ([IO.html](https://hexdocs.pm/elixir/IO.html)).

An alternative in-language builder for binaries is the append-in-recursion
form: `triples_to_bin(T, <<Acc/binary, X:32, Y:32, Z:32>>)`, presented as
"[a]ppending to a binary in an efficient way"
([erlang.org/doc/system/bit_syntax.html](https://www.erlang.org/doc/system/bit_syntax.html)).

`Enum.into/2` + the `Collectable` protocol is the generic "build a container by
folding into it" mechanism ("`Collectable.into/1` can be seen as the opposite of
`Enumerable.reduce/3`"), which is why there is no string-specific builder class
([hexdocs.pm/elixir/Collectable.html](https://hexdocs.pm/elixir/Collectable.html)).

**Byte ↔ text bridge: two parallel, explicitly named systems.**

- `iodata` = integers are **bytes** (0..255); `chardata` = integers are
  **codepoints** (0..0x10FFFF). "If you try to use `iodata_to_binary/1` on
  chardata, it will result in an argument error", demonstrated with `?π`
  ([IO.html, "Chardata"](https://hexdocs.pm/elixir/IO.html)).
- `IO.iodata_to_binary/1` "treats integers … as raw bytes and does not perform
  any kind of encoding conversion"; `IO.chardata_to_string/1` is its
  codepoint-aware counterpart ([IO.html](https://hexdocs.pm/elixir/IO.html)).
- Explicit encoding conversion and normalization live in `:unicode`
  (`characters_to_binary/3`, `characters_to_list/2`, `characters_to_nfc_binary/1`
  …) ([unicode.html](https://www.erlang.org/doc/apps/stdlib/unicode.html)).
- Validity checking/repair lives in `String`: `valid?/2`, `replace_invalid/2`,
  `chunk/2` ([String.html](https://hexdocs.pm/elixir/String.html)).

**Which layer the stdlib actually provides:** all three, but asymmetrically —
owned type yes (as plain `binary`), borrowed view only as an implicit runtime
sub-binary with no type, builder only as an iodata *shape* with native
conversion, not as an API object
(Assessment: derived from IO.html "IO data", binary.html
"referenced_byte_size/1", String.html).

(Assessment: derived from the sources above. Note `Kernel.byte_size/1` is
inlined by the compiler, so "constant time size" is a compiler guarantee, not a
library one — [Kernel.html#byte_size/1](https://hexdocs.pm/elixir/Kernel.html).)

## 10. Interesting design decisions

1. **Byte and text are the same value, so the split lives in names, not types.**
   `binary_slice` vs `String.slice` vs `String.byte_slice` is a three-way,
   explicitly documented contract rather than an implicit default
   ([String.html#byte_slice/3](https://hexdocs.pm/elixir/String.html),
   [Kernel.html#binary_slice/3](https://hexdocs.pm/elixir/Kernel.html)).
2. **Default "length" and default "iteration" mean graphemes.** `String.length/1`
   counts grapheme clusters per UAX #29, not codepoints
   ([String.html#length/1](https://hexdocs.pm/elixir/String.html)). Mojo's
   default *iteration* is graphemes; Mojo exposes no single default length.
   Elixir's grapheme defaults are the sharpest contrast to Java (UTF-16 code
   units) and Python (codepoints) (Assessment: derived from the run README
   §"Positioning fact" plus the String.html source).
3. **Invalid UTF-8 is tolerated, not rejected.** String functions operate on
   possibly-invalid binaries and rely on UTF-8 self-synchronization; validation
   is the caller's boundary responsibility, with `valid?/2`, `chunk/2`,
   `replace_invalid/2` as the repair tools
   ([String.html, "Self-synchronization"](https://hexdocs.pm/elixir/String.html)).
   This is the opposite of construction-time enforcement.
4. **`next_*` cursor pairs instead of re-slicing.** `next_codepoint/1`,
   `next_grapheme/1`, `next_grapheme_size/1` return `{token, rest}`, so a
   streaming parser walks the string without computing offsets
   ([String.html#next_grapheme/1](https://hexdocs.pm/elixir/String.html)).
5. **Two byte-slicing contracts.** `binary_part/3` raises (guard-allowed,
   strict) while `binary_slice/3` clips (not guard-allowed, forgiving) — the
   same operation with two documented error policies
   ([Kernel.html#binary_part/3](https://hexdocs.pm/elixir/Kernel.html),
   [Kernel.html#binary_slice/3](https://hexdocs.pm/elixir/Kernel.html)).
6. **`byte_slice/3` as a dedicated "at most N bytes, stay valid" primitive**,
   explicitly motivated by byte budget constraints
   ([String.html#byte_slice/3](https://hexdocs.pm/elixir/String.html)).
7. **Structural byte comparison is the default `<`.** Fast and total, but
   non-linguistic: "álien" sorts after "office". Canonical equivalence is an
   *opt-in* function, `String.equivalent?/2`, and the docs advise normalizing
   upfront when comparing many times
   ([Kernel.html, "Structural comparison"](https://hexdocs.pm/elixir/Kernel.html),
   [String.html#equivalent?/2](https://hexdocs.pm/elixir/String.html)).
8. **Locale-free core with labelled opt-in modes.** Case functions take
   `:default | :ascii | :greek | :turkic`; `:turkic` "properly handles the letter
   i with the dotless variant", `:greek` the context-sensitive sigma, `:ascii`
   is the fast path ([String.html#downcase/2](https://hexdocs.pm/elixir/String.html)).
9. **`nil` vs `""` is intentional per API.** Existence lookups (`at`, `first`,
   `last`, `next_*`) return `nil`; range/slice operations return `""`
   ([String.html](https://hexdocs.pm/elixir/String.html)).
10. **Compiled patterns as a first-class third pattern shape.**
    `pattern() :: t() | [nonempty_binary()] | :binary.cp()` — a compiled pattern
    from `:binary.compile_pattern/1` is accepted anywhere a pattern is, for
    repeated matching, and the docs note it "cannot be stored in a module
    attribute" ([String.html, type `pattern/0`](https://hexdocs.pm/elixir/String.html),
    [binary.html#compile_pattern/1](https://www.erlang.org/doc/apps/stdlib/binary.html)).
11. **Sub-binary memory retention is acknowledged and given an escape hatch.**
    `referenced_byte_size/1` exists so callers can decide when to `copy/1`,
    with an explicit warning not to do this blindly
    ([binary.html#referenced_byte_size/1](https://www.erlang.org/doc/apps/stdlib/binary.html)).
12. **Atom conversion is documented as a hazard.** `String.to_atom/1` "creates
    atoms dynamically and atoms are not garbage-collected. Therefore, `string`
    should not be an untrusted value"; `to_existing_atom/1` is the safe variant,
    with a 255-codepoint maximum atom size
    ([String.html#to_atom/1](https://hexdocs.pm/elixir/String.html)).

## 11. Decisions NOT to copy

- **No borrow/view type and no lifetime — do not copy.** Elixir can afford this
  because the BEAM owns all memory and the GC hides retention. Mojo has an
  ownership model, so the view layer must be a *type* (`StringSpan`-like), not
  a runtime accident (Assessment: derived from binary.html
  `referenced_byte_size/1`, which documents the retention you cannot express).
- **Tolerating invalid UTF-8 inside the text API — do not copy as a default.**
  Silent skipping (`normalize/2`) and self-synchronizing recovery are the right
  choice for a dynamically-typed, boundary-agnostic runtime; for a static text
  library, explicit validity at construction plus an explicit
  recovery/conversion API is safer (Assessment: derived from String.html
  "Self-synchronization" vs the run README's positioning note that Mojo 1.x
  enforces UTF-8 validity at construction).
- **Structural byte comparison as the primary text comparison — copy only with
  care.** `<` on text is a documented footgun for anything user-visible
  ("álien" > "office"); Mojo should make the fast byte comparison available but
  not let it silently be the text operator
  ([Kernel.html, "Structural comparison"](https://hexdocs.pm/elixir/Kernel.html)).
- **No builder object — do not copy.** The iodata idiom is cheap because the
  BEAM copies binaries on concatenation anyway and most sinks accept nested
  lists directly. Mojo library consumers need an explicit
  builder/append/flush contract (Assessment: derived from IO.html "IO data" and
  the run README's builder gap premise).
- **`nil` vs `""` split — do not copy.** Two sentinels for "nothing" force every
  caller to remember which function returns which; a single documented
  convention is better.
  ([String.html](https://hexdocs.pm/elixir/String.html)).
- **Grapheme-as-default-iteration cost — do not copy blindly.** Grapheme
  counting is a linear Unicode pass; a leaf library on the critical path of 36
  dependent libraries should keep byte and codepoint paths equally cheap and
  equally first-class (Assessment: derived from String.html "String and binary
  operations" and the run README's dependency note).
- **`charlist` legacy interop — do not copy.** It exists for old Erlang APIs and
  produces surprising `IEx` output (`[99, 97, 116]` printing as `~c"cat"`)
  ([binaries-strings-and-charlists.html](https://hexdocs.pm/elixir/binaries-strings-and-charlists.html)).
- **Unbounded term interning (`to_atom/1`) — do not copy.** A string library must
  not hand out an API that can exhaust a global table
  ([String.html#to_atom/1](https://hexdocs.pm/elixir/String.html)).

## 12. Ideas fitting Mojo

- **Name the measurement, three times over.** Expose byte/codepoint/grapheme
  length as three distinct names and never a generic `length`. Elixir proves
  this is teachable and that the disagreement is worth documenting with the same
  worked example everywhere (`"héllo"` → 5 vs 6)
  ([String.html#length/1](https://hexdocs.pm/elixir/String.html)).
- **A three-way slice family with documented contracts.**
  `slice` (grapheme indices), `byte_slice` (byte indices, trim truncated
  codepoints), `raw_slice`/`binary_slice` (byte indices, no adjustment, may
  return invalid). Elixir shows all three are needed and that the middle one is
  the only one that can promise a byte budget
  ([String.html#byte_slice/3](https://hexdocs.pm/elixir/String.html)).
- **`byte_slice(string, start, max_bytes)` is directly useful for MojoAkku's
  upper layers** — HTTP `Content-Length` caps, fixed-size headers, MIME
  boundaries: "useful when you have a string and you need to guarantee it does
  not exceed a certain amount of bytes"
  ([String.html#byte_slice/3](https://hexdocs.pm/elixir/String.html)).
- **Cursor pairs for streaming.** `next_codepoint`/`next_grapheme` returning
  `(token, rest)` is an allocation-cheap parser API that avoids index
  arithmetic entirely; a good Mojo pattern for `parser`/`json`/`html` consumers
  ([String.html#next_codepoint/1](https://hexdocs.pm/elixir/String.html)).
- **Builder as deferred nested buffers, converted once.** The iodata lesson
  generalizes to Mojo: offer both an in-place `StringBuilder` *and* a
  "collect pieces, materialize once" path, and make length/emptiness queryable
  before materializing (`iodata_length/1`, `iodata_empty?/1`)
  ([IO.html](https://hexdocs.pm/elixir/IO.html)).
- **Mixed-validity chunking.** `chunk(string, :valid | :printable)` is a compact
  way to let a caller find and repair invalid regions instead of failing the
  whole input — useful when MojoAkku parses network bytes
  ([String.html#chunk/2](https://hexdocs.pm/elixir/String.html)).
- **Separate "invalid" from "incomplete" in the conversion API.** The
  `{:error, …}` / `{:incomplete, …}` distinction models exactly what a
  streaming decoder needs: retry with more bytes vs reject
  ([unicode.html#characters_to_list/2](https://www.erlang.org/doc/apps/stdlib/unicode.html)).
- **A pattern argument that accepts string, list of strings, or compiled
  pattern, with one documented `pattern` type.** Reduces one-shot/repeated
  call-site divergence and is easy to mirror in Mojo with a small enum/trait
  ([String.html, type `pattern/0`](https://hexdocs.pm/elixir/String.html)).
- **Substring sharing with an explicit detach operation.** A view that references
  the parent plus `copy`/`detach` when retention matters is a well-tested
  memory/CPU trade-off Elixir documents honestly
  ([binary.html#referenced_byte_size/1](https://www.erlang.org/doc/apps/stdlib/binary.html)).
- **Normalization as an explicit, named choice.** Offer NFC/NFD/NFKC/NFKD as
  four named functions and a separate `equivalent?` comparison, never a hidden
  normalize-on-create; Elixir's docs also warn that NFKC/NFKD "should not be
  blindly applied" ([String.html#normalize/2](https://hexdocs.pm/elixir/String.html)).
- **Documentation discipline for empty edges.** A table like Elixir's — empty
  needle matches, empty pattern in split yields `["", …]`, empty separator
  intersperses, empty `match` in `replace_leading` raises — is exactly the kind
  of contract the MojoAkku string library should state per function, given it is
  the dependency of 36 libraries ([String.html](https://hexdocs.pm/elixir/String.html),
  [run README](README.md)).

## Sources

- Elixir `String` module documentation (v1.20.4):
  <https://hexdocs.pm/elixir/String.html>
- Elixir guide "Binaries, strings, and charlists" (v1.20.4):
  <https://hexdocs.pm/elixir/binaries-strings-and-charlists.html>
- Elixir `Kernel` module (binary/bit-string primitives, structural comparison):
  <https://hexdocs.pm/elixir/Kernel.html>
- Elixir `IO` module (IO data, iodata, chardata):
  <https://hexdocs.pm/elixir/IO.html>
- Elixir `String.Chars` protocol:
  <https://hexdocs.pm/elixir/String.Chars.html>
- Elixir `Collectable` protocol:
  <https://hexdocs.pm/elixir/Collectable.html>
- Erlang `:binary` module (byte-oriented binary manipulation, sub-binaries,
  compiled patterns): <https://www.erlang.org/doc/apps/stdlib/binary.html>
- Erlang `:unicode` module (encoding conversion, normalization, error/incomplete
  tuples): <https://www.erlang.org/doc/apps/stdlib/unicode.html>
- Erlang System Documentation, "Bit Syntax" (segment syntax, appending):
  <https://www.erlang.org/doc/system/bit_syntax.html>
- `unicode` (elixir-unicode) package README (codepoint introspection):
  <https://unicode.hexdocs.pm/1.16.2/readme.html>
- `unicode_string` package guides (UAX #29/#14 segmentation, locale tailoring):
  <https://hex.pm/packages/unicode_string/2.4.1/files/guides/introduction.md>
- `unicode_transform` package (CLDR Transform, UTS #35 §10):
  <https://hex.pm/packages/unicode_transform>
- `codepagex` (encoding conversion library):
  <https://github.com/tallakt/codepagex>
- Unicode Standard Annex #29 (grapheme/word/sentence boundaries):
  <https://www.unicode.org/reports/tr29/>
- Run configuration / question set for this research:
  `mojoakku/text_string/_dev/README.md`
