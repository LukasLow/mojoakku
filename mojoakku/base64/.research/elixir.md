# base64 research: Elixir

Scope: base64/base32/base16 encoding and decoding in Elixir (and its host
runtime, Erlang/OTP). Every factual claim carries a source (URL or
`repo/path:line`). Statements without a source are marked `GUESS:` with the
reason.

## 1. Standard library support

- Elixir ships the **`Base`** module in the standard library. "This module
  provides data encoding and decoding functions according to RFC 4648. This
  document defines the commonly used base 16, base 32, and base 64 encoding
  schemes." Source: <https://hexdocs.pm/elixir/Base.html>
- The public function set in Elixir v1.20.4 is `encode16/2`, `decode16/2`,
  `decode16!/2`, `encode32/2`, `decode32/2`, `decode32!/2`, `hex_encode32/2`,
  `hex_decode32/2`, `hex_decode32!/2`, `encode64/2`, `decode64/2`, `decode64!/2`,
  `url_encode64/2`, `url_decode64/2`, `url_decode64!/2`, plus the validation
  functions `valid16?/2`, `valid32?/2`, `hex_valid32?/2`, `valid64?/2`,
  `url_valid64?/2`. Source: <https://hexdocs.pm/elixir/Base.html>
- The validation functions are recent: their docs carry "since 1.19.0"
  (`valid16?/2`, `valid32?/2`, `hex_valid32?/2`, `valid64?/2`, `url_valid64?/2`).
  Source: <https://hexdocs.pm/elixir/Base.html>
- The module is implemented in pure Elixir —
  `lib/elixir/lib/base.ex` defines `defmodule Base do` with `import Bitwise` and
  all functions defined in-file. Source:
  <https://raw.githubusercontent.com/elixir-lang/elixir/v1.20.4/lib/elixir/lib/base.ex>
- The module's SPDX header is **Apache-2.0** ("SPDX-License-Identifier:
  Apache-2.0", "SPDX-FileCopyrightText: 2021 The Elixir Team",
  "SPDX-FileCopyrightText: 2012 Plataformatec"). Source: same file.
- Underneath, Erlang/OTP provides the **`base64`** module (stdlib) for base64
  only: `encode/1,2`, `decode/1,2`, `mime_decode/1,2`, `encode_to_string/1,2`,
  `decode_to_string/1,2`, `mime_decode_to_string/1,2`. Its moduledoc: "Provides
  base64 encode and decode, see RFC 2045." Source:
  <https://www.erlang.org/doc/apps/stdlib/base64.html>
- **Erlang/OTP has no standard-library Base32 module**, only `base64`; there is no
  `base32` entry in stdlib. Source: the stdlib function index in the `base64` doc
  page context and <https://www.erlang.org/doc/apps/stdlib/notes.html> (no base32
  module mentioned). Community library needed — see section 2.
- Erlang's `base64` gained `mode` (`standard` | `urlsafe`) and `padding` options
  in **OTP 26.0**: `-doc(#{since => <<"OTP 26.0">>})` on `encode/2`, `decode/2`,
  `mime_decode/2` and the `*_to_string/2` variants. Source:
  <https://raw.githubusercontent.com/erlang/otp/OTP-28.0/lib/stdlib/src/base64.erl>
- Historical note from OTP 26.0 onwards: the option defaults are
  `#{mode => standard, padding => true}`. Source:
  <https://www.erlang.org/doc/apps/stdlib/base64.html>
- Naming history: the OTP 29.1 docs render the option type as
  `decode_options()`/`encode_options()`, whereas the OTP-26.0 source typed it as
  `options()`. The external contract (map with `padding`/`mode`) is unchanged.
  Sources: <https://www.erlang.org/doc/apps/stdlib/base64.html>,
  <https://raw.githubusercontent.com/erlang/otp/OTP-26.0/lib/stdlib/src/base64.erl>

## 2. Relevant community libraries

