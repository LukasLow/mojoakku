# base32 research: Elixir

Scope: Elixir `Base` (pure-Elixir stdlib) **and** the underlying Erlang/OTP
`base64` module, since a reader of this file needs the BEAM/Erlang side too.
All claims cite the Elixir v1.20.4 docs/source and the OTP 29.1 docs unless
marked otherwise.

## 1. Standard library support

Elixir ships `Base`, "data encoding and decoding functions according to RFC
4648", defining base 16, base 32 and base 64 schemes
(https://hexdocs.pm/elixir/Base.html; source
`elixir/lib/elixir/lib/base.ex` v1.20.4). It is a **pure-Elixir** module and
does **not** delegate to Erlang's `:base64` (no `:base64` call appears in
`base.ex`; Assessment: derived from the base.ex source).

Base32 is covered by the **standard alphabet** (`encode32`/`decode32`) and the
**extended-hex alphabet** (`hex_encode32`/`hex_decode32`), alongside base16 and
base64/64url. (Source: https://hexdocs.pm/elixir/Base.html#summary)

Erlang/OTP ships a separate `base64` module in `stdlib` described as "Provides
base64 encode and decode, see RFC 2045"
(https://www.erlang.org/doc/apps/stdlib/base64.html). It covers **only base64**
(standard and URL-safe); there is no base16/base32 in Erlang stdlib
(`lib/stdlib/src/base64.erl` lists only base64 alphabet chars). So on the BEAM,
base32 comes from Elixir's `Base` only. (Assessment: derived from the `Base`
summary and the Erlang `base64` export list.)

Types declared by `Base`:
- `@type encode_case :: :upper | :lower` (`base.ex:99`)
- `@type decode_case :: :upper | :lower | :mixed` (`base.ex:100`)

There is no Crockford, no z-base-32, no base32 without padding beyond the
`:padding` option, and no streaming (see §9). (Assessment: derived from the
`Base` summary.)

**Mojo anchor:** Mojo's stdlib has no base32. The `mojov1` buch `stdlib/base64`
page records only `b64encode`, `b64decode`, `b16encode`, `b16decode`; a
`buch_search` for "base32" returns no hits. (Source: `mojov1` buch
`stdlib/base64`.)

## 2. Relevant community libraries

| name | maintainer / publisher | maturity | license | base32 notes |
| --- | --- | --- | --- | --- |
| `base64url` (hex 1.0.1) | `potatosalad` / repo `dvv/base64url` | last updated Jul 28 2019; 43M all-time downloads | MIT | URL-safe base64 only; no base32 (https://hex.pm/packages/base64url) |
| `multibase` (hex 0.0.1) | `nocursor` / `nocursor/ex-multibase` | one version, Nov 2018; 15k downloads | MIT | 22 encodings incl. base16/32/32hex/58/64 + pad variants; self-describing prefix; returns `{:ok,_}`/`:error`/`{:error,_}` and bang variants (https://hex.pm/packages/multibase, https://github.com/nocursor/ex-multibase) |
| `base58` / `b58` | e.g. `dwyl/base58` | niche, crypto/IPFS | per package | Base58 only, not base32 (https://hex.pm/packages/b58) |
| `base62` | Hex package | small | per package | Base62 only (https://hex.pm/packages/base62) |

(Assessment: derived from the Hex listings above: on the BEAM, base32 is almost
entirely served by the stdlib `Base`; only `multibase` adds base32 as one of many
self-describing encodings.)

## 3. Exposed APIs

Elixir `Base` (Source: https://hexdocs.pm/elixir/Base.html):

- Base32 standard: `encode32(data, opts \\ [])`, `decode32(string, opts \\ [])`
  returning `{:ok, binary} | :error`, `decode32!/2` raising `ArgumentError`, and
  since **1.19.0** `valid32?/2` returning `boolean()`.
- Base32 extended-hex: `hex_encode32/2`, `hex_decode32/2`, `hex_decode32!/2`,
  `hex_valid32?/2` (source anchors `base.ex:1259`, `:1302`, `:1416`, `:1462`,
  `:1501`, `:1549`, `:1596`, `:1635`).
- Options for base32: `:case` (`:upper` default | `:lower` | `:mixed`) and
  `:padding` (`true` default | `false`). There is **no `:ignore` option for
  base32** (unlike base64, which accepts `ignore: :whitespace`). (Source:
  https://hexdocs.pm/elixir/Base.html#decode32/2)
- `encode32(data, padding: false)` omits `=`; `decode32(string, padding: false)`
  ignores padding. (Source:
  https://hexdocs.pm/elixir/Base.html#encode32/2)
- No MIME-wrap function and no base32 line-wrapping exist in `Base`. (Assessment:
  derived from the `Base` summary.)

Erlang/OTP `base64`: `encode/1,2`, `decode/1,2`, `mime_decode/1,2`,
`encode_to_string/1,2`, `decode_to_string/1,2`, `mime_decode_to_string/1,2`,
`format_error/2`; option map `#{mode => standard | urlsafe, padding => boolean}`
(default `#{mode => standard, padding => true}`), added in OTP 26.0. **No base32
API.** (Source: https://www.erlang.org/doc/apps/stdlib/base64.html)

Community: `multibase` exposes `encode/2`, `encode!/2`, `decode/1`, `decode!/1`,
`codec_decode/1`, `encodings/0`, `encoding_family!/1`, `prefix/1`, `multibase/2`
(https://github.com/nocursor/ex-multibase).

## 4. Error representation

Elixir `Base` uses a **dual API**: the plain function returns a tagged tuple, the
bang version raises an exception.

- `decode32("bad")` → `:error`; `decode32!("bad")` raises `ArgumentError`
  ("non-alphabet character found …" / "incorrect padding"). `decode32!` "raises
  if the padding is incorrect or a non-alphabet character is present in the
  string." (Source: https://hexdocs.pm/elixir/Base.html#decode32!/2)
- The plain tuple form loses **all** error detail: it always collapses to the
  bare atom `:error`, never `{:error, reason}` (Assessment: derived from the
  `decode32/2` implementation wrapping the bang form).
- The `valid32?/2` predicate (1.19.0) returns `boolean()` and never raises; the
  docs justify it as "more performant and memory efficient than using
  `decode32/2`, checking that the result is `{:ok, ...}`, and then discarding the
  decoded binary." (Source: https://hexdocs.pm/elixir/Base.html#valid32?/2)
- Erlang/OTP `base64` raises Erlang errors instead: missing `=` padding raises
  `error:missing_padding` with `format_error/2` rendering "data to decode is
  missing final = padding characters, if this is intended, use the `padding =>
  false` option"; illegal characters in strict `decode/2` produce a
  function_clause/badarg-style crash, whereas `mime_decode/2` silently strips
  illegal characters. This is base64-only, cited for contrast. (Source:
  https://www.erlang.org/doc/apps/stdlib/base64.html)

`multibase` returns `:error` for malformed input and
`{:error, :unsupported_encoding}` for unknown encoding ids, with `!` variants
raising (https://github.com/nocursor/ex-multibase).

## 5. Ownership semantics

Elixir/Erlang have **no manual ownership and no explicit free** — data is
immutable and garbage-collected. The relevant "ownership" question is **buffer
representation and copying**:

- Encode input is a `binary`; decode input is a `binary` too. The produced output
  is a **new** binary. Erlang documents that appending to a binary is cheap and
  avoids copying, while prepending copies every time
  (https://www.erlang.org/doc/system/binaryhandling.html).
- BEAM binaries come in four internal flavours: refc binaries, heap binaries
  (≤64 bytes, on the heap), sub binaries and match contexts; matching out a
  binary is cheap because data is not copied
  (https://www.erlang.org/doc/system/binaryhandling.html).
- Copying is forced when a binary is sent as a message, inserted into ETS, passed
  to a port/NIF, or matched and then re-appended
  (https://www.erlang.org/doc/system/binaryhandling.html). For a codec this means
  the caller keeps the encoded/decoded binary and the GC reclaims it.

(Assessment: derived from binaryhandling.html and base.ex; the base32 functions
follow the same immutable-binary model as the base64 ones.)

## 6. Blocking / non-blocking

Not applicable. `Base` (and Erlang `base64`) are pure, synchronous, CPU-bound
functions with no I/O and no yield points; each call runs to completion on the
calling scheduler. Because the implementation is pure Elixir, large payloads run
on a normal scheduler; a NIF/port implementation would raise dirty-scheduler
questions, and neither stdlib is one. (Assessment: derived from the function
signatures — no processes, ports or NIFs in base.ex.)

## 7. Alphabet variants, case and padding

| scheme | alphabet | pad char | notes |
| --- | --- | --- | --- |
| base16 | `0123456789ABCDEF` | none | `Base.encode16`; `:case` upper/lower; no padding option |
| base32 | `ABCDEFGHIJKLMNOPQRSTUVWXYZ234567` | `=` | standard RFC 4648 §6 |
| base32hex | `0123456789ABCDEFGHIJKLMNOPQRSTUV` | `=` | `hex_encode32`, RFC 4648 §7 |
| base64 | `A–Za–z0–9+/` | `=` | standard RFC 4648 §4 |
| base64url | `A–Za–z0–9-_` | `=` | `url_encode64`, RFC 4648 §5 |

Alphabets are hard-coded character lists in `base.ex` (`b16_alphabet`,
`b32_alphabet`, `b32hex_alphabet`, `b64_alphabet`, `b64url_alphabet`), so they
are **fixed at compile time and not user-pluggable** — there is no
custom-alphabet API. (Assessment: derived from the source.)

Padding: default is **on** (`padding: true`) for base32 and base64; passing
`padding: false` omits padding on encode and ignores it on decode
(`base.ex:1259`, `:1416`). Base16 has no padding concept and therefore no
`:padding` option (`base.ex:431`). (Source:
https://hexdocs.pm/elixir/Base.html#decode32/2)

Case handling: encode accepts `:upper` (default) / `:lower`; decode accepts
`:upper` (default), `:lower`, or `:mixed`. The docs' own examples:
`Base.decode32("MZXW6YTBOI======")` → `{:ok, "foobar"}`;
`Base.decode32("mzxw6ytboi======", case: :lower)` → `{:ok, "foobar"}`;
`Base.decode32("mzXW6ytBOi======", case: :mixed)` → `{:ok, "foobar"}`;
`Base.decode32("MZXW6YTBOI", padding: false)` → `{:ok, "foobar"}`. This is a
*stricter* case model than Python's single `casefold` boolean: it distinguishes
"all lower" from "mixed". (Source:
https://hexdocs.pm/elixir/Base.html#decode32/2)

What does **not** exist: Crockford base32, z-base-32, base32 with URL-safe
`-`/`_`, custom alphabets, MIME line breaks, base45/base85. (Assessment: derived
from the `Base` summary and `base64.erl` mode types.)

RFC 4648 reference: §6 Table 3 (`A-Z2-7`), §7 Table 4 (`0-9A-V`), §3.2 padding,
§3.4 confusables, §3.5 canonical encoding; §12 warns that case-insensitive
handling of the base16/base32 alphabets "can be used to leak information or make
string equality comparisons fail". (https://www.rfc-editor.org/rfc/rfc4648.txt)

## 8. Timeouts

Not applicable — no blocking operation, so no timeout or cancellation surface
exists in `Base`, Erlang `base64` or `multibase`. (Assessment: derived from the
public API lists; none of them accept a timeout or cancellation token.)

## 9. Streaming / incremental encode and decode

**Neither Elixir `Base` nor Erlang `base64` offers streaming or incremental
encode/decode for base32.** Every function is one-shot over a complete in-memory
binary: `encode32(data)`, `decode32(string)` (`base.ex`). There is no
`init`/`update`/`finish` decoder, no chunk API and no documented carry-over of
leftover bytes across calls.

Consequences / evidence:
- Decode requires the padding to be complete unless `padding: false`; the strict
  decoder raises or errors on truncation, so partial input cannot simply be fed
  in without the caller managing boundaries
  (`base.ex` "incorrect padding"; `base64.erl` `missing_padding_error/0`).
- For base32 the caller must buffer to a multiple of **5 bytes** on encode and a
  multiple of **8 symbols** on decode, carrying the remainder manually; nothing
  in the stdlib does this. This is the base32-specific carry — 0–4 input bytes /
  0–7 symbols. (Assessment: derived from the absence of any init/update/finish
  API and the RFC 4648 §6 quantum.)
- The `valid32?/2` predicate validates without allocating the decoded output but
  is still whole-buffer.

## 10. Interesting design decisions

1. **Dual API: tuple vs bang.** Every decoder exists twice — `decode32/2`
   returning `{:ok, bin} | :error` and `decode32!/2` raising `ArgumentError`. The
   tuple form is implemented as a rescue around the bang form, i.e. exceptions
   are the single internal error mechanism and tuples are a lossy convenience
   wrapper.
2. **A three-way `:case` option** (`:upper` / `:lower` / `:mixed`) on decode and a
   two-way one on encode. This distinguishes "the producer used all-lower" from
   "the producer mixed case", which a single `casefold` boolean cannot — the
   sharpest case model found in this survey. (Source:
   https://hexdocs.pm/elixir/Base.html#decode32/2)
3. **Dedicated `valid32?`/`hex_valid32?` predicates (since 1.19.0)** that validate
   without allocating the decoded output; the docs explicitly justify them as
   "more performant and memory efficient than using decode…, checking the result
   is `{:ok, ...}`, and then discarding the decoded binary."
4. **`:padding` on both encode and decode** with a single boolean, on by default;
   `padding: false` both omits and ignores. (Source:
   https://hexdocs.pm/elixir/Base.html#encode32/2)
5. **Option model**: Elixir uses an untyped keyword list (`case: :mixed`,
   `padding: false`); Erlang uses a typed map `#{mode => standard | urlsafe,
   padding => boolean}` with documented defaults. Erlang's typed map is the
   better-modelled of the two (for base64; there is no Erlang base32).
6. **Two alphabets as separate function names** (`encode32` vs `hex_encode32`),
   rather than an alphabet parameter.
7. **Hard-coded, non-pluggable alphabets.** No custom-alphabet API, so Crockford
   or z-base-32 would require forking.
8. **Structured Erlang error for base64** (`missing_padding` + `format_error/2`),
   showing a named-error + formatter pattern Elixir's bare `:error` lacks.

## 11. Decisions NOT to copy

- **Bare `:error` as the only non-raising failure** (`Base.decode32/2`): it
  destroys the reason (bad symbol vs bad padding vs bad length). MojoAkku should
  carry a structured error enum instead.
- **Exceptions as the internal control flow** (`decode32!` + rescue): an
  allocation-free `Result`/`raises` design is clearer and cheaper.
- **Untyped keyword-list options** (`padding:`, `case:`): validated only at
  runtime; Mojo should use compile-time enums/`comptime` parameters.
- **Fixed, non-pluggable alphabets** (hard-coded char lists): fine for a minimal
  core, but it blocks Crockford/z-base-32; if MojoAkku wants alphabet
  extensibility it must be designed in.
- **No streaming API at all**: a codec library can cheaply expose an incremental
  state type.
- **A separate `encode32`/`hex_encode32` function per alphabet**: an alphabet
  value/parameter scales better.
- **Stringly/atom-typed `:case` validated at runtime**: a `comptime` case enum is
  strictly better; but Elixir's three-way `:mixed` distinction is a genuinely good
  idea to port into that enum. (Assessment: derived from base.ex.)

## 12. Ideas fitting Mojo

- **Comptime alphabets / padding policy.** `Base` hard-codes alphabets; Mojo can
  take the alphabet and the padding policy as `comptime` parameters and
  specialize the encode/decode loop, removing all runtime branching (mirrors
  `base.ex`'s compile-time character lists, but user-selectable).
- **Typed errors via `raises`.** Replace `{:ok,_}|:error` + `ArgumentError` with a
  `raises DecodeError` (or an error enum: `InvalidChar`, `BadPadding`,
  `WrongLength`), matching Mojo's explicit error model and beating both the bare
  `:error` and the Erlang crash.
- **Validation without allocation.** Copy the `valid32?` idea: a `borrowed`-input
  predicate that returns `Bool` and allocates nothing, next to a decoding
  function that returns an owned buffer — this maps directly onto Mojo ownership
  (`borrowed` in / owned `List[UInt8]` out).
- **A three-way case enum** (`Upper` / `Lower` / `Mixed`) ported from `:case`,
  which is more precise than a boolean `casefold`. (Source:
  https://hexdocs.pm/elixir/Base.html#decode32/2)
- **Explicit incremental decoder.** Design an `IncrementalDecoder` value type
  that owns the leftover carry (0–4 input bytes / 0–7 symbols for base32); Mojo
  value semantics make such a state natural, and it fills the gap both stdlibs
  leave open (§9).
- **One option model, not two.** Use a single parameter/enum model for alphabet +
  padding + case, documented once.
- **Value semantics for containers.** Input as `borrowed`/`Span`, output as an
  owned `List[UInt8]`; Mojo's value semantics make the ownership story in §5
  disappear, so the API should not carry BEAM-specific lifetime language.
- **The Erlang named-error + `format_error` pattern**: a Mojo typed error struct
  implementing `Writable` gives the same renderable, structured diagnostic.

(Assessment: derived from the Elixir findings above and `mojov1` buch
`stdlib/base64`.)

## Sources

- Elixir `Base` docs (v1.20.4): https://hexdocs.pm/elixir/Base.html
- Elixir `Base` source: `elixir/lib/elixir/lib/base.ex` (v1.20.4) —
  https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/base.ex
  (cited line anchors: encode16 L431, decode64 L836, encode32 L1259,
  hex_encode32 L1302, decode32 L1416, decode32! L1462, valid32? L1501,
  hex_decode32 L1549, hex_decode32! L1596, hex_valid32? L1635, types L99–L100)
- Erlang/OTP `base64` docs (OTP 29.1, stdlib 8.1):
  https://www.erlang.org/doc/apps/stdlib/base64.html
- Erlang/OTP `base64` source: `lib/stdlib/src/base64.erl` (OTP-29.1) —
  https://github.com/erlang/otp/blob/OTP-29.1/lib/stdlib/src/base64.erl
- Erlang binary handling: https://www.erlang.org/doc/system/binaryhandling.html
- RFC 4648, The Base16, Base32, and Base64 Data Encodings:
  https://www.rfc-editor.org/rfc/rfc4648.txt
- `base64url`: https://hex.pm/packages/base64url and
  https://github.com/dvv/base64url
- `multibase`: https://hex.pm/packages/multibase and
  https://github.com/nocursor/ex-multibase
- `b58`: https://hex.pm/packages/b58 ; `base62`: https://hex.pm/packages/base62
- Mojo side (not researched here): `mojov1` buch `stdlib/base64`
