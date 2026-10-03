from std.os import abort

from .version_error_kind import VersionErrorKind


# VersionError — the one typed error every fallible version operation declares.
@fieldwise_init
struct VersionError(Copyable, Deinitable, Writable):
    var kind: VersionErrorKind
    var op: String
    var detail: String

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# VersionError — the one typed error every fallible version operation declares.
# Signature:
#   @fieldwise_init
#   struct VersionError(Copyable, Deinitable, Writable):
#       var kind: VersionErrorKind
#       var op: String
#       var detail: String
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Constructed by the library on failure; you read it in an except/try block
#   after calling parse or the SemVer component constructor. It carries:
#     kind   — what went wrong (see VersionErrorKind).
#     op     — a short operation name ("parse", "SemVer"), so you can tell which
#              call failed. The list is illustrative, not closed.
#     detail — an opaque, human-readable string (for example the offending input
#              or identifier). It must not be parsed; it is not part of the API
#              surface.
#   It implements Writable, so `print(e)` yields a readable kind + operation +
#   detail message. It is Copyable but deliberately not ImplicitlyCopyable, so a
#   re-raise must transfer with `raise e^`.
# Returns:
#   Raised, never returned. Every condition is a recoverable data error: the
#   caller passed a malformed string or component. No operation is fatal and
#   none aborts.
# Errors:
#   none — VersionError *is* the error; constructing it cannot fail.
# Example:
#   try:
#       _ = parse("1.2")
#   except e:
#       print(e.kind)      # -> INVALID_FORMAT
#       print(e.op)        # -> parse
#       print(e.detail)    # -> opaque context
#   # Re-raise a caught error by transfer:
#   #   except e:
#   #       raise e^
# API-DOCS-END
