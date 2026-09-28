# split_once — split at the first separator into an Optional (before, after) pair.
def split_once[o: Origin[mut=False]](
    text: StringSpan[o], separator: StringSpan
) -> Optional[Tuple[StringSpan[o], StringSpan[o]]]:
    if separator.byte_length() == 0:
        return None
    var index = text.find(separator)
    if index == -1:
        return None
    var before: StringSpan[o] = text[byte=0:index]
    var after: StringSpan[o] = text[byte=index + separator.byte_length():]
    var pair = (before, after)
    return Optional(pair^)

# API-DOCS-START
# split_once — split at the first separator into an Optional pair of views.
# Signature:
#   def split_once[o: Origin[mut=False]](
#       text: StringSpan[o], separator: StringSpan
#   ) -> Optional[Tuple[StringSpan[o], StringSpan[o]]]
# What it does:
#   Finds the first occurrence of `separator` in `text` and returns the part
#   before it and the part after it. An empty `separator` has no defined split and
#   yields None. Both inputs are borrowed; the returned halves are views into
#   `text`, so nothing is allocated and no bytes are copied.
# Returns:
#   Some((before, after)) where `before` is the text up to the separator and
#   `after` is the text following it, or None when the separator is absent. Both
#   views borrow `text` and stay valid as long as `text` does.
# Errors:
#   none — absence is None, not an error.
# Example:
#   print(split_once("a=b", "="))       # -> (a, b)
#   print(split_once("a=b=c", "="))     # -> (a, b=c)
#   print(split_once("abc", "="))       # -> None
#   print(split_once("abc", ""))        # -> None
# API-DOCS-END
