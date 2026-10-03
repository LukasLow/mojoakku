from std.os import abort


# Grouping — compile-time digit-grouping discriminant for FormatSpec.grouping.
struct Grouping(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime NONE        = Grouping(0)   # no separators (default)
    comptime COMMA       = Grouping(1)   # ','
    comptime UNDERSCORE  = Grouping(2)   # '_'

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# Grouping — the thousands separator used for integer output.
# Signature:
#   struct Grouping(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime NONE        = Grouping(0)
#       comptime COMMA       = Grouping(1)
#       comptime UNDERSCORE  = Grouping(2)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Read it from `FormatSpec.grouping`; parse_format_spec produces it from `,` or
#   `_`. The members:
#     NONE         — no separators (default).
#     COMMA  (',') — group the integer part in threes with ','.
#     UNDERSCORE ('_') — the same grouping with '_'.
#   It applies to integer presentations only; on a float or a string it is a
#   TYPE_MISMATCH / INVALID_SPEC. Grouping is deterministic and does not consult
#   any locale.
# Returns:
#   A value type; reading `.grouping` returns a Grouping owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   var spec = parse_format_spec(",d")
#   print(spec.grouping == Grouping.COMMA)   # True
#   print(Grouping.UNDERSCORE)               # -> UNDERSCORE
# API-DOCS-END
