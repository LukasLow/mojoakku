# base64 research: Perl

Scope: `MIME::Base64` (the core module), its URL-safe variants, the pure-Perl and
streaming implementations, and the wrapper layers (`Mojo::Util`,
`MIME::Decoder::Base64`, `PerlIO::via::Base64`). Every factual claim carries a
source; unsourced statements are marked `GUESS:`.

## 1. Standard library support

- `MIME::Base64` is Perl's base64 facility and a **core** module: the perldoc
  browser lists it for every Perl from 5.005 through 5.44/dev, and version 3.16_01
  is documented for current perls. Sources:
  <https://perldoc.perl.org/MIME::Base64>,
  <https://perldoc.perl.org/5.8.0/MIME::Base64> (documents version 2.12 for Perl
  5.8.0).
- Distribution: `MIME-Base64`, latest release 3.16 (2020-09-27, released by
  CAPOEIRAB; author Gisle Aas), maintainers P5P + CAPOEIRAB + GAAS, license
  `perl_5`, requires Perl v5.6.0. Source: <https://metacpan.org/pod/MIME::Base64>
  (distribution sidebar).
- The repository's own `lib/MIME/Base64.pm` declares `our $VERSION = '3.17';`, so
  the git head is one patch ahead of the last CPAN release. Source:
  <https://raw.githubusercontent.com/Dual-Life/mime-base64/master/lib/MIME/Base64.pm>.
- Implementation split: the module is a thin wrapper loading XS
  (`XSLoader::load('MIME::Base64', $VERSION);`); the C implementation lives in
  `Base64.xs`. Sources:
  <https://raw.githubusercontent.com/Dual-Life/mime-base64/master/lib/MIME/Base64.pm>,
  <https://raw.githubusercontent.com/Dual-Life/mime-base64/master/Base64.xs>.
- Same distribution also provides `MIME::QuotedPrint` (same XS file, different
  `MODULE`/`PACKAGE` section). Source: `Base64.xs`.
- Historically the distribution also shipped pure-Perl implementations; these were
  unbundled in 3.00: "Drop the pure Perl implementations of the encoders and
  decoders. They are bloat that hides real problems in the XS implementations. I
  will re-release them separately in the new MIME-Base64-Perl distribution."
  Source: <https://raw.githubusercontent.com/Dual-Life/mime-base64/master/Changes>
  (entry 3.00, 2004-01-14).
- The distribution's stated encoding basis is RFC 2045 (MIME), not RFC 4648: "This
  module provides functions to encode and decode strings into and from the base64
  encoding specified in RFC 2045". Source: MIME::Base64 POD.

## 2. Relevant community libraries

- `MIME::Base64::URLSafe` — author Kazuho Oku (Cybozu Labs), version 0.01, released
  2006, license "same terms as Perl itself". Purpose: "Perl version of Python's
  URL-safe base64 codec". Source:
  <https://fastapi.metacpan.org/source/KAZUHO/MIME-Base64-URLSafe-0.01/lib/MIME/Base64/URLSafe.pm>;
  distribution listing at <https://metacpan.org/dist/MIME-Base64-URLSafe>.
- `MIME::Base64::Perl` — pure-Perl reimplementation, Gisle Aas, version 1.00
  (2004-01-14), license "unknown" on MetaCPAN, bus factor 0, no other versions ever
  released. Source: <https://metacpan.org/pod/MIME::Base64::Perl>.
- `Mojo::Util` (Mojolicious, Artistic License 2.0) exposes base64 as one-line
  aliases: `monkey_patch(__PACKAGE__, 'b64_decode', \&decode_base64);` and
  `'b64_encode', \&encode_base64);`. Source:
  <https://raw.githubusercontent.com/mojolicious/mojo/main/lib/Mojo/Util.pm>;
  license: <https://raw.githubusercontent.com/mojolicious/mojo/main/LICENSE>.
- `MIME::Decoder::Base64` (part of MIME-tools, Dianne Skoll / Eryq, license
  `perl_5`, requires Perl v5.8.0, 416 KB distribution, bus factor 1) is the MIME
  streaming adapter. Source: <https://metacpan.org/pod/MIME::Decoder::Base64>.
