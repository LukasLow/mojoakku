# find — first byte offset of a needle, as Optional (no -1 sentinel).
def find(text: StringSpan, needle: StringSpan, start: Int = 0) -> Optional[Int]:
    var begin = start
    if begin < 0:
        begin = 0
    var n = text.byte_length()
    if needle.byte_length() == 0:
        # An empty needle matches at `start`; std.find ignores `start` here, so
        # the documented start semantics are applied explicitly.
        if begin > n:
            return None
        return Optional(begin)
    var offset = text.find(needle, begin)
    if offset == -1:
        return None
    return Optional(offset)

# API-DOCS-START
# find — the first occurrence of a needle as an Optional byte offset.
# Signature:
#   def find(text: StringSpan, needle: StringSpan, start: Int = 0) -> Optional[Int]
# What it does:
#   Searches `text` for `needle`, beginning at the byte offset `start`. A `start`
#   below 0 behaves as 0; a `start` beyond the end yields None. An empty `needle`
#   matches at `start`. Both inputs are borrowed and never copied; the search is a
#   pure in-memory operation. This is the stdlib `find` with its -1 sentinel
#   translated to Optional, so absence can never be mistaken for an index.
# Returns:
#   The byte offset of the first occurrence at or after `start`, or None when the
#   needle is absent. The offset counts UTF-8 bytes, not codepoints or graphemes.
# Errors:
#   none — absence is None, not an error.
# Example:
#   print(find("hello world", "world"))   # -> 6
#   print(find("hello", "zz"))            # -> None
#   print(find("abab", "a", 1))           # -> 2
#   print(find("abc", ""))                # -> 0
# API-DOCS-END
