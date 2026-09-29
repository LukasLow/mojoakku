# codec_base64 — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected end
state. Format and rules: `.agents/workflows/LibraryLayout.md`.

## Faster engines behind the same signatures

- `constant-time engine` — a branch-free encode/decode path (base64ct-style) for security-sensitive use. (origin: `rust.md` §10, §11)
- `SIMD engine` — a vectorised encode/decode path (base64-simd-style). (origin: `rust.md` §10, §11)

## Layers on top of the codec

- `I/O stream adapters` — `DecoderReader` / `EncoderWriter` wrapping `mojoakku/io_core` traits (a consumer can build them; not shipped here). (origin: `rust.md` §5; `java.md` §9)
- `MIME / line-wrapping layer` — 64/76-column wrapping as a mail-transfer concern above the codec. (origin: `c.md` §11; `perl.md` §11; `java.md` §1)

## Variants deliberately left out

- `custom alphabets` — an `Alphabet::new`-style user-supplied symbol table. (origin: `rust.md` §11)
- `exotic variants` — Crockford base32, BIN_HEX, BCRYPT, IMAP-MUTF7. (origin: `rust.md` §11; `cpp.md` §7)
- `decode casefold policy` — a lenient cross-case decode option. (origin: `perl.md` §11; `cpp.md` §7; `python.md` §7)
