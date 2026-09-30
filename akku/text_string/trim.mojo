from akku.text_string._internal.utf8 import (
    codepoint_is_unicode_whitespace,
    decode_utf8_at,
    utf8_next_index,
    utf8_prev_index,
)


# trim — strip leading/trailing Unicode whitespace, or an explicit char set.
def trim[o: Origin[mut=False]](text: StringSpan[o]) -> StringSpan[o]:
    var bytes = text.as_bytes()
    var start = 0
    var end = len(bytes)
    while start < end:
        var decoded = decode_utf8_at(bytes, start)
        if decoded[0] == 0 or not codepoint_is_unicode_whitespace(decoded[1]):
            break
        start += decoded[0]
    while end > start:
        var prev = utf8_prev_index(bytes, end)
        var decoded = decode_utf8_at(bytes, prev)
        if decoded[0] == 0 or not codepoint_is_unicode_whitespace(decoded[1]):
            break
        end = prev
    return text[byte=start:end]


def trim[o: Origin[mut=False]](text: StringSpan[o], chars: StringSpan) -> StringSpan[o]:
    var bytes = text.as_bytes()
    var char_bytes = chars.as_bytes()
    var start = 0
    var end = len(bytes)
    while start < end:
        var width = _char_set_width(bytes, start, char_bytes)
        if width == 0:
            break
        start += width
    while end > start:
        var prev = utf8_prev_index(bytes, end)
        var width = _char_set_width(bytes, prev, char_bytes)
        if width == 0 or prev + width != end:
            break
        end = prev
    return text[byte=start:end]


# _char_set_width — if the codepoint starting at `index` is a member of the
# `chars` set, return its byte width; otherwise 0. A member is matched by its
# exact byte sequence, so the set is compared codepoint by codepoint.
def _char_set_width(bytes: Span[UInt8, _], index: Int, chars: Span[UInt8, _]) -> Int:
    var decoded = decode_utf8_at(bytes, index)
    if decoded[0] == 0:
        return 0
    var width = decoded[0]
    var j = 0
    while j < len(chars):
        var member = decode_utf8_at(chars, j)
        if member[0] == 0:
            j += 1
            continue
        if member[0] == width and member[1] == decoded[1]:
            return width
        j += member[0]
    return 0

# API-DOCS-START
# trim — remove leading and trailing whitespace, or an explicit character set.
# Signature:
#   def trim[o: Origin[mut=False]](text: StringSpan[o]) -> StringSpan[o]
#   def trim[o: Origin[mut=False]](text: StringSpan[o], chars: StringSpan) -> StringSpan[o]
# What it does:
#   The one-argument form strips leading and trailing Unicode whitespace
#   (U+0009-U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000-U+200A, U+2028,
#   U+2029, U+202F, U+205F, U+3000). The two-argument form strips any leading or
#   trailing codepoint that is a member of the SET `chars` — not a prefix or
#   suffix that must match as a whole. `text` is borrowed; the result is a view
#   into it, so nothing is allocated. An all-whitespace input yields the empty
#   view.
# Returns:
#   A borrowed view into `text` with the matching bytes removed from both ends.
#   The view stays valid as long as `text` does.
# Errors:
#   none — trimming cannot fail.
# Example:
#   print(trim("  hi  "))            # -> hi
#   print(trim("\u00A0x\u3000"))     # -> x (Unicode whitespace, unlike std strip)
#   print(trim("xxaxx", "x"))        # -> a  (chars is a set)
#   print(trim("abc", ""))           # -> abc (empty set strips nothing)
# API-DOCS-END
