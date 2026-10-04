from std.os import abort

from .alphabet import Alphabet
from .padding import Padding


# Appends to result; the implementation reserves capacity itself.
def encode_into[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: Span[UInt8, _], mut result: String) -> Int:
    abort("MojoAkku: this API is not yet implemented")


def encode_into[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: StringSpan, mut result: String) -> Int:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# encode_into — encode borrowed bytes/text into a caller-owned String.
# Signature:
#   def encode_into[
#       alphabet: Alphabet = Alphabet.B32_STANDARD,
#       padding: Padding = Padding.REQUIRED,
#   ](input: Span[UInt8], mut result: String) -> Int
#   def encode_into[
#       alphabet: Alphabet = Alphabet.B32_STANDARD,
#       padding: Padding = Padding.REQUIRED,
#   ](input: StringSpan, mut result: String) -> Int
# What it does:
#   The in-place sibling of `encode`. `input` is borrowed bytes or text treated
#   as raw bytes; `result` is a caller-owned mutable String that is APPENDED to
#   (its prior contents are kept). The implementation reserves capacity itself,
#   so `result` may have zero capacity on entry. `alphabet` and `padding` are
#   compile-time and match `encode`.
# Returns:
#   The number of encoded characters appended to `result`. The caller owns
#   `result`; `input` stays borrowed.
# Errors:
#   none — encode cannot fail.
# Example:
#   var out = String("prefix:")
#   var n = encode_into("foobar", out)   # -> n == 16, out == "prefix:MZXW6YTBOI======"
#   var plain = String()
#   _ = encode_into("foo", plain)        # plain -> "MZXW6==="
#   _ = encode_into("bar", plain)        # plain -> "MZXW6===MZXW6===" (appends)
# API-DOCS-END
