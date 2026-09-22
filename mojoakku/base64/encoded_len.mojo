from .alphabet import Alphabet
from .padding import Padding

from base64._internal.engine import encoded_len_core


# n < 0 is defined to return 0 rather than trap (caller programming error).
def encoded_len[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](n: Int) -> Int:
    return encoded_len_core[alphabet, padding](n)

# API-DOCS-START
# encoded_len — exact encoded length for n raw input bytes.
# Signature:
#   def encoded_len[
#       alphabet: Alphabet = Alphabet.B64_STANDARD,
#       padding: Padding = Padding.REQUIRED,
#   ](n: Int) -> Int
# What it does:
#   Returns how many characters `encode` will produce for an input of `n` raw
#   bytes under `alphabet` and `padding`, so a caller can pre-size a buffer
#   without guessing. It is pure, allocation-free and compile-time-callable
#   (`comptime encoded_len(...)`), which makes it usable in buffer sizing. The
#   exact formulas are base64 REQUIRED 4*((n+2)//3) and OMITTED
#   ceil(n/3)*4 - ((3-n%3)%3); base32 REQUIRED 8*((n+4)//5) and OMITTED
#   (n*8+4)//5; base16 2*n for both padding values.
# Returns:
#   The exact encoded length as an Int; `n = 0` gives 0. `n < 0` is a caller
#   programming error that is defined to return 0 rather than trap.
# Errors:
#   none — the function is total and cannot fail.
# Example:
#   encoded_len(1)                                       # -> 4
#   encoded_len(6)                                       # -> 8
#   encoded_len[Alphabet.B64_STANDARD, Padding.OMITTED](1)  # -> 2
#   encoded_len[Alphabet.B32_STANDARD, Padding.REQUIRED](5) # -> 8
#   encoded_len[Alphabet.HEX_LOWER](5)                   # -> 10
# API-DOCS-END
