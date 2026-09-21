# base64 research: Go

Scope: this file answers the standardized 12-question set from
`.agents/workflows/NewLibPhase1Research.md` for the `base64` library in Go.
Questions 5, 7 and 9 were adapted to the base64/base32 domain (buffer ownership,
alphabets/padding, streaming) as the task requires. RFC 4648 is the shared
normative reference.

## 1. Standard library support

Go covers base64, base32 and base16 (hex) in the standard library; no third-party
dependency is needed for the core functionality.

- `encoding/base64` — "Package base64 implements base64 encoding as specified by
  RFC 4648." Version go1.27.1, license BSD-3-Clause, 244,270 known importers.
  Source: <https://pkg.go.dev/encoding/base64> (Overview).
- `encoding/base32` — "Package base32 implements base32 encoding as specified by
  RFC 4648." Version go1.27.1, BSD-3-Clause, 9,623 importers.
  Source: <https://pkg.go.dev/encoding/base32>.
- `encoding/hex` — "Package hex implements hexadecimal encoding and decoding."
  Version go1.27.1, BSD-3-Clause, 248,450 importers.
  Source: <https://pkg.go.dev/encoding/hex>.

The `base64.Encoding` doc names the three RFCs it descends from: RFC 4648 (base64),
RFC 2045 (MIME) and RFC 1421 (PEM). Source: <https://pkg.go.dev/encoding/base64>
(type Encoding). base32 additionally documents the "Extended Hex Alphabet" used in
DNS/DNSSEC. Source: <https://pkg.go.dev/encoding/base32#HexEncoding>.

Base32 has two predefined alphabets in the stdlib (line anchors are the "View
Source" links on the package page):
- `StdEncoding = NewEncoding("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")` — base32.go;l=87
- `HexEncoding = NewEncoding("0123456789ABCDEFGHIJKLMNOPQRSTUV")` — the RFC 4648
  "Extended Hex Alphabet", "typically used in DNS" — base32.go;l=91
  Source: <https://pkg.go.dev/encoding/base32>.

The stdlib explicitly separates payload encoding from transport framing: no
line-wrapping is added. RFC 4648 requires this: "Implementations MUST NOT add line
feeds to base-encoded data unless the specification referring to this document
explicitly directs base encoders to add line feeds after a specific number of
characters." Source: RFC 4648 §3.1, <https://www.rfc-editor.org/rfc/rfc4648.txt>.

## 2. Relevant community libraries

All four libraries below are drop-in-ish fast paths; they exist because the stdlib
scalar implementation is not SIMD-accelerated.

| Library | Maintainer / owner | License | Maturity signal | Source |
|---|---|---|---|---|
| `github.com/cristalhq/base64` | cristalhq | MIT | 185 stars, 30 commits, dependency-free, fuzz dir present | <https://github.com/cristalhq/base64> |
| `github.com/segmentio/asm/base64` | segmentio | MIT-0 | v1.2.1 (Nov 2023), 28 importers; the module has 742 stars overall | <https://pkg.go.dev/github.com/segmentio/asm/base64>, <https://github.com/segmentio/asm> |
| `github.com/go-simd/base64` | go-simd | BSD-3-Clause | pseudoversion v0.0.0-...-8662cdc (8 Sep 2026), untagged, "100% coverage" claim | <https://pkg.go.dev/github.com/go-simd/base64> |
| `github.com/emmansun/base64` | emmansun | BSD-3-Clause | 16 stars, 277 commits, CI for arm64/ppc64le/s390x/loong64/riscv64 | <https://github.com/emmansun/base64> |

Two non-Go references are the acknowledged source of the Go SIMD kernels:
- `aklomp/base64` — "Fast Base64 stream encoder/decoder in C99, with SIMD
  acceleration"; BSD-2-Clause; 1k stars; "Does not dynamically allocate memory";
  "Re-entrant and threadsafe". Source: <https://github.com/aklomp/base64>.
- `WojciechMula/base64simd` — the AVX2/AVX512 reference implementation, cited by
  both aklomp and emmansun. Sources: <https://github.com/emmansun/base64> (README,
  Acknowledgements), <https://github.com/aklomp/base64> (README,
  Acknowledgements).

Stated accuracy positions (these matter for correctness, not only speed):
- `cristalhq/base64`: "Drop-in replacement of `encoding/base64`. — *except for
  error messages and ignoring `\r` and `\n` in decoder.*" Source:
  <https://github.com/cristalhq/base64> (README, Features).
- `go-simd/base64`: "byte- AND error-identical to `encoding/base64` ... so the
  output and every `CorruptInputError` offset match exactly." Source:
  <https://pkg.go.dev/github.com/go-simd/base64> (README).