- `PerlIO::via::Base64` — a PerlIO layer, originally by Elizabeth Mattijsen
  (copyright 2002, v0.05, "same terms as Perl itself"), later releases 0.06 by
  LNATION. Sources:
  <https://fastapi.metacpan.org/source/ELIZABETH/PerlIO-via-Base64-0.05/lib/PerlIO/via/Base64.pm>,
  <https://metacpan.org/release/LNATION/PerlIO-Via-Base64-0.06>.
- `IOLayer::Base64` is the renamed/continued line of the same idea ("PerlIO layer
  for base64 (MIME) encoded strings"). Source:
  <https://metacpan.org/pod/IOLayer::Base64>.
- `Template::Plugin::Filter::Base64` and `Text::Pipe::Encoding::Base64::Encode`
  exist as template/pipeline glue. Sources:
  <https://metacpan.org/dist/Template-Plugin-Filter-Base64>,
  <https://metacpan.org/pod/Text::Pipe::Encoding::Base64::Encode> (via metacpan
  search result for "Encode::Encoding").
- `Acme::Base64` ("Write Perl in Base64 encoding") is a joke module, listed only to
  mark the boundary of useful prior art. Source: <https://metacpan.org/dist/Acme-Base64>.

## 3. Exposed APIs

`MIME::Base64` exports (from the module source):

```perl
our @EXPORT    = qw(encode_base64 decode_base64);
our @EXPORT_OK = qw(encode_base64url decode_base64url
                    encoded_base64_length decoded_base64_length);
```
plus alias globs `*encode = \&encode_base64; *decode = \&decode_base64;`.
Source: <https://raw.githubusercontent.com/Dual-Life/mime-base64/master/lib/MIME/Base64.pm>.

Signatures (all positional, all prototyped):

- `encode_base64($bytes)` / `encode_base64($bytes, $eol)` — prototype `$;$`.
- `decode_base64($str)` — prototype `$`.
- `encode_base64url($bytes)` / `decode_base64url($str)` — pure Perl, defined in the
  PM file (no XS).
- `encoded_base64_length($bytes)` / `encoded_base64_length($bytes, $eol)` —
  prototype `$;$`.
- `decoded_base64_length($str)` — prototype `$`.
- Sources: POD in `lib/MIME/Base64.pm`; prototypes in `Base64.xs`.

`MIME::Base64::URLSafe` exports `urlsafe_b64encode` / `urlsafe_b64decode`, with
package-internal aliases `encode`/`decode` (callable as
`MIME::Base64::URLSafe::encode`). Source:
<https://fastapi.metacpan.org/source/KAZUHO/MIME-Base64-URLSafe-0.01/lib/MIME/Base64/URLSafe.pm>.

`Mojo::Util` adds `b64_encode $bytes` / `b64_encode $bytes, "\n"` and
`b64_decode $b64`; the POD documents the second `b64_encode` argument as the line
ending, defaulting to a newline. Source:
<https://docs.mojolicious.org/Mojo/Util.txt>.

`PerlIO::via::Base64` provides one class method `eol($new)` plus the layer
protocol methods `PUSHED`, `FILL`, `WRITE`, `FLUSH`, `import`; used as
`open(my $in, '<:via(Base64)', 'file.mime')`. Source:
<https://fastapi.metacpan.org/source/ELIZABETH/PerlIO-via-Base64-0.05/lib/PerlIO/via/Base64.pm>.

No constants are exported; the 64-character alphabet and reverse table are private
C statics (`static const char basis_64[]`, `static const unsigned char
index_64[256]`). Source: `Base64.xs`.

