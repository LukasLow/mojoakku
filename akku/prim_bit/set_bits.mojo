from .bit_error import BitError
from .bit_error_kind import BitErrorKind
from akku.prim_bit._internal.field_mask import field_mask

from std.bit import bit_width


# set_bits — insert a field into the inclusive [hi:lo] range of an integral
# value. Generic over the carrier's dtype; the field bound is the carrier's own
# width.
def set_bits[dtype: DType](value: Scalar[dtype], hi: Int, lo: Int, field: Scalar[dtype]) raises BitError -> Scalar[dtype] where dtype.is_unsigned():
    var total_bits = Int(bit_width(~Scalar[dtype](0)))
    if lo < 0 or hi > total_bits - 1:
        raise BitError(
            BitErrorKind.RANGE,
            "set_bits",
            "field bounds must satisfy 0 <= lo and hi <= bit_width - 1",
        )
    if hi < lo:
        raise BitError(BitErrorKind.BAD_RANGE, "set_bits", "hi is less than lo")
    var width = hi - lo + 1
    # A field with any bit above the field width does not fit: raise instead of
    # silently truncating. `width == total_bits` is the whole carrier, so nothing
    # can be above it and no `field >> total_bits` shift is evaluated.
    if width < total_bits and (field >> Scalar[dtype](width)) != Scalar[dtype](0):
        raise BitError(
            BitErrorKind.OVERFLOW,
            "set_bits",
            "field has bits above the field width",
        )
    var mask = field_mask[dtype](lo, hi)
    return (value & ~mask) | (field << Scalar[dtype](lo))


# API-DOCS-START
# set_bits — insert a field into the inclusive bit range [hi:lo] of a value.
# Signature:
#   def set_bits[dtype: DType](value: Scalar[dtype], hi: Int, lo: Int,
#       field: Scalar[dtype]) raises BitError -> Scalar[dtype]
#       where dtype.is_unsigned()
# What it does:
#   `value` is the carrier; `[hi:lo]` is the inclusive field, with
#   `0 <= lo <= hi <= bit_width - 1`, where `bit_width` is the carrier's own
#   width (8 for UInt8, 16 for UInt16, 32 for UInt32, 64 for UInt64); `field` is
#   the value to insert into that place, in the carrier's own type. Bits `[hi:lo]`
#   of `value` are replaced by `field` and every other bit is preserved.
#   `field == 0` clears the field; `hi == lo` inserts a single bit and requires
#   `field` to be 0 or 1. `field` must fit in the field width (`hi - lo + 1`) — a
#   value with any bit set above that width raises OVERFLOW, and nothing is
#   silently truncated. The `dtype` parameter is inferred from `value`, or can be
#   named explicitly (`set_bits[DType.uint8](...)`).
# Returns:
#   The new carrier with the field replaced, in the carrier's own type, owned by
#   the caller.
# Errors:
#   raises BitError — RANGE when `lo < 0` or `hi > bit_width - 1`; BAD_RANGE when
#   `hi < lo`; OVERFLOW when `field` does not fit the field width. All are
#   recoverable.
# Example:
#   var x: UInt64 = 0b0000_0000
#   var y = set_bits(x, 3, 0, UInt64(0b1010))   # -> 0b0000_1010
#   var z = set_bits(y, 3, 0, UInt64(0))        # -> 0b0000_0000  (clear)
#   var single = set_bits(x, 5, 5, UInt64(1))   # -> bit 5 set
#   print(set_bits(UInt8(0), 7, 7, UInt8(1)))   # -> UInt8(0b1000_0000)
# API-DOCS-END
