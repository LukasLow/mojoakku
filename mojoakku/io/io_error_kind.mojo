# IoErrorKind — compile-time discriminant for IoError.
struct IoErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    # Written explicitly so equality compares the discriminant only.
    def __eq__(self, other: Self) -> Bool:
        return self._id == other._id

    comptime INTERRUPTED    = IoErrorKind(0)   # interrupted; the operation may be retried
    comptime WOULD_BLOCK    = IoErrorKind(1)   # would block on a non-blocking handle
    comptime CLOSED         = IoErrorKind(2)   # the stream or its underlying handle is closed
    comptime TIMED_OUT      = IoErrorKind(3)   # a deadline expired
    comptime INVALID_UTF8   = IoErrorKind(4)   # a text adapter saw invalid UTF-8
    comptime UNEXPECTED_EOF = IoErrorKind(5)   # an exact read hit end of stream early
    comptime OTHER          = IoErrorKind(6)   # any other condition (see IoError.detail)

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        # Symbolic names, not the numeric _id. An if/elif chain is used because
        # the `comptime NAME[...]` runtime-index form does not compile.
        if self._id == 0:
            writer.write("INTERRUPTED")
        elif self._id == 1:
            writer.write("WOULD_BLOCK")
        elif self._id == 2:
            writer.write("CLOSED")
        elif self._id == 3:
            writer.write("TIMED_OUT")
        elif self._id == 4:
            writer.write("INVALID_UTF8")
        elif self._id == 5:
            writer.write("UNEXPECTED_EOF")
        else:
            writer.write("OTHER")

# API-DOCS-START
# IoErrorKind — the machine-testable reason a stream operation failed.
# Signature:
#   struct IoErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       def __eq__(self, other: Self) -> Bool
#       comptime INTERRUPTED    = IoErrorKind(0)
#       comptime WOULD_BLOCK    = IoErrorKind(1)
#       comptime CLOSED         = IoErrorKind(2)
#       comptime TIMED_OUT      = IoErrorKind(3)
#       comptime INVALID_UTF8   = IoErrorKind(4)
#       comptime UNEXPECTED_EOF = IoErrorKind(5)
#       comptime OTHER          = IoErrorKind(6)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   You read this from `IoError.kind` inside an except block; it is never
#   constructed or passed by a caller. The seven kinds are the complete, closed
#   set:
#     INTERRUPTED    — the operation was interrupted and may be retried.
#     WOULD_BLOCK    — the operation would block on a non-blocking handle.
#     CLOSED         — the stream or its underlying handle is closed.
#     TIMED_OUT      — a deadline expired.
#     INVALID_UTF8   — a text adapter saw invalid UTF-8.
#     UNEXPECTED_EOF — an exact read (read_exact) reached end of stream before
#                      filling the buffer.
#     OTHER          — any other condition; the opaque IoError.detail holds it.
#   It also implements Writable, so printing a kind shows its symbolic name.
# Returns:
#   A value type; reading `.kind` returns an IoErrorKind owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   try:
#       _ = reader.read(buf)
#   except e:
#       print(e.kind == IoErrorKind.INTERRUPTED)   # retryable?
#   print(IoErrorKind.UNEXPECTED_EOF)              # -> UNEXPECTED_EOF
# API-DOCS-END
