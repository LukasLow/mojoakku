from std.os import abort

from .string_error_kind import StringErrorKind


# StringError — the one typed error every failing string operation declares.
@fieldwise_init
struct StringError(Copyable, Deinitable, Writable):
    var kind: StringErrorKind
    var position: Int

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# StringError — the one typed error every failing string operation declares.
# Signature:
#   @fieldwise_init
#   struct StringError(Copyable, Deinitable, Writable):
#       var kind: StringErrorKind
#       var position: Int
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Constructed by the library when a string operation fails; callers read it in
#   an except/try block. It carries:
#     kind     — what went wrong (see StringErrorKind).
#     position — the byte offset in the ORIGINAL input at which the failure was
#                detected. For INDEX_OUT_OF_BOUNDS and NOT_A_BOUNDARY it is the
#                offending index; for BAD_RANGE it is the range start (or 0 when
#                the fault is an empty needle); for INVALID_UTF8 it is the byte
#                offset of the first invalid sequence.
#   It implements Writable, so `print(err)` yields a readable message with the
#   kind and position. It is Copyable but deliberately not ImplicitlyCopyable, so
#   a re-raise must transfer with `raise e^`.
# Returns:
#   Raised, never returned. Every condition is a recoverable data error: clamp
#   the index, choose a boundary, fix the bytes, or pass a non-empty needle.
# Errors:
#   none — StringError *is* the error; constructing it cannot fail.
# Example:
#   try:
#       _ = slice("hello", 1, 99)
#   except e:
#       print(e.kind)      # -> INDEX_OUT_OF_BOUNDS
#       print(e.position)  # -> 1
#   # Re-raise a caught error by transfer:
#   #   except e:
#   #       raise e^
# API-DOCS-END
