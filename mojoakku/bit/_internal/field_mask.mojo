# Private shared helper for the bitfield layer (get_bits / set_bits).
#
# `field_mask` is the one piece of logic genuinely shared by the two bitfield
# entry points, so it lives here instead of being duplicated in both API files.
# It is not part of the public surface: `__init__.mojo` does not re-export it.


# field_mask — the carrier mask for the inclusive field [lo, hi].
#
# The mask has a 1 in every bit position `lo..hi` and 0 elsewhere. A width of
# 64 would require `1 << 64`, which is undefined for a 64-bit integer, so the
# full-width case is special-cased to all-ones instead of computing the shift.
def field_mask(lo: Int, hi: Int) -> UInt64:
    var width = hi - lo + 1
    if width >= 64:
        var all_ones = ~UInt64(0)
        return all_ones << UInt64(lo)
    var low_bits = (UInt64(1) << UInt64(width)) - UInt64(1)
    return low_bits << UInt64(lo)
