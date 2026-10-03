# base32 research: Perl

## 1. Standard library support

Perl's **core** has no base32 at all — and, unlike base64, no core-distribution
package either. Base32 lives only in a separate CPAN distribution,
`MIME::Base32`, whose README says it "is for encoding/decoding data much the way
that `MIME::Base64` does". (Source: https://metacpan.org/pod/MIME::Base32)

For contrast: base64 ships with perl as the core-distribution module
`MIME::Base64` (XS/C), and base16 is a Perl core language feature via
`pack`/`unpack` templates `H`/`h`. So of the RFC 4648 family, only base32 is
outsourced to a non-core CPAN dist. (Sources: https://perldoc.perl.org/MIME::Base64,
https://perldoc.perl.org/functions/pack)

The `MIME::Base32` implementation is **pure Perl**, not XS: `encode_base32` does
`unpack('B*', $arg)`, groups the bit string in fives, and translates
`tr|\0-\37|A-Z2-7|`; `decode_base32` does the reverse with `tr|A-Z2-7|\0-\37|`
after `uc(shift)`. (Source:
https://raw.githubusercontent.com/perl5-utils/MIME-Base32/master/lib/MIME/Base32.pm)

**Mojo anchor:** Mojo's stdlib has no base32. The `mojov1` buch `stdlib/base64`
page records only `b64encode`, `b64decode`, `b16encode`, `b16decode`; a
`buch_search` for "base32" returns no hits. (Source: `mojov1` buch
`stdlib/base64`.)

## 2. Relevant community libraries

- **MIME::Base32** — CPAN, module version 1.303 (18 May 2017), "License:
  perl_5", original author Daniel Peder, current maintainer Jens Rehsack;
  "Bus factor: 1" and "8105 / 1 / 0" testers on MetaCPAN. It is the only module
  providing RFC 4648 §6/§7 base32 in the Perl ecosystem. (Source:
  https://metacpan.org/pod/MIME::Base32)
- **MIME::Base64** — core dist, author Gisle Aas, "same terms as Perl itself",
  XS implementation; base64 only (see the sibling run's `perl.md` §2).
- No widely-used third-party base32 with a different API surfaced; the reference
  signal is `MIME::Base32` alone. (Assessment: derived from the MetaCPAN listing
  above.)

## 3. Exposed APIs

`MIME::Base32` (Source: https://metacpan.org/pod/MIME::Base32 and the source
`lib/MIME/Base32.pm`):

- Exported by default: `encode_base32`, `decode_base32`.
- Exported on request (`@EXPORT_OK`): `encode_rfc3548`, `decode_rfc3548`,
  `encode_09AV`, `decode_09AV`, `encode_base32hex`, `decode_base32hex`.
- Synonyms: `encode` = `encode_base32`; `decode` = `decode_base32`;
  `encode_rfc3548` = `encode_base32`; `encode_09AV` = `encode_base32hex`.
- **No length-prediction function** (unlike `MIME::Base64`'s
  `encoded_base64_length`/`decoded_base64_length`), and **no line-wrapping or
  `$eol` parameter** (unlike `MIME::Base64`). (Assessment: derived from the full
  export/POD list in the source.)

The base32 output is unpadded: `encode_base32` appends zero bits to reach a
whole number of 5-bit groups and then translates; it never emits `=`.
(Assessment: derived from the source — there is no `'='` anywhere in the
encode/decode bodies.)

## 4. Error representation

`MIME::Base32` has **no error path and no exceptions** for malformed input —
worse than `MIME::Base64`, which at least silently ignores unknown characters:

- `decode_base32` starts with `my $arg = uc(shift || '')` then
  `$arg =~ tr|A-Z2-7|\0-\37|`. `tr///` deletes (does **not** map to an error) any
  character outside `A-Z2-7'` after uppercasing, so arbitrary junk is silently
  dropped before bit-unpacking. The final `$l & ~7` truncation discards any
  leftover partial group. No `die`, no `croak`, no return-code sentinel. (Source:
  https://raw.githubusercontent.com/perl5-utils/MIME-Base32/master/lib/MIME/Base32.pm)
- `encode_base32` only guards `undef` (`return '' unless defined($arg)`); it
  never fails otherwise.
- `decode_base32hex` is the same pattern with `tr|0-9A-V|\0-\37|`.

So the error representation is: **none** — bad input yields truncated or
garbage bytes. (Assessment: derived from the source above.)

## 5. Ownership semantics

Perl uses reference-counted SVs (scalars); there is no manual free. Both
functions return a **new scalar** produced by `pack`/`tr`/`uc` operations, each
of which may allocate temporaries:

- `encode_base32` builds a bit-string via `unpack('B*')`, grows it with
  substitutions, packs it, then translates it — several intermediate SVs, then
  the returned SV is owned by the caller.
- `decode_base32` returns a new SV; the input SV is only read (`shift`, `uc`
  returns a copy, `tr` mutates that copy).

There is no caller-provided output buffer and no length-computation API, so a
caller cannot pre-size anything. (Source:
https://raw.githubusercontent.com/perl5-utils/MIME-Base32/master/lib/MIME/Base32.pm)
(Assessment: derived from the source above.)

## 6. Blocking / non-blocking

Not applicable. Pure CPU-bound encode/decode with no I/O and no async model;
`encode_base32`/`decode_base32` run to completion synchronously. (Source:
https://metacpan.org/pod/MIME::Base32)

## 7. Alphabet variants, case and padding

- **Standard base32 (RFC 3548 §5 / RFC 4648 §6)**: `encode_base32` /
  `decode_base32`, alphabet `[A-Z2-7]`. This is the default since version 1.0;
  "Prior to version 1.0, `MIME::Base32` used the `base32hex` … methods by
  default." (Source: https://metacpan.org/pod/MIME::Base32)
- **base32hex (RFC 4648 §7)**: `encode_base32hex` / `decode_base32hex`
  (aliases `encode_09AV` / `decode_09AV`), alphabet `[0-9A-V]`. (Source: the
  source file `lib/MIME/Base32.pm`.)
- **Case handling**: `decode_base32` and `decode_base32hex` both apply
  `uc(shift)` first, so **decoding is case-insensitive by default** (lowercase
  is uppercased, then translated). Encoding always emits uppercase. There is no
  option to make decoding case-sensitive. (Source:
  https://raw.githubusercontent.com/perl5-utils/MIME-Base32/master/lib/MIME/Base32.pm)
- **Padding**: **none is emitted and none is expected.** `encode_base32` pads
  the *bit string* with zero bits to a multiple of 5 and translates; the output
  is the minimal number of symbols (`8*ceil(n/5) - padding`) with no `=`. Decode
  tolerates any partial group by truncating (`$l & ~7`). So `"f"` encodes to
  `"MY"`, not `"MY======"`. (Assessment: derived from the source; this is a
  deliberate divergence from RFC 4648 §3.2, which requires padding by default
  unless the referring spec says otherwise.)
- **Crockford base32**: **not** provided. (Assessment: derived from the export
  list.)
- **RFC 4648 reference**: §6 Table 3 (`A-Z2-7`), §7 Table 4 (`0-9A-V`), §3.2
  padding, §3.4 confusables, §3.5 canonical encoding.
  (https://www.rfc-editor.org/rfc/rfc4648.txt)

(Assessment: derived from the source above: Perl's base32 is the least
RFC-conformant of the surveyed languages on padding — it is effectively an
unpadded codec with a lenient, case-folding decoder and no error detection.)

## 8. Timeouts

Not applicable — no I/O, no locks, no cancellation surface. `MIME::Base32`
exposes no timeout or signal integration. (Source:
https://metacpan.org/pod/MIME::Base32)

## 9. Streaming / incremental encode and decode

There is **no incremental encoder/decoder object and no chunking guidance**.
Every function is one-shot over a whole scalar. (Assessment: derived from the
absence of any streaming API, context or example in
https://metacpan.org/pod/MIME::Base32 and the source.)

Leftover-byte handling is entirely the caller's: to stream you must align encode
chunks to a multiple of 5 bytes and carry the remainder, and on decode buffer to
a multiple of 8 symbols. Unlike `MIME::Base64`, `MIME::Base32` does not even
document the 57-byte/76-char chunking recipe. (Sources: the source above;
contrast https://perldoc.perl.org/MIME::Base64.)

## 10. Interesting design decisions

- **Pure-Perl bit-string implementation.** `unpack('B*')` → regex/substitution
  grouping → `pack`/`tr` is a concise, readable algorithm; it is also slow, and
  contrasts with `MIME::Base64`'s XS/256-byte-table design. (Source:
  https://raw.githubusercontent.com/perl5-utils/MIME-Base32/master/lib/MIME/Base32.pm)
- **Unpadded by construction.** By padding the bit string rather than the
  character count, the encoder naturally emits no `=`; the decode side
  truncates. Simple, but non-conformant with RFC 4648 §3.2. (Source: the source
  file.)
- **Case-folding on decode by `uc()`.** One call makes decode case-insensitive
  across both alphabets — the same security trade-off RFC 4648 §12 warns about.
- **base32hex as a translation table swap** (`tr|0-9A-V|` vs `tr|A-Z2-7|`) rather
  than a separate implementation, i.e. alphabetical variant as data.
- **A separate CPAN dist with a bus factor of 1** while base64 is core — an
  inconsistent packaging of one RFC 4648 family. (Source:
  https://metacpan.org/pod/MIME::Base32)
- **Synonym clutter**: `encode`/`encode_rfc3548`/`encode_base32` and the `09AV`
  names all alias the same two functions, a legacy of the pre-1.0 default
  switch. (Source: the source file.)

## 11. Decisions NOT to copy

- **No error signal on decode.** `tr///` silently deletes every out-of-alphabet
  character, and partial groups are truncated, so corruption is undetectable. A
  Mojo API must report invalid input via `raises`/`Result`. (Source: the source
  file.)
- **Unpadded-only encoding with no padding option.** RFC 4648 §3.2 requires
  padding by default; a predictable API should offer `padded` explicitly rather
  than hard-code unpadded.
- **Case-insensitive decode with no strict switch.** RFC 4648 §12 recommends
  against default case-insensitivity for base32; make it opt-in.
- **A whole-scalar-only API with no size function.** No `encoded_base32_length`
  equivalent exists, so callers cannot pre-size; the base64 module's length
  functions are worth copying instead.
- **Split base32 across a separate CPAN dist with a bus factor of 1** while
  base64 is core.
- **Legacy synonym sprawl** (`encode`, `encode_rfc3548`, `encode_09AV`, …).
  Pick one name per concept.
- **No documented chunking contract** even though the base64 module documents
  one. (Assessment: derived from the absence of streaming/chunk guidance.)

## 12. Ideas fitting Mojo

- **Separate pure `encoded_length` / `decoded_length` functions** (the base32
  analogue of `MIME::Base64`'s length API and the missing piece in
  `MIME::Base32`), so callers can pre-size `List[UInt8]`/`String` buffers without
  allocating twice. (Sources: https://perldoc.perl.org/MIME::Base64;
  https://metacpan.org/pod/MIME::Base32.)
- **Alphabet as constants/enum** (standard base32, base32hex, later Crockford)
  rather than a separate function per variant, matching this library's intended
  shape.
- **Explicit strict decode** contrasting Perl's silent `tr///` deletion: a
  `b32decode(..., raises)` that rejects non-alphabet bytes, rejecting the final
  partial group's symbol counts (1, 3, 6) the way cppcodec/Go do.
- **Padding as an explicit option**: `padded=True` default (RFC 4648 §3.2) with
  `padded=False` matching Perl's implied unpadded behavior — but make it visible.
- **A 32-entry encode table and 256-entry reverse table as immutable constants**
  (as perl does via `tr`), naturally expressible in Mojo.
- **Borrowed input, owned output**: take `borrowed` bytes, return an owned
  `String`/`List[UInt8]`, mirroring Perl's immutable-scalar model without the
  intermediate bit-string copies.
- **Case policy as an explicit enum** rather than a blanket `uc()`.

(Assessment: derived from the Perl findings above and `mojov1` buch
`stdlib/base64`.)

## Sources

- https://metacpan.org/pod/MIME::Base32
- https://raw.githubusercontent.com/perl5-utils/MIME-Base32/master/lib/MIME/Base32.pm
- https://perldoc.perl.org/MIME::Base64
- https://perldoc.perl.org/functions/pack
- RFC 4648, The Base16, Base32, and Base64 Data Encodings:
  https://www.rfc-editor.org/rfc/rfc4648.txt
- Mojo side (not researched here): `mojov1` buch `stdlib/base64`
