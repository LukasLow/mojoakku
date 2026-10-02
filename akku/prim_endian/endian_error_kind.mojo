# EndianErrorKind — closed discriminant for EndianError.
struct EndianErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    # Written explicitly so equality compares the discriminant only.
    def __eq__(self, other: Self) -> Bool:
        return self._id == other._id

    comptime BAD_LENGTH = EndianErrorKind(0)   # a buffer length != the carrier's byte width
    comptime OTHER = EndianErrorKind(1)        # any other condition (see EndianError.detail)

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        # Symbolic names, not the numeric _id (0 = BAD_LENGTH, 1 = OTHER).
        if self._id == 0:
            writer.write("BAD_LENGTH")
        else:
            writer.write("OTHER")

# API-DOCS-START
# EndianErrorKind — the machine-testable reason an endian operation failed.
# Signature:
#   struct EndianErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       def __eq__(self, other: Self) -> Bool
#       comptime BAD_LENGTH = EndianErrorKind(0)
#       comptime OTHER      = EndianErrorKind(1)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   You read this from `EndianError.kind` inside an except block; it is never
#   constructed or passed by a caller. The two kinds are the complete, closed
#   set:
#     BAD_LENGTH — a buffer's length did not equal the carrier's byte width.
#     OTHER      — any other condition; the opaque EndianError.detail holds it.
#                  Reserved in release 1: no release-1 operation raises it.
#   It also implements Writable, so printing a kind shows its symbolic name,
#   never the numeric id. Comparisons use ==.
# Returns:
#   A value type; reading `.kind` returns an EndianErrorKind owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   try:
#       to_bytes_into(UInt32(1), dst, EndianOrder.BIG)
#   except e:
#       print(e.kind == EndianErrorKind.BAD_LENGTH)   # True for a wrong-length dst
#   print(EndianErrorKind.BAD_LENGTH)                 # -> BAD_LENGTH
# API-DOCS-END
