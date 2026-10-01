from .endian_error import EndianError
from .endian_order import EndianOrder


# from_bytes — read a value from a borrowed span, in an order.
def from_bytes[dtype: DType](src: Span[UInt8, _], order: EndianOrder) raises EndianError -> Scalar[dtype] where dtype.is_integral():
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# from_bytes — read a value from a borrowed span, in an order.
# Signature:
#   def from_bytes[dtype: DType](src: Span[UInt8, _], order: EndianOrder)
#       raises EndianError -> Scalar[dtype]
#       where dtype.is_integral()
# What it does:
#   Reads exactly one integral value of type `dtype` from the start of `src`,
#   whose bytes are in `order`, and returns it in the host order. `src.len` must
#   equal the carrier's byte width exactly; any other length raises BAD_LENGTH.
#   Layout: for BIG, src[0] is the most significant byte; for LITTLE, src[0] is
#   the least significant byte; NATIVE uses the host layout. The `dtype`
#   parameter is inferred from the call's expected result, or can be named
#   explicitly. You own `src` and it is borrowed for the call only; the returned
#   value is owned by you. There is no offset and no streaming: exactly one whole
#   carrier is read. This is the inverse of to_bytes_into.
# Returns:
#   The integer assembled from `src`, in the host order, as `Scalar[dtype]`,
#   owned by the caller.
# Errors:
#   raises EndianError — BAD_LENGTH when `src.len` does not equal the carrier's
#   byte width. Recoverable by passing a correctly sized span.
# Example:
#   var bytes: List[UInt8] = [0x01, 0x02]
#   print(from_bytes[DType.uint16](bytes, EndianOrder.BIG))     # -> 0x0102
#   print(from_bytes[DType.uint16](bytes, EndianOrder.LITTLE))  # -> 0x0201
#   # an empty or short span raises BAD_LENGTH
# API-DOCS-END
