from .alphabet import Alphabet
from .padding_mode import PaddingMode
from .whitespace import Whitespace

from base64._internal.engine import is_valid_core


# True iff decode with the same parameters would succeed; allocates nothing.
def is_valid[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan) -> Bool:
    return is_valid_core[alphabet, padding_mode, whitespace](input.as_bytes())


def is_valid[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8, _]) -> Bool:
    return is_valid_core[alphabet, padding_mode, whitespace](input)

# API-DOCS-START
# is_valid — allocation-free validity predicate returning Bool.
# Signature:
#   def is_valid[
#       alphabet: Alphabet = Alphabet.B64_STANDARD,
#       padding_mode: PaddingMode = PaddingMode.STRICT,
#       whitespace: Whitespace = Whitespace.REJECT,
#   ](input: StringSpan) -> Bool
#   def is_valid[
#       alphabet: Alphabet = Alphabet.B64_STANDARD,
#       padding_mode: PaddingMode = PaddingMode.STRICT,
#       whitespace: Whitespace = Whitespace.REJECT,
#   ](input: Span[UInt8]) -> Bool
# What it does:
#   Checks whether `input` is acceptable to `decode` with the same parameters,
#   without building any decoded output. It performs the full validation —
#   symbol membership under the alphabet's case policy, quantum structure,
#   padding count and placement, and, under STRICT, the final symbol's zero
#   trailing bits — but allocates nothing. Input is borrowed and may be empty;
#   an empty input is valid under every policy.
# Returns:
#   True iff `decode` with the same parameters would succeed. A scalar Bool; the
#   call allocates and retains nothing.
# Errors:
#   none — it never raises; every malformed condition is reported as False.
# Example:
#   is_valid("Zm9vYmFy")                     # -> True
#   is_valid("Zm!v")                         # -> False
#   is_valid("Zg")                           # -> False under STRICT
#   is_valid[Alphabet.B64_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]("Zg")
#                                            # -> True
#   is_valid[Alphabet.HEX_UPPER]("666F")     # -> True
# API-DOCS-END
