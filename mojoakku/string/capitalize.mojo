from string._internal.utf8 import utf8_next_index, utf8_prev_index


# capitalize — uppercase the first codepoint, lowercase the rest.
def capitalize(text: StringSpan) -> String:
    if text.byte_length() == 0:
        return String()
    var bytes = text.as_bytes()
    # Only the first codepoint is upper-cased; the remainder is lower-cased.
    var first_end = utf8_next_index(bytes, 0)
    var head = text[byte=0:first_end].upper()
    if first_end >= len(bytes):
        return head^
    var tail = text[byte=first_end:].lower()
    return head + tail

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
