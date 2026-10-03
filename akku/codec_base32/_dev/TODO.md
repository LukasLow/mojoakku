# codec_base32 — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected end
state. Format and rules: `.agents/workflows/LibraryLayout.md`.

## Alphabet variants

- `Crockford base32` — Crockford's human-oriented alphabet, as used by ULID. (origin: `rust.md` §7, §10; `cpp.md` §7; `js-ts.md` §7)
- `z-base-32` — human-oriented alphabet optimized for transcription. (origin: `rust.md` §7)
- `Nix reversed base32` — Nix's right-to-left base32 variant. (origin: `rust.md` §7)
- `DNSSEC / DNSCurve base32` — DNS-specific unpadded base32 dialects. (origin: `rust.md` §3)
- `custom alphabet` — user-supplied 32-symbol table. (origin: `rust.md` §7; `java.md` §7; `go.md` §7)
- `decode aliases` — extra decode-only symbols for confusables (`I`/`L`/`O`). (origin: `rust.md` §10)

## Case / leniency policy

- `three-way case enum` — `Upper` / `Lower` / `Mixed` decode policy. (origin: `elixir.md` §7, §12)
- `casefold option` — lenient cross-case decode switch. (origin: `python.md` §7)
- `map01 confusable mapping` — `0`→`O` and `1`→`I`/`L` decode mapping. (origin: `python.md` §7)
- `ignore characters` — caller-supplied set of characters to skip (whitespace, hyphens). (origin: `python.md` §3; `cpp.md` §7; `go.md` §7)

## Padding and canonicality

- `padding toggle` — `padded: Bool` to emit/require or omit padding. (origin: `python.md` §7; `java.md` §7)
- `canonical / strict check` — reject non-zero trailing pad bits (RFC 4648 §3.5). (origin: `rust.md` §4; `go.md` §11; `c.md` §7)
- `strict decoding policy` — `LENIENT` vs `STRICT` decode enum. (origin: `java.md` §7)
- `line wrapping / MIME layer` — 64/76-column wrapping as a layer above the codec. (origin: `java.md` §7; `perl.md` §11)

## Length / validation helpers

- `encoded_length` — pure `8*ceil(n/5)` length function for pre-sizing. (origin: `go.md` §12; `perl.md` §12)
- `decoded_length` — fallible decode-side length estimate (padding-dependent). (origin: `rust.md` §12)
- `valid predicate` — allocate-free validity check. (origin: `elixir.md` §10, §12)
- `is_in_alphabet` — single-symbol alphabet membership check. (origin: `java.md` §3)

## Streaming / incremental

- `incremental encoder` — feed/finish type carrying 0–4 leftover input bytes. (origin: `rust.md` §12; `elixir.md` §12; `js-ts.md` §12)
- `incremental decoder` — feed/finish type carrying 0–7 leftover symbols. (origin: `elixir.md` §9; `c.md` §9)
- `stream adapters` — reader/writer wrappers over `akku/io_core`. (origin: `go.md` §9; `java.md` §9)
- `partial result on error` — return the successfully decoded prefix plus error. (origin: `go.md` §10; `java.md` §4)
- `read/written result struct` — allocation-free buffer-fill result. (origin: `js-ts.md` §12)

## Memory / output shapes

- `in-place encode into mut buffer` — write the encoded text into a caller `String`. (origin: `java.md` §12; `go.md` §12)
- `in-place decode into caller buffer` — write decoded bytes into a caller span. (origin: `go.md` §12; `rust.md` §12)
- `append variants` — append encoded/decoded output to a growing buffer. (origin: `go.md` §12)
