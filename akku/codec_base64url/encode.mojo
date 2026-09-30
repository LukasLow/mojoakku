from std.os import abort


def encode(input: StringSpan) -> String:
    abort("MojoAkku: this API is not yet implemented")


def encode(input: Span[UInt8, _]) -> String:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# encode — encode borrowed bytes as owned unpadded Base64url text.
# Signature:
#   def encode(input: StringSpan) -> String
#   def encode(input: Span[UInt8, _]) -> String
# What it does:
#   Encodes the whole input with the URL alphabet ('-' and '_' instead of '+'
#   and '/') and no '=' padding. StringSpan bytes are encoded as-is without
#   Unicode conversion or normalization. Input is read-only borrowed, never
#   consumed or mutated; empty input produces empty text. No policy parameters.
# Returns:
#   A newly owned String independent of the input. The caller owns the result.
# Errors:
#   none — no recoverable data errors for any input.
# Example:
#   from akku.codec_base64url import encode
#   encode("f")       # -> "Zg"
#   encode("foobar")  # -> "Zm9vYmFy"
#   var bytes: List[UInt8] = [251, 255]
#   encode(Span(bytes)) # -> "-_8"
# API-DOCS-END
