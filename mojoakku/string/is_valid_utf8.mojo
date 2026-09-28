from std.os import abort


# is_valid_utf8 — allocation-free validity predicate over raw bytes.
def is_valid_utf8(bytes: Span[UInt8, _]) -> Bool:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# is_valid_utf8 — allocation-free validity predicate over raw bytes.
# Signature:
#   def is_valid_utf8(bytes: Span[UInt8, _]) -> Bool
# What it does:
#   Reports whether a borrowed raw byte span is well-formed UTF-8 under RFC 3629:
#   1 to 4 byte sequences, no overlong forms, no surrogates, and no values above
#   U+10FFFF. An empty span is valid. No allocation is performed. This is the Bool
#   companion to constructing a String from bytes, which raises on invalid input
#   instead of returning a value.
# Returns:
#   True when the span is valid UTF-8, False otherwise. `bytes` stays borrowed.
# Errors:
#   none — invalid input is False, not an error.
# Example:
#   var hi: List[UInt8] = [104, 105]      # "hi"
#   var bad: List[UInt8] = [255]
#   var empty: List[UInt8] = []
#   print(is_valid_utf8(Span(hi)))        # -> True
#   print(is_valid_utf8(Span(bad)))       # -> False
#   print(is_valid_utf8(Span(empty)))     # -> True  (empty)
# API-DOCS-END
