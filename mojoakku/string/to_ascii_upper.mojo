from string._internal.utf8 import string_from_bytes


# to_ascii_upper — deterministic ASCII-only uppercase fast path.
def to_ascii_upper(text: StringSpan) -> String:
    var bytes = text.as_bytes()
    var out = List[UInt8](capacity=len(bytes))
    for b in bytes:
        if b >= 0x61 and b <= 0x7A:   # 'a'..'z'
            out.append(b - 0x20)
        else:
            out.append(b)
    return string_from_bytes(out^)

# API-DOCS-START
# to_ascii_upper — deterministic ASCII-only uppercasing.
# Signature:
#   def to_ascii_upper(text: StringSpan) -> String
# What it does:
#   Maps only the ASCII letters a-z to A-Z; every other byte is copied unchanged.
#   The result is always valid UTF-8 and has exactly the same byte length as the
#   input. It never touches Unicode case tables and never reads the ambient
#   locale. `text` is borrowed.
# Returns:
#   A freshly owned String of the same byte length. The caller owns it.
# Errors:
#   none.
# Example:
#   print(to_ascii_upper("AbC"))   # -> ABC
#   print(to_ascii_upper("äbc"))   # -> äBC (non-ASCII bytes unchanged)
#   print(to_ascii_upper("ABC"))   # -> ABC
# API-DOCS-END
