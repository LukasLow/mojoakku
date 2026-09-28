# string — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected end
state. Format and rules: `.agents/workflows/LibraryLayout.md`.

This is the **Phase-1 seed** (generous by design): it is the deduplicated union
of the string APIs across the ten researched languages. Later phases move items
out as they ship. `[Mojo]` marks a candidate the Mojo 1.x stdlib already
provides (`String`/`StringSpan`), so it is a *wrap/extend* case, not a rebuild.

## Inspect & measure

- `text_width` — printed column count for layout. (origin: `julia.md` §3, `elixir.md` §2, `js-ts.md` §2)
- `count_occurrences` — non-overlapping match count. (origin: `go.md` §3, `python.md` §3, `elixir.md` §3)
- `is_ascii` — all units below U+0080. (origin: `c.md` §3, `rust.md` §3)
- `byte_at` / `codepoint_at` — raw unit at an index. (origin: `c.md` §3, `rust.md` §3, `julia.md` §3)
- `first` / `last` — first/last unit or first/last n units. (origin: `cpp.md` §3, `julia.md` §3)

## Search & find

- `find` / `rfind` — first/last substring occurrence as an `Optional` index. (origin: `c.md` §3, `rust.md` §3, `python.md` §3, `js-ts.md` §3)
- `find_byte` / `find_codepoint` — first occurrence of a single unit. (origin: `c.md` §3, `go.md` §3, `julia.md` §3)
- `find_any_of` / `find_first_not_of` / `find_last_of` — search against a character set. (origin: `cpp.md` §3, `go.md` §3)
- `find_func` / `contains_func` — predicate-based search/membership. (origin: `go.md` §3)
- `starts_with` / `ends_with` — prefix/suffix test. (origin: `cpp.md` §3, `python.md` §3, `julia.md` §3)
- `matches` / `match_indices` — iterate all matches and their positions. (origin: `rust.md` §3, `python.md` §3, `java.md` §3)
- `common_prefix` / `common_suffix` — longest shared prefix/suffix. (origin: `java.md` §2, `elixir.md` §3)
- `similarity_distance` — edit/Jaro/bag similarity. (origin: `elixir.md` §3, `java.md` §2)

## Split & join

- `split` / `split_n` / `rsplit` — split on a delimiter, with bounds and from the right. (origin: `go.md` §3, `rust.md` §3, `julia.md` §3)
- `split_once` / `partition` — split once into (before, after). (origin: `go.md` §3, `rust.md` §3, `python.md` §3)
- `fields` / `split_whitespace` — split on whitespace runs. (origin: `go.md` §3, `python.md` §3, `julia.md` §3)
- `lines` — split on line terminators. (origin: `rust.md` §3, `java.md` §3, `julia.md` §3)
- `split_term` / `split_inclusive` — keep/drop delimiters in the parts. (origin: `go.md` §3, `rust.md` §3)
- `join` — concatenate parts with a separator. (origin: `go.md` §3, `python.md` §3, `julia.md` §3)
- `chunk` — split into fixed or printable chunks. (origin: `elixir.md` §3)

## Trim, pad & case

- `trim` / `trim_start` / `trim_end` — remove leading/trailing whitespace or set. (origin: `go.md` §3, `python.md` §3, `julia.md` §3)
- `trim_matches` — trim a set or predicate of units. (origin: `rust.md` §3, `go.md` §3)
- `strip_prefix` / `strip_suffix` — remove a prefix/suffix if present. (origin: `rust.md` §3, `python.md` §3, `elixir.md` §3)
- `pad_start` / `pad_end` / `center` — pad to a width. (origin: `python.md` §3, `js-ts.md` §3, `elixir.md` §3)
- `zfill` / `expand_tabs` / `indent` — numeric pad, tab expansion, indentation. (origin: `python.md` §3, `java.md` §3)
- `to_lower` / `to_upper` — full Unicode case mapping. (origin: `cpp.md` §3, `rust.md` §3, `python.md` §3, `julia.md` §3)
- `to_ascii_lower` / `to_ascii_upper` — ASCII-only fast case path. (origin: `rust.md` §3)
- `casefold` — aggressive caseless folding. (origin: `python.md` §3, `rust.md` §3)
- `capitalize` / `titlecase` / `swapcase` — first-letter, word-title, inverted case. (origin: `python.md` §3, `elixir.md` §3)
- `reverse` — reverse by unit. (origin: `elixir.md` §3, `julia.md` §3)

## Replace & mutate

- `replace_all` / `replace_n` — replace all / the first n occurrences. (origin: `go.md` §3, `rust.md` §3, `python.md` §3)
- `replace_first` / `replace_last` — replace only the first/last occurrence. (origin: `rust.md` §3)
- `remove_matches` / `retain` — delete matching units. (origin: `rust.md` §3)
- `translate` / `maketrans` — character-mapping table substitution. (origin: `python.md` §3)
- `insert` / `erase` / `truncate` — positional mutation of an owned buffer. (origin: `cpp.md` §3, `java.md` §3, `rust.md` §3)
- `append_char` / `write_rune` — append a single scalar. (origin: `go.md` §3, `rust.md` §3)
- `pop` / `split_off` — remove and return a trailing unit/range. (origin: `rust.md` §3)

