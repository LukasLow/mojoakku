# is_char_boundary — is a byte index a valid codepoint start (or the end)?
def is_char_boundary(text: StringSpan, index: Int) -> Bool:
    var n = text.byte_length()
    if index < 0 or index > n:
        return False
    if index == n:
        return True
    # A codepoint start is any byte that is not a UTF-8 continuation byte
    # (0b10xxxxxx). This is exact for valid UTF-8, which every StringSpan is.
    return (text.as_bytes()[index] & 0xC0) != 0x80

# API-DOCS-START
# is_char_boundary — is a byte index a valid UTF-8 codepoint start (or the end)?
# Signature:
#   def is_char_boundary(text: StringSpan, index: Int) -> Bool
# What it does:
#   Reports whether `index` is a safe place to start a slice of `text`. Index 0
#   and `text.byte_length()` (the end) are boundaries; an index below 0 or beyond
#   the length is False rather than an error. A byte whose top two bits are `10`
#   (a UTF-8 continuation byte) is not a boundary. The test is O(1) and never
#   aborts.
# Returns:
#   True when `index` starts a codepoint or is the end; False otherwise. `text`
#   stays borrowed.
# Errors:
#   none — an out-of-range index is False, not an error.
# Example:
#   print(is_char_boundary("hello", 0))   # -> True
#   print(is_char_boundary("hello", 5))   # -> True  (the end)
#   print(is_char_boundary("hé", 1))      # -> True  (start of 'é')
#   print(is_char_boundary("hé", 2))      # -> False (inside 'é')
#   print(is_char_boundary("hi", -1))     # -> False
# API-DOCS-END