- `emmansun/base64`: "This package keeps the same public API and behavior as Go's
  standard `encoding/base64`". Source: <https://github.com/emmansun/base64>
  (README, Overview).
- `segmentio/asm/base64` restricts custom alphabets: "Unlike the standard library,
  the encoding alphabet cannot be abitrary, and it must follow one of the know
  standard encoding variants." (typo in the original) Source:
  <https://pkg.go.dev/github.com/segmentio/asm/base64#NewEncoding>.

## 3. Exposed APIs

### 3.1 `encoding/base64` — in-memory (one-shot)

Constants:
- `StdPadding rune = '='` — "Standard padding character" — base64.go;l=31
- `NoPadding  rune = -1` — "No padding" — base64.go;l=31

Variables (preconfigured encodings):
- `StdEncoding` = `NewEncoding("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")` — base64.go;l=119
- `URLEncoding` = `NewEncoding("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")` — base64.go;l=123
- `RawStdEncoding = StdEncoding.WithPadding(NoPadding)` — base64.go;l=128
- `RawURLEncoding = URLEncoding.WithPadding(NoPadding)` — base64.go;l=133

Type `Encoding` (base64.go;l=24) methods:
- `func NewEncoding(encoder string) *Encoding` — base64.go;l=64
- `func (enc *Encoding) Encode(dst, src []byte)` — base64.go;l=145
- `func (enc *Encoding) EncodeToString(src []byte) string` — base64.go;l=201
- `func (enc *Encoding) AppendEncode(dst, src []byte) []byte` (go1.22) — base64.go;l=193
- `func (enc *Encoding) Decode(dst, src []byte) (n int, err error)` — base64.go;l=513
- `func (enc *Encoding) DecodeString(s string) ([]byte, error)` — base64.go;l=424
- `func (enc *Encoding) AppendDecode(dst, src []byte) ([]byte, error)` (go1.22) — base64.go;l=408
- `func (enc *Encoding) EncodedLen(n int) int` — base64.go;l=285
- `func (enc *Encoding) DecodedLen(n int) int` — base64.go;l=649
- `func (enc Encoding) Strict() *Encoding` (go1.8) — base64.go;l=113
- `func (enc Encoding) WithPadding(padding rune) *Encoding` (go1.5) — base64.go;l=96

Stream functions:
- `func NewEncoder(enc *Encoding, w io.Writer) io.WriteCloser` — base64.go;l=279
- `func NewDecoder(enc *Encoding, r io.Reader) io.Reader` — base64.go;l=643

Errors:
- `type CorruptInputError int64` — base64.go;l=296
- `func (e CorruptInputError) Error() string` — base64.go;l=298

(All line anchors above are the "View Source" links on
<https://pkg.go.dev/encoding/base64>.)

### 3.2 `encoding/base32` — same shape

Identical API surface, with the quantum changed from 3/4 bytes to 5/8 bytes.
Line anchors: `StdPadding`/`NoPadding` base32.go;l=28, `Encoding` l=22,
`NewEncoding` l=61, `WithPadding` l=100 (go1.9), `Encode` l=121, `EncodeToString`
l=197, `AppendEncode` l=189, `Decode` l=392, `DecodeString` l=419, `AppendDecode`
l=403, `EncodedLen` l=282, `DecodedLen` l=576, `NewEncoder` l=276, `NewDecoder`
l=570, `CorruptInputError` l=293. Source: <https://pkg.go.dev/encoding/base32>.

### 3.3 `encoding/hex` — package-level functions, no Encoding type

- `func Encode(dst, src []byte) int` — hex.go;l=45
- `func EncodeToString(src []byte) string` — hex.go;l=126
- `func AppendEncode(dst, src []byte) []byte` (go1.22) — hex.go;l=57
- `func Decode(dst, src []byte) (int, error)` — hex.go;l=87
- `func DecodeString(s string) ([]byte, error)` — hex.go;l=138
- `func AppendDecode(dst, src []byte) ([]byte, error)` (go1.22) — hex.go;l=118
- `func EncodedLen(n int) int` (returns n*2) — hex.go;l=39
- `func DecodedLen(x int) int` (returns x/2) — hex.go;l=78
- `func Dump(data []byte) string` — hex.go;l=146
- `func Dumper(w io.Writer) io.WriteCloser` — hex.go;l=242
- `func NewEncoder(w io.Writer) io.Writer` (go1.10) — hex.go;l=173
- `func NewDecoder(r io.Reader) io.Reader` (go1.10) — hex.go;l=202
- `var ErrLength = errors.New("encoding/hex: odd length hex string")` — hex.go;l=67
- `type InvalidByteError byte` — hex.go;l=70

Source: <https://pkg.go.dev/encoding/hex>.

Notable API-shape difference: hex is package-level (no alphabet object, no config);
base64/base32 are instance-based (`*Encoding` carries alphabet + padding + strict).

## 4. Error representation

Go uses out-of-band error values and interfaces here; there are no exceptions.

- **base64/base32 invalid input**: a concrete value, not a package sentinel:
  `type CorruptInputError int64`; the message is built as
  `"illegal base64 data at input byte " + strconv.FormatInt(int64(e), 10)`.
  So the error carries the **byte offset** of the failure. Sources:
  <https://pkg.go.dev/encoding/base64>, and the master source
  <https://raw.githubusercontent.com/golang/go/master/src/encoding/base64/base64.go>.
  base32 uses the same type and message shape. Source:
  <https://pkg.go.dev/encoding/base32>.
- **Partial results are returned alongside the error**, not discarded: `Decode`
  "will return the number of bytes successfully written and CorruptInputError";
  `DecodeString` "returns the partially decoded data and CorruptInputError";
  `AppendDecode` "If the input is malformed, it returns the partially decoded src
  and an error". Sources: <https://pkg.go.dev/encoding/base64> (Encoding.Decode,
  Encoding.DecodeString, Encoding.AppendDecode).
