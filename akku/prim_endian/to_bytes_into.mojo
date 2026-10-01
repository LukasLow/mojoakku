from .endian_error import EndianError
from .endian_order import EndianOrder


# to_bytes_into — write a value's bytes into a caller-owned span, in an order.
def to_bytes_into[dtype: DType](x: Scalar[dtype], dst: MutSpan[UInt8, _], order: EndianOrder) raises EndianError where dtype.is_integral():
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# to_bytes_into — write a value's bytes into a caller-owned span, in an order.
# Signature:
#   def to_bytes_into[dtype: DType](x: Scalar[dtype], dst: MutSpan[UInt8, _],
#       order: EndianOrder)
#       raises EndianError
#       where dtype.is_integral()
# What it does:
#   Writes the bytes of `x` (an integral value in the host order) into `dst` in
#   the byte layout named by `order`. `dst.len` must equal the carrier's byte
#   width exactly; any other length raises BAD_LENGTH before anything is
#   written, so a failing call leaves `dst` untouched. The whole span is
#   written; there is no offset and no partial write. Layout: for BIG, dst[0] is
#   the most significant byte; for LITTLE, dst[0] is the least significant byte;
#   NATIVE uses the host layout. Nothing is returned and nothing is allocated;
#   you own `dst` and it is borrowed for the call only. This is the inverse of
#   from_bytes.
# Returns:
#   Nothing; `dst` is mutated in place.
# Errors:
#   raises EndianError — BAD_LENGTH when `dst.len` does not equal the carrier's
#   byte width. Recoverable by passing a correctly sized span.
# Example:
#   var dst = List[UInt8](2, 0)
#   to_bytes_into(UInt16(0x0102), dst, EndianOrder.BIG)     # -> [0x01, 0x02]
#   to_bytes_into(UInt16(0x0102), dst, EndianOrder.LITTLE)  # -> [0x02, 0x01]
#   # a 4-byte carrier into this 2-byte dst raises BAD_LENGTH
# API-DOCS-END
