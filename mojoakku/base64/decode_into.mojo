from .alphabet import Alphabet
from .padding_mode import PaddingMode
from .whitespace import Whitespace
from .base64_error import Base64Error

from base64._internal.engine import decode_into_core


# Partial-commit append: whole quanta decoded before the first bad quantum stay in result.
def decode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan, mut result: List[UInt8]) raises Base64Error -> Int:
    return decode_into_core[alphabet, padding_mode, whitespace](input.as_bytes(), result)


def decode_into[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8, _], mut result: List[UInt8]) raises Base64Error -> Int:
    return decode_into_core[alphabet, padding_mode, whitespace](input, result)

# API-DOCS-START
# decode_into — decode borrowed encoded text/bytes into a caller-owned List.
# Signature:
#   def decode_into[
#       alphabet: Alphabet = Alphabet.B64_STANDARD,
#       padding_mode: PaddingMode = PaddingMode.STRICT,
#       whitespace: Whitespace = Whitespace.REJECT,
#   ](input: StringSpan, mut result: List[UInt8]) raises Base64Error -> Int
#   def decode_into[
#       alphabet: Alphabet = Alphabet.B64_STANDARD,
#       padding_mode: PaddingMode = PaddingMode.STRICT,
#       whitespace: Whitespace = Whitespace.REJECT,
#   ](input: Span[UInt8], mut result: List[UInt8]) raises Base64Error -> Int
# What it does:
#   The in-place sibling of `decode`. `input` is borrowed encoded text or bytes;
#   `result` is a caller-owned mutable List[UInt8] that is APPENDED to (prior
#   contents are kept). The implementation reserves capacity itself. The
#   compile-time options match `decode`.
# Returns:
#   The number of decoded bytes appended to `result`. On success the caller owns
#   the enlarged `result`; `input` stays borrowed.
# Errors:
#   raises Base64Error with the same kinds as `decode` (INVALID_SYMBOL,
#   INVALID_LENGTH, INVALID_PADDING), all recoverable. This form is
#   partial-commit: complete quanta decoded before the first invalid quantum stay
#   appended (always a whole number of bytes), while the returned count is not
#   available. Compare len(result) before and after to see the partial progress.
# Example:
#   var result = List[UInt8]()
#   var n = decode_into("Zm9vYmFy", result)   # -> n == 6, result == "foobar" bytes
#   # Append to existing data:
#   var more = List[UInt8]()
#   more.append(UInt8(0xAA))
#   _ = decode_into("Zm9v", more)             # more -> [0xAA, 'f', 'o', 'o']
#   # Partial commit on error:
#   #   decode_into("Zm9v!AAA", out) -> raises, out already holds "foo"
# API-DOCS-END
