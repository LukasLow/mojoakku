from std.os import abort


# BitErrorKind — compile-time discriminant for BitError.
struct BitErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    # Written explicitly so equality compares the discriminant only.
    def __eq__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    comptime RANGE     = BitErrorKind(0)   # an index/position/count is outside its addressable span
    comptime BAD_RANGE = BitErrorKind(1)   # a range is specified backwards (hi < lo)
    comptime OVERFLOW  = BitErrorKind(2)   # a field value does not fit the requested width
    comptime EOF       = BitErrorKind(3)   # a bit read ran past the end of the buffer
    comptime OTHER     = BitErrorKind(4)   # any other condition (see BitError.detail)

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# BitErrorKind — the machine-testable reason a bit operation failed.
# Signature:
#   struct BitErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       def __eq__(self, other: Self) -> Bool
#       comptime RANGE     = BitErrorKind(0)
#       comptime BAD_RANGE = BitErrorKind(1)
#       comptime OVERFLOW  = BitErrorKind(2)
#       comptime EOF       = BitErrorKind(3)
#       comptime OTHER     = BitErrorKind(4)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   You read this from `BitError.kind` inside an except block; it is never
#   constructed or passed by a caller. The five kinds are the complete, closed
#   set:
#     RANGE     — an index, bit position or count is negative or outside its
#                 addressable span.
#     BAD_RANGE — a range is specified backwards (`hi < lo`).
#     OVERFLOW  — a field value does not fit in the requested field width.
#     EOF       — a bit read ran past the end of the buffer.
#     OTHER     — any other condition; the opaque BitError.detail holds it.
#   It also implements Writable, so printing a kind shows its symbolic name.
# Returns:
#   A value type; reading `.kind` returns a BitErrorKind owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   try:
#       bits.set(-1)
#   except e:
#       print(e.kind == BitErrorKind.RANGE)   # True
#   print(BitErrorKind.OVERFLOW)              # -> OVERFLOW
# API-DOCS-END
