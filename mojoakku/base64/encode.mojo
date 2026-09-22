from .alphabet import Alphabet
from .padding import Padding

from base64._internal.engine import encode_all


def encode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: Span[UInt8, _]) -> String:
    var out = String()
    encode_all[alphabet, padding](input, out)
    return out^


# StringSpan overload: input bytes are encoded as-is (no UTF-8 conversion).
def encode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](input: StringSpan) -> String:
    var out = String()
    encode_all[alphabet, padding](input.as_bytes(), out)
    return out^

# API-DOCS-START
# encode — encode borrowed bytes/text to an owned String.
# Signature:
#   def encode[
#       alphabet: Alphabet = Alphabet.B64_STANDARD,
#       padding: Padding = Padding.REQUIRED,
#   ](input: Span[UInt8]) -> String
#   def encode[
#       alphabet: Alphabet = Alphabet.B64_STANDARD,
#       padding: Padding = Padding.REQUIRED,
#   ](input: StringSpan) -> String
# What it does:
#   Turns raw bytes (first overload) or text treated byte by byte (second
#   overload; no UTF-8 conversion or normalisation happens) into encoded text.
#   `alphabet` and `padding` are compile-time options with the defaults standard
#   base64 and required padding; see Alphabet and Padding for the other choices.
#   Input is borrowed and may be empty; it is never copied or consumed.
# Returns:
#   A freshly owned String of exactly encoded_len(input_length) bytes. An empty
#   input gives an empty String. The caller owns the result.
# Errors:
#   none — encode cannot fail for any input.
# Example:
#   encode("foobar")                                    # -> "Zm9vYmFy"
#   encode("f")                                         # -> "Zg=="
#   encode[Alphabet.B64_STANDARD, Padding.OMITTED]("f") # -> "Zg"
#   encode(Span(data))                                  # byte overload
# API-DOCS-END