- **hex invalid input**: `InvalidByteError` (value = offending byte) for a bad
  character; the exported sentinel `ErrLength` for odd-length input. Source:
  <https://pkg.go.dev/encoding/hex>.
- **Stream decoder is stricter than the one-shot decoder**: "The stream-based
  Decoder returns io.ErrUnexpectedEOF instead of ErrLength." Source:
  <https://pkg.go.dev/encoding/hex#ErrLength>. For base64 the stream decoder does
  the same internally: when a short final block remains and the reader returned
  `io.EOF`, it substitutes `io.ErrUnexpectedEOF` (master source, `decoder.Read`).
- **Offset rebasing in the stream decoder**: a `CorruptInputError` produced inside
  the 1024-byte buffer is shifted to a whole-stream offset via
  `CorruptInputError(int64(e) + d.total)` (master source, `rebaseError`).
- **Encoding has no error path at all**: `Encode` returns nothing; there is only an
  internal overflow panic. `EncodedLen` "panics if the encoded length overflows
  int" (master source doc comment).

Design consequence: errors are data, offsets are part of the contract, and callers
are expected to inspect the partially written prefix. This is a meaningfully
different stance from Rust, where decoded data and error are mutually exclusive
(`Result<Vec<u8>, DecodeError>`).

## 5. Ownership semantics (adapted Q5: buffer/ownership of encode input and output)

- **The caller owns every buffer.** `Encode(dst, src []byte)` writes
  `EncodedLen(len(src))` bytes into a caller-provided `dst`; `Decode(dst, src)`
  writes at most `DecodedLen(len(src))` bytes into `dst` and returns how many.
  "The caller must ensure that dst is large enough to hold all the decoded data."
  Sources: <https://pkg.go.dev/encoding/base64> (Encoding.Encode, Encoding.Decode).
- **The convenience functions allocate and transfer ownership to the caller**:
  `EncodeToString` allocates a `[]byte` of `EncodedLen(len(src))` and returns a
  `string`; `DecodeString` allocates a `[]byte` of `DecodedLen(len(s))` and returns
  `dbuf[:n]` — the returned slice is a reslice of a larger allocation (master
  source, `DecodeString`). Allocation is explicit in the function name, not hidden.
- **Append variants avoid reallocation churn**: `AppendEncode` calls
  `slices.Grow(dst, n)` and then encodes in place at the tail (master source). This
  is the idiomatic Go answer to "do not allocate a new buffer per call".
- **Length arithmetic is the caller's responsibility**: `EncodedLen`/`DecodedLen`
  must be called before `Encode`/`Decode`. `DecodedLen` is documented as the
  *maximum* decoded length; in the source, padded input gives `n / 4 * 3` and
  `NoPadding` gives `n/4*3 + n%4*6/8` (master source, `decodedLen`).
- **Input slices are never mutated.** Encode/decode read `src` read-only.
- **In-place decoding is possible in one specific layout.** `go-simd/base64`
  documents and tests it: "Decode may be used in place: dst and src may share the
  same backing array as long as &dst[0] == &src[0] (dst a prefix of src). ...
  Decoding consumes four input bytes per three output bytes and never reads a byte
  after overwriting it, so the write cursor always trails the read cursor."
  Source: <https://pkg.go.dev/github.com/go-simd/base64#Encoding.Decode>. This is a
  documented property of that library only; the stdlib does not promise it.
  `GUESS:` the stdlib decoder also satisfies it because it processes strictly
  forward, but the stdlib does not document it and the `Encoding.Decode` contract
  does not forbid a future reordering — so MojoAkku should not rely on it.
