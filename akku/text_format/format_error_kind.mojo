from std.os import abort


# FormatErrorKind — compile-time discriminant for FormatError.
struct FormatErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime MALFORMED_TEMPLATE = FormatErrorKind(0)  # unbalanced/bad braces, bad placeholder, mixed numbering
    comptime INVALID_SPEC       = FormatErrorKind(1)  # spec text does not follow the grammar
    comptime MISSING_ARGUMENT   = FormatErrorKind(2)  # a field references an index with no argument
    comptime EXTRA_ARGUMENT     = FormatErrorKind(3)  # an argument is never referenced by any field
    comptime TYPE_MISMATCH      = FormatErrorKind(4)  # a presentation/flag is not applicable to the kind

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        if self._id == 0:
            writer.write("MALFORMED_TEMPLATE")
        elif self._id == 1:
            writer.write("INVALID_SPEC")
        elif self._id == 2:
            writer.write("MISSING_ARGUMENT")
        elif self._id == 3:
            writer.write("EXTRA_ARGUMENT")
        else:
            writer.write("TYPE_MISMATCH")

# API-DOCS-START
# FormatErrorKind — the machine-testable reason a formatting operation failed.
# Signature:
#   struct FormatErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime MALFORMED_TEMPLATE = FormatErrorKind(0)
#       comptime INVALID_SPEC       = FormatErrorKind(1)
#       comptime MISSING_ARGUMENT   = FormatErrorKind(2)
#       comptime EXTRA_ARGUMENT     = FormatErrorKind(3)
#       comptime TYPE_MISMATCH      = FormatErrorKind(4)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   You read this from `FormatError.kind` inside an except block; it is never
#   constructed or passed by a caller. The five kinds are the complete, closed
#   set:
#     MALFORMED_TEMPLATE — unbalanced or bad braces, an empty or bad placeholder,
#                          an unknown conversion, or mixed auto/manual numbering.
#     INVALID_SPEC       — the spec text does not follow the grammar (bad fill,
#                          unknown presentation letter, repeated flag, negative
#                          width, `.` with no digits).
#     MISSING_ARGUMENT   — a field references an index for which no argument was
#                          supplied.
#     EXTRA_ARGUMENT     — an argument was supplied but never referenced by any
#                          field.
#     TYPE_MISMATCH      — the presentation or a flag is not applicable to the
#                          argument's kind.
#   It also implements Writable, so printing a kind shows its symbolic name.
# Returns:
#   A value type; reading `.kind` returns a FormatErrorKind owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   try:
#       _ = parse_format_spec("q")
#   except e:
#       print(e.kind == FormatErrorKind.INVALID_SPEC)   # True
#   print(FormatErrorKind.TYPE_MISMATCH)                # -> TYPE_MISMATCH
# API-DOCS-END
