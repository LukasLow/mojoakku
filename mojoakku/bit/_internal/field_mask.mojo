from std.bit import bit_width


# Private shared helper for the bitfield layer (get_bits / set_bits) and the
# BitSet range operations.
#
# `field_mask` is the one piece of logic genuinely shared by the two bitfield
# entry points and the container's range masks, so it lives here instead of
# being duplicated. It is not part of the public surface: `__init__.mojo` does
# not re-export it.
#
# The mask has a 1 in every bit position `lo..hi` and 0 elsewhere. A width equal
# to the carrier's full width would require `1 << total_bits`, which is
# undefined for a fixed-width integer, so the full-width case is special-cased
# to all-ones instead of computing that shift. The carrier width comes from
# `bit_width(~0)` — `bit_width(0)` is 0, not the type width, so it cannot be
# used for the bound.
def field_mask[dtype: DType](lo: Int, hi: Int) -> Scalar[dtype] where dtype.is_integral():
    var width = hi - lo + 1
    var total_bits = Int(bit_width(~Scalar[dtype](0)))
    if width >= total_bits:
        return ~Scalar[dtype](0) << Scalar[dtype](lo)
    var low_bits = (Scalar[dtype](1) << Scalar[dtype](width)) - Scalar[dtype](1)
    return low_bits << Scalar[dtype](lo)
