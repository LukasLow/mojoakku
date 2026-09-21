# base64 research: Elixir

Scope: Elixir `Base` (pure-Elixir stdlib) **and** the underlying Erlang/OTP
`base64` module, since a reader of this file needs the BEAM/Erlang side too.
All claims cite the Elixir v1.20.4 docs/source and the OTP 29.1 docs/source
unless marked otherwise.

## 1. Standard library support

Elixir ships `Base`, "data encoding and decoding functions according to
[RFC 4648]", defining base 16, base 32 and base 64 schemes
(https://hexdocs.pm/elixir/Base.html; source
`elixir/lib/elixir/lib/base.ex` v1.20.4). It is a **pure-Elixir** module and
does **not** delegate to Erlang's `:base64` (no `:base64` call appears in
`base.ex`; `(Assessment: derived from the base.ex source)`).

Covered alphabets: base16 (`encode16`/`decode16`), base32 (`encode32`/
`decode32`), base32 extended-hex (`hex_encode32`/`hex_decode32`), base64
(`encode64`/`decode64`), base64 URL/filename-safe (`url_encode64`/
`url_decode64`) — https://hexdocs.pm/elixir/Base.html#summary.

Erlang/OTP ships a separate `base64` module in `stdlib`, described as
"Provides base64 encode and decode, see RFC 2045"
(https://www.erlang.org/doc/apps/stdlib/base64.html; source
`lib/stdlib/src/base64.erl` OTP-29.1). It covers **only base64** (standard and
URL-safe); there is no base16/base32 in Erlang stdlib
(`lib/stdlib/src/base64.erl:43` lists only base64 alphabet chars). So on the
BEAM, base16/base32 come from Elixir's `Base` only, while base64 can be done by
either implementation.

Types declared by `Base`:
- `@type encode_case :: :upper | :lower` (`base.ex:99`)
- `@type decode_case :: :upper | :lower | :mixed` (`base.ex:100`)

Neither implementation offers base58/base62, MIME line-wrapping, or streaming
(see §9). `(Assessment: derived from Base summary and base64 export list.)`

## 2. Relevant community libraries

