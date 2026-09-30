# net_ip — private implementation core.
#
# Pure functions over the raw integer carriers (UInt32 for IPv4, UInt128 for
# IPv6): parsing, formatting (RFC 5952 for IPv6), classification, and
# successor/predecessor. The public per-entry modules delegate here so the logic
# exists once. Nothing here allocates beyond the returned String.

from akku.net_ip.ip_parse_error import IpParseError
from akku.net_ip.ip_parse_error_kind import IpParseErrorKind


# ---------------------------------------------------------------------------
# IPv4 carriers
# ---------------------------------------------------------------------------

# octets_to_u32 — pack four octets big-endian (a is the most significant).
def octets_to_u32(a: UInt8, b: UInt8, c: UInt8, d: UInt8) -> UInt32:
    return (
        (UInt32(a) << 24) | (UInt32(b) << 16) | (UInt32(c) << 8) | UInt32(d)
    )


# u32_octet — the octet at position 0..3 (0 is the most significant).
def u32_octet(value: UInt32, index: Int) -> UInt8:
    return UInt8((value >> UInt32(24 - 8 * index)) & UInt32(0xFF))


def format_ipv4(value: UInt32) -> String:
    var out = String()
    out += String((value >> 24) & UInt32(0xFF))
    out += "."
    out += String((value >> 16) & UInt32(0xFF))
    out += "."
    out += String((value >> 8) & UInt32(0xFF))
    out += "."
    out += String(value & UInt32(0xFF))
    return out^


# ---------------------------------------------------------------------------
# IPv6 carriers
# ---------------------------------------------------------------------------

def u128_group(value: UInt128, index: Int) -> UInt16:
    return UInt16((value >> UInt128(112 - 16 * index)) & UInt128(0xFFFF))


# hex16 — one IPv6 group as lowercase hex with no leading zeros.
def hex16(v: UInt16) -> String:
    if v == 0:
        return "0"
    var chars = String("0123456789abcdef")
    var out = String()
    var started = False
    var shift = 12
    while shift >= 0:
        var d = (Int(v) >> shift) & 0xF
        if d != 0 or started:
            started = True
            out += chars[byte=d]
        shift -= 4
    return out^


def format_ipv6(value: UInt128) -> String:
    # Special cases first, matching RFC 5952.
    if value == UInt128(0):
        return "::"
    if value == UInt128(1):
        return "::1"

    # RFC 5952 §5: an IPv4-mapped address uses the mixed dotted-quad notation.
    if v6_is_ipv4_mapped(value):
        return "::ffff:" + format_ipv4(UInt32(value & UInt128(0xFFFFFFFF)))

    var groups = List[UInt16]()
    for i in range(8):
        groups.append(u128_group(value, i))

    # Longest run of >= 2 zero groups; leftmost wins a tie.
    var best_start = -1
    var best_len = 0
    var i = 0
    while i < 8:
        if groups[i] == 0:
            var j = i
            while j < 8 and groups[j] == 0:
                j += 1
            var run = j - i
            if run > best_len:
                best_len = run
                best_start = i
            i = j
        else:
            i += 1
    if best_len < 2:
        best_start = -1

    var out = String()
    var k = 0
    while k < 8:
        if k == best_start:
            out += "::"
            k += best_len
            continue
        if out.byte_length() > 0 and not out.endswith(":"):
            out += ":"
        out += hex16(groups[k])
        k += 1
    return out^


# ---------------------------------------------------------------------------
# IPv4 parsing
# ---------------------------------------------------------------------------

