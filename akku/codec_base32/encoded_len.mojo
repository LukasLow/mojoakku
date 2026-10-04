from .padding import Padding

from akku.codec_base32._internal.engine import encoded_len_core


# n < 0 is defined to return 0 rather than trap (caller programming error).
def encoded_len[
    padding: Padding = Padding.REQUIRED,
](n: Int) -> Int:
    return encoded_len_core[padding](n)

# API-DOCS-START
# encoded_len — exact encoded length for n raw input bytes.
# Signature:
#   def encoded_len[
#       padding: Padding = Padding.REQUIRED,
#   ](n: Int) -> Int
# What it does:
#   Returns how many characters `encode` will produce for an input of `n` raw
#   bytes under `padding`, so a caller can pre-size a buffer without guessing. It
#   is pure, allocation-free and compile-time-callable (`comptime encoded_len(...)`),
#   which makes it usable in buffer sizing. There is no alphabet parameter: both
#   base32 alphabets share the same 5<->8 geometry, so the alphabet cannot change
#   the length. The exact formulas are:
#     REQUIRED — 8 * ((n + 4) // 5)
#     OMITTED  — (n * 8 + 4) // 5
# Returns:
#   The exact encoded length as an Int; `n = 0` gives 0. `n < 0` is a caller
#   programming error that is defined to return 0 rather than trap.
# Errors:
#   none — the function is total and cannot fail.
# Example:
#   encoded_len(1)                                  # -> 8
#   encoded_len(5)                                  # -> 8
#   encoded_len(6)                                  # -> 16
#   encoded_len[Padding.OMITTED](1)                 # -> 2
#   encoded_len[Padding.OMITTED](5)                 # -> 8
# API-DOCS-END
