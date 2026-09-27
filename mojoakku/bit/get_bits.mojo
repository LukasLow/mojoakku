from .bit_error import BitError
from .bit_error_kind import BitErrorKind
from bit._internal.field_mask import field_mask


# get_bits — extract the inclusive field [hi:lo] of a UInt64, right-aligned.
def get_bits(value: UInt64, hi: Int, lo: Int) raises BitError -> UInt64:
    if lo < 0 or hi > 63:
        raise BitError(
            BitErrorKind.RANGE,
            "get_bits",
            "field bounds must satisfy 0 <= lo and hi <= 63",
        )
    if hi < lo:
        raise BitError(BitErrorKind.BAD_RANGE, "get_bits", "hi is less than lo")
    # Shift the field down so its least significant bit is bit 0, then keep
    # only the field's `hi - lo + 1` bits. `field_mask` guards the width-64
    # case (a `1 << 64` shift).
    return (value & field_mask(lo, hi)) >> UInt64(lo)


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
