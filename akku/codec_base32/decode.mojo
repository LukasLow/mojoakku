from std.os import abort

from .alphabet import Alphabet
from .padding_mode import PaddingMode
from .whitespace import Whitespace
from .base32_error import Base32Error


def decode[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan) raises Base32Error -> List[UInt8]:
    abort("MojoAkku: this API is not yet implemented")


def decode[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8, _]) raises Base32Error -> List[UInt8]:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# decode — decode borrowed encoded text/bytes to an owned List[UInt8].
# Signature:
#   def decode[
#       alphabet: Alphabet = Alphabet.B32_STANDARD,
#       padding_mode: PaddingMode = PaddingMode.STRICT,
#       whitespace: Whitespace = Whitespace.REJECT,
#   ](input: StringSpan) raises Base32Error -> List[UInt8]
#   def decode[
#       alphabet: Alphabet = Alphabet.B32_STANDARD,
#       padding_mode: PaddingMode = PaddingMode.STRICT,
#       whitespace: Whitespace = Whitespace.REJECT,
#   ](input: Span[UInt8]) raises Base32Error -> List[UInt8]
# What it does:
#   Turns encoded text (StringSpan) or the same bytes (Span[UInt8]) back into
#   raw bytes. The accepted symbol set and case policy are fixed by `alphabet`
#   (both base32 alphabets are uppercase-only on decode). The defaults require
#   strict RFC 4648 canonical input and reject whitespace; see Alphabet,
#   PaddingMode and Whitespace for the other options. Input is borrowed and may
#   be empty — an empty input decodes to an empty List.
# Returns:
#   A newly owned List[UInt8], at most decoded_len(input_length) bytes (exact
#   only for a full final quantum with no skipped bytes). The caller owns it.
# Errors:
#   raises Base32Error, all recoverable data errors:
#     INVALID_SYMBOL  — a byte outside the alphabet (including lowercase and
#                       whitespace under REJECT) or a non-zero trailing bit
#                       under STRICT.
#     INVALID_LENGTH  — a structurally impossible remainder (1, 3 or 6 symbols).
#     INVALID_PADDING — missing, excess or misplaced '='.
#   The allocating form is atomic: on failure no List is produced.
# Example:
#   decode("MZXW6YTBOI======")   # -> [102, 111, 111, 98, 97, 114]
#   decode("MY======")          # -> [102]
#   decode("MZ!W6===")          # raises INVALID_SYMBOL
#   decode("MY")                # raises INVALID_PADDING under STRICT
# API-DOCS-END
