# PaddingMode — compile-time decode padding/canonicality policy; see API-DOCS below.
struct PaddingMode(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime STRICT   = PaddingMode(0)   # require canonical padding / no padding
    comptime TOLERANT = PaddingMode(1)   # padding optional, but consistent if present

# API-DOCS-START
# PaddingMode — compile-time decode padding and canonicality policy.
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
#   `decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT]("MY")`.
#     STRICT   — require RFC 4648 canonical input: a partial final quantum must
#                carry exactly its padding (data-symbol counts 2, 4, 5 or 7), a
#                full final quantum must carry no '=', and the unused trailing
#                bits of the final symbol must be zero (non-zero bits raise
#                INVALID_SYMBOL).
#     TOLERANT — accept a padded or unpadded final quantum. If padding is
#                present its count must still be exactly right, padding may only
#                appear at the end, and no symbol may follow it. Non-zero
#                trailing bits are accepted.
#   STRICT is the default. A structurally impossible remainder (1, 3 or 6 data
#   symbols) fails under both modes.
# Returns:
#   An opaque compile-time value, used only as a value parameter.
# Errors:
#   none at selection time. A policy violation during decode raises Base32Error
#   with kind INVALID_PADDING (or INVALID_LENGTH for an impossible remainder);
#   every failure is a recoverable data error.
# Example:
#   decode[Alphabet.B32_STANDARD, PaddingMode.STRICT]("MY")    # raises INVALID_PADDING
#   decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT]("MY")  # -> [102]
#   decode[Alphabet.B32_STANDARD, PaddingMode.STRICT]("MZ======") # trailing bits -> INVALID_SYMBOL
# API-DOCS-END