def parse_ipv4(b: Span[UInt8, _]) raises IpParseError -> UInt32:
    var n = len(b)
    if n == 0:
        raise IpParseError(IpParseErrorKind.EMPTY_INPUT, 0)
    var value: UInt32 = 0
    var octet = 0
    var count = 0
    var digits = 0
    for i in range(n):
        var c = Int(b[i])
        if c >= 48 and c <= 57:
            octet = octet * 10 + (c - 48)
            digits += 1
            if octet > 255 or digits > 3:
                raise IpParseError(IpParseErrorKind.OCTET_OUT_OF_RANGE, i)
        elif c == 46:  # '.'
            if digits == 0:
                raise IpParseError(IpParseErrorKind.BAD_GROUP_SEPARATOR, i)
            count += 1
            if count > 3:
                raise IpParseError(IpParseErrorKind.TOO_MANY_GROUPS, i)
            value = (value << 8) | UInt32(octet)
            octet = 0
            digits = 0
        else:
            raise IpParseError(IpParseErrorKind.INVALID_CHARACTER, i)
    if digits == 0:
        raise IpParseError(IpParseErrorKind.BAD_GROUP_SEPARATOR, n - 1)
    count += 1
    if count < 4:
        raise IpParseError(IpParseErrorKind.TOO_FEW_GROUPS, n - 1)
    value = (value << 8) | UInt32(octet)
    return value


# ---------------------------------------------------------------------------
# IPv6 parsing (with '::' compression and an embedded IPv4 tail)
# ---------------------------------------------------------------------------

# A hex group must be 1..4 digits.
def _hex_group(b: Span[UInt8, _], start: Int, end: Int) raises IpParseError -> UInt16:
    if end <= start:
        raise IpParseError(IpParseErrorKind.BAD_GROUP_SEPARATOR, start)
    if end - start > 4:
        raise IpParseError(IpParseErrorKind.SEGMENT_OUT_OF_RANGE, start)
    var value: UInt32 = 0
    for i in range(start, end):
        var c = Int(b[i])
        var d: Int
        if c >= 48 and c <= 57:
            d = c - 48
        elif c >= 97 and c <= 102:
            d = c - 87
        elif c >= 65 and c <= 70:
            d = c - 55
        else:
            raise IpParseError(IpParseErrorKind.INVALID_CHARACTER, i)
        value = (value << 4) | UInt32(d)
    return UInt16(value)


def parse_ipv6(b: Span[UInt8, _]) raises IpParseError -> UInt128:
    var n = len(b)
    if n == 0:
        raise IpParseError(IpParseErrorKind.EMPTY_INPUT, 0)
    for i in range(n):
        if b[i] == UInt8(37):  # '%'
            raise IpParseError(IpParseErrorKind.ZONE_NOT_SUPPORTED, i)

    # Locate the single '::' (if any).
    var comp = -1
    for i in range(n - 1):
        if b[i] == UInt8(58) and b[i + 1] == UInt8(58):
            if comp != -1:
                raise IpParseError(IpParseErrorKind.BAD_IPV6_COMPRESSION, i)
            comp = i

    var groups = List[UInt16]()  # groups before '::' (the whole address if no '::')

    var first_end = n
    var second_start = -1
    if comp != -1:
        first_end = comp
        second_start = comp + 2

    # Parse the head segment [0, first_end) — skipped if empty.
    if first_end > 0:
        var parts = List[Int]()  # boundaries
        _collect(b, 0, first_end, parts)
        _fill_groups(b, parts, groups)

    if comp != -1:
        # Parse the tail segment [second_start, n) — skipped if empty.
        var tail = List[UInt16]()
        if second_start < n:
            var parts2 = List[Int]()
            _collect(b, second_start, n, parts2)
            _fill_groups(b, parts2, tail)
        if len(groups) + len(tail) > 7:
            raise IpParseError(IpParseErrorKind.TOO_MANY_GROUPS, n - 1)
        # Build the 8 groups with zeros inserted at the hole.
        var zeros = 8 - len(groups) - len(tail)
        var value: UInt128 = 0
        for i in range(len(groups)):
            value = (value << 16) | UInt128(groups[i])
        for _ in range(zeros):
            value = value << 16
        for i in range(len(tail)):
            value = (value << 16) | UInt128(tail[i])
        return value

    if len(groups) != 8:
        if len(groups) < 8:
            raise IpParseError(IpParseErrorKind.TOO_FEW_GROUPS, n - 1)
        raise IpParseError(IpParseErrorKind.TOO_MANY_GROUPS, n - 1)
    var plain: UInt128 = 0
    for i in range(8):
        plain = (plain << 16) | UInt128(groups[i])
    return plain


