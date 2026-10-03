from std.os import abort


# SignMode — compile-time sign discriminant for FormatSpec.sign.
struct SignMode(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime NEGATIVE_ONLY = SignMode(0)   # default: '-' for negatives only
    comptime ALWAYS        = SignMode(1)   # '+' for positives, '-' for negatives
    comptime SPACE         = SignMode(2)   # ' ' for positives, '-' for negatives

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# SignMode — how the sign of a numeric value is rendered.
# Signature:
#   struct SignMode(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime NEGATIVE_ONLY = SignMode(0)
#       comptime ALWAYS        = SignMode(1)
#       comptime SPACE         = SignMode(2)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Controls the leading sign of a number. Read it from `FormatSpec.sign`; it is
#   produced by parse_format_spec from `+`, an explicit `-`, or a leading space:
#     NEGATIVE_ONLY — a leading '-' for negative numbers only; positives carry no
#                     sign. This is the default.
#     ALWAYS  ('+') — a leading '+' for positives and '-' for negatives.
#     SPACE   (' ') — a leading space for positives and '-' for negatives.
#   It applies to numeric presentations only; using it on a string or bool is a
#   TYPE_MISMATCH.
# Returns:
#   A value type; reading `.sign` returns a SignMode owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   var spec = parse_format_spec("+d")
#   print(spec.sign == SignMode.ALWAYS)   # True
#   print(SignMode.SPACE)                 # -> SPACE
# API-DOCS-END
