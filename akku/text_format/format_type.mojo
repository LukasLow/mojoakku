from std.os import abort


# FormatType — compile-time presentation discriminant for FormatSpec.presentation.
struct FormatType(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime DEFAULT            = FormatType(0)
    comptime BINARY             = FormatType(1)    # 'b'
    comptime OCTAL              = FormatType(2)    # 'o'
    comptime DECIMAL            = FormatType(3)    # 'd'
    comptime LOWER_HEX          = FormatType(4)    # 'x'
    comptime UPPER_HEX          = FormatType(5)    # 'X'
    comptime CHAR               = FormatType(6)    # 'c'
    comptime STRING             = FormatType(7)    # 's'
    comptime REPR               = FormatType(8)    # 'r'
    comptime FIXED              = FormatType(9)    # 'f' (and 'F', same output)
    comptime SCIENTIFIC         = FormatType(10)   # 'e'
    comptime UPPER_SCIENTIFIC   = FormatType(11)   # 'E'

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# FormatType — the form a value takes in the output (radix, float style, text).
# Signature:
#   struct FormatType(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime DEFAULT          = FormatType(0)
#       comptime BINARY           = FormatType(1)
#       comptime OCTAL            = FormatType(2)
#       comptime DECIMAL          = FormatType(3)
#       comptime LOWER_HEX        = FormatType(4)
#       comptime UPPER_HEX        = FormatType(5)
#       comptime CHAR             = FormatType(6)
#       comptime STRING           = FormatType(7)
#       comptime REPR             = FormatType(8)
#       comptime FIXED            = FormatType(9)
#       comptime SCIENTIFIC       = FormatType(10)
#       comptime UPPER_SCIENTIFIC = FormatType(11)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Read it from `FormatSpec.presentation`; parse_format_spec produces it from the
#   trailing presentation letter. The members:
#     DEFAULT     — natural form: decimal for integers, shortest round-trip for
#                   floats, the text itself for strings, true/false for bools.
#     BINARY/OCTAL/DECIMAL/LOWER_HEX/UPPER_HEX — integer radix presentations
#                   ('b'/'o'/'d'/'x'/'X').
#     CHAR   ('c')— a Unicode codepoint (an integer) rendered as that character.
#     STRING ('s')— text.
#     REPR   ('r')— the debug form via repr/write_repr_to.
#     FIXED  ('f', or 'F' as an alias with identical lowercase output) —
#                   fixed-point with `precision` digits after the point.
#     SCIENTIFIC ('e') / UPPER_SCIENTIFIC ('E') — scientific notation with
#                   `precision` digits, lowercase/uppercase exponent.
# Returns:
#   A value type; reading `.presentation` returns a FormatType owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   var spec = parse_format_spec("#x")
#   print(spec.presentation == FormatType.LOWER_HEX)   # True
#   print(FormatType.FIXED)                            # -> FIXED
# API-DOCS-END
