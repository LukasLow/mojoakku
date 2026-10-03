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

- `three-way case enum` — `Upper` / `Lower` / `Mixed` decode policy. (origin: `elixir.md` §7, §12; `java.md` §7)
- `casefold option` — lenient cross-case decode switch. (origin: `python.md` §7)
- `map01 confusable mapping` — `0`→`O` and `1`→`I`/`L` decode mapping. (origin: `python.md` §7)
- `ignore characters` — caller-supplied set of characters to skip (whitespace, hyphens), beyond the fixed `Whitespace.IGNORE` set. (origin: `python.md` §3; `cpp.md` §7; `go.md` §4/§11)

## Padding and canonicality

- `line wrapping / MIME layer` — 64/76-column wrapping as a layer above the codec. (origin: `java.md` §7; `perl.md` §11; `python.md` §7)

## Length / validation helpers

- `is_in_alphabet` — single-symbol alphabet membership check. (origin: `java.md` §3)

## Streaming / incremental

- `stream adapters` — reader/writer wrappers over `akku/io_core`. (origin: `go.md` §9; `java.md` §9)
- `partial result on error` — return the successfully decoded prefix plus a written count alongside the error. (origin: `go.md` §10; `java.md` §4; `rust.md` §4)
- `read/written result struct` — allocation-free buffer-fill result recording consumed symbols and produced bytes. (origin: `js-ts.md` §12)