| Library | What | Maturity signal (Hex) | License |
|---|---|---|---|
| `base64url` (potatosalad) | "URL safe base64-compatible codec"; GitHub `dvv/base64url` | v1.0.1, 0 dependencies, 43 091 702 all-time downloads, **last updated Jul 28, 2019** | MIT |
| `base32` (dnsimple) | "Erlang implementation of base32 encoding and decoding", GitHub `dnsimple/base32_erlang` | v1.0.0, 0 dependencies, 237 412 downloads, last updated Apr 02, 2025, rebar3 | Apache-2.0 |
| `crockford_base32` (xinz) | "Crockford Base32 encoding and decoding for integers and bitstrings in Elixir", GitHub `xinz/crockford_base32` | v0.9.0, 12 versions, 0 dependencies, 27 749 downloads, last updated Aug 11, 2026 | MIT |
| `multibase` (nocursor) | "Elixir library for encoding and decoding data using the Multibase standard" (base1, base2, base8, base10, base16, base32, base32hex, base58, base64, zbase32), GitHub `nocursor/ex-multibase` | v0.0.1 (only release), 4 dependencies, 15 110 downloads, last updated Nov 14, 2018 | MIT |
| `voldy/base32_crockford` | alternative Crockford Base32 implementation, install as `{:base32_crockford, "~> 1.0.0"}` | described on GitHub readme (no Hex page checked) | MIT — repository `LICENSE` (<https://github.com/voldy/base32_crockford>) |

Sources: <https://hex.pm/packages/base64url>, <https://hex.pm/packages/base32>,
<https://hex.pm/packages/crockford_base32>, <https://hex.pm/packages/multibase>,
<https://github.com/voldy/base32_crockford>.

Observation: the Hex ecosystem has **no widely-used community library for
standard (non-URL) base64** — its most-downloaded base64 package, `base64url`
(43M downloads), is URL-safe-specific and last updated in 2019. The reason is
that `Base` already covers base64/base64url/base16/base32/base32hex. The community
gap is exotic alphabets (Crockford) and multi-format envelopes (Multibase).
Sources: the four Hex pages above.

## 3. Exposed APIs

### Elixir `Base`

Signatures (Elixir v1.20.4):

| Function | Spec |
|---|---|
| `encode64(data, opts \\ [])` | `binary, padding: boolean -> binary` |
| `decode64(string, opts \\ [])` | `binary, ignore: :whitespace, padding: boolean -> {:ok, binary} \| :error` |
| `decode64!(string, opts \\ [])` | `binary, ignore: :whitespace, padding: boolean -> binary` |
| `url_encode64(data, opts \\ [])` | `binary, padding: boolean -> binary` |
| `url_decode64(string, opts \\ [])` / `url_decode64!/2` | as `decode64`/`decode64!` |
| `encode16(data, opts \\ [])` | `binary, case: :upper\|:lower -> binary` |
| `decode16(string, opts \\ [])` / `decode16!/2` | `binary, case: :upper\|:lower\|:mixed -> {:ok, binary} \| :error` / `binary` |
| `encode32(data, opts \\ [])` | `binary, case: :upper\|:lower, padding: boolean -> binary` |
| `decode32(string, opts \\ [])` / `decode32!/2` | `binary, case: decode_case, padding: boolean -> {:ok, binary} \| :error` / `binary` |
| `hex_encode32(data, opts \\ [])`, `hex_decode32/2`, `hex_decode32!/2` | same shape, extended-hex alphabet |
| `valid16?/2`, `valid32?/2`, `hex_valid32?/2`, `valid64?/2`, `url_valid64?/2` | `-> boolean` |

Types: `@type encode_case :: :upper | :lower`, `@type decode_case :: :upper |
:lower | :mixed`. Sources: <https://hexdocs.pm/elixir/Base.html>, source anchors
<https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/base.ex#L99>
and `#L100`.

### Erlang `base64`

`encode(Data, Options) -> Base64 :: binary()`, `encode_to_string(Data, Options)
-> base64_string()`, `decode(Base64, Options) -> binary()`,
`decode_to_string(...) -> byte_string()`, `mime_decode/2` and
`mime_decode_to_string/2`; `Data :: byte_string() | binary()`. Options are maps
`#{padding => boolean(), mode => standard | urlsafe}`. Sources:
<https://www.erlang.org/doc/apps/stdlib/base64.html>,
<https://raw.githubusercontent.com/erlang/otp/OTP-28.0/lib/stdlib/src/base64.erl>

### Community

- `base32`: `encode/1,2`, `decode/1,2`; options `hex` (extended hex alphabet),
  `lower` (lowercase), `nopad` (skip padding) — for encode; `hex` for decode.
  Source: <https://base32.hexdocs.pm/base32.html>
- `base64url` exposes a URL-safe codec (readme text only, package page renders
  the readme as "URL safe base64-compatible codec"). Source:
  <https://hex.pm/packages/base64url>
- `crockford_base32` is documented as supporting integers and bitstrings.
  Source: <https://hex.pm/packages/crockford_base32>
- `GUESS:` the exact exported function names of `base64url` and `crockford_base32`
  are not on the Hex package pages I read (the readme did not render); I did not
  fetch their HexDocs.

## 4. Error representation

Elixir deliberately exposes **two parallel APIs**:

- Non-bang functions return a tagged tuple: `{:ok, binary} | :error`
  (`decode64/2`, `decode32/2`, `decode16/2`, `url_decode64/2`, `hex_decode32/2`).
  Source: <https://hexdocs.pm/elixir/Base.html>
- Bang functions raise: "An `ArgumentError` exception is raised if the padding is
  incorrect or a non-alphabet character is present in the string."
  (`decode64!/2`, `decode32!/2`, `decode16!/2`, `url_decode64!/2`,
  `hex_decode32!/2`). Source: <https://hexdocs.pm/elixir/Base.html>
- Both cases carry **one error type only**: `ArgumentError`, no subtypes. In the
  source, the two distinct failure causes are the private helper
  `bad_character!/1` ("non-alphabet character found: ... (byte N)") and the
  literal `raise ArgumentError, "incorrect padding"`. Source:
  <https://raw.githubusercontent.com/elixir-lang/elixir/v1.20.4/lib/elixir/lib/base.ex>
- `decode16!/2` also raises on wrong length, with an explicit message: "string
  given to decode has wrong length. An even number of bytes was expected, got:
  N. Double check your string for unwanted characters or pad it accordingly."
  Source: same file (`lib/elixir/lib/base.ex`).
- The non-bang functions are implemented as
  `{:ok, decode64!(...)} rescue ArgumentError -> :error`, i.e. **the specific
  reason is discarded**. Source: same file.
- Validation functions return a bare `boolean` and never raise; their docs
  motivate them as "more performant and memory efficient than using
  `decode64/2`, checking that the result is `{:ok, ...}`, and then discarding
  the decoded binary." Source: <https://hexdocs.pm/elixir/Base.html>
- Erlang's `base64` instead raises an `error` term: the source defines
  `missing_padding_error() -> error(missing_padding, none, [{error_info, #{}}])`
  with `format_error(missing_padding, _) -> #{general => "data to decode is
  missing final = padding characters, if this is intended, use the `padding =>
  false` option"}`. Whitespace and illegal characters are handled differently per
  function (see section 7). Source:
  <https://raw.githubusercontent.com/erlang/otp/OTP-28.0/lib/stdlib/src/base64.erl>
- No `Result`/`Either` monad and no error codes appear anywhere in the surveyed
  API. Sources: all API pages in section 3.

## 5. Ownership semantics (buffer / encode input and output)

- Elixir is a garbage-collected, immutable-data language; the API is
  value-in/value-out. Every codec signature is `binary -> binary` or
  `binary -> {:ok, binary} | :error`; no buffer, capacity, offset or length is
  passed in, and there is no in-place variant. Source:
  <https://hexdocs.pm/elixir/Base.html>
- Consequence: each call allocates a fresh output binary; there is no caller-owned
  destination buffer and therefore no "output too small" error class. This is the
  opposite of Java's `encode(byte[] src, byte[] dst)` overload. Sources:
  <https://hexdocs.pm/elixir/Base.html>,
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>
- **Input acceptance is narrower than Erlang's**: Erlang `base64` accepts
  `byte_string() | binary()` (list or binary, per its specs and the
  `is_binary`/`is_list` guards in `encode/2` and `decode/2`), while Elixir's
  `Base` guards on `is_binary(data)` / `is_binary(string)` for the
  binary-producing functions. Sources:
  <https://raw.githubusercontent.com/erlang/otp/OTP-28.0/lib/stdlib/src/base64.erl>,
  <https://raw.githubusercontent.com/elixir-lang/elixir/v1.20.4/lib/elixir/lib/base.ex>
- Erlang additionally offers a **string-vs-binary output choice** via
  `encode/2 -> base64_binary()` vs `encode_to_string/2 -> base64_string()` (a
  charlist), and `decode/2 -> binary()` vs `decode_to_string/2 -> byte_string()`
  (a list). Source:
  <https://www.erlang.org/doc/apps/stdlib/base64.html>
- `GUESS:` the exact reference-sharing behaviour between an input binary and the
  produced sub-binaries (immutable ref-counted binaries, sub-binary sharing) is
  not stated in the `Base` docs I read; a source would have to come from the
  Erlang binary/bitstring documentation, which I did not fetch. Reason for the
  guess: the `Base` module docs make no memory/reference-sharing statement at all.
- `GUESS:` no `Base64` allocation happens in a NIF, so no off-heap ownership
  question arises; I could not source whether any part of OTP's base64 is a BIF.
  The module is ordinary `.erl` source with no `-nifs`/`erlang:nif_error` in the
  file I read, which is strong but not conclusive evidence.

## 6. Blocking / non-blocking

- All `Base` and `:base64` functions are **pure, synchronous, CPU-bound calls**
  with no I/O and no async variant anywhere: there is no `Task`, `Stream`,
  `Future` or `handle_*` counterpart in either module. Sources:
  <https://hexdocs.pm/elixir/Base.html>,
  <https://www.erlang.org/doc/apps/stdlib/base64.html>
- The only I/O-adjacent surface is the Erlang naming pair `encode` vs
  `encode_to_string` and `decode` vs `decode_to_string`, which is about output
  *data type* (binary vs charlist), **not** streaming. The Erlang docs state this
  explicitly: "Equivalent to `encode(Data, Options)`, but returns a
  `byte_string/0`." Sources:
  <https://www.erlang.org/doc/apps/stdlib/base64.html>,
  <https://raw.githubusercontent.com/erlang/otp/OTP-28.0/lib/stdlib/src/base64.erl>
- `GUESS:` because the OTP implementation is pure Erlang rather than a NIF, a long
  `encode/1` call is subject to the BEAM's normal preemptive scheduling and does
  not block other processes; I have not fetched a scheduler source to prove the
  preemption claim for this specific function.
- `GUESS:` for Elixir `Base`, which is also pure Elixir, the same reasoning
  applies with the same missing source.

## 7. Alphabet variants (standard / URL-safe) and padding handling

### Alphabets present in Elixir `Base`

| Variant | Alphabet | Padding default | Case options |
|---|---|---|---|
| Base 16 | `0-9 A-F` | none needed | encode `:upper`/`:lower`; decode `:upper`/`:lower`/`:mixed` |
| Base 32 | `A-Z 2-7` | `=` to nearest multiple of 8 | encode `:upper`/`:lower`; decode `:upper`/`:lower`/`:mixed` |
| Base 32 extended hex | `0-9 A-V` | `=` to nearest multiple of 8 | as base 32 |
| Base 64 | `A-Z a-z 0-9 + /` | `=` | none (alphabet is inherently mixed case) |
| Base 64 URL and filename safe | `A-Z a-z 0-9 - _` | `=` | none |

Source (all five tables are reproduced in the moduledoc):
<https://hexdocs.pm/elixir/Base.html>; the alphabets are also `comptime`
charlists in the source (`b16_alphabet`, `b64_alphabet`, `b64url_alphabet`,
`b32_alphabet`, `b32hex_alphabet`):
<https://raw.githubusercontent.com/elixir-lang/elixir/v1.20.4/lib/elixir/lib/base.ex>
This matches RFC 4648 tables 1–5. Source:
<https://www.rfc-editor.org/rfc/rfc4648.txt>

### Padding

- `encode64/2`, `encode32/2`, `url_encode64/2`, `hex_encode32/2` accept
  `padding: false` and "will omit padding from the output string"; the default is
  `true`. Source: <https://hexdocs.pm/elixir/Base.html>
- `decode64/2`/`url_decode64/2` accept `padding: false`, which "will ignore
  padding from the input string"; with the default `true` the padding must be
  correct. Sources: <https://hexdocs.pm/elixir/Base.html>,
  <https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/base.ex#L836>
- `decode32/2`/`hex_decode32/2` accept `padding: true` (default, "requires the
  input string to be padded to the nearest multiple of 8") and `padding: false`
  ("ignores padding"). Source: <https://hexdocs.pm/elixir/Base.html>
- The padding amounts per partial quantum are hard-coded in the source helper
  `maybe_pad(acc, true, n)` for n in 1..6: `"======"`, `"===="`, `"==="`, `"=="`,
  `"="`. Source: `lib/elixir/lib/base.ex`.
- RFC 4648 §3.2 mandates padding "unless the specification ... explicitly states
  otherwise", so Elixir's default (`padding: true`) is the RFC-faithful choice;
  §5 notes the URL-safe alphabet may drop padding when the length is known.
  Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>
- **Erlang `base64` mode/padding**: `mode => standard | urlsafe` selects the
  alphabet, `padding => true | false` appends/requires or skips/ignores the `=`
  characters; default `#{mode => standard, padding => true}`. Notably, the
  standard mode treats `-` and `_` as **illegal** characters and urlsafe treats
  `+` and `/` as illegal — the two alphabets are not interchangeable per the
  docs. Source: <https://www.erlang.org/doc/apps/stdlib/base64.html>
  (implementation: two disjoint decode tables selected by
  `get_decoding_offset/1` → 1 or 257, and two encode tables by
  `get_encoding_offset/1` → 1 or 65, in
  <https://raw.githubusercontent.com/erlang/otp/OTP-28.0/lib/stdlib/src/base64.erl>)
- Erlang's `mime_decode/2` is the lenient path: "The function will strips away
  any illegal characters. It does *not* check for the correct number of `=`
  padding characters at the end of the encoded string." `decode/2`, by contrast,
  "will strip away any whitespace characters and check for the correct number of
  `=` padding characters". Source:
  <https://www.erlang.org/doc/apps/stdlib/base64.html>
- The source comment frames the split exactly that way: "mime_decode strips away
  all characters not Base64 before converting, whereas decode crashes if an
  illegal character is found", and references "section 3.3 of RFC4648" for the
  liberal behaviour. Source: `lib/stdlib/src/base64.erl`.
- RFC 4648 §3.3 says implementations **MUST** reject out-of-alphabet characters
  unless the referring spec says otherwise, and names MIME as the example that
  says "ignore" instead. §12 warns the ignore-mode creates a covert channel.
  Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>
- **Crockford Base32 is a different alphabet entirely** (community add-on, not RFC
  4648). Source: <https://hex.pm/packages/crockford_base32>
- `GUESS:` the exact Crockford symbol set used by `crockford_base32` is not on the
  Hex package page I read; the readme did not render.

## 8. Timeouts and cancellation

Not applicable, and there is nothing to opt into:

- Neither Elixir `Base` nor Erlang `base64` exposes any timeout, deadline or
  cancellation parameter; all functions are total CPU transformations of their
  argument. Sources: <https://hexdocs.pm/elixir/Base.html>,
  <https://www.erlang.org/doc/apps/stdlib/base64.html>
- In the BEAM, cancellation of a computation in another process is a generic
  property of the VM (process isolation / exit signals), not of this library;
  the codec offers no hooks for it. Sources: the two API pages above (they
  document no such hooks).
- `GUESS:` for very large inputs there is no chunked-yield API (no
  `reduce`-style callback, no `Stream` integration); I could not find any such
  function in the module's function list, which is the strongest available
  negative evidence.

## 9. Streaming (incremental/chunked encode/decode with leftover bytes)

This is the most striking difference from the Java side: **there is no streaming
API at all** in either Elixir `Base` or Erlang `base64`. Every function consumes
a whole binary.

- Evidence (negative): the complete function lists in section 3 contain no
  `stream_*`, no `init/update/finish`, no state struct and no `Stream`
  integration. Sources: <https://hexdocs.pm/elixir/Base.html>,
  <https://www.erlang.org/doc/apps/stdlib/base64.html>
- The recommended Elixir workaround is compositional: chunk the input yourself
  and keep the remainder, or build a `Stream` around repeated whole-buffer calls.
  `GUESS:` I could not find an official doc page prescribing this pattern, so the
  workaround is inference rather than a sourced recommendation.
- **Leftover handling inside one call** is done with binary pattern matching on
  bitstrings, so partial quanta are a first-class case rather than an error:
  `encode64base` matches `<<c1::12, c2::12, c3::12, c4::12, rest::binary>>` for
  full 3-octet quanta and falls through to
  `<<c1::12, c2::12, c3::12, c4::4>>` (→ 1 pad), `<<c1::12, c2::12, c3::8>>`
  (→ 2 pads) and shorter tails. Source: `lib/elixir/lib/base.ex`.
- The decode side does arithmetic on the trailing window instead: it splits
  `segs = div(byte_size(string) + 7, 8) - 1` 8-byte units off the front and then
  pattern-matches the remainder against the legal tail shapes
  (`<<c1,c2,?=,?=>>`, `<<c1,c2,c3,?=>>`, `<<c1..c4>>`, …, plus the
  `when not pad?` variants), finally `raise ArgumentError, "incorrect padding"` if
  nothing matches. Source: `lib/elixir/lib/base.ex`.
- Erlang instead recurses with explicit partial-quantum clauses and an
  accumulator: `encode_binary(ModeOffset, Padding, <<B1:6, B2:6, B3:6, B4:6,
  Ls/bits>>, A)` for the full quantum, and dedicated `<<B1:6, B2:2>>` and
  `<<B1:6, B2:6, B3:4>>` clauses that append `=`, `==` or nothing depending on
  `Padding`. Source:
  <https://raw.githubusercontent.com/erlang/otp/OTP-26.0/lib/stdlib/src/base64.erl>
- Erlang's MIME path tolerates **padding in the middle**: the comment reads
  "Skipping pad character if not at end of string. Also liberal about excess
  padding and skipping of other illegal (non-base64 alphabet) characters. See
  section 3.3 of RFC4648", implemented by `mime_decode_list_after_eq/...` and
  `decode_list/...` state machines (`only_ws`/`only_ws_binary` accept trailing
  whitespace after the final `=`, and excess pad characters "MAY also be
  ignored" per RFC 4648 §3.3). Sources: `lib/stdlib/src/base64.erl`,
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
- Erlang's `encode_to_string/2` and `encode/2` both take the **whole** input and
  return the whole output; the "33% larger" note is documentation, not a
  streaming contract: "Encodes a plain ASCII string into base64 using the
  alphabet indicated by the `mode` option. The result is 33% larger than the
  data." Source: <https://www.erlang.org/doc/apps/stdlib/base64.html>
- For large binaries, Elixir's `Base` gains robustness from its **SWAR fast
  paths** in the `valid*?` functions (7 bytes validated per stride via 56-bit
  bitwise arithmetic, with a documented reason: "56 bits is the largest width
  that fits in a BEAM small int on 64-bit ... at 64 bits every `w + 0x80..` would
  allocate a bignum on the heap and the optimisation would collapse"). That is a
  throughput optimization, not streaming. Source: `lib/elixir/lib/base.ex`.

## 10. Interesting design decisions

- **Two APIs for one operation: tagged tuple vs bang.** `decode64/2` returns
  `{:ok, binary} | :error`, `decode64!/2` returns `binary` or raises. The
  functional-style caller gets a total function; the pipeline-style caller gets
  an exception. Source: <https://hexdocs.pm/elixir/Base.html>
- **The bang function is the implementation; the tuple function is a rescue
  wrapper.** In the source both `decode64/2` and `decode32/2` are literally
  `{:ok, decode64!(string, opts)} rescue ArgumentError -> :error`. Source:
  `lib/elixir/lib/base.ex`. Consequence: the non-bang call is not cheaper, and
  the reason is lost — a deliberate but debatable trade-off.
- **Dedicated validation functions as a performance API.** `valid64?/2` and
  friends exist precisely so callers do not decode-and-discard; the docs say they
  are "both more performant and memory efficient". Source:
  <https://hexdocs.pm/elixir/Base.html>
- **Alphabet variants are named functions, not an options hash.**
  `encode64` vs `url_encode64` vs `hex_encode32` vs `encode32`; the variant is in
  the name, the tunables (`case`, `padding`, `ignore`) are in the options. This
  is more discoverable but grows the function count (five variants of encode and
  five of decode). Source: <https://hexdocs.pm/elixir/Base.html>
- **Case as a first-class option for base16/base32, absent for base64.** The
  `encode_case`/`decode_case` types exist only where an alphabet can be cased;
  `:mixed` is decode-only ("allows mixed case characters"). Note the RFC 4648 §12
  warning that case-insensitive base16/base32 handling enables a covert channel.
  Sources: <https://hexdocs.pm/elixir/Base.html>,
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
- **Whitespace handling is opt-in and narrower than MIME.** Elixir's
  `ignore: :whitespace` is documented per-function (`decode64`, `url_decode64`)
  and the source implements it as stripping exactly `\s\t\r\n`. Erlang, in
  contrast, always strips whitespace in `decode/2` and strips *everything*
  illegal in `mime_decode/2`. Sources: `lib/elixir/lib/base.ex`,
  <https://www.erlang.org/doc/apps/stdlib/base64.html>
- **A deliberate split between `decode` (strict) and `mime_decode` (lenient)**
  rather than one function with a policy enum, documented in the source comment
  as "decode crashes if an illegal character is found" versus "mime_decode strips
  away all characters not Base64". Source: `lib/stdlib/src/base64.erl`.
- **Two output representations in Erlang, chosen in the function name**
  (`encode` → binary, `encode_to_string` → charlist), which is a data-type choice
  inherited from Erlang's string/binary duality (deprecated charlist style; the
  Elixir side dropped it entirely and always returns binaries). Sources:
  <https://www.erlang.org/doc/apps/stdlib/base64.html>,
  <https://hexdocs.pm/elixir/Base.html>
- **Explicit, source-level performance engineering.** The `Base` source documents
  SWAR range checks (with per-range constants and the Lemire trick of extending
  the digit range to absorb `/`), 7-byte strides, an ASCII gate to prevent
  inter-lane carries, and inline annotations (`@compile {:inline, ...}`). This is
  unusually candid performance documentation for a stdlib. Source:
  `lib/elixir/lib/base.ex`.
- **`bitwise` and compile-time code generation.** `import Bitwise`, plus
  `for {base, alphabet} <- [...]` loops that generate the per-alphabet clauses at
  compile time and `elem({unquote_splicing(encoded)}, byte)` lookup tuples. The
  table-driven design is expressed metaprogrammatically instead of as a runtime
  map. Source: `lib/elixir/lib/base.ex`.
- **Erlang's alphabet tables are single `element/2` tuple lookups** with an
  integer offset switching between the two alphabets (`get_encoding_offset/1`,
  `get_decoding_offset/1`), i.e. a flattened 128-entry map per mode instead of a
  branch. Source: `lib/stdlib/src/base64.erl`.

## 11. Decisions NOT to copy

- **Returning `:error` and throwing the reason away.** `{:ok, x} rescue
  ArgumentError -> :error` collapses "non-alphabet character" and "incorrect
  padding" into one atom. A Mojo API with a typed error can and should keep the
  distinction. Source: `lib/elixir/lib/base.ex`.
- **Bang/non-bang duplication.** Ten near-identical function pairs (`encode64`
  and no bang, but five decode pairs with/without `!`) double the API surface and
  the documentation; Mojo's `raises` already encodes "may fail" in the signature,
  so a single raising function plus `try`/`except` covers both call styles.
  Sources: <https://hexdocs.pm/elixir/Base.html>,
  <https://mojolang.org/docs/manual/errors/>
- **Variant-as-a-new-function-name.** `encode64` / `url_encode64` /
  `hex_encode32` / `encode32` scales poorly if more alphabets arrive (Crockford,
  Multibase, base58); an alphabet *value* (or a `comptime` parameter) is the more
  extensible shape. Sources: <https://hexdocs.pm/elixir/Base.html>,
  <https://hex.pm/packages/multibase>
- **`decode16!/2` raising a "wrong length" `ArgumentError` from the same error
  type as "bad character".** Distinguishing shape errors from content errors
  makes recovery possible. Source: `lib/elixir/lib/base.ex`.
- **Case-insensitive decoding as an option without a canonicalizing default.**
  RFC 4648 §12 warns that accepting case variation lets an attacker alter case to
  defeat string comparisons; `:mixed` is useful, but it should never be the
  default. Sources: <https://hexdocs.pm/elixir/Base.html>,
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
- **Two output data types for the same operation** (`binary` vs charlist strings)
  — an Erlang heritage. Mojo has no such duality: one byte container, one result.
  Sources: <https://www.erlang.org/doc/apps/stdlib/base64.html>,
  buch `mojov1/appendix/cheat-sheet` (types table) citing
  <https://mojolang.org/docs/reference/types/>.
- **`mime_decode` as a silently-lossy decoder.** Skipping arbitrary characters
  contradicts RFC 4648 §3.3's MUST-reject default and §12's covert-channel
  warning. Sources: <https://www.erlang.org/doc/apps/stdlib/base64.html>,
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
- **Always stripping whitespace in the standard `decode/2`.** Erlang's strict
  decoder still silently ignores whitespace (`ws` entries in the decode table),
  so `"AQ ID BA=="` decodes; a caller who wants exactness cannot get it. Source:
  `lib/stdlib/src/base64.erl` (plus the doc example
  `base64:decode("AQ ID BA=="). -> <<1,2,3,4>>` at
  <https://www.erlang.org/doc/apps/stdlib/base64.html>).
- **No streaming API at all.** For network protocols, "buffer the whole message,
  then decode" is not always affordable; MojoAkku, built for sockets/TCP/HTTP,
  cannot inherit that limitation. Sources:
  <https://hexdocs.pm/elixir/Base.html>,
  <https://www.erlang.org/doc/apps/stdlib/base64.html>
- **Exposing `encode_to_string`/`decode_to_string` at all**: the charlist forms
  exist for legacy interop and create two mental models for "the result". Source:
  <https://www.erlang.org/doc/apps/stdlib/base64.html>

## 12. Ideas fitting Mojo

- **One raising function per operation, with a typed error.** Mojo errors are
  values, `def encode(...) raises EncodeError -> ...` keeps the Elixir
  bang/no-bang convenience without the duplicated surface, and a Mojo `try` block
  handles exactly one error type — so one error type with variants
  (`bad_character` / `incorrect_padding` / `wrong_length`) is the natural fit.
  Sources: buch `mojov1/errors/raising-and-propagation` and
  `mojov1/appendix/cheat-sheet#8. Error handling`, citing
  <https://mojolang.org/docs/manual/errors/>.
- **Value-in/value-out ownership.** Mojo's `Span[UInt8]` (documented as a
  non-owning view) as the input parameter and a returned `List[UInt8]` as the
  output mirror Elixir's `binary -> binary` shape while staying allocation-explicit.
  Sources: buch `mojov1/types/pointers-and-references` and
  `mojov1/appendix/cheat-sheet` (types table: `List[T]`, `Span[T, origin]`),
  citing <https://mojolang.org/docs/manual/pointers/using-pointers/>.
- **A separate validation path.** Elixir's `valid64?/2` is the right idea: an
  allocation-free validity check is cheaper than decode-and-discard, and the
  buch records `Bool` returns and SIMD-width reasoning as normal Mojo concerns.
  Sources: <https://hexdocs.pm/elixir/Base.html>, buch
  `mojov1/appendix/cheat-sheet` (`simd_width_of`, `Bool`) citing
  <https://mojolang.org/docs/std/>.
- **Compile-time alphabet selection.** Mojo's `comptime` and "Parameterized
  alias" let the alphabet be chosen at compile time (as Elixir generates its
  per-alphabet clauses at compile time with `for {base, alphabet} <- ...`),
  instead of a runtime branch or a new function name per variant. Sources: buch
  `mojov1/appendix/cheat-sheet` (`comptime`, "Parameterized alias",
  "Compile-time unroll") citing
  <https://mojolang.org/docs/manual/metaprogramming/comptime-evaluation/>;
  Elixir source technique: `lib/elixir/lib/base.ex`.
- **Bit-level tail handling with `comptime for`/pattern matching.** Elixir's
  `<<c1::12, c2::12, c3::12, c4::4>>`-style clauses are exactly the shape a Mojo
  encoder wants for the 1-/2-pad cases; Mojo's fixed-width integer types
  (`UInt8`–`UInt256`, `SIMD[dtype, length]`) make the quantum arithmetic explicit.
  Sources: `lib/elixir/lib/base.ex`; buch `mojov1/appendix/cheat-sheet` (types
  table) citing <https://mojolang.org/docs/reference/numeric-types/>.
- **Strict by default, lenient by explicit option.** Elixir's `padding: true` +
  narrow `ignore: :whitespace` is closer to RFC 4648 §3.2/§3.3 than Erlang's
  always-whitespace-stripping `decode`; Mojo should follow Elixir here and make
  every relaxation explicit. Sources: <https://hexdocs.pm/elixir/Base.html>,
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
- **Streaming as a first-class, later phase.** Neither Elixir nor Erlang offers
  incremental encode/decode, so this is greenfield: a stateful encoder/decoder
  holding the leftover partial quantum (a small fixed-size inline buffer) fits
  Mojo's `Span`/ownership model and is needed for the socket/TCP/HTTP siblings.
  Sources: <https://hexdocs.pm/elixir/Base.html>,
  <https://www.erlang.org/doc/apps/stdlib/base64.html>; buch
  `mojov1/types/pointers-and-references`.
- **Canonical-encoding rejection.** RFC 4648 §3.5 lets a decoder reject non-zero
  pad bits; Elixir's strict padding mode is the closest existing behaviour and
  Mojo can make the canonical check an explicit, typed failure. Sources:
  <https://www.rfc-editor.org/rfc/rfc4648.txt>,
  <https://hexdocs.pm/elixir/Base.html>
- **Documented performance engineering.** The Elixir source's SWAR notes and the
  BEAM small-int constraint are a model for the kind of `Performance:` docstring
  section the Mojo buch already recommends. Sources: `lib/elixir/lib/base.ex`;
  buch `mojov1/appendix/cheat-sheet#11. Docstring skeleton` citing
  <https://mojolang.org/docs/reference/docstrings/>.

## Sources

- Elixir `Base` (v1.20.4): <https://hexdocs.pm/elixir/Base.html>
- Elixir `Base` source (v1.20.4): <https://raw.githubusercontent.com/elixir-lang/elixir/v1.20.4/lib/elixir/lib/base.ex>
- Elixir `Base` source anchors (v1.20.4): <https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/base.ex#L710>,
  <https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/base.ex#L836>,
  <https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/base.ex#L932>
- Elixir `Base` (v1.18.1, for the pre-`valid*?` function set):
  <https://hexdocs.pm/elixir/1.18.1/Base.html>
- Erlang `base64` (OTP 29.1): <https://www.erlang.org/doc/apps/stdlib/base64.html>
- Erlang `base64` source (OTP 26.0): <https://raw.githubusercontent.com/erlang/otp/OTP-26.0/lib/stdlib/src/base64.erl>
- Erlang `base64` source (OTP 28.0): <https://raw.githubusercontent.com/erlang/otp/OTP-28.0/lib/stdlib/src/base64.erl>
- STDLIB release notes: <https://www.erlang.org/doc/apps/stdlib/notes.html>
- RFC 4648 — The Base16, Base32, and Base64 Data Encodings: <https://www.rfc-editor.org/rfc/rfc4648.txt>
- Hex: `base64url`: <https://hex.pm/packages/base64url>
- Hex: `base32`: <https://hex.pm/packages/base32>; docs: <https://base32.hexdocs.pm/base32.html>
- Hex: `crockford_base32`: <https://hex.pm/packages/crockford_base32>
- Hex: `multibase`: <https://hex.pm/packages/multibase>
- GitHub: `voldy/base32_crockford`: <https://github.com/voldy/base32_crockford>
- Java comparison point quoted in section 5: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>
- Mojo buch `mojov1`: `errors/raising-and-propagation`, `types/pointers-and-references`, `appendix/cheat-sheet` (<https://mojolang.org/docs/manual/errors/>, <https://mojolang.org/docs/manual/pointers/using-pointers/>, <https://mojolang.org/docs/reference/types/>, <https://mojolang.org/docs/reference/numeric-types/>, <https://mojolang.org/docs/reference/docstrings/>)
