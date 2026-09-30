from akku.text_string._internal.utf8 import string_from_bytes

from .string_error import StringError
from .string_error_kind import StringErrorKind


# replace_n — replace the first `count` occurrences (or all) of a needle.
def replace_n(
    text: StringSpan, old: StringSpan, new: StringSpan, count: Int
) raises StringError -> String:
    if old.byte_length() == 0:
        raise StringError(StringErrorKind.BAD_RANGE, 0)
    var hay = text.as_bytes()
    var needle = old.as_bytes()
    var replacement = new.as_bytes()
    var out = List[UInt8](capacity=len(hay))
    var i = 0
    var done = 0
    while i < len(hay):
        # `count < 0` means replace all; stop once `count` replacements are done
        # (or immediately when count == 0).
        var matches = count < 0 or done < count
        if matches and _matches_at(hay, i, needle):
            for b in replacement:
                out.append(b)
            i += len(needle)
            done += 1
        else:
            out.append(hay[i])
            i += 1
    return string_from_bytes(out^)


# _matches_at — does `needle` occur at byte index `i` of `hay`?
def _matches_at(hay: Span[UInt8, _], i: Int, needle: Span[UInt8, _]) -> Bool:
    if i + len(needle) > len(hay):
        return False
    for j in range(len(needle)):
        if hay[i + j] != needle[j]:
            return False
    return True

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
