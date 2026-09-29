# Padding — compile-time encode padding policy; see API-DOCS below.
struct Padding(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime REQUIRED = Padding(0)   # emit '=' to complete the final quantum
    comptime OMITTED  = Padding(1)   # never emit '='

# API-DOCS-START
# Padding — compile-time encode padding policy.
# Signature:
#   struct Padding(Equatable, ImplicitlyCopyable, Deinitable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime REQUIRED = Padding(0)
#       comptime OMITTED  = Padding(1)
# What it does:
#   Passed as a compile-time value parameter to the encoding entries
#   `encode`, `encode_into` and `Encoder`, e.g.
#   `encode[Alphabet.B64_STANDARD, Padding.OMITTED]("f")`. It controls only what
#   the encoder emits:
#     REQUIRED — emit '=' to complete the final partial quantum.
#     OMITTED  — never emit '='.
#   REQUIRED only matters for base64 and base32. For HEX_LOWER/HEX_UPPER both
#   values produce identical output, because base16 has no padding symbol.
#   Decoding is governed separately by PaddingMode.
# Returns:
#   An opaque compile-time value, used only as a value parameter.
# Errors:
#   none — choosing either constant cannot fail.
# Example:
#   encode[Alphabet.B64_STANDARD, Padding.REQUIRED]("f")  # -> "Zg=="
#   encode[Alphabet.B64_STANDARD, Padding.OMITTED]("f")   # -> "Zg"
# API-DOCS-END
