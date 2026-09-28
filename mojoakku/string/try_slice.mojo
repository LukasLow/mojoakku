# try_slice — checked byte-range extraction returning Optional (never raises).
def try_slice[o: Origin[mut=False]](
    text: StringSpan[o], start: Int, end: Int
) -> Optional[StringSpan[o]]:
    var n = text.byte_length()
    if start < 0 or end > n or start > end:
        return None
    if not _is_boundary(text, start) or not _is_boundary(text, end):
        return None
    var view: StringSpan[o] = text[byte=start:end]
    return Optional(view)


# _is_boundary — local boundary test (index 0, the end, and every non-
# continuation byte). Kept local so `try_slice` has no cross-entry dependency.
def _is_boundary(text: StringSpan, index: Int) -> Bool:
    var n = text.byte_length()
    if index < 0 or index > n:
        return False
    if index == n:
        return True
    return (text.as_bytes()[index] & 0xC0) != 0x80

# API-DOCS-START
# try_slice — checked byte-range extraction returning Optional (never raises).
# Signature:
#   def try_slice[o: Origin[mut=False]](
#       text: StringSpan[o], start: Int, end: Int
#   ) -> Optional[StringSpan[o]]
# What it does:
#   The total sibling of slice: it accepts the same half-open byte range [start,
#   end) but reports every invalid range as None instead of raising. A range is
#   invalid when start < 0, end > text.byte_length(), start > end, or either end
#   is not a codepoint boundary. `start == end` is a valid empty view. `text` is
#   borrowed and the result is a view into it.
# Returns:
#   Some(view) for a valid range, None for any invalid range. The view borrows
#   `text` and stays valid as long as `text` does.
# Errors:
#   none — every invalid range is None.
# Example:
#   print(try_slice("hello", 1, 3))   # -> el
#   print(try_slice("hello", 2, 2))   # -> (empty view)
#   print(try_slice("hello", 0, 99))  # -> None
#   print(try_slice("hé", 0, 2))      # -> None
# API-DOCS-END
