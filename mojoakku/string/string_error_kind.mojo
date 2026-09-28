from std.os import abort


# StringErrorKind — compile-time discriminant for StringError.
struct StringErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime INDEX_OUT_OF_BOUNDS = StringErrorKind(0)  # index outside [0, byte_length]
    comptime BAD_RANGE           = StringErrorKind(1)  # backwards range, or an empty required needle
    comptime NOT_A_BOUNDARY      = StringErrorKind(2)  # in-range byte index that is not a codepoint start
    comptime INVALID_UTF8        = StringErrorKind(3)  # bytes are not valid UTF-8

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# StringErrorKind — the machine-testable reason a string operation failed.
# Signature:
#   struct StringErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime INDEX_OUT_OF_BOUNDS = StringErrorKind(0)
#       comptime BAD_RANGE           = StringErrorKind(1)
#       comptime NOT_A_BOUNDARY      = StringErrorKind(2)
#       comptime INVALID_UTF8        = StringErrorKind(3)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   You read this from `StringError.kind` inside an except block; it is never
#   constructed or passed by a caller. The four kinds are the complete, closed
#   set:
#     INDEX_OUT_OF_BOUNDS — an index lies outside [0, byte_length].
#     BAD_RANGE           — a range is specified backwards (start > end), or a
#                           required needle (e.g. the `old` of replace_n) is empty.
#     NOT_A_BOUNDARY      — an in-range byte index is not the first byte of a
#                           codepoint (it is a UTF-8 continuation byte).
#     INVALID_UTF8        — input bytes are not valid UTF-8.
#   It also implements Writable, so printing a kind shows its symbolic name.
# Returns:
#   A value type; reading `.kind` returns a StringErrorKind owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   try:
#       _ = slice("héllo", 0, 2)
#   except e:
#       print(e.kind == StringErrorKind.NOT_A_BOUNDARY)   # True
#   print(StringErrorKind.INVALID_UTF8)                   # -> INVALID_UTF8
# API-DOCS-END