- **Alphabets are immutable values.** `NewEncoding` copies the 64-byte alphabet
  into a fixed `[64]byte` and precomputes a `[256]uint8` decode map (master source,
  `type Encoding`). `WithPadding`/`Strict` have *value* receivers and return a *new*
  `*Encoding`; the original is not modified.
- **Encoding objects are safe for concurrent read-only use by construction**: all
  fields are set at construction and never mutated afterwards; the package has no
  global mutable state. `GUESS:` the stdlib does not state thread-safety
  explicitly, but the value-receiver design plus immutable fields make concurrent
  read-only use safe. For the C family it is explicit: `aklomp/base64` is
  documented "Re-entrant and threadsafe". Source: <https://github.com/aklomp/base64>.
- **The stream encoder owns a 3-byte carry buffer and a 1024-byte output buffer**
  (`type encoder struct { buf [3]byte; nbuf int; out [1024]byte }`); the stream
  decoder owns a 1024-byte input buffer plus a 768-byte output buffer (`type
  decoder struct { buf [1024]byte; outbuf [1024/4*3]byte }`). Both are embedded
  arrays, so the stream wrappers do not heap-allocate. Source: master
  <https://raw.githubusercontent.com/golang/go/master/src/encoding/base64/base64.go>.

## 6. Blocking / non-blocking

- **The in-memory API is purely synchronous and CPU-bound**; there is no async
  variant and no I/O.
- **The streaming API is synchronous blocking I/O** over `io.Reader`/`io.Writer`.
  `NewDecoder(enc, r)` returns an `io.Reader` whose `Read` calls `r.Read`;
  `NewEncoder(enc, w)` returns an `io.WriteCloser` whose `Write` calls `w.Write`.
  Sources: <https://pkg.go.dev/encoding/base64> (NewDecoder, NewEncoder), and the
  master source.
- **Concurrency is not the library's concern.** Go's model is synchronous
  blocking calls plus goroutines; the encoder/decoder objects are not internally
  locked. Cancellation is done by the caller (closing the underlying
  reader/writer, or a caller-side `context`); the base64 package participates in no
  cancellation protocol.
- Contrast for the research record: the SIMD community libraries stay
  single-threaded and rely on the Go scheduler; `aklomp/base64` (C) is the outlier
  offering optional OpenMP parallelism ("Can use OpenMP for even more parallel
  speedups"). Source: <https://github.com/aklomp/base64>.

## 7. Alphabet variants and padding (adapted Q7: std vs URL-safe, padding handling)

### 7.1 Alphabets

Go builds an encoding from the alphabet string itself; the "variant" is just which
64-character string is passed to `NewEncoding`.

- Standard (RFC 4648 §4): `A-Z a-z 0-9 + /` — base64.go;l=119
- URL/filename-safe (RFC 4648 §5): `A-Z a-z 0-9 - _` — base64.go;l=123
- base32 standard: `A-Z 2-7` — base32.go;l=87
- base32 extended-hex (RFC 4648 §7): `0-9 A-V` — base32.go;l=91

RFC 4648 warns against conflating the variants: "This encoding should not be
regarded as the same as the 'base64' encoding and should not be referred to as only
'base64'." (§5) and "This encoding should not be regarded as the same as the
'base32' encoding" (§7). Source:
<https://www.rfc-editor.org/rfc/rfc4648.txt>.

`NewEncoding` validates the alphabet and panics on
`"encoding alphabet is not 64-bytes long"`, on
`"encoding alphabet contains newline character"`, and on
`"encoding alphabet includes duplicate symbols"` (master source). It does **not**
reject the padding character; the source comments: "While we document that the
alphabet cannot contain the padding character, we do not enforce it since we do not
know if the caller intends to switch the padding from StdPadding later." (master
source).

`segmentio/asm/base64` deliberately narrows this: only RFC 4648/1421/2045/2152/4880
(`+ /`), RFC 4648 URI (`- _`) and RFC 3501 (`+ ,`) are accepted. Source:
<https://pkg.go.dev/github.com/segmentio/asm/base64#NewEncoding>.

### 7.2 Padding

- Padding is a character, and "no padding" is expressed as a sentinel rune:
  `StdPadding rune = '='`, `NoPadding rune = -1` — base64.go;l=31.
- `WithPadding(padding rune)` "creates a new encoding identical to enc except with a
  specified padding character, or NoPadding to disable padding. The padding
  character must not be '\r' or '\n', must not be contained in the encoding's
  alphabet, must not be negative, and must be a rune equal or below '\xff'.
  Padding characters above '\x7f' are encoded as their exact byte value rather than
  using the UTF-8 representation of the codepoint." It **panics** on
  `"invalid padding"` or `"padding contained in alphabet"`. Sources:
  <https://pkg.go.dev/encoding/base64#Encoding.WithPadding>, master source.
