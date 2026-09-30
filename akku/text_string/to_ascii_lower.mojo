from akku.text_string._internal.utf8 import string_from_bytes


# to_ascii_lower — deterministic ASCII-only lowercase fast path.
def to_ascii_lower(text: StringSpan) -> String:
    var bytes = text.as_bytes()
    var out = List[UInt8](capacity=len(bytes))
    for b in bytes:
        if b >= 0x41 and b <= 0x5A:   # 'A'..'Z'
            out.append(b + 0x20)
        else:
            out.append(b)
    return string_from_bytes(out^)

# API-DOCS-START
# to_ascii_lower — deterministic ASCII-only lowercasing.
# Signature:
#   def to_ascii_lower(text: StringSpan) -> String
# What it does:
#   Maps only the ASCII letters A-Z to a-z; every other byte is copied unchanged.
#   The result is therefore always valid UTF-8 and has exactly the same byte
#   length as the input. It never touches Unicode case tables and never reads the
#   ambient locale. `text` is borrowed.
# Returns:
#   A freshly owned String of the same byte length. The caller owns it.
# Errors:
#   none.
# Example:
#   print(to_ascii_lower("AbC"))   # -> abc
#   print(to_ascii_lower("ÄBC"))   # -> Äbc (non-ASCII bytes unchanged)
#   print(to_ascii_lower("abc"))   # -> abc
# API-DOCS-END
