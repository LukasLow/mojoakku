from std.os import abort

from .bit_error import BitError


# get_bits — extract the inclusive field [hi:lo] of a UInt64, right-aligned.
def get_bits(value: UInt64, hi: Int, lo: Int) raises BitError -> UInt64:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# get_bits — extract the inclusive bit field [hi:lo] of a value, right-aligned.
# Signature:
#   def get_bits(value: UInt64, hi: Int, lo: Int) raises BitError -> UInt64
# What it does:
#   `value` is the carrier; `[hi:lo]` is the inclusive field, with
#   `0 <= lo <= hi <= 63`. The field is returned shifted down so its least
#   significant bit is bit 0, and the result's bits above the field width
#   (`hi - lo + 1`) are zero. The width is `hi - lo + 1`. `hi == lo` is a
#   one-bit field; `[63:0]` returns the whole value.
# Returns:
#   The extracted field as a right-aligned UInt64, owned by the caller.
# Errors:
#   raises BitError — RANGE when `lo < 0` or `hi > 63`; BAD_RANGE when `hi < lo`.
#   Both are recoverable by correcting the range.
# Example:
#   var x = 0b1011_0100
#   print(get_bits(x, 5, 4))   # -> 3   (bits 5..4)
#   print(get_bits(x, 7, 0))   # -> 180 (whole value)
#   print(get_bits(x, 2, 2))   # -> 1   (single bit)
# API-DOCS-END
