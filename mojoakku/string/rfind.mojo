from std.os import abort


# rfind — last byte offset of a needle at or after start, as Optional.
def rfind(text: StringSpan, needle: StringSpan, start: Int = 0) -> Optional[Int]:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# rfind — the last occurrence of a needle as an Optional byte offset.
# Signature:
#   def rfind(text: StringSpan, needle: StringSpan, start: Int = 0) -> Optional[Int]
# What it does:
#   Searches `text` for the highest occurrence of `needle` whose start is at or
#   after the byte offset `start`; matches wholly before `start` are ignored.
#   Both inputs are borrowed and never copied. This is the stdlib `rfind` with
#   its -1 sentinel translated to Optional.
# Returns:
#   The byte offset of the last occurrence at or after `start`, or None when the
#   needle is absent. The offset counts UTF-8 bytes.
# Errors:
#   none — absence is None, not an error.
# Example:
#   print(rfind("abab", "a"))        # -> 2
#   print(rfind("abab", "a", 2))     # -> 2
#   print(rfind("hello", "zz"))      # -> None
# API-DOCS-END