CLI: the old `{en,de}code-base64` utility scripts were unbundled in 3.06 ("These
are now found in the MIME-Base64-Scripts package") and `MIME::Base64` itself has no
`main()`. Sources: `Changes` (3.06); `lib/MIME/Base64.pm` has no CLI code.

## 4. Error representation

- Errors are Perl exceptions raised with `croak`/`die`; there are no error classes or
  codes. No `try/catch` keyword, no `Result`/`Either`, no sentinel values.
- Documented failure mode for encoding: "The function will croak with 'Wide
  character in subroutine entry' if `$bytes` contains characters with code above
  255. The base64 encoding is only defined for single-byte characters. Use the
  Encode module to select the byte encoding you want." Source: MIME::Base64 POD.
- The pure-Perl variant is more explicit: it croaks "The Base64 encoding is only
  defined for bytes" when `bytes::length > length` or the string matches
  `/[^\0-\xFF]/`. Source:
  <https://fastapi.metacpan.org/source/GAAS/MIME-Base64-Perl-1.00/lib/MIME/Base64/Perl.pm>.
- Decoding is deliberately non-failing: "Any character not part of the 65-character
  base64 subset is silently ignored. Characters occurring after a '=' padding
  character are never decoded." Source: MIME::Base64 POD.
- That silence is recent: 3.11 (2010-10-24) removed the warnings — "The
  decode_base64() does not issue warnings on suspect input data any more." Earlier
  versions warned under `-w` with "Premature end of base64 data" and "Premature
  padding of base64 data", documented in the 5.8.0 POD. Sources: `Changes` (3.11);
  <https://perldoc.perl.org/5.8.0/MIME::Base64> (DIAGNOSTICS section).
- The XS decoder has no error path at all for malformed input: the reverse table
  maps every byte outside the alphabet to `XX` and the loop simply skips it
  (`if (uc != INVALID) c[i++] = uc;`); on `EQ` it breaks out of the loop. Source:
  `Base64.xs` (`decode_base64`).
- The pure-Perl decoder only carps and continues: `Carp::carp("Length of base64 data
  not a multiple of 4")` followed by `$str =~ s/=+$//;`. Source:
  `MIME-Base64-Perl-1.00/lib/MIME/Base64/Perl.pm`.
- `MIME::Base64::URLSafe::decode` has a silent-input-repair strategy: it deletes
  `+`, `/` and whitespace from the input, then repairs padding with
  `$data .= substr('====', $mod4)`. Source: URLSafe.pm.
- `PerlIO::via::Base64::FLUSH` returns `-1` on a failed `print`, which is the only
  C-style sentinel in the studied surface. Source: PerlIO-via-Base64-0.05.

## 5. Ownership semantics of encode input and output

- Perl has no ownership model: scalars are reference-counted SVs and strings are
  mutable. The XS code reads the argument through `SvPV(sv, rlen)` — a borrowed
  pointer into the argument's buffer — and encodes it without mutating it.
  Source: `Base64.xs` (`encode_base64`).
- Output is always a newly allocated scalar: the encoder computes the result length
  first, then does `RETVAL = newSV(rlen ? rlen : 1); SvPOK_on(RETVAL);
  SvCUR_set(RETVAL, rlen); r = SvPVX(RETVAL);`. Source: `Base64.xs`.
- The decoder allocates with a documented over-estimate:
  `STRLEN rlen = len * 3 / 4; RETVAL = newSV(rlen ? rlen : 1);` with the comment
  "always enough, but might be too much", then fixes the real length with
  `SvCUR_set(RETVAL, r - SvPVX(RETVAL));`. Source: `Base64.xs`.
- Ownership of the output therefore passes to the caller as an ordinary Perl scalar;
  freeing happens by refcount when the last reference goes away. There is no
  explicit free function in the API. Source: `Base64.xs` (no free API) and
  `lib/MIME/Base64.pm` (no free API).
- Encoding temporarily mutates the **input's** UTF8 flag state: the code saves
  `had_utf8 = SvUTF8(sv);`, calls `sv_utf8_downgrade(sv, FALSE)` before reading the
  bytes, and restores with `sv_utf8_upgrade(sv)` afterwards. Source: `Base64.xs`.
- That flag handling has a history of bugs and was explicitly fixed twice: 3.12
  "Don't change SvUTF8 flag on the strings encoded [RT#60105]" and 3.13 "The fix in
  v3.12 to try to preserve the SvUTF8 flag was buggy and actually managed to set the
  flag on strings that did not have it originally." Source: `Changes`.
- The 2.05 fix records a buffer-sizing ownership bug worth remembering: "The
  decode_base64() would previously allocate a too short buffer for the result string
  when the trailing '==' padding was missing in the string to be decoded." Source:
  `Changes`.
- `PerlIO::via::Base64` owns an internal buffer array `['', $eol]` per handle:
  `WRITE` appends to `$_[0]->[0]` and `FLUSH` encodes and prints it. The caller owns
  the filehandle; the layer owns the pending bytes. Source:
  PerlIO-via-Base64-0.05.
- `MIME::Decoder::Base64` owns a decoder-side accumulation buffer: "The input
  accumulates in an internal buffer, which is decoded in multiple-of-4-sized chunks
  (plus a possible 'leftover' input chunk, of course)." Source:
  <https://metacpan.org/pod/MIME::Decoder::Base64>.

## 6. Blocking / non-blocking

- `encode_base64` / `decode_base64` perform no I/O whatsoever; they are pure
  in-memory string transformations. Source: `Base64.xs` — neither function contains
  any `PerlIO`/`read`/`write` call.
- Perl has no built-in async/await model. Concurrency comes from `fork`, threads,
  event loops (POE, AnyEvent) or `Mojo::IOLoop`; the base64 functions integrate with
  none of them specially. Source: the API is synchronous by construction
  (`Base64.xs`).
- Blocking appears only in the streaming wrappers: `PerlIO::via::Base64::FILL`
  does `local $/; my $line = readline($_[1]);` — a blocking whole-handle read —
  and `FLUSH` blocks on `print`. Source: PerlIO-via-Base64-0.05.
- `MIME::Decoder::Base64` reads "one line at a time" when decoding and 6840 bytes
  at a time when encoding, all blocking on the underlying handle. Source:
  <https://metacpan.org/pod/MIME::Decoder::Base64>.
- `Mojo::Util`'s aliases inherit `MIME::Base64`'s synchronous behaviour and add
  nothing concurrent. Source:
  <https://raw.githubusercontent.com/mojolicious/mojo/main/lib/Mojo/Util.pm>.
- No cancellation, signal or interruption protocol exists in any studied module.
  Sources: all four POD pages and `Base64.xs`.

## 7. Alphabet variants and padding handling

- Standard alphabet and padding are hard-wired in the encoder's C table:
  `static const char basis_64[] =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";` and the
  `=` pad is written in C (`*r++ = '=';`). The pod states the character subset is
  `[A-Za-z0-9+/=]`. Sources: `Base64.xs`; MIME::Base64 POD.
- Line breaking is part of the core encoder, not opt-in: `#define MAX_LINE 76` and
  a newline (default `"\n"`) is emitted after every 76 encoded characters; the
  result "will end with `$eol` unless it is empty". A caller must pass `""` as the
  second argument to switch wrapping off. Sources: `Base64.xs`; MIME::Base64 POD.
- URL-safe alphabet is a post-processing wrapper, not an alphabet parameter:
  `sub encode_base64url { my $e = encode_base64(shift, ""); $e =~ s/=+\z//;
  $e =~ tr[+/][-_]; return $e; }`. Decode is
  `sub decode_base64url { my $s = shift; $s =~ tr[-_][+/]; $s .= '=' while
  length($s) % 4; return decode_base64($s); }`. Source:
  `https://raw.githubusercontent.com/Dual-Life/mime-base64/master/lib/MIME/Base64.pm`.
- Consequences, all sourced from the same code: `encode_base64url` has **no
  padding** and **no line breaks**; `decode_base64url` re-pads to a multiple of 4
  before delegating, so missing padding is accepted; `decode_base64url` does **not**
  reject `+`/`/` — they pass straight through the `tr` into the standard decoder.
- This makes `encode_base64url`/`decode_base64url` non-round-tripping as a pair for
  inputs containing literal `-`/`_` in the encoded form — the decode step rewrites
  any `-` to `+` and `_` to `/`. Source: the two subs above. `GUESS:` no documented
  test or issue was found for this; it follows from reading the code, not from a
  quoted statement.
- `MIME::Base64::URLSafe` uses a **different** translation: encode does
  `$data =~ tr|+/=|\-_|d;` — that `d` flag *deletes* the `=` while mapping `+`→`-`
  and `/`→`_`; decode does `$data =~ tr|\-_\t-\x0d |+/|d;` — deleting `-`, `_`,
  whitespace and control characters *and* the `+`/`/` that should have been
  converted, per its own comment "+/ should not be handled, so convert them to
  invalid chars". Source: URLSafe.pm.
- `MIME::Base64::URLSafe` documents its rules explicitly: "use '-' and '_' instead
  of '+' and '/'; no line feeds; no trailing equals (=)". Source: URLSafe.pm POD.
- Decode-side padding tolerance differs per module: `MIME::Base64::decode_base64`
  accepts unpadded input (the C loop synthesises `EQ` when it runs out:
  `if (i == 2) c[2] = EQ; c[3] = EQ;`) whereas `MIME::Base64::URLSafe::decode`
  repairs padding by hand with `substr('====', $mod4)`. Sources: `Base64.xs`;
  URLSafe.pm.
- Case-insensitivity does not exist for base64 (it is relevant only to the base16
  and base32 alphabets in RFC 4648, and to the base32 `map01` mapping). Source:
  <https://www.rfc-editor.org/rfc/rfc4648.txt> section 3.4.
- RFC 4648 section 3.2 requires padding unless a referring spec says otherwise;
  MIME::Base64 encodes padded and decodes tolerantly, which matches RFC 2045-style
  "be liberal in what you accept" rather than RFC 4648 section 3.3's "MUST reject".
  Sources: RFC 4648 sections 3.2 and 3.3; MIME::Base64 POD.

## 8. Timeouts

- No timeout, deadline, retry or cancellation API exists in `MIME::Base64`,
  `MIME::Base64::URLSafe`, `Mojo::Util`, `MIME::Decoder::Base64` or
  `PerlIO::via::Base64`. Sources: all POD pages cited in sections 1-3.
- Blocking time is inherited from the caller's handle. `PerlIO::via::Base64::FILL`
  performs an unbounded `local $/; readline($_[1])`, so a slow producer blocks the
  read indefinitely; there is no layer-level timeout hook. Source:
  PerlIO-via-Base64-0.05.
- `MIME::Decoder::Base64` reads line-wise / 6840-byte-wise from the caller's
  handle; timeouts would have to be set on that handle (e.g. an alarm or a
  select-based loop), not on the decoder. Source:
  <https://metacpan.org/pod/MIME::Decoder::Base64>.
- Conclusion for this research: there is nothing to copy. Timeout handling belongs to
  the transport layer, not to a base64 codec.

## 9. Streaming (incremental / chunked encode and decode, leftover bytes)

- The core API is whole-string; there is no `update()`/`final()` and no exposed
  leftover state. Source: `lib/MIME/Base64.pm` and `Base64.xs` (no such subs).
- Perl's answer to streaming is a documented chunking idiom, not an API: "If you
  want to encode a large file, you should encode it in chunks that are a multiple of
  57 bytes. This ensures that the base64 lines line up and that you do not end up
  with padding in the middle. 57 bytes of data fills one complete base64 line
  (76 == 57*4/3)". Source: MIME::Base64 POD (EXAMPLES).
- The documented decode-side counterpart is line-oriented: "Decoding does not need
  slurp mode if every line contains a multiple of four base64 chars:
  `perl -MMIME::Base64 -ne 'print decode_base64($_)' <file`". Source: MIME::Base64
  POD.
- The two length helpers exist precisely to support chunked/buffered use without a
  trial allocation: `encoded_base64_length($bytes[, $eol])` "Returns the length that
  the encoded string would have without actually encoding it" and
  `decoded_base64_length($str)` likewise. Their C implementations are the
  arithmetic `RETVAL = (len+2) / 3 * 4;` plus `((RETVAL-1) / MAX_LINE + 1) * eollen`
  for the line endings. Sources: MIME::Base64 POD; `Base64.xs`.
- `MIME::Decoder::Base64` is the only studied implementation with a real internal
  buffer and leftover handling: decoding reads line by line into a buffer decoded in
  multiple-of-4 chunks "plus a possible 'leftover' input chunk", and encoding reads
  6840 bytes (120 * 57) at a time so each 57-byte section becomes exactly one
  76-character line. Source: <https://metacpan.org/pod/MIME::Decoder::Base64>.
- `PerlIO::via::Base64` is explicitly **not** streaming and says so: "The current
  implementation slurps the whole contents of a handle into memory before doing any
  encoding or decoding. This may change in the future when I finally figured out how
  READ and WRITE are supposed to work on incompletely processed buffers." Source:
  PerlIO-via-Base64-0.05 (CAVEAT).
- Leftover arithmetic for a correct streaming encoder follows from the 3-byte
  quantum: after each chunk, 0, 1 or 2 input bytes remain unencoded (the same rule
  Python's `base64io` documents as "might hold up to two bytes of unencoded data in
  an internal buffer"). Sources: RFC 4648 section 4 (24-bit input groups; final
  quantum of 8 or 16 bits); for the cross-language statement,
  <https://github.com/aws/base64io-python/blob/master/README.rst>.
- Default line-feed policy for RFC 4648 implementations: "Implementations MUST NOT
  add line feeds to base-encoded data unless the specification referring to this
  document explicitly directs base encoders to add line feeds after a specific
  number of characters." MIME::Base64 violates this by default because it targets
  RFC 2045 instead. Sources: RFC 4648 section 3.1; MIME::Base64 POD.

## 10. Interesting design decisions

- The chunk-size constant is treated as a public convention: 57 input bytes == one
  76-character line, documented in the POD so users can chunk safely; the C encoder
  enforces the same 76 via `MAX_LINE` and `chunk == (MAX_LINE/4)`. Sources:
  MIME::Base64 POD; `Base64.xs`.
- Cheap, non-allocating size prediction as first-class API:
  `encoded_base64_length`/`decoded_base64_length`. This is a genuinely useful idea
  for a language with explicit buffer reservation. Sources: MIME::Base64 POD;
  `Base64.xs`.
- The URL-safe variant is built by string translation around the standard encoder,
  four lines total, instead of parameterising the alphabet. Minimal code, but it
  makes the alphabet a wrapper concern. Source: `lib/MIME/Base64.pm`.
- The decoder is written to be lenient by construction: the reverse table's `XX`
  entries make unknown bytes fall through, and the padding state machine tolerates
  missing trailing `=`. Source: `Base64.xs`.
- UTF8 flag save/restore around every call (`had_utf8` + `sv_utf8_downgrade` /
  `sv_utf8_upgrade`) — an explicit attempt to make a bytes-only operation safe for
  Perl's dual-typed strings. Source: `Base64.xs`.
- The XS/Pure-Perl split was resolved decisively in favour of one implementation:
  3.00 dropped pure Perl because it "is bloat that hides real problems in the XS
  implementations". Source: `Changes` (3.00).
- A documented, honest capability gap in `PerlIO::via::Base64`'s CAVEAT (it slurps)
  is better engineering communication than silently pretending to stream. Source:
  PerlIO-via-Base64-0.05.
- Backwards compatibility is carried for a very long time: `Changes` records support
  restorations for perl 5.4 and 5.6 across 3.15 and 3.16 ("Restore compatibility with
  perl-5.4", "Bump the required Perl version to v5.6.2"). Source: `Changes`.

## 11. Decisions NOT to copy into MojoAkku

- Line wrapping and a trailing EOL in the default encode path. RFC 4648 section 3.1
  forbids implicit line feeds; wrapping must be opt-in, and certainly not the default
  of a function name that does not say "MIME".
- Two parallel URL-safe implementations with **different** semantics
  (`MIME::Base64::encode_base64url` maps `+/`→`-_` and strips padding, while
  `MIME::Base64::URLSafe` translates with the `d` flag and additionally deletes
  `+`, `/` and whitespace on decode). Overloading one alphabet concept with several
  subtly different wrappers is a trap.
- A decoder that silently ignores every non-alphabet byte. RFC 4648 section 3.3
  warns that ignoring them "instead of causing rejection of the entire encoding (as
  recommended), a covert channel that can be used to 'leak' information is made
  possible"; RFC 4648 section 12 repeats the warning about non-significant bits and
  ignored characters.
- "The string is the bytes" with an invisible UTF8 flag: the encode path has to
  downgrade/upgrade the input SV and has a documented two-release bug history around
  that flag (3.12, 3.13). A bytes type should not carry a hidden text mode.
- Croaking with a message like "Wide character in subroutine entry" that originates
  inside Perl's string layer rather than the module. Error text should describe the
  codec-level violation, ideally as a typed error.
- Decode-input repair as a feature (`$data .= substr('====', $mod4)`). Silently
  accepting truncated input hides data loss; a caller who knows the length should say
  so explicitly.
- Exposing a slurping "streaming layer" (`PerlIO::via::Base64`) whose contract is
  violated by its implementation — the CAVEAT is admirable, the behaviour is not
  worth copying.
- Positional, prototyped C-style signatures (`encode_base64($bytes, $eol)`) with
  boolean/mode semantics encoded in ordering and empty-string sentinels; MojoAkku
  should use named, typed parameters.

## 12. Ideas fitting Mojo

- Context: the Mojo stdlib already ships `base64` with four functions and no
  `@stable(since=...)` marker, so it is unstable by default. Sources: buch
  `mojov1/stdlib/base64`; <https://mojolang.org/docs/api-docs/stability/>.
- Steal the length-prediction idea, in Mojo's non-raising style:
  `def encoded_length(n: Int) -> Int` and `def decoded_length(n: Int) -> Int` for
  the common `decoded_length(4 * k)` / `encoded_length(3 * k)` cases, so the caller
  can size a `mut result: String` before calling the in-place encoder. Mojo's stdlib
  encoder already documents that "This method reserves the necessary capacity" and
  that `result` "can be a 0 capacity string", which is exactly the contract these
  helpers serve. Sources: MIME::Base64 POD; buch `mojov1/stdlib/base64`;
  <https://mojolang.org/docs/std/base64/base64/b64encode/>.
- Replace the wrapper-function explosion (standard + url + two competing URLSafe
  modules) with one compile-time alphabet choice. Mojo provides `comptime` values
  and aliases for exactly this: `comptime URL_SAFE = ...`, plus `comptime if`/`comptime
  for` to specialise the table lookup. Sources: buch `mojov1/appendix/cheat-sheet`
  (`comptime NAME = value`, `comptime if cond:`, `comptime for i in range(n):`).
- Use typed errors for decode, which Perl's `croak` and Python's exception hierarchy
  both lack: `def b64decode(...) raises Base64Error -> ...`. Mojo permits at most one
  error type and bare `raises` erases it, so the type must be explicit; the error
  value can carry an offset and a reason (bad character, bad padding, non-canonical
  pad bits) mirroring the taxonomy Perl spreads across free-text messages. Sources:
  buch `mojov1/keyword-conventions/raises`; buch `mojov1/errors/error-model`.
- Encoding is total and must not be `raises`: Perl needs `croak` only because of its
  loose string model (chars > 255), a problem Mojo does not have because input is
  `Span[UInt8]`/`StringSpan` (both confirmed as accepted encode inputs in the
  signatures in buch `mojov1/stdlib/base64`). Sources: MIME::Base64 POD ("Wide
  character..."); buch `mojov1/stdlib/base64`; Mojo stdlib signatures at
  <https://mojolang.org/docs/std/base64/base64/b64encode/>.
- Adopt borrowed-input / caller-owned-output from both references: Perl's XS reads
  the argument through `SvPV` and writes into a fresh `newSV`, and Mojo's stdlib takes
  `Span[UInt8]` in and returns `String` (decode returns `List[UInt8]`). Sources:
  `Base64.xs`; buch `mojov1/stdlib/base64`;
  <https://mojolang.org/docs/std/base64/base64/b64decode/>.
- Make wrapping explicit and separate from encoding, following RFC 4648 section 3.1,
  and model the chunk arithmetic on Perl's documented 57/76 relation (with the
  leftover rule of a 3-byte input quantum) if a streaming API is ever added. Sources:
  RFC 4648 section 3.1; MIME::Base64 POD.
- For streaming, prefer `MIME::Decoder::Base64`'s explicit state model (accumulate,
  decode in multiples of 4, keep a named leftover chunk) over `PerlIO::via::Base64`'s
  slurp-and-hope. In Mojo this would be a struct with an owned buffer and a
  `var`/`mut self` method pair, since Mojo has value semantics and explicit
  ownership rather than refcounted scalars. Sources:
  <https://metacpan.org/pod/MIME::Decoder::Base64>; PerlIO-via-Base64-0.05;
  buch `mojov1/memory/ownership-and-lifetimes`.
