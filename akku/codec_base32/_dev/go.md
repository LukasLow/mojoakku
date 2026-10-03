# base32 research: Go

## 1. Standard library support

Go's standard library has a dedicated `encoding/base32` package: "Package
base32 implements base32 encoding as specified by RFC 4648"
(`encoding/base32/base32.go:7`), with both the standard alphabet and the
"Extended Hex Alphabet" used in DNSSEC (`encoding/base32/base32.go:21`, `:92`).
It is a first-class sibling of `encoding/base64` and `encoding/hex`, all
standard library, BSD-3-Clause. (Source:
https://raw.githubusercontent.com/golang/go/master/src/encoding/base32/base32.go)

**Mojo anchor:** Mojo's stdlib has no base32. The `mojov1` buch `stdlib/base64`
page lists only `b64encode`, `b64decode`, `b16encode`, `b16decode`; a
`buch_search` for "base32" returns no hits. (Source: `mojov1` buch
`stdlib/base64`.)

## 2. Relevant community libraries

base32 is covered by the stdlib, so community work is performance- or
compatibility-oriented and largely base64-focused:

- **`github.com/segmentio/asm/base32`** — the `segmentio/asm` family ships
  standard-library-compatible encodings; license MIT No Attribution (MIT-0)
  (https://github.com/segmentio/asm,
  https://github.com/segmentio/asm/blob/main/LICENSE). Its base64 `NewEncoding`
  panics on non-standard alphabets; base32 follows the same shape.
  (Assessment: derived from the repository and its base64 sibling.)
- **`github.com/cristalhq/base64`** — "Drop-in replacement of
  `encoding/base64`", MIT; no base32 equivalent advertised
  (https://github.com/cristalhq/base64).
- **`github.com/segmentio/encoding`** — json/iso8601 focus; no distinct base32
  API (https://github.com/segmentio/encoding).

(Assessment: derived from the stdlib docs and the three repository READMEs
above: Go's community signal for base32 is negligible because the stdlib already
ships a complete, streaming, offset-erroring implementation.)

## 3. Exposed APIs

`encoding/base32` (line numbers in `encoding/base32/base32.go`):

- `type Encoding struct { encode [32]byte; decodeMap [256]uint8; padChar rune }`
  (`:23-29`).
- Constants `StdPadding rune = '='`, `NoPadding rune = -1` (`:33-36`).
- `NewEncoding(encoder string) *Encoding` — 32 unique bytes, no padding char, no
  CR/LF; panics otherwise (`:56-90`).
- `Encoding.WithPadding(padding rune) *Encoding` (`:101`).
- Package vars: `StdEncoding` (`ABCDEFGHIJKLMNOPQRSTUVWXYZ234567`, padded)
  (`:88`), `HexEncoding` (`0123456789ABCDEFGHIJKLMNOPQRSTUV`, padded) (`:92`).
- `Encode(dst, src []byte)` (`:133`), `AppendEncode(dst, src []byte) []byte`
  (`:190`), `EncodeToString(src []byte) string` (`:198`), `EncodedLen(n int) int`
  (`:275`).
- `Decode(dst, src []byte) (int, error)` (`:396`), `AppendDecode(dst, src
  []byte) ([]byte, error)` (`:406`), `DecodeString(s string) ([]byte, error)`
  (`:428`), `DecodedLen(n int) int` (`:573`).
- `NewEncoder(enc *Encoding, w io.Writer) io.WriteCloser` (`:277`),
  `NewDecoder(enc *Encoding, r io.Reader) io.Reader` (`:579`).
- `type CorruptInputError int64` (`:302`).

Unlike `encoding/base64`, **base32 has no `Strict()` method**; the only knobs
are the alphabet (via `NewEncoding`) and padding (via `WithPadding`).
(Assessment: derived from the full API listing in the source.)

## 4. Error representation

Go uses **sentinel/typed error values**, not exceptions.

- base32 decode errors are of type `CorruptInputError` (an `int64` carrying the
  input byte offset); `Error()` renders "illegal base32 data at input byte N"
  (`encoding/base32/base32.go:302-305`).
- `Decode`/`DecodeString` return **partial output plus the error**: `Decode`
  "will return the number of bytes successfully written and CorruptInputError"
  (`:396-400`); `AppendDecode` "returns the partially decoded src and an error"
  (`:406-412`). So error recovery keeps the successfully decoded prefix.
- The encode side produces no in-memory errors; the streaming encoder only
  surfaces underlying `io.Writer` errors (`:212-243`).
- Newline characters (`\r`, `\n`) are ignored on decode, and this is applied
  unconditionally — there is no strict mode to disable it (`:390-395`,
  `stripNewlines` `:552-577`).

## 5. Ownership semantics

Go is garbage-collected and uses `[]byte` slices; there is no ownership transfer
in the Rust/RAII sense.

- `Encode(dst, src []byte)` and `Decode(dst, src []byte)` write into a
  **caller-provided destination** and return only a count; the caller sizes
  `dst` via `EncodedLen`/`DecodedLen` (`:133-134`, `:396-400`). No allocation for
  the result buffer inside `Encode`.
- `EncodeToString` allocates a fresh `make([]byte, EncodedLen)` and converts to
  `string` (`:198-202`); `AppendEncode` grows the caller's dst with
  `slices.Grow` and returns the extended slice (`:190-195`).
- `DecodeString` decodes **in place over its own input buffer** —
  `buf := []byte(s); n, _, err := enc.decode(buf, buf[:l]); return buf[:n]`
  (`:428-433`) — a small memory optimisation that also means the returned slice
  aliases a copy of the string's bytes.
- The streaming `encoder` owns leftover input `buf [5]byte` (`nbuf`) and output
  staging `out [1024]byte` (`:204-211`); the streaming `decoder` owns
  `buf [1024]byte` (leftover input), a leftover decoded-output slice `out []byte`
  and `outbuf [1024/8*5]byte` (`:435-446`).
- Note the deliberate difference from base64: the base32 buffer is `[5]byte`
  (one 40-bit quantum), while base64's is `[3]byte` (one 24-bit quantum).
  (Assessment: derived from the quoted source lines.)

## 6. Blocking / non-blocking

Not applicable to the codec itself: encode/decode are pure in-memory
transformations with no I/O and no concurrency primitives. The only I/O-aware
surface is `NewEncoder`/`NewDecoder`, synchronous/blocking `io.Writer`/
`io.Reader` wrappers by contract; the decoder reads from the wrapped reader
inside `Read` (`:435-543`). Go's concurrency model is goroutine-based, not
`async`/`await`; an async caller wraps the blocking reader/writer in a
goroutine. No async variant exists in the stdlib.

## 7. Alphabet variants, case and padding

- Two presets only: `StdEncoding` (`ABCDEFGHIJKLMNOPQRSTUVWXYZ234567`) and
  `HexEncoding` (`0123456789ABCDEFGHIJKLMNOPQRSTUV`) (`encoding/base32/base32.go:88`,
  `:92`). There is **no URL-safe base32** and **no Crockford** built in.
- Arbitrary custom alphabets via `NewEncoding(string)` for any 32 unique bytes
  (`:56-90`); `WithPadding(rune)` sets any pad byte or `NoPadding` (`rune = -1`)
  (`:101-110`).
- **Case handling is fixed uppercase on encode; decode is uppercase-only.** The
  decode table is built only from the supplied `encoder` bytes, so lowercase
  input is an illegal byte and produces `CorruptInputError`. There is no
  `casefold`/`ignoreCase` option — a real difference from Python and Elixir.
  (Source: `NewEncoding` in `encoding/base32/base32.go`.)
- **Padding**: `StdEncoding` and `HexEncoding` are padded by default;
  `WithPadding(NoPadding)` produces the unpadded presets
  (`RawStdEncoding`/`RawURLEncoding` exist for base64 but **not** for base32).
  `EncodedLen` accounts for the padding mode: padded = `(n+4)/5*8`, unpadded =
  `n/5*8 + (n%5*8+4)/5` (`:275-286`).
- **Valid padding lengths**: the decoder rejects `dlen` of 1, 3 or 6 as invalid
  padding lengths, citing "RFC 4648 Section 6 'Base 32 Encoding' listing the
  five valid padding lengths" (`:355-363`). The five valid lengths are 0, 1, 3,
  4, 6 `=` characters (equivalently 8, 7, 5, 4, 2 data symbols).
- **RFC 4648 reference**: §6 Table 3 (base32 `A-Z2-7`), §7 Table 4 (base32hex
  `0-9A-V`), §3.2 padding, §3.5 canonical encoding.
  (https://www.rfc-editor.org/rfc/rfc4648.txt)

## 8. Timeouts

Not applicable: the package has no timeout or cancellation concept. There is no
`context.Context` parameter anywhere in `encoding/base32`; cancellation must
happen at the `io.Reader`/`io.Writer` layer, because the stream wrappers only
propagate the delegate's error (`:212-243`, `:435-543`). (Assessment: derived
from the API surface quoted above; no timeout symbol exists in the source.)

## 9. Streaming / incremental encode and decode

- **Block functions are explicitly not streaming**: `Encode` "pads the output to
  a multiple of 8 bytes, so Encode is not appropriate for use on individual
  blocks of a large data stream. Use NewEncoder instead"
  (`encoding/base32/base32.go:115-119`).
- `NewEncoder` returns an `io.WriteCloser`; `Write` carries leftover input in
  `buf [5]byte` (`nbuf`), flushing only when 5 bytes accumulate, and **`Close`
  must be called to flush the final partial block** (`:204-271`). This is the
  base32-specific carry: 0–4 input bytes waiting for the 40-bit quantum.
- `NewDecoder` returns an `io.Reader`; `Read` keeps leftover encoded input in
  `buf [1024]byte` (`nbuf`) and leftover **decoded** output in `out []byte`,
  returning buffered bytes on the next call before touching the delegate
  (`:435-543`). It distinguishes padded vs unpadded via
  `readEncodedData(..., min, expectsPadding)` and an `end` flag
  (`:448-477`, `:479-543`).
- The internal `decode` returns an `end bool` "which indicates if end-of-message
  padding was encountered and thus any additional data is an error"; after `end`
  any further non-empty input is rejected (`:312-399`, `:497-499`).
- At the whole-buffer level, the `Append*` family is the incremental building
  block: append to a growing buffer, no internal state, and a partial result on
  error (`:190-195`, `:406-412`).

## 10. Interesting design decisions

- **Alphabet as a first-class value, not an enum**: `Encoding` carries
  `encode[32]` and `decodeMap[256]` lookup tables built once by `NewEncoding`, so
  hot loops index arrays instead of branching (`encoding/base32/base32.go:23-29`,
  `:56-90`).
- **Same package shape across radices**: base32 and base64 share almost
  identical naming (`StdEncoding`, `WithPadding`, `Encode`, `AppendEncode`,
  `EncodeToString`, `NewEncoder`, `CorruptInputError`, `EncodedLen`/`DecodedLen`),
  making the family easy to learn.
- **Partial output on error**: decode never discards what it already decoded; it
  returns `n` bytes plus the error, which matters for error recovery (`:396-400`,
  `:406-412`). Note this differs from base64, which at least used to be
  all-or-nothing on this point.
- **`end`/padding sentinel in the streaming decoder**: a padded group terminates
  the logical stream, so post-padding garbage is detected even across `Read`
  calls (`:312-399`, `:479-543`).
- **Partial in-place decode**: base32's `DecodeString` decodes into the caller's
  own input buffer (`:428-433`).
- **No `Strict()`**: unlike base64, base32 does not reject non-zero trailing bits
  as an option. This is a meaningful gap — non-canonical base32 is accepted.
  (Assessment: derived from the absence of a `Strict` method in the source.)
- **Allocation-free hot path**: `Encode`/`Decode` write into user buffers with no
  allocation; only the convenience `...ToString` variants allocate (`:133-202`).

## 11. Decisions NOT to copy

- **Implicit newline ignoring**: base32 silently skips `\r`/`\n` on decode with
  no strict mode to turn it off. A predictable API should make whitespace
  tolerance explicit, not implicit (`encoding/base32/base32.go:390-395`).
- **Uppercase-only decode**: no lenient case option exists, so callers with
  lowercase input must uppercase it themselves (or use a custom alphabet). This
  is a false strictness: it rejects valid RFC 4648 lower-case spellings without
  giving the caller a switch. (Assessment: derived from `NewEncoding`.)
- **No canonicality check**: the decoder accepts non-zero trailing bits
  unconditionally. RFC 4648 §3.5 exists precisely to prevent "multiple
  base-encoded strings … decoded to the same binary data"; an API should expose a
  canonical/`Strict` toggle. (Sources: `encoding/base32/base32.go`,
  https://www.rfc-editor.org/rfc/rfc4648.txt)
- **`panic` for invalid configuration**: `NewEncoding` panics on a
  wrong-length/duplicate alphabet and `WithPadding` panics on bad padding
  (`:56-110`). Prefer a compile-time or `raises`-style error over a runtime
  panic.
- **`rune`-typed padding (`NoPadding = -1`)**: the magic negative rune (`:36`) is
  a Go-idiomatic sentinel; model padding as an explicit option instead.
- **Mutable global `Encoding` vars**: `StdEncoding`/`HexEncoding` are package
  `var`s (`:88`, `:92`), i.e. mutable global state; alphabets should be
  compile-time constants or values.
- **No `context`/cancellation seam**: the streaming wrappers cannot be cancelled
  except through the delegate — not a pattern to replicate for a predictable API.
  (Assessment: derived from the `encoding/base32/base32.go` API surface.)

## 12. Ideas fitting Mojo

- **Lookup-table Encoding value**: the `encode[32]`/`decodeMap[256]` pair built
  once fits a Mojo `struct` with fixed-size arrays and value semantics
  (`encoding/base32/base32.go:23-29`).
- **Separate "how long is it" from "do it"**: `EncodedLen`/`DecodedLen` as pure
  `fn` used to size a buffer maps cleanly to Mojo's explicit buffer sizing;
  `var`/`borrowed` can express "borrow dst mutably, borrow src immutably" exactly
  like `Encode(dst, src)`.
- **`Append*` as the incremental primitive**: `AppendEncode`/`AppendDecode`
  returning an extended buffer is a good model for an explicit-buffer Mojo API;
  no hidden global state (`:190-195`, `:406-412`).
- **Uniform radix API**: one naming scheme across base16/32/64 (Go's
  base64/base32 similarity) matches the "predictable, consistent" goal in
  `AGENTS.md`; Mojo could use compile-time radix parameters (`comptime`/`alias`)
  to unify them without Go's code duplication.
- **Partial result on error**: returning the successfully decoded prefix
  alongside an error (`:396-400`) is expressible as an error plus an out-parameter
  count, and matters for recovery.
- **Streaming carry state as a plain struct**: `encoder.buf [5]byte` /
  `decoder.buf [1024]byte` show the minimal leftover state an incremental
  encoder/decoder needs — for base32 it is a 5-byte (not 3-byte) carry; a Mojo
  `struct` with a fixed array and a count is a natural translation
  (`:204-211`, `:435-446`).
- **Padding-mode-aware length function**: `EncodedLen` already encodes the
  padded/unpadded distinction (`:275-286`); expose `encoded_length(n, padded)`
  as a compile-time-specialised pure function.
- **An explicit `canonical`/`strict` option** that Go lacks — the RFC 4648 §3.5
  trailing-bit check should be a first-class, documented choice.
- **Explicit case policy** (`Upper`/`Lower`/`Mixed`) so lowercase decode is a
  visible, opt-in decision rather than impossible (Go) or blanket-folded (Perl's
  always-on `uc()`; Elixir and Python offer explicit case options — `elixir.md`
  §7, `python.md` §7).

## Sources

- Go stdlib source, `encoding/base32`:
  https://raw.githubusercontent.com/golang/go/master/src/encoding/base32/base32.go
  (line numbers cited inline)
- Go `encoding/base32` docs: https://pkg.go.dev/encoding/base32
- `segmentio/asm` (base64/SIMD family; base32 sibling):
  https://github.com/segmentio/asm ;
  license https://github.com/segmentio/asm/blob/main/LICENSE
- `cristalhq/base64`: https://github.com/cristalhq/base64
- `segmentio/encoding` (sibling repo, json/iso8601 focus):
  https://github.com/segmentio/encoding
- RFC 4648, The Base16, Base32, and Base64 Data Encodings:
  https://www.rfc-editor.org/rfc/rfc4648.txt
- Mojo side (not researched here): `mojov1` buch `stdlib/base64`
