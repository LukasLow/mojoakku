from .alphabet import Alphabet

from base64._internal.engine import decoded_len_core


# Returns a safe upper bound (counts padding and, under IGNORE, whitespace).
def decoded_len[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
](n: Int) -> Int:
    return decoded_len_core[alphabet](n)

# API-DOCS-START
# decoded_len — maximum decoded byte count for n encoded symbols.
# Signature:
#   def decoded_len[
#       alphabet: Alphabet = Alphabet.B64_STANDARD,
#   ](n: Int) -> Int
# What it does:
#   Returns a safe upper bound on the bytes `decode` can produce from `n`
#   encoded input bytes, so a caller can pre-size a decode buffer. `n` is the
#   total input byte count including padding symbols and, under
#   Whitespace.IGNORE, skipped whitespace; it should be >= 0. It is pure,
#   allocation-free and compile-time-callable. The formulas are base64
#   (n//4)*3 plus the partial final quantum (n%4 of 2 -> 1, of 3 -> 2, of 1 ->
#   0); base32 (n//8)*5 plus n%8 of 2/4/5/7 contributing 1/2/3/4 (1/3/6
#   contribute 0); base16 n//2. Because '=' symbols are counted as input bytes,
#   the result is a true upper bound whenever padding is present.
# Returns:
#   A conservative maximum as an Int; `n = 0` gives 0. `n < 0` is a caller
#   programming error that is defined to return 0.
# Errors:
#   none — the function is total and cannot fail.
# Example:
#   decoded_len(4)                          # -> 3
#   decoded_len(8)                          # -> 6
#   decoded_len[Alphabet.B32_STANDARD](8)   # -> 5
#   decoded_len[Alphabet.HEX_UPPER](8)      # -> 4
# API-DOCS-END
