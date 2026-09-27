from std.os import abort


# BitOrder — the sequence in which the bits of a byte are visited.
struct BitOrder(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    # Written explicitly so equality compares the discriminant only.
    def __eq__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    comptime MSB_FIRST = BitOrder(0)   # most significant bit of a byte first (bit 7 .. bit 0)
    comptime LSB_FIRST = BitOrder(1)   # least significant bit of a byte first (bit 0 .. bit 7)

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# BitOrder — the sequence in which the bits of a byte are read or written.
# Signature:
#   struct BitOrder(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       def __eq__(self, other: Self) -> Bool
#       comptime MSB_FIRST = BitOrder(0)
#       comptime LSB_FIRST = BitOrder(1)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Passed explicitly to BitReader and BitWriter; also read back from a stored
#   reader/writer for inspection. The two members are the complete set:
#     MSB_FIRST — the most significant bit of a byte is visited first (bit 7
#                 then ... then bit 0). The network/wire-canonical order.
#     LSB_FIRST — the least significant bit first (bit 0 then ... then bit 7).
#                 Common for DEFLATE-class and little-endian formats.
#   Order is a value passed in, never a global setting. Both readers and writers
#   require an explicit order; there is no parameter default.
# Returns:
#   A value type, copied by value; stored readers/writers return it from their
#   `order()` accessor.
# Errors:
#   none — it is a value, not an operation.
# Example:
#   var w = BitWriter(BitOrder.MSB_FIRST)
#   var r = BitReader(Span(data), BitOrder.LSB_FIRST)
#   print(BitOrder.MSB_FIRST)     # -> MSB_FIRST
# API-DOCS-END
