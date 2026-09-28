from std.os import abort

from .string_error import StringError


# replace_n — replace the first `count` occurrences (or all) of a needle.
def replace_n(
    text: StringSpan, old: StringSpan, new: StringSpan, count: Int
) raises StringError -> String:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# replace_n — replace the first `count` occurrences of a needle in a copy.
# Signature:
#   def replace_n(
#       text: StringSpan, old: StringSpan, new: StringSpan, count: Int
#   ) raises StringError -> String
# What it does:
#   Returns a copy of `text` in which the leftmost non-overlapping occurrences of
#   `old` are replaced by `new`. At most `count` occurrences are replaced: a
#   negative `count` means replace all, and `count == 0` returns `text`
#   unchanged. `old` must be non-empty. All three inputs are borrowed.
# Returns:
#   A freshly owned String. The caller owns it; the inputs are not modified.
# Errors:
#   raises StringError — BAD_RANGE when `old` is empty. Recoverable by passing a
#   non-empty needle.
# Example:
#   print(replace_n("aaa", "a", "b", 2))    # -> bba
#   print(replace_n("aaa", "a", "b", -1))   # -> bbb
#   print(replace_n("aaa", "a", "b", 0))    # -> aaa
#   print(replace_n("a-b-c", "-", "+", 1))  # -> a+b-c
# API-DOCS-END
