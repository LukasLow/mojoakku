from std.os import abort

from .endian_error_kind import EndianErrorKind


# EndianError — the one typed error every fallible endian operation declares.
@fieldwise_init
struct EndianError(Copyable, Deinitable, Writable):
    var kind: EndianErrorKind
    var op: String
    var detail: String

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# EndianError — the one typed error every fallible endian operation declares.
# Signature:
#   @fieldwise_init
#   struct EndianError(Copyable, Deinitable, Writable):
#       var kind: EndianErrorKind
#       var op: String
#       var detail: String
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Constructed by the library when a buffer call fails; you read it in an
#   except/try block. It carries:
#     kind   — what went wrong (see EndianErrorKind).
#     op     — a short operation name ("to_bytes_into", "from_bytes"), so you
#              can tell which call failed. The list is illustrative, not closed.
#     detail — an opaque, human-readable string. It must not be parsed; it is
#              not part of the API surface.
#   It implements Writable, so `print(e)` yields a readable kind + operation +
#   detail message. It is Copyable but deliberately not ImplicitlyCopyable, so a
#   re-raise must transfer with `raise e^`.
# Returns:
#   Raised, never returned. The only release-1 condition is BAD_LENGTH (a buffer
#   whose length does not equal the carrier's byte width); it is recoverable by
#   passing a correctly sized buffer. No operation is fatal.
# Errors:
#   none — EndianError *is* the error; constructing it cannot fail.
# Example:
#   var dst: List[UInt8] = [0, 0]
#   try:
#       to_bytes_into(UInt32(1), dst, EndianOrder.BIG)   # 4-byte carrier, 2-byte dst
#   except e:
#       print(e.kind)      # -> BAD_LENGTH
#       print(e.op)        # -> to_bytes_into
#       print(e.detail)    # -> opaque context
#   # Re-raise a caught error by transfer:
#   #   except e:
#   #       raise e^
# API-DOCS-END
