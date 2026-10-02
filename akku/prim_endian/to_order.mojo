from .endian_order import EndianOrder
from .host_order import host_order
from .swap_bytes import swap_bytes


# to_order — convert a host-order value into a named byte order.
def to_order[dtype: DType](x: Scalar[dtype], order: EndianOrder) -> Scalar[dtype] where dtype.is_integral():
    # Identity when `order` already is the host order (including NATIVE),
    # otherwise a byte reversal. A 1-byte carrier is a no-op either way.
    if order == host_order():
        return x
    return swap_bytes(x)

# API-DOCS-START
# to_order — convert a host-order value into a named byte order.
# Signature:
#   def to_order[dtype: DType](x: Scalar[dtype], order: EndianOrder)
#       -> Scalar[dtype]
#       where dtype.is_integral()
# What it does:
#   `x` is an integral value in the host order (an ordinary Mojo integer is
#   native-endian in memory); `order` is the target order. If `order` is the
#   host order (including EndianOrder.NATIVE) the result is `x` unchanged;
#   otherwise the bytes are swapped. A one-byte carrier is a no-op for every
#   order. `order` is always required; there is no default. This is the
#   "prepare a value for the wire" direction; use from_order for the opposite
#   intent. For network order, pass EndianOrder.BIG.
# Returns:
#   A new value of the same type as `x`, reinterpreted into `order`, owned by
#   the caller.
# Errors:
#   none — the conversion is total for every integral carrier.
# Example:
#   var wire = to_order(UInt32(0x01020304), EndianOrder.BIG)
#   # on a little-endian host, wire has its bytes swapped: 0x04030201
#   var same = to_order(UInt32(5), EndianOrder.NATIVE)   # identity
#   var one = to_order(UInt8(7), EndianOrder.BIG)        # identity, one byte
# API-DOCS-END
