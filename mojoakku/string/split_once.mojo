from std.os import abort


# split_once — split at the first separator into an Optional (before, after) pair.
def split_once[o: Origin[mut=False]](
    text: StringSpan[o], separator: StringSpan
) -> Optional[Tuple[StringSpan[o], StringSpan[o]]]:
    abort("MojoAkku: this API is not yet implemented")

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
