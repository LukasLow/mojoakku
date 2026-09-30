from .ip_parse_error_kind import IpParseErrorKind


# IpParseError — the one typed error every parser declares via `raises`.
@fieldwise_init
struct IpParseError(Copyable, Deinitable, Writable):
    var kind: IpParseErrorKind
    var position: Int

    def write_to(self, mut writer: Some[Writer]):
        writer.write("IpParseError(", self.kind, ", position=", self.position, ")")

# API-DOCS-START
# IpParseError — the one typed error every parser declares via `raises`.
# Signature:
#   @fieldwise_init
#   struct IpParseError(Copyable, Deinitable, Writable):
#       var kind: IpParseErrorKind
#       var position: Int
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Constructed by the library when parsing fails; callers read it in an
#   except/try block. It carries:
#     kind     — what went wrong (see IpParseErrorKind).
#     position — the zero-based byte index into the original input where the
#                failure was detected (a byte index, not a character index).
#   It implements Writable, so `print(err)` yields a readable message with the
#   kind and position. It is Copyable but deliberately not ImplicitlyCopyable,
#   so a re-raise must transfer with `raise e^`.
# Returns:
#   Raised, never returned. Every parse failure is a data error and fully
#   recoverable: the caller may correct the input, or inspect `position` to
#   report where the text went wrong.
# Errors:
#   none — IpParseError *is* the error; constructing it cannot fail.
# Example:
#   try:
#       _ = parse("1.2.3")
#   except e:
#       print(e.kind)      # -> TOO_FEW_GROUPS
#       print(e.position)  # -> 5
#   # Re-raise a caught error by transfer:
#   #   except e:
#   #       raise e^
# API-DOCS-END
