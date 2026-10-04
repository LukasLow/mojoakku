from std.os import abort


# Returns a safe upper bound (counts padding and, under IGNORE, whitespace).
def decoded_len(n: Int) -> Int:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# decoded_len — maximum decoded byte count for n encoded symbols.
# Signature:
#   def decoded_len(n: Int) -> Int
# What it does:
#   Returns a safe upper bound on the bytes `decode` can produce from `n`
#   encoded input bytes, so a caller can pre-size a decode buffer. `n` is the
#   total input byte count including padding symbols and, under
#   Whitespace.IGNORE, skipped whitespace; it should be >= 0. It is pure,
#   allocation-free and compile-time-callable. There is no parameter: base32's
#   geometry is fixed, and padding mode does not change the bound because '='
#   symbols are counted as input bytes. The formula is (n // 8) * 5 plus the
#   partial-quantum contribution n % 8 of 2/4/5/7 contributing 1/2/3/4 bytes;
#   a remainder of 1, 3 or 6 contributes 0. Because '=' symbols are counted as
#   input bytes, the result is a true upper bound whenever padding is present.
# Returns:
#   A conservative maximum as an Int; `n = 0` gives 0. `n < 0` is a caller
#   programming error that is defined to return 0.
# Errors:
#   none — the function is total and cannot fail.
# Example:
#   decoded_len(8)     # -> 5
#   decoded_len(16)    # -> 10
#   decoded_len(4)     # -> 2   (4 % 8 == 4 -> 2)
#   decoded_len(7)     # -> 4   (7 % 8 == 7 -> 4)
# API-DOCS-END
