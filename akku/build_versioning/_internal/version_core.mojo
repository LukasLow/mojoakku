# version_core — private implementation core for akku/build_versioning.
#
# Pure functions over raw version fields: the SemVer clause-11 precedence
# comparison and the shared identifier validation. Both `semver.mojo` (its
# `__eq__`) and `precedence.mojo` delegate here, so the logic exists once and
# neither public module imports the other. This file imports no public module,
# which is what breaks the would-be cycle. Not public API.


# --- byte predicates --------------------------------------------------------

def _is_digit(b: UInt8) -> Bool:
    return b >= UInt8(48) and b <= UInt8(57)  # '0'..'9'


def _is_alpha(b: UInt8) -> Bool:
    return (b >= UInt8(65) and b <= UInt8(90)) or (  # 'A'..'Z'
        b >= UInt8(97) and b <= UInt8(122)
    )  # 'a'..'z'


def _is_hyphen_or_alnum(b: UInt8) -> Bool:
    return _is_digit(b) or _is_alpha(b) or b == UInt8(45)  # '-'


# --- identifier classification ----------------------------------------------

# identifier_class — 0 = invalid character or empty, 1 = numeric (all digits),
# 2 = alphanumeric (contains at least one non-digit, all chars allowed).
def identifier_class(text: StringSpan) -> Int:
    var bytes = text.as_bytes()
    var n = len(bytes)
    if n == 0:
        return 0
    var all_digits = True
    for i in range(n):
        var b = bytes[i]
        if _is_digit(b):
            continue
        all_digits = False
        if not _is_hyphen_or_alnum(b):
            return 0
    if all_digits:
        return 1
    return 2


# has_leading_zero — true for an all-digit string of length > 1 whose first
# byte is '0'. Callers only ask this of a numeric identifier.
def has_leading_zero(text: StringSpan) -> Bool:
    var bytes = text.as_bytes()
    return len(bytes) > 1 and bytes[0] == UInt8(48)


# parse_digits — parse an all-digit, non-empty identifier into an Int.
# Returns -1 when the value does not fit Int (the caller has already checked
# that every byte is a digit and that there is no leading zero).
def parse_digits(text: StringSpan) -> Int:
    var bytes = text.as_bytes()
    var value = 0
    for i in range(len(bytes)):
        var d = Int(bytes[i]) - 48
        if value > (9223372036854775807 - d) // 10:
            return -1
        value = value * 10 + d
    return value


# validate_qualifier — 0 = valid, -1 = INVALID_FORMAT, -2 = LEADING_ZERO.
# Splits `text` on '.' and checks each identifier. `allow_leading_zero` is true
# for build metadata (leading zeros allowed) and false for prerelease.
def validate_qualifier(text: StringSpan, allow_leading_zero: Bool) -> Int:
    var bytes = text.as_bytes()
    var n = len(bytes)
    if n == 0:
        return -1
    var start = 0
    while True:
        var end = start
        while end < n and bytes[end] != UInt8(46):  # '.'
            end += 1
        var id = text[byte=start:end]
        var kind = identifier_class(id)
        if kind == 0:
            return -1
        if kind == 1 and not allow_leading_zero and has_leading_zero(id):
            return -2
        if end >= n:
            return 0
        start = end + 1


# --- precedence -------------------------------------------------------------

def _compare_ascii(a: StringSpan, b: StringSpan) -> Int:
    var ab = a.as_bytes()
    var bb = b.as_bytes()
    var n = len(ab)
    if len(bb) < n:
        n = len(bb)
    for i in range(n):
        if ab[i] < bb[i]:
            return -1
        if ab[i] > bb[i]:
            return 1
    if len(ab) < len(bb):
        return -1
    if len(ab) > len(bb):
        return 1
    return 0


# _compare_numeric — numeric identifiers have no leading zeros here, so the
# longer digit string is the larger number; equal length compares lexically.
def _compare_numeric(a: StringSpan, b: StringSpan) -> Int:
    var la = a.byte_length()
    var lb = b.byte_length()
    if la < lb:
        return -1
    if la > lb:
        return 1
    return _compare_ascii(a, b)


# _compare_identifier — classify both, then numeric-vs-numeric, alphabetic
# ASCII order, and numeric-below-alphanumeric. Only called on valid identifiers
# (from compare_precedence on a parsed version or from an in-test string).
def _compare_identifier(a: StringSpan, b: StringSpan) -> Int:
    var ka = identifier_class(a)
    var kb = identifier_class(b)
    if ka == kb:
        if ka == 1:
            return _compare_numeric(a, b)
        return _compare_ascii(a, b)
    # A numeric identifier always has lower precedence than an alphanumeric one.
    if ka == 1:
        return -1
    return 1


def _compare_prerelease(a: StringSpan, b: StringSpan) -> Int:
    var ab = a.as_bytes()
    var bb = b.as_bytes()
    var na = len(ab)
    var nb = len(bb)
    var ai = 0
    var bi = 0
    while True:
        var a_end = ai
        while a_end < na and ab[a_end] != UInt8(46):  # '.'
            a_end += 1
        var b_end = bi
        while b_end < nb and bb[b_end] != UInt8(46):
            b_end += 1
        var c = _compare_identifier(a[byte=ai:a_end], b[byte=bi:b_end])
        if c != 0:
            return c
        var a_more = a_end < na
        var b_more = b_end < nb
        if not a_more and not b_more:
            return 0
        # A larger set of identifiers has higher precedence.
        if a_more and not b_more:
            return 1
        if b_more and not a_more:
            return -1
        ai = a_end + 1
        bi = b_end + 1


# compare_precedence — SemVer clause 11 ordering over raw fields, -1/0/+1.
def compare_precedence(
    a_major: Int,
    a_minor: Int,
    a_patch: Int,
    a_prerelease: StringSpan,
    b_major: Int,
    b_minor: Int,
    b_patch: Int,
    b_prerelease: StringSpan,
) -> Int:
    if a_major != b_major:
        return -1 if a_major < b_major else 1
    if a_minor != b_minor:
        return -1 if a_minor < b_minor else 1
    if a_patch != b_patch:
        return -1 if a_patch < b_patch else 1
    var a_has = a_prerelease.byte_length() > 0
    var b_has = b_prerelease.byte_length() > 0
    if a_has and not b_has:
        return -1
    if b_has and not a_has:
        return 1
    if not a_has and not b_has:
        return 0
    return _compare_prerelease(a_prerelease, b_prerelease)
