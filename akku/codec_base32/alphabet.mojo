# Alphabet — compile-time value type selecting the symbol table; see API-DOCS below.
struct Alphabet(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime B32_STANDARD = Alphabet(0)   # RFC 4648 §6,  A-Z 2-7
    comptime B32_HEX      = Alphabet(1)   # RFC 4648 §7,  0-9 A-V

# API-DOCS-START
# Alphabet — compile-time value type selecting the symbol table.
# Signature:
#   struct Alphabet(Equatable, ImplicitlyCopyable, Deinitable):
#       var _id: UInt8
#       @doc_hidden
#       def __init__(out self, id: UInt8)
#       comptime B32_STANDARD = Alphabet(0)
#       comptime B32_HEX      = Alphabet(1)
# What it does:
#   Passed as a compile-time value parameter to every codec entry, e.g.
#   `encode[Alphabet.B32_HEX](...)` or `[alphabet: Alphabet = Alphabet.B32_STANDARD]`.
#   The two constants are the complete public set:
#     B32_STANDARD — RFC 4648 §6, "A-Z 2-7"
#     B32_HEX      — RFC 4648 §7, "0-9 A-V"
#   The alphabet fixes the symbol table and the 5-bits-per-symbol geometry
#   (5 bytes <-> 8 symbols). Padding is NOT part of the alphabet: it is chosen
#   separately with Padding / PaddingMode, so padded and unpadded variants are
#   both expressible. Case policy on decode is fixed per alphabet: both accept
#   only their uppercase spellings and reject lowercase as a bad symbol.
# Returns:
#   An opaque compile-time value, used only as a value parameter; it owns
#   nothing and is never returned from a function.
# Errors:
#   none — choosing either named constant cannot fail.
# Example:
#   encode[Alphabet.B32_STANDARD]("f")   # -> "MY======"
#   encode[Alphabet.B32_HEX]("f")        # -> "CO======"
#   is_valid[Alphabet.B32_HEX]("co======")  # -> False (lowercase is rejected)
# API-DOCS-END
