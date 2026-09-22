# API-DOCS-START
# Purpose
#
# `mojoakku/base64` is the single source of truth for the MojoAkku `base64`
# library. It defines the public API, the full semantics of every entry, the
# error surface, the ownership and lifecycle rules, and the conventions that
# every sibling library copies. It is designed for a low-vision user: one naming
# scheme, one option model, one typed error, borrowed input, owned output and
# explicit streaming with a mandatory flush.
#
# Status legend
#
# Every API entry carries a `Status:` field with exactly one of these values:
#   planned     — designed and documented; no code exists yet.
#   scaffolded  — a stub with the documented signature exists; behaviour is not
#                 implemented.
#   tested      — tests exist and pass against the implementation.
#   implemented — implemented and passing its tests.
#   benchmarked — implemented, tested and measured against the performance goals.
#
# Dependencies
#
# `base64` has no dependency edge to any sibling MojoAkku library. It is a leaf
# in the dependency graph: it depends only on the Mojo standard library.
#   Why a leaf: a dependency edge exists only when a library needs another
#   library's public types or functions. `base64` needs none — every parameter
#   and return type (Span[UInt8], StringSpan, String, List[UInt8], Int, Bool,
#   UInt8, Array) comes from the Mojo standard library. Adding an edge would
#   create coupling without a technical reason.
#   No physical nesting: `mojoakku/base64/` is a flat sibling under `mojoakku/`.
#   Direction of future edges: if a later library (e.g. an HTTP or MIME layer)
#   needs base64, the edge points from that library to `base64`, never outward.
#
# Overview
#
# MojoAkku `base64` is a pure, in-process data-encoding library that covers the
# RFC 4648 family — base64 (standard), base64url, base32 (standard), base32hex
# and base16/hex — through one uniform API shape. The problem space is well
# covered by every reference language, so the value of this library is not
# "another base64": it is a predictable, consistent and easy-to-read surface for
# a low-vision user — one naming scheme, one option model, one typed error,
# borrowed input, owned output, and explicit streaming with a mandatory flush.
# The reference ecosystems each get one or two of these right and rarely all at
# once (Go's global mutable encodings, Rust's deprecated free functions and
# Drop-suppressed write errors, Python's lossy validate=False default, Java's
# Object-erased bridge, C/C++ sentinels and abort(), Elixir's lossy :error,
# Perl's silent-ignore anti-reference).
#
# Mojo's own stdlib `base64` is the direct Mojo anchor: four functions
# (b64encode with three overloads including `mut result: String`, b64decode,
# b16encode, b16decode), borrowed StringSpan/Span[UInt8] in, owned
# String/List[UInt8] out, decoders raise. It has no alphabet parameter, no
# base32, and no streaming — the three gaps this library closes.
#
# Goals
#
# 1. One consistent shape across the whole radix family. base64, base64url,
#    base32, base32hex and base16/hex all use the same function names and the
#    same option model, so learning one teaches the rest.
# 2. Zero-cost alphabet specialization. The alphabet and the padding/whitespace
#    policies are compile-time inputs, so table lookups and branches are resolved
#    while compiling and there is no runtime variant switch.
# 3. Explicit policy, strict by default. Padding, whitespace handling and
#    canonicality are visible in the signature; silent leniency is never the
#    default.
# 4. Byte-first borrowing. Encode borrows bytes; decode borrows encoded text;
#    encode returns an owned String; decode returns an owned List[UInt8].
# 5. Allocation-free options. Length functions, an in-place encode/decode
#    overload and an allocation-free validity predicate let a caller avoid
#    allocations on the hot path.
# 6. Structured failure. A single typed error with a kind discriminant and a
#    position so callers can distinguish bad symbol, bad length and bad padding.
# 7. Explicit streaming. A stateful encoder and decoder carry the sub-quantum
#    remainder; the final flush is mandatory and cannot be silently skipped.
# 8. Readability for a low-vision user. Stable names, one option model, one
#    error type, identical field names in every documented entry.
# 9. Pure Mojo. No hidden global state, no Python dependency, no `unsafe`
#    requirement in the public surface.
#
# Non-Goals
#
# Decisions the library deliberately does not copy, each a
# "MojoAkku rejects … because …" statement naming the reference or reasoned
# design constraint:
#   - Implicit newline/whitespace ignoring (Go strips CR/LF even under Strict()).
#   - Panic on bad configuration (Go's NewEncoding/WithPadding).
#   - Negative padding sentinels (Go's NoPadding = -1 rune).
#   - Mutable global encoding variables (Go's StdEncoding/RawStdEncoding vars).
#   - Lax cross-alphabet decode (Node/js-base64 mixing URL-safe into base64).
#   - Python's legacy file-object API and two Base16 spellings.
#   - Python's b32decode map01 confusable mapping.
#   - Java's Object-erased bridge and checked exceptions in a pure codec.
#   - MIME/line-wrapping options (OpenSSL/Perl/Java getMimeEncoder).
#   - abort() or panic on a mis-sized output buffer (cppcodec/Rust).
#   - Unchecked public decode entry points (decode_slice_unchecked).
#   - Per-variant class names / factory-per-alphabet.
#   - Arbitrary custom alphabets and exotic variants (Crockford, BIN_HEX,
#     BCRYPT, IMAP-MUTF7).
#   - Bare :error with no reason (Elixir's plain decoders).
#   - Silent-ignore decoding (Perl MIME::Base64).
#   - Timeouts, cancellation and async (a pure memory transform has no I/O).
#   - A constant-time "secure" engine and a SIMD engine in the first API.
#   - A separable flush + argument-light finish.
#   - I/O stream adapters (io::Read/io::Write wrappers).
#
# Reference APIs
#
# The decision inputs, taken from the Phase-1 research files. The names cited in
# the justifications below name the reference API(s) and their source section.
#   - Alphabet as first-class value: Go Encoding/NewEncoding/StdEncoding/
#     URLEncoding/HexEncoding (go.md §3, §7, §10).
#   - Variant as type / zero-cost specialization: cppcodec detail::codec,
#     generates_padding()/requires_padding()/should_ignore() (cpp.md §7, §10, §12).
#   - Padding as explicit policy: Rust DecodePaddingMode + encode_padding; Go
#     WithPadding/NoPadding; Python 3.15 padded; Java withoutPadding().
#   - Explicit ignore/whitespace policy: libsodium `ignore` with NULL = strict;
#     data-encoding `ignore`.
#   - Byte-first borrowed in / owned out: Mojo stdlib b64encode/b64decode; ES
#     2027 Uint8Array.fromBase64/toBase64; C++ std::span (base64pp).
#   - In-place output overload: Mojo stdlib b64encode(input, mut result); Go
#     Encode(dst, src); Java encode(src, dst) -> int; cppcodec Result& refill.
#   - Length functions: Perl encoded_base64_length/decoded_base64_length; Go
#     EncodedLen/DecodedLen; Commons getEncodedLength; cppcodec
#     encoded_size/decoded_max_size; Rust encoded_len/decoded_len_estimate.
#   - Typed error with kind+offset: Rust DecodeError; data-encoding DecodeError{
#     position,kind}; Python binascii.Error vs Incomplete; Go CorruptInputError;
#     cppcodec parse_error/symbol_error.
#   - Streaming with explicit finalize: Rust EncoderWriter::finish; data-encoding
#     Encoder::append/finalize; JS setFromBase64 -> {read,written}; Java wrap;
#     OpenSSL EVP_EncodeFinal.
#   - Validity predicate without allocation: Elixir valid64?/valid32?/valid16?.
#   - Strict canonicality (trailing bits): gnulib; glibc b64_pton; Go Strict();
#     Commons CodecPolicy.STRICT; RFC 4648 §3.5.
#   - Compile-time reverse table: Perl index_64; js-base64 lookup/revLookup;
#     cppcodec make_lookup_table.
#   - Uniform radix shape: Go base64/base32 identical naming; Erlang one-table
#     two-alphabet offsets.
#   - Mojo language anchors: Span/StringSpan borrowed views; List/String owned;
#     comptime value parameters; typed raises errors; @explicit_destroy; with.
#
# Public API
#
# Every entry below is listed with its one-line meaning and is fully specified in
# its own file's API-DOCS block. Names are stable.
#
# Option and error types
#   1. Alphabet — compile-time value type selecting the symbol table; named
#      constants B64_STANDARD, B64_URL, B32_STANDARD, B32_HEX, HEX_LOWER,
#      HEX_UPPER.
#   2. Padding — compile-time encode padding policy: REQUIRED, OMITTED.
#   3. PaddingMode — compile-time decode padding policy: STRICT, TOLERANT.
#   4. Whitespace — compile-time decode whitespace policy: REJECT, IGNORE.
#   5. ErrorKind — compile-time discriminant for Base64Error: INVALID_SYMBOL,
#      INVALID_LENGTH, INVALID_PADDING.
#   6. Base64Error — the one typed error carrying kind: ErrorKind and
#      position: Int.
# One-shot encode/decode
#   7. encode — encode borrowed bytes/text to an owned String; two overloads
#      (Span[UInt8], StringSpan).
#   8. encode_into — encode borrowed bytes/text into a caller-owned mut result:
#      String and return the number of characters written; two overloads.
#   9. decode — decode borrowed encoded text/bytes to an owned List[UInt8],
#      raising Base64Error; two overloads (StringSpan, Span[UInt8]).
#  10. decode_into — decode borrowed encoded text/bytes into a caller-owned
#      mut result: List[UInt8] and return the number of bytes written, raising
#      Base64Error; two overloads.
# Buffer sizing and validation
#  11. encoded_len — pure function returning the exact encoded length for n
#      input bytes under an alphabet and padding policy.
#  12. decoded_len — pure function returning the maximum decoded byte count for
#      n encoded symbols under an alphabet.
#  13. is_valid — allocation-free predicate returning Bool for whether input
#      conforms to an alphabet and the decode policies; never raises; two
#      overloads (StringSpan, Span[UInt8]).
# Streaming
#  14. Encoder — stateful encode value type owning the sub-quantum byte carry;
#      feed + mandatory finish (and discard).
#  15. Decoder — stateful decode value type owning the sub-quantum character
#      carry; feed + mandatory finish (and discard), raising Base64Error.
#
# Error Surface
#
# There is exactly one error type: Base64Error, declared with
# `raises Base64Error` on every decoder. It carries:
#   kind:     ErrorKind — INVALID_SYMBOL, INVALID_LENGTH or INVALID_PADDING.
#   position: Int — zero-based index into the original input where the failure
#             was detected.
#
# Which API can raise which kind:
#   encode, encode_into                         — no
#   encoded_len, decoded_len                    — no
#   is_valid                                    — no (returns Bool)
#   decode, decode_into                         — INVALID_SYMBOL,
#                                                 INVALID_LENGTH,
#                                                 INVALID_PADDING
#   Decoder.feed                                — INVALID_SYMBOL,
#                                                 INVALID_PADDING (never
#                                                 INVALID_LENGTH)
#   Decoder.finish                              — INVALID_SYMBOL,
#                                                 INVALID_LENGTH,
#                                                 INVALID_PADDING (as decode)
#   Encoder.feed/finish/discard                 — no
#   Decoder.discard                             — no
#
# Rules:
#   - One error type per function: Mojo allows at most one error type per
#     signature; Base64Error is it. Callers needing another type wrap it.
#   - Recoverable vs not: every kind is a data error and recoverable; the caller
#     may correct input, truncate at position, or change policy and retry.
#   - No I/O errors: EINTR, EAGAIN/would-block, EOF-as-error and close/shutdown
#     errors cannot occur; the library performs no system call and owns no
#     descriptor. "End of input" is an explicit finish call, not a zero read.
#   - No allocation errors: a failed allocation surfaces as Mojo's usual
#     allocation failure, not as Base64Error.
#   - Diagnostics: Base64Error implements Writable, so print(e) yields a
#     readable, allocation-cheap message including the kind and position.
#
# Conventions
#
#   - One entry per public API member, in design order. Names are stable.
#   - Identical field names and order in every entry: Status, Signature,
#     Semantics, Errors, Tests, Implementation status, Rationale. No field is
#     omitted, even when its value is empty.
#   - Signature is the exact Mojo declaration (copied verbatim from the approved
#     design; the implementation writes Span[UInt8, _] where the design read
#     Span[UInt8]).
#   - Semantics is complete: parameters/preconditions, return/meaning, ownership
#     and the stream-I/O/flush contract as applicable.
#   - Errors names every raised or returned error and says whether it is
#     recoverable; pure functions say none.
#   - Tests names the test-file/test name(s) that prove the API.
#   - Rationale is a `MojoAkku uses X because Y` statement naming the reference
#     API and its research section.
#   - Terminology is shared: symbol, quantum, carry, padding and canonical are
#     defined once and used consistently. A symbol is one encoded character; a
#     quantum is the smallest group of input bytes mapping to a whole number of
#     symbols (base64 3↔4, base32 5↔8, base16 1↔2); the carry is the held-back
#     remainder of a partial quantum; padding is the '=' completing the final
#     partial quantum (base64/base32 only); canonical means padding is present in
#     exactly the required count, no symbols follow padding, and the unused
#     trailing bits of the final symbol are zero (RFC 4648 §3.5).
#
# Ownership and Lifecycle
#
#   Borrowed input, owned output. Every encode takes Span[UInt8] or StringSpan by
#   immutable reference and never copies or consumes it; every decode does the
#   same. Every allocating call returns a freshly owned String (encode) or
#   List[UInt8] (decode).
#   In-place output. encode_into takes `mut result: String` and decode_into takes
#   `mut result: List[UInt8]`; the callee appends and the caller owns and sizes
#   the buffer. Argument exclusivity guarantees input and output cannot alias.
#   Streaming state. Encoder and Decoder are value types owning only a small
#   fixed Array carry plus a count. They own no heap and no external resource, so
#   @explicit_destroy is used only to make the final flush mandatory, not to
#   manage memory. feed borrows self and its chunk; finish/discard take deinit
#   self and consume the value.
#   No hidden global state. Alphabets, pad policies and error kinds are comptime
#   constants, so two threads (or fibers) share nothing mutable; thread-safety is
#   unconditional.
#   Pure Mojo. The library uses only Span, StringSpan, String, List, Array, Bool,
#   Int, UInt8, comptime parameters, typed raises and @explicit_destroy. No
#   Python, no unsafe_* in the public surface, no C dependency.
#
#   Lifecycle summary:
#     encode / decode            — no (borrow) input; caller owns result; can be
#                                  abandoned (ordinary return).
#     encode_into / decode_into  — no (borrow) input; caller owns result; can be
#                                  abandoned.
#     is_valid / length fns      — no (borrow) input; no allocation; n/a.
#     Encoder / Decoder          — no (borrow chunk); caller owns out; cannot be
#                                  abandoned — finish/discard required.
#
# Open Questions
#
# Most decisions are closed against the reviewed research and the `mojov1` buch.
#
# Closed:
#   - The alphabet is a compile-time value parameter; Mojo's documented scalar
#     and String value-parameter idiom covers the intent. The stronger claim —
#     that a user-struct value may itself be a value-parameter type — was
#     verified during implementation (see below).
#   - The option and error-kind types carry no @fieldwise_init and therefore
#     expose no public arbitrary-id constructor; only their named comptime
#     members exist in the public contract.
#   - Padding and whitespace are explicit comptime policies with named constants.
#   - The error surface is a single typed struct with kind and position.
#   - Re-raising is `raise e^`: Base64Error is Copyable but not
#     ImplicitlyCopyable, so the transfer form is required.
#   - encode_into/decode_into append; this matches Go's AppendEncode/AppendDecode
#     and the Mojo stdlib in-place writer.
#   - Decode case policy is fixed per alphabet: base64 is case-sensitive; base32
#     is case-sensitive (uppercase only); base16 is case-sensitive on decode.
#   - decoded_len gives an explicit partial-quantum contribution for base64 and
#     base32.
#   - decode_into and is_valid offer both StringSpan and Span[UInt8] overloads.
#   - Streaming uses @explicit_destroy with named finish/discard methods taking
#     deinit self.
#   - The flush-before-finish restructure was considered and rejected.
#   - There is no I/O, so EOF/EINTR/EAGAIN/close are structurally not applicable.
#
# Open:
#   - Go base32 decode case sensitivity. go.md §7 says only that base32's
#     decodeMap is built from the uppercase alphabet and is silent on lowercase
#     rejection, so the Go corroboration for B32_* uppercase-only is a GUESS;
#     the Mojo behaviour follows Python (casefold=False), cppcodec (uppercase-only
#     tables) and RFC 4648.
#
# Resolved during implementation:
#   - Named destructor signature — works. finish(deinit self, mut out: String) ->
#     Int (and the raises decoder form) compiled unchanged; callers transfer with
#     `^` (e.g. enc^.finish(out)).
#   - User-struct value as a value-parameter type — works. [alphabet: Alphabet]
#     with user-defined Alphabet/Padding/PaddingMode/Whitespace values compiled;
#     the UInt8-id fallback is not needed.
#   - Span[UInt8] spelling — implementation uses Span[UInt8, _]. The exact
#     documented signature Span[UInt8] is under-specified for Mojo 1.x, which
#     requires an explicit origin; the implementation writes the idiomatic
#     Span[UInt8, _] (wildcard origin). This is a syntax necessity, not an API
#     change. Documented signatures reading Span[UInt8] are to be understood as
#     Span[UInt8, _].
# API-DOCS-END

# MojoAkku base64 — package entry point.
#
# Re-exports the public API from the flat per-entry modules so
# `from base64 import ...` works. Nothing else lives here: the public surface is
# defined by the per-entry files and this file only forwards names.

from .alphabet import Alphabet
from .padding import Padding
from .padding_mode import PaddingMode
from .whitespace import Whitespace
from .error_kind import ErrorKind
from .base64_error import Base64Error
from .encode import encode
from .encode_into import encode_into
from .decode import decode
from .decode_into import decode_into
from .encoded_len import encoded_len
from .decoded_len import decoded_len
from .is_valid import is_valid
from .encoder import Encoder
from .decoder import Decoder
