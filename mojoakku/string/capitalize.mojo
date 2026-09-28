from std.os import abort


# capitalize — uppercase the first codepoint, lowercase the rest.
def capitalize(text: StringSpan) -> String:
    abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# capitalize — uppercase the first codepoint and lowercase the rest.
# Signature:
#   def capitalize(text: StringSpan) -> String
# What it does:
#   Returns a copy of `text` whose first codepoint is upper-cased and whose every
#   following codepoint is lower-cased. This is a first-letter operation, not
#   word-based titlecasing (which is not part of this library). `text` is
#   borrowed; an empty input returns an empty String.
# Returns:
#   A freshly owned String. The caller owns it; `text` is not modified.
# Errors:
#   none.
# Example:
#   print(capitalize("abc"))     # -> Abc
#   print(capitalize("hELLO"))   # -> Hello
#   print(capitalize(""))        # -> (empty)
# API-DOCS-END
