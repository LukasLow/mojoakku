from .bit_error import BitError
from .bit_error_kind import BitErrorKind
from bit._internal.field_mask import field_mask


# set_bits — insert a field into the inclusive [hi:lo] range of a UInt64.
def set_bits(value: UInt64, hi: Int, lo: Int, field: UInt64) raises BitError -> UInt64:
    if lo < 0 or hi > 63:
        raise BitError(
            BitErrorKind.RANGE,
            "set_bits",
            "field bounds must satisfy 0 <= lo and hi <= 63",
        )
    if hi < lo:
        raise BitError(BitErrorKind.BAD_RANGE, "set_bits", "hi is less than lo")
    var width = hi - lo + 1
    # A field with any bit above the field width does not fit: raise instead of
    # silently truncating. `width == 64` is the whole carrier, so nothing can
    # be above it and no `field >> 64` shift is evaluated.
    if width < 64 and (field >> UInt64(width)) != UInt64(0):
        raise BitError(
            BitErrorKind.OVERFLOW,
            "set_bits",
            "field has bits above the field width",
        )
    var mask = field_mask(lo, hi)
    return (value & ~mask) | (field << UInt64(lo))


# API-DOCS-START
# set_bits — insert a field into the inclusive bit range [hi:lo] of a value.
# Signature:
#   def set_bits(value: UInt64, hi: Int, lo: Int, field: UInt64) raises BitError -> UInt64
# What it does:
#   `value` is the carrier; `[hi:lo]` is the inclusive field, with
#   `0 <= lo <= hi <= 63`; `field` is the value to insert into that place. Bits
#   `[hi:lo]` of `value` are replaced by `field` and every other bit is
#   preserved. `field == 0` clears the field; `hi == lo` inserts a single bit and
#   requires `field` to be 0 or 1. `field` must fit in the field width
#   (`hi - lo + 1`) — a value with any bit set above that width raises OVERFLOW,
#   and nothing is silently truncated.
# Returns:
#   The new carrier with the field replaced, owned by the caller.
# Errors:
#   raises BitError — RANGE when `lo < 0` or `hi > 63`; BAD_RANGE when
#   `hi < lo`; OVERFLOW when `field` does not fit the field width. All are
#   recoverable.
# Example:
#   var x = 0b0000_0000
#   var y = set_bits(x, 3, 0, 0b1010)   # -> 0b0000_1010
#   var z = set_bits(y, 3, 0, 0)        # -> 0b0000_0000  (clear the field)
#   var single = set_bits(x, 5, 5, 1)   # -> bit 5 set
# API-DOCS-END
