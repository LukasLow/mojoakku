from .alphabet import Alphabet
from .padding_mode import PaddingMode
from .whitespace import Whitespace
from .base64_error import Base64Error

from base64._internal.engine import decode_into_core


def decode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan) raises Base64Error -> List[UInt8]:
    var result = List[UInt8]()
    _ = decode_into_core[alphabet, padding_mode, whitespace](input.as_bytes(), result)
    return result^


def decode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8, _]) raises Base64Error -> List[UInt8]:
    var result = List[UInt8]()
    _ = decode_into_core[alphabet, padding_mode, whitespace](input, result)
    return result^

# API-DOCS-START
# decode — decode borrowed encoded text/bytes to an owned List[UInt8].
# Signature:
#   def decode[
#       alphabet: Alphabet = Alphabet.B64_STANDARD,
#       padding_mode: PaddingMode = PaddingMode.STRICT,
#       whitespace: Whitespace = Whitespace.REJECT,
#   ](input: StringSpan) raises Base64Error -> List[UInt8]
#   def decode[
#       alphabet: Alphabet = Alphabet.B64_STANDARD,
#       padding_mode: PaddingMode = PaddingMode.STRICT,
#       whitespace: Whitespace = Whitespace.REJECT,
#   ](input: Span[UInt8]) raises Base64Error -> List[UInt8]
# What it does:
#   Turns encoded text (StringSpan) or the same bytes (Span[UInt8]) back into
#   raw bytes. The accepted symbol set and case policy are fixed by `alphabet`.
#   The defaults require strict RFC 4648 canonical input and reject whitespace;
#   see Alphabet, PaddingMode and Whitespace for the other options. Input is
#   borrowed and may be empty — an empty input decodes to an empty List.
# Returns:
#   A newly owned List[UInt8], at most decoded_len(input_length) bytes (exact
#   only for a full final quantum with no skipped bytes). The caller owns it.
# Errors:
#   raises Base64Error, all recoverable data errors:
#     INVALID_SYMBOL  — a byte outside the alphabet (including whitespace under
#                       REJECT) or a non-zero trailing bit under STRICT.
#     INVALID_LENGTH  — an impossible remainder.
#     INVALID_PADDING — missing, excess or misplaced '='.
#   The allocating form is atomic: on failure no List is produced.
# Example:
#   decode("Zm9vYmFy")   # -> [102, 111, 111, 98, 97, 114]
#   decode("Zg==")       # -> [102]
#   decode("Zm!v")       # raises INVALID_SYMBOL
#   decode("Zg")         # raises INVALID_PADDING under STRICT
# API-DOCS-END
