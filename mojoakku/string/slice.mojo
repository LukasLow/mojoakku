from .string_error import StringError
from .string_error_kind import StringErrorKind


# slice — checked byte-range extraction raising StringError.
def slice[o: Origin[mut=False]](
    text: StringSpan[o], start: Int, end: Int
) raises StringError -> StringSpan[o]:
    var n = text.byte_length()
    if start < 0 or end > n:
        raise StringError(StringErrorKind.INDEX_OUT_OF_BOUNDS, start)
    if start > end:
        raise StringError(StringErrorKind.BAD_RANGE, start)
    # Both ends must be codepoint boundaries; report the offending one.
    if not _is_boundary(text, start):
        raise StringError(StringErrorKind.NOT_A_BOUNDARY, start)
    if not _is_boundary(text, end):
        raise StringError(StringErrorKind.NOT_A_BOUNDARY, end)
    return text[byte=start:end]


# _is_boundary — local boundary test (index 0, the end, and every non-
# continuation byte). Kept local so `slice` has no cross-entry dependency.
def _is_boundary(text: StringSpan, index: Int) -> Bool:
    var n = text.byte_length()
    if index < 0 or index > n:
        return False
    if index == n:
        return True
    return (text.as_bytes()[index] & 0xC0) != 0x80

# API-DOCS-START
# slice — checked byte-range extraction raising StringError.
# Signature:
#   def slice[o: Origin[mut=False]](
#       text: StringSpan[o], start: Int, end: Int
#   ) raises StringError -> StringSpan[o]
# What it does:
#   Returns the half-open byte range [start, end) of `text`, guaranteeing that the
#   result is valid UTF-8. `start == end` is the empty view. A start below 0 or an
#   end past `text.byte_length()` is out of bounds; a start greater than end is a
#   backwards range; and a start or end that is not a codepoint boundary is
#   rejected. `text` is borrowed and the result is a view into it, so nothing is
#   copied. This is the checked form of the annotated std slice `s[byte=a:b]`,
#   which aborts instead of reporting the problem.
# Returns:
#   A borrowed view into `text` spanning [start, end). The view stays valid as
#   long as `text` does.
# Errors:
#   raises StringError — INDEX_OUT_OF_BOUNDS (start < 0 or end > byte_length),
#   BAD_RANGE (start > end), NOT_A_BOUNDARY (start or end is not a codepoint
#   boundary). `position` is the offending index. All are recoverable: clamp the
#   range or choose a boundary with is_char_boundary.
# Example:
#   print(slice("hello", 1, 3))     # -> el
#   print(slice("hello", 2, 2))     # -> (empty)
#   print(slice("hello", 0, 99))    # raises INDEX_OUT_OF_BOUNDS
#   print(slice("hé", 0, 2))        # raises NOT_A_BOUNDARY
# API-DOCS-END
