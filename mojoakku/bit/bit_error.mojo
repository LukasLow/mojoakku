from .bit_error_kind import BitErrorKind


# BitError — the one typed error every fallible bit operation declares.
@fieldwise_init
struct BitError(Copyable, Deinitable, Writable):
    var kind: BitErrorKind
    var op: String
    var detail: String

    def write_to(self, mut writer: Some[Writer]):
        writer.write("BitError(", self.kind, ", op=", self.op, ", detail=", self.detail, ")")

# API-DOCS-START
# BitError — the one typed error every fallible bit operation declares.
# Signature:
#   @fieldwise_init
#   struct BitError(Copyable, Deinitable, Writable):
#       var kind: BitErrorKind
#       var op: String
#       var detail: String
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Constructed by the library when a bit operation fails; you read it in an
#   except/try block. It carries:
#     kind   — what went wrong (see BitErrorKind).
#     op     — a short operation name ("set", "clear", "toggle", "set_to",
#              "test", "set_range", "clear_range", "toggle_range",
#              "complement_with", "get_bits", "set_bits", "read_bit",
#              "read_bits", "write_bits"), so you can tell which call failed.
#     detail — an opaque, human-readable string. It must not be parsed; it is not
#              part of the API surface.
#   EOF is a bit-read condition only: there is no "end of set", and find_next
#   signals absence with Optional, never with an error. It implements Writable,
#   so `print(e)` yields a readable kind + operation + detail message. It is
#   Copyable but deliberately not ImplicitlyCopyable, so a re-raise must
#   transfer with `raise e^`.
# Returns:
#   Raised, never returned. Every condition is a recoverable data error: correct
#   the index/range (RANGE / BAD_RANGE), widen the field (OVERFLOW), or read
#   fewer bits / supply more bytes (EOF). No operation is fatal.
# Errors:
#   none — BitError *is* the error; constructing it cannot fail.
# Example:
#   var bits = BitSet()
#   try:
#       bits.set(-1)          # a negative index raises
#   except e:
#       print(e.kind)      # -> RANGE
#       print(e.op)        # -> set
#       print(e.detail)    # -> opaque context
#   # Re-raise a caught error by transfer:
#   #   except e:
#   #       raise e^
# API-DOCS-END
