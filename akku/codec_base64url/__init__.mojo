from .encode import encode
from .decode import decode

# API-DOCS-START
# Purpose — encode bytes as unpadded Base64url and decode URL-alphabet text.
# Overview — encode returns an owned String; decode returns an owned List[UInt8].
#   Both accept borrowed StringSpan or Span[UInt8, _]. No I/O or stream state.
# Dependencies — akku.codec_base64 supplies its public radix engine, alphabet,
#   padding policies and typed errors; this package specializes those operations.
# Public API — encode: bytes to unpadded URL-safe text; decode: URL-safe text to bytes.
# Error Surface — decode raises akku.codec_base64.Base64Error unchanged, with
#   ErrorKind.INVALID_SYMBOL, INVALID_LENGTH or INVALID_PADDING and a zero-based
#   original-input position. All are recoverable input errors; encode cannot fail
#   with a recoverable data error. No result is returned when decode fails.
# Conventions — encode fixes the URL alphabet and omits '='. Decode accepts
#   correctly padded or unpadded input, rejects whitespace and standard '+/'
#   symbols, and accepts non-zero unused trailing bits. It does not establish
#   textual canonicality. Inputs remain unchanged; outputs are independently owned.
#   These are synchronous memory operations: no EOF, blocking, timeout or close.
#   Base64url represents bytes; it does not encrypt or decode Unicode text.
# API-DOCS-END