- Four presets therefore exist: padded/unpadded crossed with standard/URL-safe
  (see 3.1). There is **no "accept either" decode mode**: Go has no
  `Indifferent`-style padding policy, unpadded input to a padded encoding is an
  error, and padded input to `Raw*` is trailing garbage.
- RFC 4648 mandates padding by default: "Implementations MUST include appropriate
  pad characters at the end of encoded data unless the specification referring to
  this document explicitly states otherwise." (RFC 4648 §3.2).

### 7.3 Canonical encoding / trailing bits

`Strict()` "creates a new encoding identical to enc except with strict decoding
enabled. In this mode, the decoder requires that trailing padding bits are zero, as
described in RFC 4648 section 3.5. Note that the input is still malleable, as new
line characters (CR and LF) are still ignored." Source:
<https://pkg.go.dev/encoding/base64#Encoding.Strict>. In the source, strictness is
checked in the 2- and 3-symbol final cases with explicit zero tests (master source,
`decodeQuantum`).

RFC 4648 §3.5 explains why this matters: "These pad bits MUST be set to zero by
conforming encoders ... If this property do not hold, there is no canonical
representation of base-encoded data, and multiple base-encoded strings can be
decoded to the same binary data. ... decoders MAY chose to reject an encoding if
the pad bits have not been set to zero." Source:
<https://www.rfc-editor.org/rfc/rfc4648.txt>.

### 7.4 Non-alphabet characters — the deliberate leniency

Go ignores CR and LF inside base64 input but rejects everything else:

- `Decode`: "New line characters (\r and \n) are ignored."
- `DecodeString`: same.
- The stream decoder wraps the reader: `NewDecoder` returns
  `&decoder{enc: enc, r: &newlineFilteringReader{r}}` (master source).

RFC 4648 makes this a policy decision, and Go picked the lenient option only for
line breaks: "Implementations MUST reject the encoded data if it contains
characters outside the base alphabet when interpreting base-encoded data, unless
the specification referring to this document explicitly states otherwise." (§3.3).
That section also names the risk: ignored characters "may be exploited as a 'covert
channel'", repeated in §12 (Security Considerations). Source:
<https://www.rfc-editor.org/rfc/rfc4648.txt>.

Practical consequence: because CR/LF are ignored, encoding is not canonical with
respect to whitespace, so string equality of the encoded form is the only reliable
equality test; a decoded-value equality test can be fooled by inserted newlines.
(Assessment, not a source quote.)

## 8. Timeouts

Not applicable in the literal sense: base64/base32/hex are pure functions over byte
slices, and neither the stdlib nor the community libraries expose a timeout,
deadline or cancellation parameter. There is no blocking resource to time out.

Closest analogues, for completeness:

- **I/O deadlines belong to the wrapped transport.** A `NewDecoder`/`NewEncoder`
  blocked in `r.Read`/`w.Write` is governed by the underlying reader/writer's own
  deadline mechanism (e.g. `net.Conn.SetDeadline`), not by the base64 package.
  `GUESS:` the base64 package documents no interaction with such deadlines, and the
  `io.Reader`/`io.Writer` contracts do not mention them.
- **Cancellation is caller-side**: close the underlying stream, or stop calling
  `Read`/`Write`. The encoder/decoder hold no token and no context.
- **Partial-progress semantics substitute for abortability**: because `Decode`
  returns `(n, err)` even on failure, a caller can keep or discard the partially
  decoded prefix; no mid-call cancellation is needed.
- **Error stickiness in the stream encoder**: `encoder.Write` returns the stored
  error immediately once set (`if e.err != nil { return 0, e.err }`), so an upstream
  write failure latches and subsequent calls fail fast (master source).

## 9. Streaming (adapted Q9: incremental/chunked encode/decode with leftover bytes)

### 9.1 Encoder

`NewEncoder` returns an `io.WriteCloser`. The contract: "Base64 encodings operate
in 4-byte blocks; when finished writing, the caller must Close the returned encoder
to flush any partially written blocks." Source:
<https://pkg.go.dev/encoding/base64#NewEncoder>. The doc example comments: "Must
close the encoder when finished to flush any partial blocks. If you comment out the
following line, the last partial block 'r' won't be encoded."

Leftover handling is explicit and small: `type encoder struct { buf [3]byte; nbuf
int; out [1024]byte }` (master source). `Write` has three phases:
1. **Leading fringe**: top up `buf` to 3 bytes, then encode and write 4 output
   bytes.
2. **Large interior chunks**: encode `len(out)/4*3` input bytes per round, rounded
   down to a multiple of 3, and write `nn/3*4` output bytes.
