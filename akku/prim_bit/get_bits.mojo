from .bit_error import BitError
from .bit_error_kind import BitErrorKind
from akku.prim_bit._internal.field_mask import field_mask

from std.bit import bit_width


# get_bits — extract the inclusive field [hi:lo] of an integral value,
# right-aligned. Generic over the carrier's dtype; the field bound is the
# carrier's own width.
def get_bits[dtype: DType](value: Scalar[dtype], hi: Int, lo: Int) raises BitError -> Scalar[dtype] where dtype.is_unsigned():
    var total_bits = Int(bit_width(~Scalar[dtype](0)))
    if lo < 0 or hi > total_bits - 1:
        raise BitError(
            BitErrorKind.RANGE,
            "get_bits",
            "field bounds must satisfy 0 <= lo and hi <= bit_width - 1",
        )
    if hi < lo:
        raise BitError(BitErrorKind.BAD_RANGE, "get_bits", "hi is less than lo")
    # Shift the field down so its least significant bit is bit 0, then keep
    # only the field's `hi - lo + 1` bits. `field_mask` guards the full-width
    # case (a `1 << total_bits` shift).
    return (value & field_mask[dtype](lo, hi)) >> Scalar[dtype](lo)


# API-DOCS-START
# get_bits — extract the inclusive bit field [hi:lo] of a value, right-aligned.
# Signature:
#   def get_bits[dtype: DType](value: Scalar[dtype], hi: Int, lo: Int)
#       raises BitError -> Scalar[dtype]
#       where dtype.is_unsigned()
# What it does:
#   `value` is the carrier; `[hi:lo]` is the inclusive field, with
#   `0 <= lo <= hi <= bit_width - 1`, where `bit_width` is the carrier's own
#   width (8 for UInt8, 16 for UInt16, 32 for UInt32, 64 for UInt64). The field
#   is returned shifted down so its least significant bit is bit 0, and the
#   result's bits above the field width (`hi - lo + 1`) are zero. The result has
#   the carrier's own type. `hi == lo` is a one-bit field; `[bit_width-1:0]`
#   returns the whole value. The `dtype` parameter is inferred from `value`, or
#   can be named explicitly (`get_bits[DType.uint8](...)`).
# Returns:
#   The extracted field as a right-aligned value of the carrier's type, owned by
#   the caller.
# Errors:
#   raises BitError — RANGE when `lo < 0` or `hi > bit_width - 1`; BAD_RANGE when
#   `hi < lo`. Both are recoverable by correcting the range.
# Example:
#   var x: UInt64 = 0b1011_0100
#   print(get_bits(x, 5, 4))   # -> 3   (bits 5..4)
#   print(get_bits(x, 7, 0))   # -> 180 (whole value)
#   print(get_bits(UInt8(0b1011_0100), 5, 2))   # -> 13 (UInt8 field)
# API-DOCS-END
