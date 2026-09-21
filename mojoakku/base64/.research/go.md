# base64 research: Go

## 1. Standard library support

Go's standard library has dedicated packages for all three codecs:

- `encoding/base64` — "Package base64 implements base64 encoding as specified by RFC 4648" (`encoding/base64/base64.go:7`).
- `encoding/base32` — "Package base32 implements base32 encoding as specified by RFC 4648" (`encoding/base32/base32.go:7`), with both the standard alphabet and the "Extended Hex Alphabet" used in DNSSEC (`encoding/base32/base32.go:21`, `:92`).
- `encoding/hex` — hexadecimal (base16); "Package hex implements hexadecimal encoding and decoding" (`encoding/hex/hex.go:7`).

There is no base16 package name: base16 is called **hex** in Go. Encode output is fixed lowercase (`encoding/hex/hex.go:17`), while `reverseHexTable` accepts both upper- and lower-case digits on decode (the table maps `A`..`F` at `encoding/hex/hex.go:22-23` and `a`..`f` at `:27-28`, both to 10..15).

All three are standard library, BSD-3-Clause; `encoding/base64` showed "Imported by: 244,270" at time of access (https://pkg.go.dev/encoding/base64).

## 2. Relevant community libraries

- **`github.com/segmentio/asm/base64`** — "standard library compatible base64 encodings", part of the `segmentio/asm` package family; license MIT No Attribution (MIT-0) (https://github.com/segmentio/asm, https://github.com/segmentio/asm/blob/main/LICENSE). Its `NewEncoding` panics on "non-standard encoding alphabets" and only allows `+/`, `-_` and `+,` (IMAP) (`segmentio/asm/base64/base64.go`). This is a real design difference from the stdlib, which accepts any unique 64-byte alphabet (`encoding/base64/base64.go:65`).
- **`github.com/cristalhq/base64`** — "Faster base64 encoding for Go, based on Turbo-Base64. Drop-in replacement of `encoding/base64`" with the caveat "except for error messages and ignoring `\r` and `\n` in decoder"; MIT license (https://github.com/cristalhq/base64, https://github.com/cristalhq/base64/blob/main/LICENSE).
- **`github.com/segmentio/encoding`** — sibling repo focused on `json`/`iso8601`; the base64 work lives in `segmentio/asm` (https://github.com/segmentio/encoding). No distinct base64 API there.
(Assessment: derived from the stdlib docs and the three repository READMEs above.)

## 3. Exposed APIs

`encoding/base64` (line numbers in `encoding/base64/base64.go`):

- `type Encoding struct { encode [64]byte; decodeMap [256]uint8; padChar rune; strict bool }` (`:25-30`).
- Constants `StdPadding rune = '='`, `NoPadding rune = -1` (`:33-36`).
- `NewEncoding(encoder string) *Encoding` — 64 unique bytes, no padding char, no CR/LF; panics otherwise (`:65`).
- `Encoding.WithPadding(padding rune) *Encoding` (`:97`); `Encoding.Strict() *Encoding` — requires trailing padding bits to be zero (`:114`).
- Package vars: `StdEncoding` (padded, `+/`) (`:120`), `URLEncoding` (padded, `-_`) (`:124`), `RawStdEncoding` (unpadded) (`:129`), `RawURLEncoding` (unpadded) (`:134`).
- `Encode(dst, src []byte)` (`:146`), `AppendEncode(dst, src []byte) []byte` (`:194`), `EncodeToString(src []byte) string` (`:202`), `EncodedLen(n int) int` (`:288`).
- `Decode(dst, src []byte) (int, error)` (`:548`), `AppendDecode(dst, src []byte) ([]byte, error)` (`:417`), `DecodeString(s string) ([]byte, error)` (`:433`), `DecodedLen(n int) int` (`:684`).
- `NewEncoder(enc *Encoding, w io.Writer) io.WriteCloser` (`:280`), `NewDecoder(enc *Encoding, r io.Reader) io.Reader` (`:678`).
- `type CorruptInputError int64` (`:305`).

`encoding/base32` mirrors this exactly, except no `Strict` and two package vars: `StdEncoding` (`A-Z2-7`) (`:88`) and `HexEncoding` (`0-9A-V`) (`:92`); plus `AppendEncode` (`:190`), `DecodeString` (`:428`), `NewEncoder` (`:277`), `NewDecoder` (`:579`).

`encoding/hex` uses a flat, function-based API rather than an `Encoding` type: `EncodedLen` (`:39`), `Encode(dst, src) int` (`:45`), `AppendEncode` (`:57`), `EncodeToString` (`:126`), `DecodedLen` (`:78`), `Decode(dst, src) (int, error)` (`:87`), `AppendDecode` (`:118`), `DecodeString` (`:138`), `NewEncoder(w) io.Writer` (`:173`), `NewDecoder(r) io.Reader` (`:202`). There is no alphabet knob — hex is always `0123456789abcdef` on encode.

(Line numbers from https://raw.githubusercontent.com/golang/go/master/src/encoding/... as cited; API summaries likewise on https://pkg.go.dev/encoding/base64.)

## 4. Error representation

Go uses **sentinel/typed error values**, not exceptions.

- base64 decode errors are `CorruptInputError` (an `int64` carrying the input byte offset); `Error()` renders "illegal base64 data at input byte N" (`encoding/base64/base64.go:305-308`). base32 has the analogous type and message "illegal base32 data at input byte N" (`encoding/base32/base32.go:302-305`).
- `Decode`/`DecodeString` return **partial output plus the error**: "it will return the number of bytes successfully written and CorruptInputError" (`encoding/base64/base64.go:548-556`; also pkg.go.dev).
- hex has two explicit errors: `ErrLength = errors.New("encoding/hex: odd length hex string")` (`encoding/hex/hex.go:67`) and `type InvalidByteError byte` rendering "encoding/hex: invalid byte: %#U" (`encoding/hex/hex.go:70-73`). `InvalidByteError` is checked *before* the odd-length check so the earlier problem wins (`encoding/hex/hex.go:110-116`).
- The encode side produces no in-memory errors; the streaming encoder only surfaces underlying `io.Writer` errors (`encoding/base64/base64.go:217-263`).

## 5. Ownership semantics (buffer/ownership of encode input and produced output)

Go is garbage-collected and uses `[]byte` slices; there is no ownership transfer in the Rust/RAII sense.

- `Encode(dst, src []byte)` and `Decode(dst, src []byte)` write into a **caller-provided destination** and return only a count; the caller sizes `dst` via `EncodedLen`/`DecodedLen` (`encoding/base64/base64.go:146-153`, `:548-557`). No allocation for the result buffer inside `Encode`.
- `EncodeToString` allocates a fresh `make([]byte, EncodedLen)` and converts to `string` (`encoding/base64/base64.go:202-206`); `AppendEncode` grows the caller's dst with `slices.Grow` and returns the extended slice (`:194-199`).
- `DecodeString` allocates `make([]byte, DecodedLen)` and returns the `dbuf[:n]` re-slice (`encoding/base64/base64.go:433-437`).
- The streaming `encoder` owns leftover input `buf [3]byte` (`nbuf`) and output staging `out [1024]byte` (`encoding/base64/base64.go:208-215`); the streaming `decoder` owns `buf [1024]byte`, a leftover decoded-output slice `out []byte`, and `outbuf [1024/4*3]byte` (`:439-452`).
- base32's streaming encoder owns `buf [5]byte` instead (`encoding/base32/base32.go:204-211`).
(Assessment: derived from the quoted source lines.)

## 6. Blocking / non-blocking

Not applicable to the codec itself: encode/decode are pure in-memory transformations with no I/O and no concurrency primitives. The only I/O-aware surface is `NewEncoder`/`NewDecoder`, synchronous/blocking `io.Writer`/`io.Reader` wrappers by contract; the decoder reads from the wrapped reader inside `Read` (`encoding/base64/base64.go:461-...`). Go's concurrency model is goroutine-based, not `async`/`await`; an async caller wraps the blocking reader/writer in a goroutine. No async variant exists in the stdlib.

## 7. Alphabet variants and padding

- base64 exposes four presets: `StdEncoding` (`ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/`), `URLEncoding` (`...-_`), and the unpadded `RawStdEncoding`/`RawURLEncoding` (`encoding/base64/base64.go:120-134`).
- Arbitrary custom alphabets via `NewEncoding(string)` for any 64 unique bytes; `WithPadding(rune)` sets any pad byte or `NoPadding` (`rune = -1`) (`encoding/base64/base64.go:65`, `:97`).
- `Strict()` toggles rejection of non-zero trailing bits per RFC 4648 §3.5 — the default decoder is lenient about them (`encoding/base64/base64.go:114-118`).
- base32 has only `StdEncoding` and `HexEncoding` (Extended Hex) plus `WithPadding`; it has **no** `Strict` (`encoding/base32/base32.go:88`, `:92`, `:101`).
- base16/hex has no alphabet variants; encode output is fixed lowercase (`encoding/hex/hex.go:17`), decode accepts both cases (`:22-28`).
- Newline handling: base64/base32 decoders ignore `\r` and `\n` unconditionally, even in `Strict` mode — "the input is still malleable, as new line characters (CR and LF) are still ignored" (`encoding/base64/base64.go:114-118`, `:548-556`), implemented by `newlineFilteringReader`/`stripNewlines` (`encoding/base64/base64.go:656-676`, `encoding/base32/base32.go:552-577`).

## 8. Timeouts

Not applicable: the packages have no timeout or cancellation concept. There is no `context.Context` parameter anywhere in `encoding/base64`, `encoding/base32` or `encoding/hex`; cancellation must happen at the `io.Reader`/`io.Writer` layer, because the stream wrappers only propagate the delegate's error (`encoding/base64/base64.go:217-263`, `:461-...`). (Assessment: derived from the API surface quoted above; no timeout symbol exists in the sources.)

## 9. Streaming / incremental encode+decode and leftover-byte carry

- **Block functions are explicitly not streaming**: `Encode` "pads the output to a multiple of 4 bytes, so Encode is not appropriate for use on individual blocks of a large data stream. Use NewEncoder instead" (`encoding/base64/base64.go:146-150`; base32 says 8-byte blocks, `encoding/base32/base32.go:122-127`).
- `NewEncoder` returns an `io.WriteCloser`; `Write` carries leftover input in `buf [3]byte` (`nbuf`), flushing only when 3 (base32: 5) bytes accumulate, and **`Close` must be called to flush the final partial block** (`encoding/base64/base64.go:208-280`; doc example `encoding/base64/example_test.go`: "Must close the encoder ... If you comment out the following line, the last partial block 'r' won't be encoded").
- `NewDecoder` returns an `io.Reader`; `Read` keeps leftover encoded input in `buf [1024]byte` (`nbuf`) and leftover **decoded** output in `out []byte`, returning buffered bytes on the next call before touching the delegate (`encoding/base64/base64.go:439-547`). base32's decoder additionally distinguishes padded vs unpadded via `readEncodedData(..., min, expectsPadding)` and an `end` flag (`encoding/base32/base32.go:435-550`).
- base64's decoder marks `end` after a padded group and rejects any further non-empty input (`encoding/base64/base64.go:439-547`); base32's `decode` returns an `end` bool for the same purpose (`encoding/base32/base32.go:312-399`).
- hex streams symmetrically: `NewEncoder` buffers a 1024-byte output array (`encoding/hex/hex.go:166-191`); `NewDecoder` buffers input in `in []byte`/`arr [bufferSize]byte` and returns `io.ErrUnexpectedEOF` for a trailing odd byte (`encoding/hex/hex.go:193-240`, `:67`).
- At the whole-buffer level, the `Append*` family is the incremental building block: append to a growing buffer, no internal state (`encoding/base64/base64.go:194-199`, `:417-431`).

## 10. Interesting design decisions

- **Alphabet as a first-class value, not an enum**: `Encoding` carries `encode[64]` and `decodeMap[256]` lookup tables built once by `NewEncoding`, so hot loops index arrays instead of branching (`encoding/base64/base64.go:25-30`, `:65-88`). base32 does the same with 32-byte tables (`encoding/base32/base32.go:23-29`).
- **Leniency is the default, strictness is opt-in**: `Strict()` must be explicitly requested; `\r`/`\n` are always ignored (`encoding/base64/base64.go:114-118`).
- **Same package shape across radices**: base64 and base32 share the identical naming (`StdEncoding`, `WithPadding`, `Encode`, `AppendEncode`, `EncodeToString`, `NewEncoder`, `CorruptInputError`, `EncodedLen`/`DecodedLen`), making the family easy to learn (`encoding/base64/base64.go`, `encoding/base32/base32.go`).
- **Flat stateless API for hex**: hex deliberately avoids an `Encoding` type — `Encode`/`Decode` are package functions (`encoding/hex/hex.go:39-145`), because base16 has no alphabet/padding choice.
- **Partial output on error**: decode never discards what it already decoded; it returns `n` bytes plus the error, which matters for error recovery (`encoding/base64/base64.go:548-557`, `encoding/hex/hex.go:83-116`).
- **`end`/padding sentinel in the streaming decoder**: a padded group terminates the logical stream, so post-padding garbage is detected even across `Read` calls (`encoding/base64/base64.go:439-547`, `encoding/base32/base32.go:312-399`).
- **Partial in-place decode**: base32's `DecodeString` decodes into the caller's own input buffer (`n, _, err := enc.decode(buf, buf[:l])`) (`encoding/base32/base32.go:428-433`), a small memory optimisation.
- **Allocation-free hot path**: `Encode`/`Decode` write into user buffers with no allocation; only the convenience `...ToString` variants allocate (`encoding/base64/base64.go:146-206`).

## 11. Decisions NOT to copy

- **Implicit newline ignoring**: base64/base32 silently skip `\r`/`\n` even under `Strict()`. A predictable API should make whitespace tolerance explicit, not implicit (`encoding/base64/base64.go:114-118`).
- **`panic` for invalid configuration**: `NewEncoding` panics on a wrong-length/duplicate alphabet and `WithPadding` panics on bad padding (`encoding/base64/base64.go:65-107`). Prefer a compile-time or `raises`-style error over a runtime panic.
- **`rune`-typed padding (`NoPadding = -1`)**: the magic negative rune (`encoding/base64/base64.go:36`) is a Go-idiomatic sentinel; model padding as an explicit option instead.
- **Mutable global `Encoding` vars**: `StdEncoding` etc. are package `var`s (`encoding/base64/base64.go:120-134`), i.e. mutable global state; alphabets should be compile-time constants or values.
- **Different package names for the same concept**: base16 is `hex`, while base64/base32 are separate packages with near-duplicated code. The flat sibling-library layout can share a radix core instead.
- **No `context`/cancellation seam**: the streaming wrappers cannot be cancelled except through the delegate — not a pattern to replicate for a predictable API (Assessment: derived from `encoding/base64/base64.go` API surface).

## 12. Ideas fitting Mojo

- **Lookup-table Encoding value**: the `encode[64]`/`decodeMap[256]` pair built once fits a Mojo `struct` with fixed-size arrays and value semantics (`encoding/base64/base64.go:25-30`).
- **Separate "how long is it" from "do it"**: `EncodedLen`/`DecodedLen` as pure `fn` used to size a buffer maps cleanly to Mojo's explicit buffer sizing; `var`/`borrowed` can express "borrow dst mutably, borrow src immutably" exactly like `Encode(dst, src)`.
- **`Append*` as the incremental primitive**: `AppendEncode`/`AppendDecode` returning an extended buffer is a good model for an explicit-buffer Mojo API; no hidden global state.
- **Strictness as an explicit option, not the default**: the `Strict()`/`WithPadding()` pattern shows how to encode canonical-vs-permissive decoding as a value flag — a good fit for a Mojo `alias`/enum parameter.
- **Uniform radix API**: one naming scheme across base16/32/64 (Go's base64/base32 similarity) matches the "predictable, consistent" goal in `AGENTS.md`; Mojo could use compile-time radix parameters (`comptime`/`alias`) to unify them without Go's code duplication.
- **Partial result on error**: returning the successfully decoded prefix alongside an error (`encoding/base64/base64.go:548-557`) is expressible as an error plus an out-parameter count, and matters for recovery.
- **Streaming carry state as a plain struct**: `encoder.buf [3]byte` / `decoder.buf [1024]byte` show the minimal leftover state an incremental encoder/decoder needs; a Mojo `struct` with a fixed array and a count is a natural translation (`encoding/base64/base64.go:208-215`, `:439-452`).

## Sources

- Go stdlib source, `encoding/base64`: https://raw.githubusercontent.com/golang/go/master/src/encoding/base64/base64.go (line numbers cited inline)
- Go stdlib source, `encoding/base32`: https://raw.githubusercontent.com/golang/go/master/src/encoding/base32/base32.go
- Go stdlib source, `encoding/hex`: https://raw.githubusercontent.com/golang/go/master/src/encoding/hex/hex.go
- Go stdlib example tests: https://raw.githubusercontent.com/golang/go/master/src/encoding/base64/example_test.go
- `encoding/base64` docs: https://pkg.go.dev/encoding/base64
- `segmentio/asm` (base64 + SIMD): https://github.com/segmentio/asm ; source https://raw.githubusercontent.com/segmentio/asm/main/base64/base64.go ; license https://github.com/segmentio/asm/blob/main/LICENSE
- `segmentio/encoding` (sibling repo, json/iso8601 focus): https://github.com/segmentio/encoding
- `cristalhq/base64`: https://github.com/cristalhq/base64 ; license https://github.com/cristalhq/base64/blob/main/LICENSE
- RFC 4648 (referenced by all three packages): https://datatracker.ietf.org/doc/html/rfc4648
