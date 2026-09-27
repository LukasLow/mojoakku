from std.os import abort

from .bit_error import BitError


# set_bits — insert a field into the inclusive [hi:lo] range of a UInt64.
def set_bits(value: UInt64, hi: Int, lo: Int, field: UInt64) raises BitError -> UInt64:
    abort("MojoAkku: this API is not yet implemented")

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