3. **Trailing fringe**: `copy(e.buf[:], p); e.nbuf = len(p)` — up to 2 bytes are
   retained.
`Close` flushes exactly those `nbuf` leftover bytes:
`e.enc.Encode(e.out[:], e.buf[:e.nbuf])`, writing `e.enc.EncodedLen(e.nbuf)` bytes.
Source: master
<https://raw.githubusercontent.com/golang/go/master/src/encoding/base64/base64.go>.

Because `Encode` alone "pads the output to a multiple of 4 bytes", it "is not
appropriate for use on individual blocks of a large data stream. Use NewEncoder
instead" — Go explicitly warns that the one-shot function is wrong for chunked use.
Source: <https://pkg.go.dev/encoding/base64#Encoding.Encode>.

### 9.2 Decoder

`NewDecoder` returns an `io.Reader` over `&newlineFilteringReader{r}`, which strips
CR/LF in place before decoding (master source). Leftovers and framing:
- `type decoder struct { err error; readErr error; enc *Encoding; r io.Reader; end
  bool; total int64; buf [1024]byte; nbuf int; out []byte; outbuf [1024/4*3]byte }`
  (master source). It keeps **both** undecoded input (`buf`/`nbuf`) and undelivered
  output (`out`).
- It refills until at least 4 input bytes are available, and it only decodes whole
  quanta (`nr := d.nbuf / 4 * 4`), leaving the remainder in `buf`.
- If the caller's destination `p` is smaller than the decodable output, it decodes
  into `outbuf` and hands out `out` across successive calls, so a short read buffer
  never loses decoded data.
- `DecodedLen` for unpadded input is defined so partial trailing groups are safe:
  `n/4*3 + n%4*6/8` (master source, `decodedLen`).
- **Trailing/truncated input**: if the reader is exhausted while leftovers remain,
  the error becomes `io.ErrUnexpectedEOF` rather than `io.EOF` (master source).

### 9.3 Framing edge case worth copying as a test

The master source contains an explicit end-of-stream rule that is easy to get
wrong: once a *padded* group has been decoded, any further input is an error — "A
padded group must end the stream: decoding the same input as a whole reports any
input after it as garbage." Implemented as `d.end = true` when the last decoded
input byte was the pad character, followed by `if d.end && d.nbuf > 0 { ...
CorruptInputError }` (master source). `GUESS:` whether the go1.27.1 release
contains this exact rule could not be confirmed from a tagged source here, because
the source read for this research was the `master` branch; re-check against the
tagged version at implementation time.

### 9.4 Streaming in the community libraries

- `segmentio/asm/base64` and `emmansun/base64` keep the stdlib streaming surface,
  so stream semantics are inherited unchanged; emmansun lists "stream
  encoder/decoder" as compatible. Source: <https://github.com/emmansun/base64>
  (README, Overview).
- `go-simd/base64` ships a framing pre-pass instead of a stream object:
  `Compact(dst, src []byte) int` and `CompactString(dst []byte, src string) int`
  "copies into dst every standard base64 alphabet byte ... dropping whitespace,
  line breaks, padding and any other byte" and applies "the RFC-2045 / MRI relaxed
  padding rule". `dst` must have room for `len(src)`; it never allocates. Source:
  <https://pkg.go.dev/github.com/go-simd/base64#Compact>.
- `cristalhq/base64` re-exports the stdlib stream constructors but changes error
  messages and newline handling (see section 2).

## 10. Interesting design decisions

Each entry names a design choice and the reason seen in the source.

1. **The alphabet string is the constructor input, and the decode table is
   precomputed.** `NewEncoding` copies 64 bytes into `encode [64]byte` and fills a
   `decodeMap [256]uint8` with `0xff` sentinels (master source). Encoding becomes a
   table lookup and decoding a single indexed load, with the invalid-byte case
   pre-encoded as a value instead of a per-class branch. The
   `assemble32`/`assemble64` helpers then OR the four/eight map results and reject
   the group iff the OR is `0xff`. Source: master `base64.go`.
2. **Two branch-free fast paths for the happy path.** `Decode` processes 8 input
   symbols into 6 output bytes (`assemble64`, 64-bit only) and 4 into 3
   (`assemble32`) before falling back to `decodeQuantum` for the tail or for any
   invalid byte. Source: master `base64.go`.
3. **`Strict()` and `WithPadding()` are value-receiver and copy-on-modify.** Deriving
   a variant never mutates a shared preset, which removes a class of aliasing bugs
   and makes the presets safe to share. Source: master `base64.go`
   (`func (enc Encoding) Strict()`, `func (enc Encoding) WithPadding(...)`).
