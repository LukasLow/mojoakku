from std.os import abort


# Alignment — compile-time alignment discriminant for FormatSpec.align.
struct Alignment(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime DEFAULT     = Alignment(0)   # no alignment given; the formatter chooses
    comptime LEFT        = Alignment(1)   # '<'
    comptime RIGHT       = Alignment(2)   # '>'
    comptime CENTER      = Alignment(3)   # '^'
    comptime SIGN_AWARE  = Alignment(4)   # '=' (numbers only)

    # write_to — symbolic name, not the numeric _id.
    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# Alignment — how a formatted value is padded to its field width.
# Signature:
#   struct Alignment(Equatable, ImplicitlyCopyable, Deinitable, Writable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime DEFAULT     = Alignment(0)
#       comptime LEFT        = Alignment(1)
#       comptime RIGHT       = Alignment(2)
#       comptime CENTER      = Alignment(3)
#       comptime SIGN_AWARE  = Alignment(4)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   Selects where padding goes when the rendered value is narrower than the spec
#   width. Read it from `FormatSpec.align`; it is also produced by
#   parse_format_spec from the letters `<`, `>`, `^`, `=`:
#     DEFAULT     — no alignment letter; the formatter chooses (left for strings
#                   and bools, right for numbers).
#     LEFT  ('<') — pad on the right.
#     RIGHT ('>') — pad on the left.
#     CENTER ('^')— pad both sides, the extra fill on the right.
#     SIGN_AWARE ('=') — pad after the sign and before the digits; valid only for
#                   numbers (on a string or bool it is a TYPE_MISMATCH).
# Returns:
#   A value type; reading `.align` returns an Alignment owned by the caller.
# Errors:
#   none — it is a discriminant, not an operation.
# Example:
#   var spec = parse_format_spec("*>10")
#   print(spec.align == Alignment.RIGHT)   # True
#   print(Alignment.CENTER)                # -> CENTER
# API-DOCS-END
