from std.os import abort

from .string_error import StringError


# slice — checked byte-range extraction raising StringError.
def slice[o: Origin[mut=False]](
    text: StringSpan[o], start: Int, end: Int
) raises StringError -> StringSpan[o]:
    abort("MojoAkku: this API is not yet implemented")

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
