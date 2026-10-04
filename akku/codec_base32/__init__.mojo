# MojoAkku codec_base32 — package entry point.
#
# Re-exports the public API from the flat per-entry modules so
# `from akku.codec_base32 import ...` works. Nothing else lives here: the public
# surface is defined by the per-entry files and this file only forwards names.

from .alphabet import Alphabet
from .padding import Padding
from .padding_mode import PaddingMode
from .whitespace import Whitespace
from .error_kind import ErrorKind
from .base32_error import Base32Error
from .encode import encode
from .encode_into import encode_into
from .decode import decode
from .decode_into import decode_into
from .encoded_len import encoded_len
from .decoded_len import decoded_len
from .is_valid import is_valid
from .encoder import Encoder
from .decoder import Decoder

# API-DOCS-START
# Purpose   — akku/codec_base32 encodes raw bytes to text and decodes encoded
#   text back to bytes for the two RFC 4648 base32 schemes: base32 standard
#   (A-Z 2-7) and base32hex (0-9 A-V). It is a pure, in-process data transform:
#   no files, sockets, threads or global state.
# Overview  — one uniform shape across both alphabets. Every entry takes the
#   alphabet (and, for decode, the padding and whitespace policies) as
#   compile-time value parameters, so there is no runtime variant switch. The
#   base32 geometry is 5 input bytes <-> 8 symbols, 5 bits per symbol, with '='
#   padding completing the final partial quantum to a multiple of 8. Input is
#   always borrowed (Span[UInt8] or StringSpan); output is either freshly owned
#   (encode -> String, decode -> List[UInt8]) or appended to a caller-owned
#   mut result (encode_into, decode_into). For streams that arrive in pieces,
#   Encoder and Decoder hold the sub-quantum remainder (0-4 bytes on encode,
#   0-7 symbols on decode) and require an explicit finish. Failures surface as
#   one typed error, Base32Error.
# Dependencies — none in code. base32 is a leaf: it imports nothing and depends
#   only on the Mojo standard library (Span, StringSpan, String, List, Int,
#   UInt8, Bool). The catalogue records a build-ordering name-family hint to
#   codec_base64 (the RFC 4648 family is built base64-first); it is not a code
#   import edge.
# Public API — the ordered index (each entry is specified in its own file):
#    1. Alphabet     — compile-time symbol table: B32_STANDARD, B32_HEX.
#    2. Padding      — encode padding policy: REQUIRED, OMITTED.
#    3. PaddingMode  — decode padding/canonicality policy: STRICT, TOLERANT.
#    4. Whitespace   — decode whitespace policy: REJECT, IGNORE.
#    5. ErrorKind    — decode failure reason: INVALID_SYMBOL,
#                      INVALID_LENGTH, INVALID_PADDING.
#    6. Base32Error  — the one typed error: kind: ErrorKind, position: Int.
#    7. encode       — borrowed bytes/text -> owned String (two overloads).
#    8. encode_into  — borrowed bytes/text -> appended to mut result: String;
#                      returns the characters appended (two overloads).
#    9. decode       — borrowed text/bytes -> owned List[UInt8], raising
#                      Base32Error (two overloads).
#   10. decode_into  — borrowed text/bytes -> appended to mut result:
#                      List[UInt8]; returns the bytes appended, raising
#                      Base32Error (two overloads).
#   11. encoded_len  — exact encoded length for n raw bytes under a padding
#                      policy (pure).
#   12. decoded_len  — maximum decoded bytes for n encoded symbols (pure bound).
#   13. is_valid     — allocation-free Bool validity check; never raises (two
#                      overloads).
#   14. Encoder      — stateful streaming encoder: feed + mandatory finish.
#   15. Decoder      — stateful streaming decoder: feed + mandatory finish,
#                      raising Base32Error.
# Error Surface — exactly one error type, Base32Error, carrying
#   kind: ErrorKind and position: Int (zero-based index into the original input;
#   cumulative across chunks for a streaming Decoder). Every kind is a
#   recoverable data error. Which API can raise what:
#     encode, encode_into, encoded_len, decoded_len, is_valid, Encoder.* — no
#     decode, decode_into                                               — INVALID_SYMBOL, INVALID_LENGTH, INVALID_PADDING
#     Decoder.feed                                                      — INVALID_SYMBOL, INVALID_PADDING (never INVALID_LENGTH)
#     Decoder.finish                                                    — INVALID_SYMBOL, INVALID_LENGTH, INVALID_PADDING
#     Decoder.discard                                                   — no
#   There are no I/O or allocation errors: the library owns no descriptor and
#   "end of input" is the caller's finish call. `print(err)` gives a readable
#   kind + position message.
# Conventions — names are stable; the alphabet and policy are chosen at compile
#   time via named constants; the decoder defaults to strict canonical input
#   (PaddingMode.STRICT, Whitespace.REJECT). A symbol is one encoded character;
#   a quantum is the smallest group of input bytes mapping to a whole number of
#   symbols (base32: 5 bytes <-> 8 symbols); the carry is the retained remainder
#   of a partial quantum; padding is the '=' completing the final partial quantum
#   (valid '=' runs complete data-symbol counts 2, 4, 5 or 7; remainders 1, 3 and
#   6 are impossible). Both base32 alphabets are uppercase-only on decode. The
#   decode_into form appends on error (partial commit); decode is atomic.
#   Encoder and Decoder are value types and must be consumed with finish (or
#   discard).
# API-DOCS-END
