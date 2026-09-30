# utf8.mojo — private UTF-8 helpers shared across several string entries.
#
# These functions exist once to keep `trim.mojo` (the Unicode whitespace set)
# and `is_valid_utf8.mojo` (the RFC 3629 validation) from duplicating the same
# codepoint-boundary and decoding logic. They are private: nothing here is part
# of the public API surface.

# decode_utf8_at — decode the codepoint starting at byte index `i`.
#
# Returns (byte_width, codepoint_value). On an invalid, truncated or overlong
# sequence the width is 0 and the value is 0, so callers can distinguish a real
# U+FFFD (0xEF 0xBF 0xBD, a valid 3-byte sequence) from a failure. `i` must be a
# valid index into `bytes`.
def decode_utf8_at(bytes: Span[UInt8, _], i: Int) -> Tuple[Int, Int]:
    var b0 = bytes[i]
    if b0 < 0x80:
        return (1, Int(b0))
    if b0 >= 0xC2 and b0 <= 0xDF:
        if i + 1 < len(bytes) and (bytes[i + 1] & 0xC0) == 0x80:
            var value = (Int(b0) & 0x1F) << 6
            value |= Int(bytes[i + 1]) & 0x3F
            return (2, value)
    elif b0 >= 0xE0 and b0 <= 0xEF:
        if i + 2 < len(bytes) and (bytes[i + 1] & 0xC0) == 0x80 and (bytes[i + 2] & 0xC0) == 0x80:
            # Reject overlong forms and surrogate encodings.
            var b1 = bytes[i + 1]
            if not (b0 == 0xE0 and b1 < 0xA0) and not (b0 == 0xED and b1 >= 0xA0):
                var value = (Int(b0) & 0x0F) << 12
                value |= (Int(b1) & 0x3F) << 6
                value |= Int(bytes[i + 2]) & 0x3F
                return (3, value)
    elif b0 >= 0xF0 and b0 <= 0xF4:
        if i + 3 < len(bytes) and (bytes[i + 1] & 0xC0) == 0x80 and (bytes[i + 2] & 0xC0) == 0x80 and (bytes[i + 3] & 0xC0) == 0x80:
            var b1 = bytes[i + 1]
            # Reject overlong forms and values above U+10FFFF.
            if not (b0 == 0xF0 and b1 < 0x90) and not (b0 == 0xF4 and b1 >= 0x90):
                var value = (Int(b0) & 0x07) << 18
                value |= (Int(b1) & 0x3F) << 12
                value |= (Int(bytes[i + 2]) & 0x3F) << 6
                value |= Int(bytes[i + 3]) & 0x3F
                return (4, value)
    return (0, 0)


# utf8_first_invalid — the byte offset of the first invalid/truncated/overlong
# sequence, or `len(bytes)` when the whole span is valid UTF-8. Allocation-free.
def utf8_first_invalid(bytes: Span[UInt8, _]) -> Int:
    var i = 0
    var n = len(bytes)
    while i < n:
        var b0 = bytes[i]
        if b0 < 0x80:
            i += 1
            continue
        var decoded = decode_utf8_at(bytes, i)
        if decoded[0] == 0:
            return i
        i += decoded[0]
    return n


# codepoint_is_unicode_whitespace — the fixed whitespace set documented in
# `trim.mojo` (U+0009-U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000-U+200A,
# U+2028, U+2029, U+202F, U+205F, U+3000).
def codepoint_is_unicode_whitespace(cp: Int) -> Bool:
    if cp >= 0x09 and cp <= 0x0D:
        return True
    if cp == 0x20 or cp == 0x85 or cp == 0xA0 or cp == 0x1680:
        return True
    if cp >= 0x2000 and cp <= 0x200A:
        return True
    if cp == 0x2028 or cp == 0x2029 or cp == 0x202F or cp == 0x205F:
        return True
    if cp == 0x3000:
        return True
    return False


# utf8_next_index — the byte index of the next codepoint start after `i`.
def utf8_next_index(bytes: Span[UInt8, _], i: Int) -> Int:
    if i >= len(bytes):
        return len(bytes)
    var b = bytes[i]
    if b < 0x80:
        return i + 1
    var width = 1
    if b >= 0xC2 and b <= 0xDF:
        width = 2
    elif b >= 0xE0 and b <= 0xEF:
        width = 3
    elif b >= 0xF0 and b <= 0xF4:
        width = 4
    var next = i + width
    if next > len(bytes):
        next = len(bytes)
    return next


# utf8_prev_index — the byte index of the previous codepoint start before `i`.
# Only used to walk a string backwards from a known boundary; a continuation
# byte is skipped by masking the UTF-8 lead-byte pattern.
def utf8_prev_index(bytes: Span[UInt8, _], i: Int) -> Int:
    if i <= 0:
        return 0
    var k = i - 1
    while k > 0 and (bytes[k] & 0xC0) == 0x80:
        k -= 1
    return k


# string_from_bytes — build an owned String from raw UTF-8 bytes without any
# per-byte Codepoint re-encoding. The caller guarantees the bytes are valid
# UTF-8 (byte-preserving transforms such as the ASCII case paths keep validity).
def string_from_bytes(var bytes: List[UInt8]) -> String:
    return String(unsafe_from_utf8=Span(bytes))
