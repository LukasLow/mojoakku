# PaddingMode — compile-time decode padding policy; see API-DOCS below.
struct PaddingMode(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime STRICT   = PaddingMode(0)   # require canonical padding / no padding
    comptime TOLERANT = PaddingMode(1)   # padding optional, but consistent if present

# API-DOCS-START
# PaddingMode — compile-time decode padding policy.
# Signature:
#   struct PaddingMode(Equatable, ImplicitlyCopyable, Deinitable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime STRICT   = PaddingMode(0)
#       comptime TOLERANT = PaddingMode(1)
# What it does:
#   Passed as a compile-time value parameter to the decoding entries `decode`,
#   `decode_into`, `Decoder` and `is_valid`, e.g.
#   `decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT]("Zg")`.
#     STRICT   — require RFC 4648 canonical input: a partial final quantum must
#                carry exactly its padding, a full quantum none, and the unused
#                trailing bits of the final symbol must be zero (non-zero bits
#                raise INVALID_SYMBOL).
#     TOLERANT — accept a padded or unpadded final quantum. If padding is
#                present its count must still be exactly right, padding may only
#                appear at the end, and no symbol may follow it. Non-zero
#                trailing bits are accepted.
#   STRICT is the default. For HEX_LOWER/HEX_UPPER there is no padding symbol,
#   so the two modes behave identically; the parameter remains for uniformity.
#   A structurally impossible remainder (e.g. a single base64 symbol) fails under
#   both modes.
# Returns:
#   An opaque compile-time value, used only as a value parameter.
# Errors:
#   none at selection time. A policy violation during decode raises Base64Error
#   with kind INVALID_PADDING (or INVALID_LENGTH for an impossible remainder);
#   every failure is a recoverable data error.
# Example:
#   decode[Alphabet.B64_STANDARD, PaddingMode.STRICT]("Zg")    # raises INVALID_PADDING
#   decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT]("Zg")  # -> [102]
#   decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT]("Zh==") # -> [102]
# API-DOCS-END