| name | maintainer / publisher | maturity | license | notes |
| --- | --- | --- | --- | --- |
| `base64url` (hex 1.0.1) | publisher `potatosalad`; repo `dvv/base64url` | last updated Jul 28 2019; 43,091,702 all-time downloads; 8 dependants | MIT | standalone URL-safe base64 codec, Erlang module, no padding; adds `encode_mime` for padded URL-safe (https://hex.pm/packages/base64url, https://github.com/dvv/base64url) |
| `multibase` (hex 0.0.1) | publisher `nocursor`; repo `nocursor/ex-multibase` | last updated Nov 14 2018; one version only; 15,110 all-time downloads | MIT | 22 encodings incl. base16/32/32hex/58/64 + pad variants; self-describing prefix; returns `{:ok,_}`/`:error`/`{:error,_}` and bang variants (https://hex.pm/packages/multibase, https://github.com/nocursor/ex-multibase) |
| `b58` / `base58` | e.g. `dwyl/base58` | niche, crypto/IPFS oriented | (per package) | Base58 `encode/1`/`decode/1`, e.g. for IPFS CID (https://hex.pm/packages/b58, https://github.com/dwyl/base58) |
| `base62` | Hex package | small | (per package) | Base62 encoder/decoder pure Elixir (https://hex.pm/packages/base62) |

`base64url`'s own README documents the padding split explicitly: plain
`encode` emits `_3_-_A` (no padding) while `encode_mime` emits `_3_-_A==`
(padded, "for MIME compatibility") (https://github.com/dvv/base64url).

## 3. Exposed APIs

Elixir `Base` (https://hexdocs.pm/elixir/Base.html):
- Base16: `encode16(data, opts \\ [])`, `decode16/2` (`{:ok, binary} | :error`),
  `decode16!/2` (raises), `valid16?/2` (since 1.19.0). Option: `:case`
  (https://hexdocs.pm/elixir/Base.html#encode16/2, `base.ex:431`, `:518`, `:555`, `:603`).
- Base32: `encode32/2`, `decode32/2`, `decode32!/2`, `valid32?/2`; option
  `:case` + `:padding`; plus `hex_encode32/2`, `hex_decode32/2`,
  `hex_decode32!/2`, `hex_valid32?/2` (`base.ex:1259`, `:1416`, `:1462`, `:1501`,
  `:1302`, `:1549`, `:1596`, `:1635`).
- Base64: `encode64/2`, `decode64/2`, `decode64!/2`, `valid64?/2`; URL-safe:
  `url_encode64/2`, `url_decode64/2`, `url_decode64!/2`, `url_valid64?/2`
  (`base.ex:710`, `:836`, `:870`, `:904`, `:732`, `:932`, `:964`, `:998`).
- Options: `:padding` (encode+decode), `:case` (encode16/32/decode16/32),
  `:ignore` (`:whitespace`, base64 decode). Base64 decode does **not** expose
  `:case` (its alphabet is fixed-case) (`base.ex:836`, `url_decode64:932`).
- No MIME-wrap function exists in `Base`.

Erlang/OTP `base64` (https://www.erlang.org/doc/apps/stdlib/base64.html):
- `encode/1`, `encode/2`, `decode/1`, `decode/2`, `mime_decode/1`,
  `mime_decode/2`, `encode_to_string/1,2`, `decode_to_string/1,2`,
  `mime_decode_to_string/1,2`, `format_error/2`
  (`lib/stdlib/src/base64.erl` export list ~L29).
- Option map `#{mode => standard | urlsafe, padding => boolean}` for both
  encode and decode; default `#{mode => standard, padding => true}`
  (`base64.erl:84`, `:109`).
- `encode/decode` return/accept `binary()`; the `_to_string` variants work on
  byte lists / `byte_string()` (`base64.erl:114`–`:120`).
- `mode` and `padding` options were added in **OTP 26.0**
  (https://www.erlang.org/doc/apps/stdlib/base64.html, "since OTP 26.0").

Community: `base64url` exposes `encode/1`, `decode/1`, `encode_mime/1`
(https://github.com/dvv/base64url). `multibase` exposes `encode/2`,
`encode!/2`, `decode/1`, `decode!/1`, `codec_decode/1`, `encodings/0`,
`encodings_for!/1`, `encoding_family!/1`, `prefix/1`, `prefix!/1`, `multibase/2`,
`multibase!/2` (https://github.com/nocursor/ex-multibase).

## 4. Error representation

Elixir `Base` uses a **dual API**: the plain function returns a tagged tuple,
the bang version raises an exception.
- `decode64("bad")` → `:error`; `decode64!("bad")` raises `ArgumentError`
  ("non-alphabet character found ..." / "incorrect padding")
  (`base.ex` `decode64/2` wraps `{:ok, decode64!(...)} rescue ArgumentError -> :error`;
  `bad_character!` helper in `base.ex`; https://hexdocs.pm/elixir/Base.html#decode64/2).
- Note the plain form loses **all** error detail: it always collapses to the
  bare atom `:error`, never `{:error, reason}`
  (`base.ex:836`–`:842`). `(Assessment: derived from the source.)`
- `decode16!` raises a length-specific `ArgumentError` when
  `rem(byte_size(string), 2) != 0` (`base.ex:555`–`:570`).
- The `valid*?` predicates (1.19.0) return `boolean()` and never raise
  (`base.ex:603`, `:904`, `:1501`, `:1635`).

Erlang/OTP `base64` raises Erlang errors instead of returning tuples:
- Missing `=` padding raises `error:missing_padding` with `format_error/2`
  producing "data to decode is missing final = padding characters, if this is
  intended, use the `padding => false` option"
  (`base64.erl` `missing_padding_error/0` + `format_error/2`).
- Illegal characters in strict `decode/2` produce a function_clause/badarg-style
  crash (the `b64d` lookup yields `bad` and no clause matches), whereas
  `mime_decode/2` silently strips illegal characters
  (`base64.erl` `b64d` table + `mime_decode` comment).

`multibase` returns `:error` for malformed input and `{:error, :unsupported_encoding}`
for unknown encoding ids, with `!` variants raising
(https://github.com/nocursor/ex-multibase).

## 5. Ownership semantics (buffer/ownership of input and output)

Elixir/Erlang have **no manual ownership and no explicit free** — data is
immutable and garbage-collected. The relevant "ownership" question is
**buffer representation and copying**:
- Encode input is a `binary` (Elixir guard `when is_binary(data)`,
  `base.ex:431` etc.). Decode input is a `binary` too. Erlang additionally
  accepts byte lists and its `_to_string` variants return byte lists
  (`base64.erl:114`–`:120`).
- The produced output is a **new** binary; `Base` builds it with an accumulator
  append `<<acc::binary, ...>>` (`base.ex` encode clauses), which is exactly the
  BEAM-optimized append pattern. OTP documents that appending to a binary is
  cheap and avoids copying, while prepending copies every time
  (https://www.erlang.org/doc/system/binaryhandling.html).
- BEAM binaries come in four internal flavours: refc binaries (reference-counted,
  outside process heaps), heap binaries (≤64 bytes, on the heap), sub binaries
  and match contexts (both references into a larger binary). Matching out a
  binary is cheap because data is not copied
  (https://www.erlang.org/doc/system/binaryhandling.html).
- Copying is forced when a binary is sent as a message, inserted into ETS,
  passed to a port/NIF, or matched and then re-appended — because the append
  optimization requires a single ProcBin/single reference
  (https://www.erlang.org/doc/system/binaryhandling.html). For a codec this
  means the caller keeps the encoded/decoded binary and the GC reclaims it.
- `base64url` returns the same ownership model (immutable binary in, new binary
  out) (https://github.com/dvv/base64url).

`(Assessment: derived from binaryhandling.html + base.ex/base64.erl.)`

## 6. Blocking / non-blocking

Not applicable. `Base` and Erlang `base64` are pure, synchronous, CPU-bound
functions with no I/O and no yield points; each call runs to completion on the
calling scheduler (`(Assessment: derived from the function signatures — no
processes, ports, or NIFs in base.ex; Erlang base64.erl is pure Erlang, not a
NIF).`). Because the Erlang implementation is pure Erlang
(`lib/stdlib/src/base64.erl`), large payloads run on a normal scheduler; only a
NIF/port implementation would raise dirty-scheduler questions, and neither
stdlib does. Elixir's version deliberately adds SIMD-within-a-register (SWAR)
fast paths inside the same synchronous call (see §10).

## 7. Alphabet variants and padding

| scheme | alphabet | pad char | notes |
| --- | --- | --- | --- |
| base16 | `0123456789ABCDEF` | none | `Base.encode16`; `:case` upper/lower; no padding option |
| base32 | `ABCDEFGHIJKLMNOPQRSTUVWXYZ234567` | `=` | standard RFC 4648 §6 |
| base32hex | `0123456789ABCDEFGHIJKLMNOPQRSTUV` | `=` | `hex_encode32`, RFC 4648 §7 |
| base64 | `A–Za–z0–9+/` | `=` | standard RFC 4648 §4 |
| base64url | `A–Za–z0–9-_` | `=` | `url_encode64`, RFC 4648 §5 |

Alphabets are hard-coded character lists in `base.ex`
(`b16_alphabet`, `b32_alphabet`, `b32hex_alphabet`, `b64_alphabet`,
`b64url_alphabet`, `base.ex` around L104–L108), so they are **fixed at compile
time and not user-pluggable** — there is no custom-alphabet API.

Padding: default is **on** (`padding: true`) for base32 and base64; passing
`padding: false` omits padding on encode and ignores it on decode
(`base.ex:710`, `:836`, `:1259`, `:1416`). Base16 has no padding concept and
therefore no `:padding` option (`base.ex:431`). Case handling: encode accepts
`:upper`/`:lower`; decode accepts `:upper` (default), `:lower`, or `:mixed`;
base64 decode has no `:case` option because its alphabet is case-sensitive but
its decoder already maps both cases (`base.ex:99`–`:100`, `decode64`).

Erlang `base64` exposes **two** alphabets via `mode`: `standard` (`+`/`/`, then
`-`/`_` illegal) and `urlsafe` (`-`/`_`, then `+`/`/` illegal), selected by an
integer offset into one shared lookup table — `get_decoding_offset/1` returns 1
or 257, `get_encoding_offset/1` returns 1 or 65 (`base64.erl` accessors). This
is a compact "two alphabets, one table" trick.

What does **not** exist: z-base-32, base32 with URL-safe `-`/`_`, custom
alphabets, MIME line breaks, unpadded base16 (irrelevant), base45/base85.
`(Assessment: derived from Base summary + base64.erl mode types.)`

## 8. Timeouts

Not applicable — no blocking operation, so no timeout or cancellation surface
exists in `Base`, Erlang `base64`, `base64url` or `multibase`
(`(Assessment: derived from the public API lists; none of them accept a timeout
or cancellation token).`).

## 9. Streaming / incremental encode+decode

**Neither Elixir `Base` nor Erlang `base64` offers streaming or incremental
encode/decode.** Every function is one-shot over a complete in-memory binary:
`encode64(data)`, `decode64(string)` (`base.ex`; `base64.erl`). There is no
`init`/`update`/`finish` decoder, no chunk API, and no documented carry-over of
leftover bytes across calls.

Consequences / evidence:
- Decode requires the padding to be complete (unless `padding: false`); the
  strict decoder raises or errors on truncation, so partial input cannot simply
  be fed in without the caller managing boundaries
  (`base.ex` "incorrect padding"; `base64.erl` `missing_padding_error/0`).
- Erlang's `decode/2` strips whitespace and then processes the whole binary in
  fixed 4-character groups (`decode_binary/4` and helper clauses in
  `base64.erl`), i.e. the loop is internal to a single call.
- `mime_decode/2` is the lenient variant (strips illegal chars, ignores padding
  count), which is the closest thing to "robust input handling", but it is still
  whole-buffer (`base64.erl` mime_decode clauses).
- The `_to_string` variants differ only in output container type, not in
  streaming (`base64.erl:114`–`:120`).

If chunked processing is needed, the caller must buffer to a multiple of the
group size (3 bytes for base64, 5 for base32, 1 for base16) and carry the
remainder manually; nothing in the stdlib does this. `(Assessment: derived from
the absence of any init/update/finish API in both sources.)`

## 10. Interesting design decisions

1. **Dual API: tuple vs bang.** Every decoder exists twice — `decode64/2`
   returning `{:ok, bin} | :error` and `decode64!/2` raising `ArgumentError`.
   The tuple form is implemented as `rescue ArgumentError -> :error` around the
   bang form (`base.ex:836`), i.e. exceptions are the single internal error
   mechanism and tuples are a lossy convenience wrapper.
2. **Dedicated `valid*?` predicates (since 1.19.0).** `valid64?`, `valid32?`,
   `valid16?`, `hex_valid32?`, `url_valid64?` validate without allocating the
   decoded output; the docs explicitly justify them as "more performant and
   memory efficient than using decode..., checking the result is `{:ok, ...}`,
   and then discarding the decoded binary" (`base.ex:603`, `:904`; docs
   "When to use this").
3. **SWAR fast paths.** 1.19's validators process 7 bytes per stride with
   bitwise range checks packed into a 56-bit integer, keeping within the BEAM
   59-bit fixnum range to avoid bignum allocation; comments cite OTP PR #10938
   and a Lemire SWAR trick (`base.ex` SWAR comments around L150–L210).
4. **Option model.** Elixir uses an untyped keyword list (`case: :mixed`,
   `padding: false`, `ignore: :whitespace`); Erlang uses a typed map
   `#{mode => standard | urlsafe, padding => boolean}` with documented defaults
   (`base64.erl:84`, `:109`). Erlang's typed map is the better-modelled of the
   two.
5. **Two alphabets, one table.** Erlang selects standard vs urlsafe by an
   integer offset into a single character/digit table
   (`get_encoding_offset/1`, `get_decoding_offset/1`), a terse
   dispatch-table design.
6. **`mime_decode` vs `decode`.** A deliberate lenient/strict split: MIME strips
   illegal characters and does not count padding, strict `decode` refuses
   illegal characters and enforces padding (`base64.erl` comments and clauses).
7. **Container-type variants.** `encode` vs `encode_to_string` and
   `decode` vs `decode_to_string` return binary vs byte list separately, rather
   than one function with a mode flag (`base64.erl:114`–`:120`).
8. **Structured Erlang error.** `missing_padding` is a named error atom paired
   with `format_error/2`, so tooling can render a precise message
   (`base64.erl` `format_error/2`).

## 11. Decisions NOT to copy

- **Bare `:error` as the only non-raising failure** (`Base.decode64`): it
  destroys the reason (bad char vs bad padding vs bad length). MojoAkku should
  carry a structured error enum instead. `(Assessment: derived from base.ex
  rescue clause.)`
- **Exceptions as the internal control flow** (`decode!` + `rescue
  ArgumentError`): an allocation-free `Result`/`raises` design is clearer and
  cheaper. `(Assessment: derived from base.ex.)`
- **Untyped keyword-list options** (`padding:`, `case:`, `ignore:`): stringly/
  symbol-typed and validated only at runtime; Mojo should use compile-time
  enums/`comptime` parameters.
- **Two overlapping stdlib implementations on one VM** (Elixir `Base` and
  Erlang `base64`), with different option models and different error styles —
  a maintenance/duplication hazard worth *not* reproducing: one codec, one
  option model.
- **Fixed, non-pluggable alphabets** (hard-coded char lists): fine for a
  minimal core, but it blocks z-base-32/other alphabets without forking; if
  MojoAkku claims alphabet extensibility, it must be designed in, not patched
  in.
- **BEAM-specific micro-optimizations as API** (the 257/65 offset table):
  interesting technically, but it is an implementation detail tied to the BEAM
  and must not shape the public API.
- **No streaming API at all**: not a behaviour to copy; a codec library can
  cheaply expose an incremental state type.
- **Lenient-by-default MIME semantics** (`mime_decode` silently dropping
  characters): acceptable as an explicit opt-in, dangerous as a default.

## 12. Ideas fitting Mojo

- **Comptime alphabets / padding policy.** `Base` hard-codes alphabets; Mojo
  can take the alphabet and the padding policy as `comptime` parameters and
  specialize the encode/decode loop, removing all runtime branching (mirrors
  `base.ex`'s compile-time character lists, but user-selectable).
- **Typed errors via `raises`.** Replace `{:ok,_}|:error` + `ArgumentError`
  with a `raises DecodeError` (or an error enum: `InvalidChar`, `BadPadding`,
  `WrongLength`), matching Mojo's explicit error model and beating both the
  bare `:error` and the Erlang crash.
- **Validation without allocation.** Copy the `valid64?` idea: a
  `borrowed`-input predicate that returns `Bool` and allocates nothing, next to
  a decoding function that returns an owned buffer — this maps directly onto
  Mojo ownership (`borrowed` in / owned `List[UInt8]` out).
- **Value semantics for containers.** Input as `borrowed`/`Span`, output as an
  owned `List[UInt8]`; no GC, no ProcBin/sub-binary complexity — Mojo's value
  semantics make the ownership story in §5 disappear, so the API should not
  carry BEAM-specific lifetime language.
- **Explicit incremental decoder.** Design an `IncrementalDecoder` value type
  that owns the leftover-byte carry; Mojo value semantics make such a state
  natural, and it fills the gap both stdlibs leave open (§9).
- **One option model, not two.** Use a single parameter/enum model for
  alphabet + padding (Elixir keyword list and Erlang map are both weaker),
  documented once.
- **SWAR-style fast validation as an implementation technique**, not an API:
  the 7-byte-per-stride range-check trick from `base.ex` is portable to Mojo
  and worth studying for the validator, while staying invisible in the public
  surface.

## Sources

- Elixir `Base` docs (v1.20.4): https://hexdocs.pm/elixir/Base.html
- Elixir `Base` source: `elixir/lib/elixir/lib/base.ex` (v1.20.4) —
  https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/base.ex
  (cited line anchors from hexdocs: encode16 L431, decode16 L518, decode16!
  L555, valid16? L603, encode64 L710, url_encode64 L732, decode64 L836,
  decode64! L870, valid64? L904, url_decode64 L932, url_decode64! L964,
  url_valid64? L998, encode32 L1259, hex_encode32 L1302, decode32 L1416,
  decode32! L1462, valid32? L1501, hex_decode32 L1549, hex_decode32! L1596,
  hex_valid32? L1635, types L99–L100)
- Erlang/OTP `base64` docs (OTP 29.1, stdlib 8.1):
  https://www.erlang.org/doc/apps/stdlib/base64.html
- Erlang/OTP `base64` source: `lib/stdlib/src/base64.erl` (OTP-29.1) —
  https://github.com/erlang/otp/blob/OTP-29.1/lib/stdlib/src/base64.erl
- Erlang binary handling / ownership: "Constructing and Matching Binaries",
  https://www.erlang.org/doc/system/binaryhandling.html
- RFC 4648: https://datatracker.ietf.org/doc/html/rfc4648 (referenced by both
  stdlibs)
- `base64url`: https://hex.pm/packages/base64url and
  https://github.com/dvv/base64url
- `multibase`: https://hex.pm/packages/multibase and
  https://github.com/nocursor/ex-multibase
- `b58`: https://hex.pm/packages/b58 and https://github.com/dwyl/base58
- `base62`: https://hex.pm/packages/base62
