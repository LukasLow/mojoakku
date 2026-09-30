from .io_error_kind import IoErrorKind


# IoError — the one typed error every fallible stream operation declares.
@fieldwise_init
struct IoError(Copyable, Deinitable, Writable):
    var kind: IoErrorKind
    var op: String
    var detail: String

    def write_to(self, mut writer: Some[Writer]):
        writer.write("IoError(", self.kind, ", op=", self.op, ", detail=", self.detail, ")")

# API-DOCS-START
# IoError — the one typed error every fallible stream operation declares.
# Signature:
#   @fieldwise_init
#   struct IoError(Copyable, Deinitable, Writable):
#       var kind: IoErrorKind
#       var op: String
#       var detail: String
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Constructed by the library when a stream operation fails; you read it in an
#   except/try block. It carries:
#     kind   — what went wrong (see IoErrorKind).
#     op     — a short operation name ("read", "write", "flush", "seek"), so you
#              can tell which call failed.
#     detail — an opaque, human-readable string. It must not be parsed; it is not
#              part of the API surface.
#   End of stream is NOT an IoError: that is ReadResult.eof. It implements
#   Writable, so `print(e)` yields a readable kind + operation + detail message.
#   It is Copyable but deliberately not ImplicitlyCopyable, so a re-raise must
#   transfer with `raise e^`.
# Returns:
#   Raised, never returned. Every condition is a recoverable data error: retry
#   (INTERRUPTED / WOULD_BLOCK), reopen (CLOSED), adjust the deadline
#   (TIMED_OUT), re-encode (INVALID_UTF8). UNEXPECTED_EOF is lossy (the consumed
#   prefix of an exact read is gone) but not fatal.
# Errors:
#   none — IoError *is* the error; constructing it cannot fail.
# Example:
#   try:
#       _ = reader.read(buf)
#   except e:
#       print(e.kind)      # -> INTERRUPTED
#       print(e.op)        # -> read
#       print(e.detail)    # -> opaque context
#   # Re-raise a caught error by transfer:
#   #   except e:
#   #       raise e^
# API-DOCS-END
