from .alphabet import Alphabet
from .padding import Padding

from akku.codec_base32._internal.engine import encode_all


def encode[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: Span[UInt8, _]) -> String:
    var out = String()
    encode_all[alphabet, padding](input, out)
    return out^


# StringSpan overload: input bytes are encoded as-is (no UTF-8 conversion).
def encode[
    alphabet: Alphabet = Alphabet.B32_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: StringSpan) -> String:
    var out = String()
    encode_all[alphabet, padding](input.as_bytes(), out)
    return out^

# API-DOCS-START
# encode — encode borrowed bytes/text to an owned String.
# Signature:
#   def encode[
#       alphabet: Alphabet = Alphabet.B32_STANDARD,
#       padding: Padding = Padding.REQUIRED,
#   ](input: Span[UInt8]) -> String
#   def encode[
#       alphabet: Alphabet = Alphabet.B32_STANDARD,
#       padding: Padding = Padding.REQUIRED,
#   ](input: StringSpan) -> String
# What it does:
#   Turns raw bytes (first overload) or text treated byte by byte (second
#   overload; no UTF-8 conversion or normalisation happens) into encoded text.
#   `alphabet` and `padding` are compile-time options with the defaults standard
#   base32 and required padding; see Alphabet and Padding for the other choices.
#   Input is borrowed and may be empty; it is never copied or consumed.
#   Full 5-byte quanta become 8 symbols; a final partial quantum becomes 2, 4, 5
#   or 7 data symbols, followed by the '=' padding selected by `padding`.
# Returns:
#   A freshly owned String of exactly encoded_len(input_length) characters. An
#   empty input gives an empty String. The caller owns the result.
# Errors:
#   none — encode cannot fail for any input.
# Example:
#   encode("foobar")                                      # -> "MZXW6YTBOI======"
#   encode("f")                                           # -> "MY======"
#   encode[Alphabet.B32_STANDARD, Padding.OMITTED]("f")   # -> "MY"
#   encode[Alphabet.B32_HEX]("f")                         # -> "CO======"
#   encode(Span(data))                                    # byte overload
# API-DOCS-END
