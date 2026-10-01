from .endian_order import EndianOrder


# from_order — convert a value that is in a named byte order back to host order.
def from_order[dtype: DType](x: Scalar[dtype], order: EndianOrder) -> Scalar[dtype] where dtype.is_integral():
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# from_order — convert a value that is in a named byte order back to host order.
# Signature:
#   def from_order[dtype: DType](x: Scalar[dtype], order: EndianOrder)
#       -> Scalar[dtype]
#       where dtype.is_integral()
# What it does:
#   `x` is an integral value whose bytes are in `order` (for example a value
#   assembled from wire bytes); `order` is the source order. If `order` is the
#   host order (including EndianOrder.NATIVE) the result is `x` unchanged;
#   otherwise the bytes are swapped. A one-byte carrier is a no-op for every
#   order. `order` is always required; there is no default. This is the
#   "interpret wire bytes" direction; use to_order for the opposite intent.
# Returns:
#   A new value of the same type as `x`, reinterpreted from `order` into the
#   host order, owned by the caller.
# Errors:
#   none — the conversion is total for every integral carrier.
# Example:
#   # a value read from the wire in big-endian order
#   var host = from_order(UInt32(0x04030201), EndianOrder.BIG)
#   # on a little-endian host, host is 0x01020304
#   var same = from_order(UInt32(5), EndianOrder.NATIVE)   # identity
#   var one = from_order(UInt8(7), EndianOrder.BIG)        # identity, one byte
# API-DOCS-END