4. **Error offsets are first-class.** `CorruptInputError` is an `int64` index with a
   human-readable message, and the stream decoder rebases buffered offsets to
   whole-stream indices (master source). A caller can point at the exact offending
   byte, which is what you want when a PEM blob or config value fails to parse.
5. **Partial output on error is intentional and documented** (section 4). It
   matches Go's general "return what you got plus the error" idiom.
6. **Newline filtering is a wrapper reader, not a branch in the decode loop**
   (`newlineFilteringReader`), so the hot loop never checks for `\r`/`\n` while the
   documented leniency still holds. Source: master `base64.go`.
7. **No public streaming state-machine type.** The state is private
   (`encoder`/`decoder` structs) and the public contract is `io.Reader` /
   `io.WriteCloser`, so callers can compose with `io.Copy`, gzip, chunked HTTP
   bodies, etc. Source: master `base64.go`.
8. **Append-style APIs were added late (go1.22)** to remove the "allocate a fresh
   buffer per call" pattern; `AppendEncode` uses `slices.Grow` and writes into the
   tail. Source: <https://pkg.go.dev/encoding/base64#Encoding.AppendEncode>
   ("added in go1.22.0"), master source.
9. **hex is intentionally a flat API.** No `Encoding` type, no alphabet, no padding,
   no `Strict` — because RFC 4648 §8 says base16 needs no padding and the only
   alphabet freedom is upper vs lower case. Sources:
   <https://pkg.go.dev/encoding/hex>, <https://www.rfc-editor.org/rfc/rfc4648.txt>
   §8.
10. **base32 carries the same shape as base64, so one mental model serves both.**
    Same type name, same method names, same error type; only the quantum size
    differs (5 bytes to 8 symbols). Source: <https://pkg.go.dev/encoding/base32>.

## 11. Decisions NOT to copy

Each item names the Go behaviour and why it is a poor fit for a predictable,
low-vision-friendly MojoAkku API.

1. **Do not use a sentinel rune (`NoPadding rune = -1`) to express "no padding".**
   It overloads a character value with a mode flag, makes `WithPadding(NoPadding)`
   read like an ordinary padding choice, and forces `if enc.padChar != NoPadding`
   checks in the encoder tail. Sources: master `base64.go` (`case 1:`/`case 2:`
   branches), base64.go;l=31.
2. **Do not panic on user-supplied configuration.** `NewEncoding` panics on bad
   alphabet length/duplicates/newlines, `WithPadding` panics on invalid padding,
   and `EncodedLen` panics on overflow (master source). A library whose inputs may
   come from config or from a spec should return an error or be validated at
   compile time. This is also why `segmentio/asm/base64` could not accept arbitrary
   alphabets — an unenforceable panic contract.
3. **Do not model "no padding" as a separate encoding object per alphabet.** Go
   needs four presets plus `WithPadding` to cover the matrix; padding policy and
   alphabet are orthogonal and should be modelled orthogonally.
4. **Do not silently ignore CR/LF by default.** Go folds newline filtering into
   `Decode`, `DecodeString` and `NewDecoder` unconditionally (master source). That
   contradicts RFC 4648 §3.3's MUST-reject default and is a documented
   covert-channel vector (§3.3, §12). A predictable API should require an explicit
   opt-in.
5. **Do not conflate "lenient about whitespace" with "strict about trailing bits".**
   In Go the default is lenient about whitespace and `Strict()` only adds the
   trailing-bits check; the two axes are separate in RFC 4648 (§3.3 vs §3.5).
   Sources: <https://pkg.go.dev/encoding/base64#Encoding.Strict>,
   <https://www.rfc-editor.org/rfc/rfc4648.txt>.
6. **Do not expose a 256-entry decode table through a constructor that can also
   fail by panic.** Prefer a compile-time alphabet with a distinct type, as Rust
   does with `Alphabet` (see the Rust research file for that design).
7. **Do not make `(n, error)` with partially valid output the only in-memory
   shape.** Go's contract is powerful but easy to misuse: a caller that ignores
   `err` still receives bytes. Type-level separation of success and failure is
   safer for a clarity-focused library. (Assessment based on the contracts in
   section 4.)
8. **Do not copy `int`-typed length arithmetic without an overflow policy.** The
   stdlib panics on overflow in `EncodedLen` and the community libraries vary. A
   predictable API should define behaviour (checked arithmetic, a wider return
   type, or a documented precondition) instead of panicking.
9. **Do not copy `DecodedLen` as "maximum" without saying so.** It is documented as
   the maximum corresponding length, so append-style callers must track the real
   `n`; conflating capacity with length is a known footgun. Source:
   <https://pkg.go.dev/encoding/base64#Encoding.DecodedLen>.
