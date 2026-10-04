from std.os import abort

from .format_error_kind import FormatErrorKind


# FormatError — the one typed error every failing formatting operation declares.
@fieldwise_init
struct FormatError(Copyable, Deinitable, Writable):
    var kind: FormatErrorKind
    var position: Int
    var message: String

    # write_to — readable kind + position + message, used by print(err).
    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "FormatError(", self.kind, ", position=", self.position,
            ", ", self.message, ")",
        )

# API-DOCS-START
# FormatError — the one typed error every failing formatting operation declares.
# Signature:
#   @fieldwise_init
#   struct FormatError(Copyable, Deinitable, Writable):
#       var kind: FormatErrorKind
#       var position: Int
#       var message: String
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Constructed by the library when a formatting operation fails; callers read it
#   in an except/try block. It carries:
#     kind     — what went wrong (see FormatErrorKind).
#     position — the byte offset in the ORIGINAL template/spec text at which the
#                failure was detected. For EXTRA_ARGUMENT it is the template's
#                byte length (its end), since no field owns the fault.
#     message  — a short, human-readable explanation with the offending text.
#   It implements Writable, so `print(err)` yields a readable message. It is
#   Copyable but deliberately not ImplicitlyCopyable, so a re-raise must transfer
#   with `raise e^`.
# Returns:
#   Raised, never returned. Every condition is a recoverable data error: fix the
#   template/spec, supply the missing argument, drop the extra argument, or pick a
#   compatible presentation.
# Errors:
#   none — FormatError *is* the error; constructing it cannot fail.
# Example:
#   try:
#       _ = format_int(255, parse_format_spec("q"))
#   except e:
#       print(e.kind)      # -> INVALID_SPEC
#       print(e.position)
#   # Re-raise a caught error by transfer:
#   #   except e:
#   #       raise e^
# API-DOCS-END
