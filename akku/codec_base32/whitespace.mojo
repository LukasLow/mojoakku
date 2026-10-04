# Whitespace — compile-time decode whitespace policy; see API-DOCS below.
struct Whitespace(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime REJECT = Whitespace(0)   # default: any whitespace is INVALID_SYMBOL
    comptime IGNORE = Whitespace(1)   # skip space, tab, CR, LF, FF, VT

# API-DOCS-START
# Whitespace — compile-time decode whitespace policy.
# Signature:
#   struct Whitespace(Equatable, ImplicitlyCopyable, Deinitable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime REJECT = Whitespace(0)
#       comptime IGNORE = Whitespace(1)
# What it does:
#   Passed as a compile-time value parameter to the decoding entries `decode`,
#   `decode_into`, `Decoder` and `is_valid`, e.g.
#   `decode[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE]("MY ======")`.
#     REJECT (default) — any whitespace byte is INVALID_SYMBOL.
#     IGNORE           — skip space, tab, CR, LF, FF and VT. Skipped bytes still
#                        advance the original-stream index reported as
#                        `Base32Error.position`, but they are not part of any
#                        quantum.
#   Whitespace tolerance is always opt-in; REJECT differs from Go base32 and
#   Bouncy Castle, which ignore whitespace with no strict switch.
# Returns:
#   An opaque compile-time value, used only as a value parameter.
# Errors:
#   none at selection time. Under REJECT a whitespace byte raises Base32Error
#   with kind INVALID_SYMBOL; under IGNORE whitespace never fails. Recoverable.
# Example:
#   decode("MY ======")                                              # raises INVALID_SYMBOL
#   decode[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE]("MY ======")
#                                                                    # -> [102]
# API-DOCS-END