- Keep an explicit "ignore whitespace" policy as a separate, named option rather than
  a silent default — Perl ignores *all* non-alphabet characters, the Mojo stdlib
  ignores whitespace only and rejects the rest, and RFC 4648 section 3.3 recommends
  rejection. Sources: MIME::Base64 POD;
  <https://mojolang.org/docs/std/base64/base64/b64decode/>; RFC 4648 section 3.3.
- Use Mojo's compile-time constant/`where` facilities to avoid the per-call reverse
  table build that both Perl (XS static table, fine) and Python
  (`get_reverse_table()`) perform, and to make the alphabet a type-level parameter
  with zero runtime branching. Sources: `Base64.xs`;
  <https://raw.githubusercontent.com/python/cpython/main/Modules/binascii.c>;
  buch `mojov1/appendix/cheat-sheet`.

## Sources

- MIME::Base64 POD (latest): <https://perldoc.perl.org/MIME::Base64>
- MIME::Base64 POD for Perl 5.8.0 (v2.12, DIAGNOSTICS):
  <https://perldoc.perl.org/5.8.0/MIME::Base64>
- MIME::Base64 distribution page: <https://metacpan.org/pod/MIME::Base64>
- MIME::Base64 PM source:
  <https://raw.githubusercontent.com/Dual-Life/mime-base64/master/lib/MIME/Base64.pm>
