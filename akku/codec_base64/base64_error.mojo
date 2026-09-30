from .error_kind import ErrorKind


# Base64Error — the one typed error every decoder declares via `raises`.
@fieldwise_init
struct Base64Error(Copyable, Deinitable, Writable):
    var kind: ErrorKind
    var position: Int

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Base64Error(", self.kind, ", position=", self.position, ")")

# API-DOCS-START
# Base64Error — the one typed error every decoder declares via `raises`.
# Signature:
#   @fieldwise_init
#   struct Base64Error(Copyable, Deinitable, Writable):
#       var kind: ErrorKind
#       var position: Int
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Constructed by the library when decoding fails; callers read it in an
#   except/try block. It carries:
#     kind     — what went wrong (see ErrorKind).
#     position — the zero-based index into the original input where the failure
#                was detected. For a streaming Decoder it is cumulative across
#                the whole stream, independent of chunking; under
#                Whitespace.IGNORE skipped whitespace still advances the count.
#                For INVALID_LENGTH it is the first symbol of the impossible
#                remainder, for INVALID_PADDING the start of the offending final
#                quantum, and for INVALID_SYMBOL the offending symbol.
#   It implements Writable, so `print(err)` yields a readable, allocation-cheap
#   message with the kind and position. It is Copyable but deliberately not
#   ImplicitlyCopyable, so a re-raise must transfer with `raise e^`.
# Returns:
#   Raised, never returned. All decode failures are data errors and fully
#   recoverable: the caller may correct the input, truncate at `position`, or
#   change policy and retry.
# Errors:
#   none — Base64Error *is* the error; constructing it cannot fail.
# Example:
#   try:
#       _ = decode("Zg")
#   except e:
#       print(e.kind)      # -> INVALID_PADDING
#       print(e.position)  # -> 0
#   # Re-raise a caught error by transfer:
#   #   except e:
#   #       raise e^
# API-DOCS-END
