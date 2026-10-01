from std.os import abort


# swap_bytes — reverse an integral value's byte order.
def swap_bytes[dtype: DType](x: Scalar[dtype]) -> Scalar[dtype] where dtype.is_integral():
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# swap_bytes — reverse an integral value's byte order.
# Signature:
#   def swap_bytes[dtype: DType](x: Scalar[dtype]) -> Scalar[dtype]
#       where dtype.is_integral()
# What it does:
#   Returns `x` with its bytes reversed — a bit-for-bit byte reversal, not an
#   order conversion. `x` may be signed or unsigned; the carrier's byte width is
#   its own type width. The `dtype` parameter is inferred from `x`, or can be
#   named explicitly. A one-byte carrier is already order-independent and is
#   returned unchanged.
# Returns:
#   A new value of the same type as `x`, owned by the caller.
# Errors:
#   none — total for every integral carrier.
# Example:
#   print(swap_bytes(UInt16(0x0102)))   # -> 0x0201
#   print(swap_bytes(UInt32(0x01020304)))   # -> 0x04030201
#   print(swap_bytes(UInt8(0x01)))      # -> 0x01 (one byte, unchanged)
# API-DOCS-END