- MIME::Base64 XS source:
  <https://raw.githubusercontent.com/Dual-Life/mime-base64/master/Base64.xs>
- MIME::Base64 change log:
  <https://raw.githubusercontent.com/Dual-Life/mime-base64/master/Changes>
- MIME::Base64 repository: <https://github.com/Dual-Life/mime-base64>
- MIME::Base64::URLSafe source:
  <https://fastapi.metacpan.org/source/KAZUHO/MIME-Base64-URLSafe-0.01/lib/MIME/Base64/URLSafe.pm>
- MIME::Base64::URLSafe distribution:
  <https://metacpan.org/dist/MIME-Base64-URLSafe>
- MIME::Base64::Perl POD: <https://metacpan.org/pod/MIME::Base64::Perl>
- MIME::Base64::Perl source:
  <https://fastapi.metacpan.org/source/GAAS/MIME-Base64-Perl-1.00/lib/MIME/Base64/Perl.pm>
- Mojo::Util source:
  <https://raw.githubusercontent.com/mojolicious/mojo/main/lib/Mojo/Util.pm>
- Mojo::Util POD: <https://docs.mojolicious.org/Mojo/Util.txt>
- Mojo license (Artistic 2.0):
  <https://raw.githubusercontent.com/mojolicious/mojo/main/LICENSE>
