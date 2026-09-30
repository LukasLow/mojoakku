from std.os import abort
from akku.codec_base64 import Base64Error as _Base64Error


def decode(input: StringSpan) raises _Base64Error -> List[UInt8]:
    abort("MojoAkku: this API is not yet implemented")


def decode(input: Span[UInt8, _]) raises _Base64Error -> List[UInt8]:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# decode — decode borrowed Base64url text to independently owned bytes.
# Signature:
#   def decode(input: StringSpan) raises _Base64Error -> List[UInt8]
#   def decode(input: Span[UInt8, _]) raises _Base64Error -> List[UInt8]
# What it does:
#   Decodes the whole input with the URL alphabet; input is borrowed read-only.
#   _Base64Error is the existing akku.codec_base64.Base64Error type. Correctly
#   padded and unpadded final quanta are accepted. Present '=' padding must have
#   the exact count, appear only at the end and have no following symbol.
#   Non-zero unused trailing bits are accepted: this is not a canonical-text
#   validator. Whitespace, '+' and '/' are rejected rather than silently skipped.
#   Empty input yields empty bytes. Output is binary, without Unicode decoding.
# Returns:
#   A newly owned List[UInt8]. No result is returned on failure.
# Errors:
#   Raises akku.codec_base64.Base64Error unchanged. All are recoverable input
#   errors; correct input and retry. Its kind and original zero-based position:
#   INVALID_SYMBOL — offending byte; INVALID_LENGTH — first symbol of impossible
#   remainder; INVALID_PADDING — first symbol of offending final quantum, or
#   the first following byte after a completed padded quantum. This terminal
#   padding check takes precedence over symbol validation ("Zg== " errors at 4).
# Example:
#   from akku.codec_base64url import decode
#   decode("Zg")    # -> [102]
#   decode("Zg==")  # -> [102]
#   decode("Zh")    # -> [102], tolerant trailing-bit policy
#   decode("-_8")   # -> [251, 255]
#   try:
#       _ = decode("Zm!v")
#   except e:
#       print(e.kind, e.position) # INVALID_SYMBOL 2
# API-DOCS-END