10. **Do not adopt stream error-stickiness silently.** The stream encoder latches
    the first error and fails fast forever after (master source,
    `if e.err != nil { return 0, e.err }`). Latching is defensible, but must be
    documented, because otherwise "write once more after a failure" becomes
    impossible.

## 12. Ideas fitting Mojo

Mojo facts are **not** asserted here; per project rule they must be looked up in the
`mojov1` buch (page `stdlib/base64`) before use. The points below therefore name
*properties of the Go design* and how they map onto language features, and are
explicitly assessments.

1. **Compile-time alphabets.** Go precomputes `encode [64]byte` and
   `decodeMap [256]uint8` at runtime construction. The same two tables can be
   produced at compile time from an alphabet literal, turning an invalid alphabet
   into a compile error instead of a panic — removing item 2 of section 11.
   (Assessment; verify compile-time facilities in `mojov1`.)
2. **Explicit buffer ownership mirrors value/borrowed semantics.** Go's
   `Encode(dst, src)` and `Decode(dst, src) (n, err)` map onto a borrowed read-only
   input plus an `inout` output buffer whose length contract the callee checks.
   (Assessment.)
3. **`raises` replaces `(n, error)`.** A raising function gives Go's out-of-band
   error channel a first-class home, and the partial-output contract can then be
   documented explicitly instead of being implied by a returned slice. This is the
   single biggest ergonomic gain available over Go (section 11, item 7).
   (Assessment.)
4. **Distinct types per variant beat a rune plus four-preset matrix.** An
   alphabet type combined with a padding policy removes Go's sentinel `-1` and its
   four presets (section 11, items 1 and 3). (Assessment.)
5. **The quantum/leftover model is directly portable.** `buf [3]byte` plus `nbuf`,
   and `nr := nbuf / 4 * 4` with `nbuf -= nr`, are plain integer bookkeeping that
   needs no ownership tricks; the "must Close" requirement is the part to redesign
   into an explicit `finish()` (see Rust's `EncoderWriter::finish`, which returns
   the inner writer and is documented). (Assessment.)
6. **Keep the two entry points the stdlib proves are needed**: a convenience
   allocating path (`EncodeToString`) and a caller-buffer path
   (`Encode(dst, src)`), plus the `EncodedLen`/`DecodedLen` helpers. The go1.22
   addition of `AppendEncode` is evidence that a third, append-into-existing-buffer
   affordance is wanted.
7. **Carry error offsets.** Go's `CorruptInputError` offset and its stream-level
   rebasing are little code with a large usability payoff; for a low-vision user,
   "byte 137 of the input is not base64" is far more actionable than "invalid
   base64".
8. **Keep newline leniency as an explicit opt-in.** Go's unconditional filtering is
   the design to avoid (section 11, item 4), but the capability is needed for
   real-world PEM/MIME input, so it should be a named policy on the decoder rather
   than hidden default behaviour.
9. **Do not chase SIMD in the first iteration.** The stdlib scalar path and the
   drop-ins agree on semantics; SIMD is a pure performance swap behind an unchanged
   API (section 2). Getting alphabet, padding and error semantics right first is
   the higher-value work, and the Go evidence shows SIMD can be added later without
   breaking the interface.

## Sources

- Go `encoding/base64` package docs: <https://pkg.go.dev/encoding/base64>
- Go `encoding/base32` package docs: <https://pkg.go.dev/encoding/base32>
- Go `encoding/hex` package docs: <https://pkg.go.dev/encoding/hex>
- Go `encoding/base64` source (master; used for struct layout, quantum arithmetic,
  streaming buffers, error rebasing):
  <https://raw.githubusercontent.com/golang/go/master/src/encoding/base64/base64.go>
- RFC 4648, "The Base16, Base32, and Base64 Data Encodings":
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
  (used for §3.1 line feeds, §3.2 padding MUST, §3.3 non-alphabet characters,
  §3.5 canonical encoding, §4/§5 alphabets, §7 base32hex, §8 base16, §12 security)
- `cristalhq/base64`: <https://github.com/cristalhq/base64>
- `segmentio/asm/base64` (API and alphabet restriction):
  <https://pkg.go.dev/github.com/segmentio/asm/base64>
- `segmentio/asm` (project, SIMD rationale): <https://github.com/segmentio/asm>
- `go-simd/base64` (byte/error-identical claim, `Compact`, in-place decode):
  <https://pkg.go.dev/github.com/go-simd/base64>
- `emmansun/base64` (architecture matrix, API compatibility):
  <https://github.com/emmansun/base64>
- `aklomp/base64` (C99 reference; stream API shape, no dynamic allocation,
  re-entrant/threadsafe, OpenMP): <https://github.com/aklomp/base64>
- Mojo side is covered by the `mojov1` buch page `stdlib/base64`, not by this file.
