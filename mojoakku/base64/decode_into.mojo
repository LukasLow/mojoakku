# API-DOCS-START
# decode_into — decode borrowed encoded text/bytes into a caller-owned List.
# Status: implemented
# Signature: def decode_into[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding_mode: PaddingMode = PaddingMode.STRICT,
#   whitespace: Whitespace = Whitespace.REJECT,
# ](input: StringSpan, mut result: List[UInt8]) raises Base64Error -> Int
# def decode_into[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding_mode: PaddingMode = PaddingMode.STRICT,
#   whitespace: Whitespace = Whitespace.REJECT,
# ](input: Span[UInt8], mut result: List[UInt8]) raises Base64Error -> Int
# Semantics: `input` is borrowed encoded text or bytes; `result` is a
#   caller-owned mutable List[UInt8], appended to (append semantics); capacity is
#   reserved by the implementation. Returns the number of decoded bytes appended.
#   On error, complete quanta decoded before the first invalid quantum remain
#   appended and the count is not returned; compare len(result) before and after
#   for partial progress. Caller owns result on success and error; input stays
#   borrowed. No I/O.
# Errors: raises Base64Error with the same kinds as decode, all recoverable. A
#   partial prefix (a whole number of bytes, complete quanta only) may already be
#   appended when the error is raised.
# Tests: test_base64_decode_into.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses a partial-commit appending in-place decoder because
#   Go's AppendDecode(dst, src) ([]byte, error) grows the caller's buffer and
#   returns partial output alongside its error, and data-encoding documents the
#   same contract as DecodePartial{read, written, error}. This makes error
#   recovery first-class. The append contract keeps a caller's prior data intact.
# API-DOCS-END

from .alphabet import Alphabet
from .padding_mode import PaddingMode
from .whitespace import Whitespace
from .base64_error import Base64Error

from base64._internal.engine import decode_into_core


# decode_into (StringSpan) — decode encoded text into a caller-owned List.
#
# Parameters: `input` is borrowed encoded text; `result` is caller-owned and
# appended to (append semantics); capacity is reserved by the implementation.
# Return / meaning: the number of decoded bytes appended.
# Errors: raises Base64Error with the same kinds as `decode`. On error, complete
# quanta decoded before the first invalid quantum remain appended; the appended
# prefix is always a whole number of bytes.
# Semantics (one line): partial-commit decode with an append contract.
def decode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan, mut result: List[UInt8]) raises Base64Error -> Int:
    return decode_into_core[alphabet, padding_mode, whitespace](input.as_bytes(), result)


# decode_into (Span[UInt8]) — decode encoded bytes into a caller-owned List.
#
# Parameters: `input` is borrowed encoded bytes; `result` is caller-owned and
# appended to; capacity is reserved by the implementation.
# Return / meaning: the number of decoded bytes appended.
# Errors: raises Base64Error with the same kinds as `decode`; a partial prefix of
# complete quanta may already be appended when the error is raised.
# Semantics (one line): the byte overload of the partial-commit appending
# decoder.
def decode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8, _], mut result: List[UInt8]) raises Base64Error -> Int:
    return decode_into_core[alphabet, padding_mode, whitespace](input, result)