- MIME::Decoder::Base64: <https://metacpan.org/pod/MIME::Decoder::Base64>
- PerlIO::via::Base64 (0.05 source):
  <https://fastapi.metacpan.org/source/ELIZABETH/PerlIO-via-Base64-0.05/lib/PerlIO/via/Base64.pm>
- PerlIO::via::Base64 (0.06 release):
  <https://metacpan.org/release/LNATION/PerlIO-Via-Base64-0.06>
- IOLayer::Base64: <https://metacpan.org/pod/IOLayer::Base64>
- Template::Plugin::Filter::Base64:
  <https://metacpan.org/dist/Template-Plugin-Filter-Base64>
- Acme::Base64: <https://metacpan.org/dist/Acme-Base64>
- RFC 4648 (Base16, Base32, Base64): <https://www.rfc-editor.org/rfc/rfc4648.txt>
- RFC 2045 (MIME), referenced by MIME::Base64:
  <https://datatracker.ietf.org/doc/html/rfc2045>
- Mojo stdlib `base64` package: <https://mojolang.org/docs/std/base64/>
- Mojo stdlib `b64encode`: <https://mojolang.org/docs/std/base64/base64/b64encode/>
- Mojo stdlib `b64decode`: <https://mojolang.org/docs/std/base64/base64/b64decode/>
- Mojo stability guarantees: <https://mojolang.org/docs/api-docs/stability/>
- buch `mojov1/stdlib/base64`, `mojov1/errors/error-model`,
  `mojov1/keyword-conventions/raises`, `mojov1/appendix/cheat-sheet`,
  `mojov1/memory/ownership-and-lifetimes`
