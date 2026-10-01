from std.os import abort

from .time_error_kind import TimeErrorKind


# TimeError — the one typed error every fallible time operation declares.
@fieldwise_init
struct TimeError(Copyable, Deinitable, Writable):
    var kind: TimeErrorKind
    var detail: String

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# TimeError — the one typed error every fallible time operation declares.
# Signature:
#   @fieldwise_init
#   struct TimeError(Copyable, Deinitable, Writable):
#       var kind: TimeErrorKind
#       var detail: String
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Constructed by the library when a time operation fails; you read it in an
#   except/try block. It carries:
#     kind   — what went wrong (see TimeErrorKind).
#     detail — an opaque, human-readable string naming the failing operation.
#              It must not be parsed; it is not part of the API surface.
#   It implements Writable, so `print(e)` yields a readable kind + detail
#   message. It is Copyable but deliberately not ImplicitlyCopyable, so a
#   re-raise must transfer with `raise e^`.
# Returns:
#   Raised, never returned. Every condition is a recoverable data error: retry
#   with smaller operands, a different unit, or a non-zero divisor. Nothing is
#   fatal and nothing aborts.
# Errors:
#   none — TimeError *is* the error; constructing it cannot fail.
# Example:
#   try:
#       _ = Duration.from_seconds(1) + Duration.from_seconds(1)
#   except e:
#       print(e.kind)      # -> OVERFLOW
#       print(e.detail)    # -> opaque context
#   # Re-raise a caught error by transfer:
#   #   except e:
#   #       raise e^
# API-DOCS-END
