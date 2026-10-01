from std.os import abort
from std.sys import is_little_endian


# EndianOrder — the byte order a conversion targets.
struct EndianOrder(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    # Written explicitly so equality compares the discriminant only.
    def __eq__(self, other: Self) -> Bool:
        return self._id == other._id

    comptime LITTLE = EndianOrder(0)   # byte 0 is the least significant byte
    comptime BIG = EndianOrder(1)      # byte 0 is the most significant byte; network order
    comptime NATIVE = EndianOrder.LITTLE if is_little_endian() else EndianOrder.BIG

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# EndianOrder — the byte order a conversion targets.
# Signature:
#   struct EndianOrder(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       def __eq__(self, other: Self) -> Bool
#       comptime LITTLE = EndianOrder(0)
#       comptime BIG    = EndianOrder(1)
#       comptime NATIVE = EndianOrder.LITTLE if is_little_endian() else EndianOrder.BIG
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Names the byte order used by every conversion and buffer call. The two
#   concrete members are the complete set:
#     LITTLE — byte 0 is the least significant byte.
#     BIG    — byte 0 is the most significant byte. Network byte order is
#              big-endian and is documented as BIG; there is no separate
#              NETWORK value.
#   NATIVE is a compile-time alias resolved to LITTLE or BIG for the build
#   target; host_order() returns the same value. It is the non-portable path
#   and should not be used for wire data. Order is always passed explicitly;
#   there is no default and no global switch. Comparisons use ==.
# Returns:
#   A value type, copied by value; it is passed to and returned from the
#   conversion and buffer APIs.
# Errors:
#   none — it is a value, not an operation.
# Example:
#   var order = EndianOrder.BIG
#   print(order)                       # -> BIG
#   print(EndianOrder.NATIVE)          # -> LITTLE or BIG, for this host
#   print(EndianOrder.BIG == host_order())   # network order is big-endian
# API-DOCS-END
