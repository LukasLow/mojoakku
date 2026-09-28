from std.os import abort


# rsplit_once — split at the last separator into an Optional (before, after) pair.
def rsplit_once[o: Origin[mut=False]](
    text: StringSpan[o], separator: StringSpan
) -> Optional[Tuple[StringSpan[o], StringSpan[o]]]:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# rsplit_once — split at the last separator into an Optional pair of views.
# Signature:
#   def rsplit_once[o: Origin[mut=False]](
#       text: StringSpan[o], separator: StringSpan
#   ) -> Optional[Tuple[StringSpan[o], StringSpan[o]]]
# What it does:
#   Like split_once, but splits at the LAST occurrence of `separator`. An empty
#   `separator` yields None. Both inputs are borrowed; the returned halves are
#   views into `text`, so nothing is allocated.
# Returns:
#   Some((before, after)) at the last separator, or None when it is absent. Both
#   views borrow `text`.
# Errors:
#   none — absence is None, not an error.
# Example:
#   print(rsplit_once("a=b=c", "="))   # -> (a=b, c)
#   print(rsplit_once("a=b", "="))     # -> (a, b)
#   print(rsplit_once("abc", "="))     # -> None
# API-DOCS-END
