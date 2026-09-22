# API-DOCS-START
# encode — encode borrowed bytes/text to an owned String.
# Status: implemented
# Signature: def encode[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding: Padding = Padding.REQUIRED,
# ](input: Span[UInt8]) -> String
# def encode[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding: Padding = Padding.REQUIRED,
# ](input: StringSpan) -> String
# Semantics: `input` is the raw bytes (first overload) or UTF-8 text treated as
#   raw bytes (second overload; no UTF-8 conversion is performed). Borrowed and
#   possibly empty; an empty input returns an empty String. alphabet and padding
#   are compile-time; the defaults are standard base64 with required padding.
#   Returns an owned String of exactly encoded_len bytes. input is never copied or
#   consumed; no hidden global state. No I/O.
# Errors: none for any input; encode cannot fail.
# Tests: test_base64_encode.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses borrowed-bytes-in / owned-String-out because the Mojo
#   stdlib's b64encode and C++ base64pp's encode(std::span<uint8_t const>) both
#   borrow input while returning a fresh value, and ES 2027's byte-first
#   Uint8Array API confirms the direction.
# API-DOCS-END

from .alphabet import Alphabet
from .padding import Padding

from base64._internal.engine import encode_all


# encode (Span[UInt8]) — encode borrowed raw bytes to an owned String.
#
# Parameters: `input` is the raw bytes, borrowed and possibly empty. `alphabet`
# and `padding` are compile-time; defaults are standard base64 with required
# padding.
# Return / meaning: an owned String containing exactly `encoded_len` bytes of
# encoded text; an empty input returns an empty String.
# Errors: none for any input; encode cannot fail.
# Semantics (one line): bytes in, encoded text out, no hidden state.
def encode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: Span[UInt8, _]) -> String:
    var out = String()
    encode_all[alphabet, padding](input, out)
    return out^


# encode (StringSpan) — encode borrowed UTF-8 text treated as raw bytes.
#
# Parameters: `input` is text treated byte by byte (no UTF-8 conversion is
# performed); borrowed and possibly empty. `alphabet` and `padding` are
# compile-time.
# Return / meaning: an owned String containing the encoded text; an empty input
# returns an empty String.
# Errors: none for any input; encode cannot fail.
# Semantics (one line): each input byte is encoded; the text overload mirrors
# the byte overload.
def encode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: StringSpan) -> String:
    var out = String()
    encode_all[alphabet, padding](input.as_bytes(), out)
    return out^