## Compare & sort

- `compare` — lexicographic three-way ordering. (origin: `cpp.md` §3, `swift.md` §3, `julia.md` §3)
- `eq_ignore_case` / `compare_ignore_case` — caseless equality/ordering. (origin: `go.md` §3, `rust.md` §3, `java.md` §3)
- `collate` / `locale_compare` — locale-aware ordering. (origin: `c.md` §3, `js-ts.md` §3, `java.md` §3)
- `normalize` / `canonically_equal` — NFC/NFD/NFKC/NFKD and normalization-aware equality. (origin: `python.md` §3, `java.md` §3, `julia.md` §3)
- `hash` — stable hash for map keys. (origin: `cpp.md` §3, `python.md` §3, `julia.md` §3)

## Slice, index & boundary

- `slice` / `substring` — extract a sub-range. (origin: `go.md` §3, `rust.md` §3, `julia.md` §3)
- `get` / `try_slice` — checked slice returning `Optional`. (origin: `rust.md` §3, `julia.md` §3)
- `split_at` / `split_at_checked` — split into two halves at an index. (origin: `rust.md` §3, `elixir.md` §3)
- `byte_slice` — slice by byte offsets, snapping truncated codepoints. (origin: `elixir.md` §3, `julia.md` §8)
- `is_char_boundary` — is an index a valid character start? (origin: `rust.md` §3, `julia.md` §3)
- `floor_char_boundary` / `ceil_char_boundary` / `next_index` / `prev_index` — snap/step to a boundary. (origin: `rust.md` §3, `julia.md` §3)
- `offset_by_codepoints` / `offset_by_graphemes` — advance an index by n scalars/graphemes. (origin: `java.md` §3, `swift.md` §3)

## Encoding & byte bridge

- `from_bytes` / `decode` — construct text from bytes. (origin: `go.md` §3, `rust.md` §3, `python.md` §3)
- `from_bytes_lossy` — decode replacing invalid bytes. (origin: `rust.md` §3, `python.md` §4, `java.md` §4)
- `to_c_string` / `from_c_string` — NUL-terminated C bridge. (origin: `c.md` §3, `swift.md` §3, `julia.md` §3)
- `encode_utf16` / `decode_utf16` — UTF-16 bridge. (origin: `rust.md` §3, `java.md` §7, `js-ts.md` §7)
- `transcode` — convert between encodings. (origin: `elixir.md` §3, `julia.md` §3, `python.md` §3)
- `hex_encode` / `hex_decode` — hex byte bridge. (origin: `elixir.md` §3, `js-ts.md` §3)
- `decode_error_policy` — strict/replace/ignore failure policy. (origin: `python.md` §4, `java.md` §4, `rust.md` §3)

## Unicode level

- `grapheme_slice` — slice by grapheme index. (origin: `elixir.md` §3, `swift.md` §12)
- `word_segmentation` / `sentence_segmentation` / `line_segmentation` — UAX-14 word/sentence/line breaks. (origin: `java.md` §3, `js-ts.md` §3)
- `codepoint_predicates` — is_letter / is_digit / is_whitespace per scalar. (origin: `rust.md` §3, `java.md` §3)
- `char_from_u32` / `ord` — scalar ↔ integer. (origin: `rust.md` §3, `python.md` §3)
- `unaccent` / `transliterate` — strip accents / change script. (origin: `elixir.md` §2, `java.md` §2)
- `unicode_property_lookup` — script/block/category introspection. (origin: `elixir.md` §2, `python.md` §3)

## Builder layer

- `builder` — incremental append/flush construction. (origin: `go.md` §9, `java.md` §9, `rust.md` §9, `julia.md` §9)
- `builder_grow` / `builder_reset` / `shrink_to_fit` — capacity management. (origin: `go.md` §3, `rust.md` §3, `java.md` §3)
- `finish` / `take` — materialize and consume the builder. (origin: `go.md` §3, `java.md` §3)
- `join_builder` — efficient build-by-join. (origin: `python.md` §9, `java.md` §3)
- `iodata` — deferred nested pieces, materialized once. (origin: `elixir.md` §9)
- `format_to` / `writer` — write formatted output. (origin: `cpp.md` §3, `python.md` §3)

## Validation & error type

- `string_result` — typed outcome for string operations. (origin: `rust.md` §4, `cpp.md` §4, `elixir.md` §4)
- `index_out_of_bounds` — out-of-range index failure. (origin: `go.md` §4, `python.md` §4, `swift.md` §4)
- `boundary_error` — in-range but non-boundary index, with nearest valid indices. (origin: `julia.md` §4, `rust.md` §4)
- `invalid_encoding` — malformed byte/scalar failure. (origin: `rust.md` §4, `java.md` §4, `elixir.md` §4)
- `not_found` — absent match as `Optional`, not a sentinel. (origin: `rust.md` §4, `julia.md` §4)
- `length_overflow` — result too large / capacity overflow. (origin: `cpp.md` §4, `go.md` §4)
- `empty_input_policy` — defined handling of empty input. (origin: `java.md` §4, `elixir.md` §8)
