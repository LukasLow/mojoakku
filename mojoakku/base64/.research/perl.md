# base64 research: Perl

## 1. Standard library support

Perl's base64 support is **not** in `perlfunc`/core built-ins; it ships as a
core-distribution CPAN module, `MIME::Base64`, bundled with perl. It "provides
functions to encode and decode strings into and from the base64 encoding specified
in RFC 2045 - MIME". The module is an XS (C) implementation for speed.
(Sources: https://perldoc.perl.org/MIME::Base64,
https://raw.githubusercontent.com/Perl/perl5/blead/cpan/MIME-Base64/Base64.xs)

Base16 (hex) *is* a Perl core language feature, via `pack`/`unpack` templates
`H`/`h`: "The `h` and `H` formats pack a string that many nybbles (4-bit groups,
representable as hexadecimal digits, `"0".."9"` `"a".."f"`) long", with `H` giving
high-nybble-first (normal hex) order. (Source:
https://perldoc.perl.org/functions/pack)

There is **no core Base32**. Base32 requires a CPAN module (`MIME::Base32`).
(Assessment: derived from the absence of any base32 function in
https://perldoc.perl.org/MIME::Base64 and the existence of a separate CPAN dist
https://metacpan.org/pod/MIME::Base32)

`pack("u", ...)` provides **uuencode**, a different transfer encoding, not
RFC 4648 Base64. (Source: https://perldoc.perl.org/functions/pack)

## 2. Relevant community libraries

- **MIME::Base64** — core module, author Gisle Aas, "same terms as Perl itself"
  (Perl 5 / Artistic+GPL), XS implementation using metamail-derived code
  (Bellcore). Version 3.16_01 documented. (Sources:
  https://perldoc.perl.org/MIME::Base64,
  https://raw.githubusercontent.com/Perl/perl5/blead/cpan/MIME-Base64/Base64.xs)
- **MIME::Base32** — CPAN, current maintainer Jens Rehsack, license `perl_5`,
  version 1.303 (2017), "Base32 encoder and decoder … much the way that
  MIME::Base64 does". Bus factor 1; 8105 testers pass. (Source:
  https://metacpan.org/pod/MIME::Base32)
- **MIME::QuotedPrint** — ships in the same distribution, quoted-printable (listed
  in MIME::Base64's SEE ALSO). (Source: https://perldoc.perl.org/MIME::Base64)

## 3. Exposed APIs

`MIME::Base64` (Source: https://perldoc.perl.org/MIME::Base64):

- `encode_base64($bytes, $eol)` — exported by default; `$eol` optional, defaults to
  `"\n"`; output wrapped at 76 chars and ends with `$eol` unless empty.
- `decode_base64($str)` — exported by default.
- `encode_base64url($bytes)` / `decode_base64url($str)` — not exported by default;
  URL-safe variant, no padding, no line breaks, `-`/`_`.
- `encoded_base64_length($bytes, $eol)` / `decoded_base64_length($str)` — length
  prediction without doing the work ("should be more efficient").
- Non-exported aliases: `MIME::Base64::encode` / `MIME::Base64::decode`.

XS-level symbols in the same file also include `encode_qp`/`decode_qp` in package
`MIME::QuotedPrint`. (Source:
https://raw.githubusercontent.com/Perl/perl5/blead/cpan/MIME-Base64/Base64.xs)

`MIME::Base32` (Source: https://metacpan.org/pod/MIME::Base32): `encode_base32`,
`decode_base32`, `encode_base32hex`, `decode_base32hex`, aliases `encode`,
`decode`, `encode_rfc3548`, `decode_rfc3548`, `encode_09AV`, `decode_09AV`.

Base16 via core: `pack("H*", $bytes)` and `unpack("H*", $str)`. (Source:
https://perldoc.perl.org/functions/pack)

## 4. Error representation

MIME::Base64 does **not** return error codes or throw typed exceptions:

- `encode_base64` "will croak with 'Wide character in subroutine entry' if `$bytes`
  contains characters with code above 255"; otherwise it never fails. (`croak` is
  Perl's string-based `die` from the call site.)
- `decode_base64` "Any character not part of the 65-character base64 subset is
  silently ignored. Characters occurring after a '=' padding character are never
  decoded." It has **no error path** for malformed data — bad input yields
  truncated/garbage bytes.

(Source: https://perldoc.perl.org/MIME::Base64)

At the XS level, `decode_base64` uses an `index_64[256]` table where illegal
characters are `255` (XX) and `=` is `254` (EQ); illegal bytes are simply skipped
(`if (uc != INVALID) c[i++] = uc;`) and `c[0]==EQ $%$$%$ c[1]==EQ` stops decoding.
(Source:
https://raw.githubusercontent.com/Perl/perl5/blead/cpan/MIME-Base64/Base64.xs)

Error signalling in Perl generally is `die`/`croak` or the `$!` errno variable;
MIME::Base64 uses neither for decode failures. (Assessment: derived from
https://perldoc.perl.org/MIME::Base64 and
https://raw.githubusercontent.com/Perl/perl5/blead/cpan/MIME-Base64/Base64.xs)

## 5. Ownership semantics (buffer/ownership of input and output)

Perl uses reference-counted SVs (scalars); there is no manual free. Both functions
return a **new SV** allocated by the XS code:

- `encode_base64` computes the exact output length first
  (`rlen = (len+2)/3*4` plus EOL space), does `RETVAL = newSV(rlen ? rlen : 1)`,
  `SvPOK_on`, `SvCUR_set`, then writes into `SvPVX(RETVAL)` and NUL-terminates.
- `decode_base64` allocates `newSV(len * 3 / 4)` ("always enough, but might be too
  much"), writes into it, then shrinks with `SvCUR_set(RETVAL, r - SvPVX(RETVAL))`.

(Source: https://raw.githubusercontent.com/Perl/perl5/blead/cpan/MIME-Base64/Base64.xs)

Input is passed as a borrowed SV pointer (`SvPV(sv, rlen)`), never mutated by
decode. `encode_base64` does temporarily downgrade UTF-8
(`sv_utf8_downgrade(sv, FALSE)`) and restores it afterwards
(`sv_utf8_upgrade(sv)` if it had been UTF-8) — a borrow-with-restore pattern.
(Source: https://raw.githubusercontent.com/Perl/perl5/blead/cpan/MIME-Base64/Base64.xs)

Consequence: the caller owns every returned string; large outputs are ordinary
heap SVs subject to refcount GC. (Assessment: derived from the XS source above.)

## 6. Blocking / non-blocking

Not applicable. Pure CPU-bound encode/decode with no I/O and no async model; Perl
has no async colouring in these functions. `encode_base64`/`decode_base64` run to
completion synchronously. (Source: https://perldoc.perl.org/MIME::Base64)

## 7. Alphabet variants and padding

- **Standard**: "A 65-character subset ([A-Za-z0-9+/=]) of US-ASCII is used,
  enabling 6 bits to be represented per printable character." Padding `=` is always
  produced (`*r++ = '='` for the 1- and 2-byte tails) and expected on decode.
- **URL-safe**: `encode_base64url`/`decode_base64url` use `-` and `_` instead of
  `+` and `/`, **do not use padding**, and do not break lines. These are "not
  exported by default" and must be imported explicitly or called fully qualified.
- **Line-breaking is the default**: output is broken at 76 characters and ends
  with `$eol`; pass `""` as second arg to `encode_base64` to disable.
- **Base32 (CPAN)**: `encode_base32` uses RFC 3548 §5 standard alphabet by default;
  `encode_base32hex` uses the hex (`[0-9A-V]`) alphabet; before v1.0 the module
  defaulted to base32hex, changed to standard for RFC 3548 compliance.
- **Base16 (core)**: `unpack("H*", ...)` produces lowercase hex; decode via
  `pack("H*", ...)`, which tolerates both `a..f` and `A..F` ("for characters
  `"a".."f"` and `"A".."F"`, the result is compatible with the usual hexadecimal
  digits").

(Sources: https://perldoc.perl.org/MIME::Base64,
https://metacpan.org/pod/MIME::Base32,
https://perldoc.perl.org/functions/pack)

Padding semantics quirk: because decode "silently ignores" every non-alphabet
character and stops after `=`, *missing* padding on 2- or 3-char tails is still
decoded, and *excess* trailing junk is ignored. (Source:
https://perldoc.perl.org/MIME::Base64)

## 8. Timeouts

Not applicable — no I/O, no locks, no cancellation surface. `MIME::Base64` exposes
no timeout or signal integration. (Source: https://perldoc.perl.org/MIME::Base64)

## 9. Streaming / incremental encode+decode

There is **no incremental encoder/decoder object**. The documented streaming recipe
is chunking by the caller at a size that aligns to the line format: "If you want to
encode a large file, you should encode it in chunks that are a multiple of 57
bytes. This ensures that the base64 lines line up and that you do not end up with
padding in the middle. 57 bytes of data fills one complete base64 line
(76 == 57*4/3)". (Source: https://perldoc.perl.org/MIME::Base64)

Decoding stream-wise is also caller-driven: "Decoding does not need slurp mode if
every line contains a multiple of four base64 chars". The example `while
(read(FILE, $buf, 60*57)) { print encode_base64($buf); }` shows the chunked
pattern; a large-memory alternative is to slurp with `local($/) = undef`. (Source:
https://perldoc.perl.org/MIME::Base64)

Leftover-byte carry is therefore **the caller's responsibility**: choose multiples
of 57 (or 3) input bytes, or buffer the remainder yourself. There is no state object
to carry partial groups across calls. (Assessment: derived from the 57-byte chunk
guidance and the absence of any incremental API in
https://perldoc.perl.org/MIME::Base64)

## 10. Interesting design decisions

- **Core-module-as-stdlib**: base64 ships with perl but as a CPAN dist, so the
  "standard library" boundary is blurrier than in Python/Go.
- **XS for speed**: the hot loop is C, with a 256-byte reverse lookup table
  `index_64` — the classic fast-decode design.
- **Length prediction API**: `encoded_base64_length` / `decoded_base64_length`
  compute sizes without encoding — useful for pre-allocating buffers (and easy to
  port to Mojo as a pure function).
- **Perl-idiomatic dual default/URL alphabet via export lists**: security-sensitive
  URL-safe functions are deliberately not exported by default.
- **Line-breaking on by default** (76 chars + EOL), a 1990s MIME legacy baked into
  the primary function signature.
- **Borrow-with-restore UTF-8 handling**: XS downgrades UTF-8 for byte processing
  and upgrades back, keeping the caller's SV unchanged.

(Sources: https://perldoc.perl.org/MIME::Base64,
https://raw.githubusercontent.com/Perl/perl5/blead/cpan/MIME-Base64/Base64.xs)

## 11. Decisions NOT to copy

- **No error signal on decode.** "Silently ignored" input is the opposite of
  predictable; a Mojo API must report malformed input via `raises`/`Result`.
- **Line-wrapping as default behavior** in the primary encode function. Wrapping is
  a MIME-email concern, not a codec concern; keep it a separate, explicit option.
- **`$eol` as a magic second positional argument** with `""` meaning "off" —
  implicit overload of a string argument.
- **`croak` string errors** ("Wide character in subroutine entry") — untyped,
  unparseable; Mojo should use typed errors.
- **Split Base32 across a separate CPAN dist with a bus factor of 1** while Base64
  is core — inconsistent packaging of one RFC 4648 family.
- **Case-insensitive Base16 decode by default** (`pack "H*"` accepts `A..F` and
  `a..f`), which RFC 4648 explicitly recommends against for security.
  (Source: https://perldoc.perl.org/functions/pack)

## 12. Ideas fitting Mojo

- **Separate pure `encoded_length` / `decoded_length` functions** (from
  `encoded_base64_length`/`decoded_base64_length`) so callers can pre-size
  `List[UInt8]`/`String` buffers without allocating twice.
- **A 256-entry compile-time reverse lookup table** (`index_64`) as an immutable
  constant — naturally expressible in Mojo and avoids runtime branchy decoding.
- **Borrowed input, owned output**: take `borrowed` bytes, return an owned
  `String`/`List[UInt8]`, mirroring Perl's borrow-with-restore without the mutation
  trick.
- **Explicit strict decode** contrasting Perl's silent-ignore: `b64decode(..., raises)`
  that rejects non-alphabet bytes, with whitespace tolerance as an explicit option
  (matching what `mojov1/stdlib/base64` already records for Mojo's `b64decode`).
- **A chunked streaming helper that requires 3-byte-multiple chunks on encode**, as
  a typed wrapper around the caller-side discipline Perl documents (57-byte lines /
  4-char decode groups).
- **Alphabet as constants/enum** (standard, URL-safe, base32hex) rather than a
  separate function per variant, so `base64`, `base32` and `base16` share one shape.

(Assessment: derived from the Perl findings above and `mojov1` buch
`stdlib/base64`.)

## Sources

- https://perldoc.perl.org/MIME::Base64
- https://raw.githubusercontent.com/Perl/perl5/blead/cpan/MIME-Base64/Base64.xs
- https://perldoc.perl.org/functions/pack
- https://metacpan.org/pod/MIME::Base32
- Mojo side (not researched here): `mojov1` buch `stdlib/base64`