# _collect — record group boundaries (start,end) inside [start,end) split on
# ':'. A trailing dotted-quad group is left intact for _fill_groups.
def _collect(b: Span[UInt8, _], start: Int, end: Int, mut bounds: List[Int]):
    var seg_start = start
    var i = start
    while i < end:
        if b[i] == UInt8(58):  # ':'
            bounds.append(seg_start)
            bounds.append(i)
            seg_start = i + 1
        i += 1
    bounds.append(seg_start)
    bounds.append(end)


def _fill_groups(
    b: Span[UInt8, _], bounds: List[Int], mut out: List[UInt16]
) raises IpParseError:
    var count = len(bounds) // 2
    for k in range(count):
        var s = bounds[2 * k]
        var e = bounds[2 * k + 1]
        if s == e:
            raise IpParseError(IpParseErrorKind.BAD_GROUP_SEPARATOR, s)
        # An embedded IPv4 tail is the last group and contains a '.'.
        if k == count - 1 and _has_dot(b, s, e):
            var v4 = parse_ipv4(b[s:e])
            out.append(UInt16((v4 >> 16) & UInt32(0xFFFF)))
            out.append(UInt16(v4 & UInt32(0xFFFF)))
        else:
            out.append(_hex_group(b, s, e))


def _has_dot(b: Span[UInt8, _], start: Int, end: Int) -> Bool:
    for i in range(start, end):
        if b[i] == UInt8(46):
            return True
    return False


# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

def v4_is_unspecified(v: UInt32) -> Bool:
    return v == UInt32(0)


def v4_is_loopback(v: UInt32) -> Bool:
    return (v >> 24) == UInt32(127)


def v4_is_private(v: UInt32) -> Bool:
    if (v >> 24) == UInt32(10):
        return True
    if (v >> 20) == UInt32(0xAC1):  # 172.16.0.0/12
        return True
    if (v >> 16) == UInt32(0xC0A8):  # 192.168.0.0/16
        return True
    return False


def v4_is_link_local(v: UInt32) -> Bool:
    return (v >> 16) == UInt32(0xA9FE)  # 169.254.0.0/16


def v4_is_multicast(v: UInt32) -> Bool:
    return (v >> 28) == UInt32(0xE)  # 224.0.0.0/4


def v4_is_broadcast(v: UInt32) -> Bool:
    return v == UInt32(0xFFFFFFFF)


def v6_is_unspecified(v: UInt128) -> Bool:
    return v == UInt128(0)


def v6_is_loopback(v: UInt128) -> Bool:
    return v == UInt128(1)


def v6_is_private(v: UInt128) -> Bool:
    return (v >> UInt128(121)) == UInt128(0x7E)  # fc00::/7 (ULA)


def v6_is_link_local(v: UInt128) -> Bool:
    return (v >> UInt128(118)) == UInt128(0x3FA)  # fe80::/10


def v6_is_multicast(v: UInt128) -> Bool:
    return (v >> UInt128(120)) == UInt128(0xFF)  # ff00::/8


def v6_is_ipv4_mapped(v: UInt128) -> Bool:
    return (v >> UInt128(32)) == UInt128(0xFFFF)  # ::ffff:0:0/96


def v6_is_ipv4_compatible(v: UInt128) -> Bool:
    # ::a.b.c.d with the top 96 bits zero, except the unspecified/loopback forms.
    return (v >> UInt128(32)) == UInt128(0) and v != UInt128(0) and v != UInt128(1)


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

def v4_next(v: UInt32) -> Optional[UInt32]:
    if v == UInt32(0xFFFFFFFF):
        return None
    return UInt32(v + 1)


def v4_prev(v: UInt32) -> Optional[UInt32]:
    if v == UInt32(0):
        return None
    return UInt32(v - 1)
