# API-DOCS-START
# encode_into — encode borrowed bytes/text into a caller-owned String.
# Status: implemented
# Signature: def encode_into[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding: Padding = Padding.REQUIRED,
# ](input: Span[UInt8], mut result: String) -> Int
# def encode_into[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding: Padding = Padding.REQUIRED,
# ](input: StringSpan, mut result: String) -> Int
# Semantics: `input` is borrowed bytes or text treated as raw bytes; `result` is
#   a caller-owned mutable String appended to (prior contents kept). The
#   implementation reserves capacity itself, so `result` may have zero capacity on
#   entry. Returns the number of encoded characters appended; no new heap
#   allocation beyond result's own growth. Caller owns result; input stays
#   borrowed. No I/O.
# Errors: none; encode cannot fail.
# Tests: test_base64_encode_into.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses an appending in-place `mut result` overload because
#   Go's incremental building block is the Append* family (AppendEncode grows the
#   caller's buffer and returns the extended slice), and the Mojo stdlib's
#   b64encode(input_bytes, mut result: String) writes into the caller's String
#   while reserving capacity, so result may be a 0-capacity string on entry.
#   Append, not overwrite-at-offset-0, is the documented contract.
# API-DOCS-END

from .alphabet import Alphabet
from .padding import Padding

from base64._internal.engine import encode_all


# encode_into (Span[UInt8]) — encode raw bytes into a caller-owned String.
#
# Parameters: `input` is borrowed bytes; `result` is caller-owned and appended
# to (its prior contents are kept). The implementation reserves capacity itself,
# so `result` may have zero capacity on entry.
# Return / meaning: the number of encoded characters appended to `result`.
# Errors: none; encode cannot fail.
# Semantics (one line): append semantics, like Go's AppendEncode.
def encode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: Span[UInt8, _], mut result: String) -> Int:
    var start = result.byte_length()
    encode_all[alphabet, padding](input, result)
    return result.byte_length() - start


# encode_into (StringSpan) — encode text into a caller-owned String.
#
# Parameters: `input` is borrowed text treated byte by byte; `result` is
# caller-owned and appended to; capacity is reserved by the implementation.
# Return / meaning: the number of encoded characters appended to `result`.
# Errors: none; encode cannot fail.
# Semantics (one line): append semantics, matching encode_into's byte overload.
def encode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: StringSpan, mut result: String) -> Int:
    var start = result.byte_length()
    encode_all[alphabet, padding](input.as_bytes(), result)
    return result.byte_length() - start
