# Alphabet — compile-time value type selecting the symbol table; see API-DOCS below.
struct Alphabet(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime B64_STANDARD = Alphabet(0)   # RFC 4648 §4,  A-Z a-z 0-9 + /
    comptime B64_URL      = Alphabet(1)   # RFC 4648 §5,  A-Z a-z 0-9 - _
    comptime B32_STANDARD = Alphabet(2)   # RFC 4648 §6,  A-Z 2-7
    comptime B32_HEX      = Alphabet(3)   # RFC 4648 §7,  0-9 A-V
    comptime HEX_LOWER    = Alphabet(4)   # RFC 4648 §8,  0-9 a-f
    comptime HEX_UPPER    = Alphabet(5)   # RFC 4648 §8,  0-9 A-F

# API-DOCS-START
# Alphabet — compile-time value type selecting the symbol table.
# Signature:
#   struct Alphabet(Equatable, ImplicitlyCopyable, Deinitable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime B64_STANDARD = Alphabet(0)
#       comptime B64_URL      = Alphabet(1)
#       comptime B32_STANDARD = Alphabet(2)
#       comptime B32_HEX      = Alphabet(3)
#       comptime HEX_LOWER    = Alphabet(4)
#       comptime HEX_UPPER    = Alphabet(5)
# What it does:
#   Passed as a compile-time value parameter to every codec entry, e.g.
#   `encode[Alphabet.B64_URL](...)` or `[alphabet: Alphabet = Alphabet.B64_STANDARD]`.
#   The six constants are the complete public set:
#     B64_STANDARD — RFC 4648 §4, "A-Z a-z 0-9 + /"
#     B64_URL      — RFC 4648 §5, "A-Z a-z 0-9 - _"
#     B32_STANDARD — RFC 4648 §6, "A-Z 2-7"
#     B32_HEX      — RFC 4648 §7, "0-9 A-V"
#     HEX_LOWER    — RFC 4648 §8, "0-9 a-f"
#     HEX_UPPER    — RFC 4648 §8, "0-9 A-F"
#   The alphabet fixes the symbol table, the bytes-per-quantum ratio (base64 3,
#   base32 5, base16 1) and the case policy on decode: B64_* are case-sensitive
#   and accept both cases as distinct symbols; B32_STANDARD, B32_HEX and the two
#   HEX_* accept only their own case and reject the other as a bad symbol.
# Returns:
#   An opaque compile-time value, used only as a value parameter; it owns
#   nothing and is never returned from a function.
# Errors:
#   none — choosing any named constant cannot fail.
# Example:
#   encode[Alphabet.B64_URL](Span(data))            # uses '-' and '_'
#   decode[Alphabet.HEX_UPPER]("666F")              # -> [0x66, 0x6F]
#   is_valid[Alphabet.HEX_UPPER]("666f")            # -> False (case mismatch)
# API-DOCS-END
