# text_string — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected end
state. Format and rules: `.agents/workflows/LibraryLayout.md`. The Phase-3
shipped entries and the stdlib-first operations deliberately not re-wrapped are
not listed here (see `DESIGN.md`, "Empirical std surface").

## Inspect & measure

- `text_width` — printed column count for layout. (origin: `julia.md` §3, `elixir.md` §2, `js-ts.md` §2)
- `is_ascii` — all units below U+0080. (origin: `c.md` §3, `rust.md` §3)
- `byte_at` / `codepoint_at` — checked single-unit accessors returning `Optional`. (origin: `c.md` §3, `rust.md` §3, `julia.md` §3)
- `first` / `last` — first/last unit or first/last n units. (origin: `cpp.md` §3, `julia.md` §3)

## Search & find

- `find_byte` / `find_codepoint` — first occurrence of a single unit. (origin: `c.md` §3, `go.md` §3, `julia.md` §3)
- `find_any_of` / `find_first_not_of` / `find_last_of` — search against a character set. (origin: `cpp.md` §3, `go.md` §3)
- `find_func` / `contains_func` — predicate-based search/membership. (origin: `go.md` §3)
- `matches` / `match_indices` — iterate all matches and their positions. (origin: `rust.md` §3, `python.md` §3, `java.md` §3)
- `common_prefix` / `common_suffix` — longest shared prefix/suffix. (origin: `java.md` §2, `elixir.md` §3)
- `similarity_distance` — edit/Jaro/bag similarity. (origin: `elixir.md` §3, `java.md` §2)

## Split & join

- `rsplit` — split on a delimiter from the right. (origin: `go.md` §3, `rust.md` §3, `julia.md` §3)
- `partition` / `rpartition` — split once keeping the separator in the tuple. (origin: `python.md` §3)
- `split_term` / `split_inclusive` — keep/drop delimiters in the parts. (origin: `go.md` §3, `rust.md` §3)
- `chunk` — split into fixed or printable chunks. (origin: `elixir.md` §3)

## Trim, pad & case

- `trim_start` / `trim_end` — Unicode-whitespace trim from one end. (origin: `go.md` §3, `python.md` §3, `julia.md` §3)
- `trim_matches` — trim a predicate of units. (origin: `rust.md` §3, `go.md` §3)
- `pad_start` / `pad_end` / `center` — pad to a width. (origin: `python.md` §3, `js-ts.md` §3, `elixir.md` §3)
- `zfill` / `expand_tabs` / `indent` — numeric pad, tab expansion, indentation. (origin: `python.md` §3, `java.md` §3)
- `casefold` — aggressive caseless folding. (origin: `python.md` §3, `rust.md` §3)
- `titlecase` / `swapcase` — word-title, inverted case. (origin: `python.md` §3, `elixir.md` §3)
- `reverse` — reverse by unit. (origin: `elixir.md` §3, `julia.md` §3)

## Replace & mutate

- `replace_first` / `replace_last` — replace only the first/last occurrence. (origin: `rust.md` §3)
- `remove_matches` / `retain` — delete matching units. (origin: `rust.md` §3)
- `translate` / `maketrans` — character-mapping table substitution. (origin: `python.md` §3)
- `insert` / `erase` / `truncate` — positional mutation of an owned buffer. (origin: `cpp.md` §3, `java.md` §3, `rust.md` §3)
- `pop` / `split_off` — remove and return a trailing unit/range. (origin: `rust.md` §3)

## Compare & sort

- `compare` — lexicographic three-way ordering. (origin: `cpp.md` §3, `swift.md` §3, `julia.md` §3)
- `eq_ignore_case` / `compare_ignore_case` — caseless equality/ordering. (origin: `go.md` §3, `rust.md` §3, `java.md` §3)
- `collate` / `locale_compare` — locale-aware ordering. (origin: `c.md` §3, `js-ts.md` §3, `java.md` §3)
- `normalize` / `canonically_equal` — NFC/NFD/NFKC/NFKD and normalization-aware equality. (origin: `python.md` §3, `java.md` §3, `julia.md` §3)
- `hash` — stable hash for map keys. (origin: `cpp.md` §3, `python.md` §3, `julia.md` §3)

## Slice, index & boundary

- `substring` — extract a sub-range as an owned copy. (origin: `go.md` §3, `rust.md` §3, `julia.md` §3)
- `split_at` / `split_at_checked` — split into two halves at an index. (origin: `rust.md` §3, `elixir.md` §3)
- `byte_slice` — slice by byte offsets, snapping truncated codepoints. (origin: `elixir.md` §3, `julia.md` §8)
- `floor_char_boundary` / `ceil_char_boundary` / `next_index` / `prev_index` — snap/step to a boundary. (origin: `rust.md` §3, `julia.md` §3)
- `offset_by_codepoints` / `offset_by_graphemes` — advance an index by n scalars/graphemes. (origin: `java.md` §3, `swift.md` §3)

## Encoding & byte bridge

- `to_c_string` / `from_c_string` — NUL-terminated C bridge. (origin: `c.md` §3, `swift.md` §3, `julia.md` §3)
- `encode_utf16` / `decode_utf16` — UTF-16 bridge. (origin: `rust.md` §3, `java.md` §7, `js-ts.md` §7)
- `transcode` — convert between encodings. (origin: `elixir.md` §3, `julia.md` §3, `python.md` §3)
- `hex_encode` / `hex_decode` — hex byte bridge. (origin: `elixir.md` §3, `js-ts.md` §3)
- `decode_error_policy` — strict/replace/ignore failure policy. (origin: `python.md` §4, `java.md` §4, `rust.md` §3)
- `streaming_validity` — incremental validity distinguishing `incomplete` (retry with more bytes) from `invalid` (reject). (origin: `elixir.md` §3, §12)

## Unicode level

- `grapheme_slice` — slice by grapheme index. (origin: `elixir.md` §3, `swift.md` §12)
- `word_segmentation` / `sentence_segmentation` / `line_segmentation` — UAX-14 word/sentence/line breaks. (origin: `java.md` §3, `js-ts.md` §3)
- `codepoint_predicates` — is_letter / is_digit / is_whitespace per scalar. (origin: `rust.md` §3, `java.md` §3)
- `char_from_u32` / `ord` — scalar ↔ integer. (origin: `rust.md` §3, `python.md` §3)
- `unaccent` / `transliterate` — strip accents / change script. (origin: `elixir.md` §2, `java.md` §2)
- `unicode_property_lookup` — script/block/category introspection. (origin: `elixir.md` §2, `python.md` §3)

## Builder layer

- `shrink_to_fit` — release excess builder capacity. (origin: `go.md` §3, `rust.md` §3, `java.md` §3)
- `join_builder` — efficient build-by-join. (origin: `python.md` §9, `java.md` §3)
- `iodata` — deferred nested pieces, materialized once. (origin: `elixir.md` §9)
- `builder_as_writer` — an adapter exposing a `StringBuilder` as an `io.Writer` sink. (origin: `elixir.md` §9)

## Validation & error type

- `string_result` — typed outcome for string operations. (origin: `rust.md` §4, `cpp.md` §4, `elixir.md` §4)
- `length_overflow` — result too large / capacity overflow. (origin: `cpp.md` §4, `go.md` §4)
- `empty_input_policy` — defined handling of empty input. (origin: `java.md` §4, `elixir.md` §8)
