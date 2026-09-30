# Concern: `parse_ipv6` — IPv6 parsing with '::' compression and an embedded
# IPv4 tail (docs block in `../parse_ipv6.mojo`).
#
# Covers: full and compressed forms; the leftmost/longest compression; mapped
# and compatible tails; the IPv6 error surface; position points at the failure.

from std.testing import assert_equal, assert_true, TestSuite
from akku.net_ip import parse_ipv6, parse, IpParseErrorKind


def test_parse_ipv6_full_form() raises:
    var a = parse_ipv6("2001:0db8:0000:0000:0000:0000:0000:0001")
    assert_equal(String(a), "2001:db8::1")
    assert_equal(String(parse_ipv6("1:2:3:4:5:6:7:8")), "1:2:3:4:5:6:7:8")


def test_parse_ipv6_compressed_forms() raises:
    assert_equal(String(parse_ipv6("2001:db8::1")), "2001:db8::1")
    assert_equal(String(parse_ipv6("::1")), "::1")
    assert_equal(String(parse_ipv6("::")), "::")
    assert_equal(String(parse_ipv6("fe80::1")), "fe80::1")
    assert_equal(String(parse_ipv6("2001:db8::")), "2001:db8::")
    # ::ffff:0:0 is within ::ffff:0:0/96, so it is IPv4-mapped and renders in
    # the RFC 5952 mixed notation as the mapping of 0.0.0.0.
    assert_equal(String(parse_ipv6("::ffff:0:0")), "::ffff:0.0.0.0")


def test_parse_ipv6_family_is_ipv6() raises:
    var a = parse("2001:db8::1")
    assert_true(a.is_ipv6())
    assert_equal(String(a.family), "IPV6")


def test_parse_ipv6_embedded_ipv4_tail() raises:
    assert_equal(String(parse_ipv6("::ffff:127.0.0.1")), "::ffff:127.0.0.1")
    assert_equal(String(parse_ipv6("::ffff:192.168.1.1")), "::ffff:192.168.1.1")
    assert_equal(String(parse_ipv6("64:ff9b::1.2.3.4")), "64:ff9b::102:304")


def test_parse_ipv6_too_few_groups() raises:
    var caught = False
    try:
        _ = parse_ipv6("1:2:3")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.TOO_FEW_GROUPS)
    assert_true(caught)


def test_parse_ipv6_too_many_groups() raises:
    var caught = False
    try:
        _ = parse_ipv6("1:2:3:4:5:6:7:8:9")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.TOO_MANY_GROUPS)
    assert_true(caught)


def test_parse_ipv6_second_compression_rejected() raises:
    var caught = False
    try:
        _ = parse_ipv6("1::2::3")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.BAD_IPV6_COMPRESSION)
    assert_true(caught)


def test_parse_ipv6_segment_out_of_range() raises:
    var caught = False
    try:
        _ = parse_ipv6("12345::1")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.SEGMENT_OUT_OF_RANGE)
    assert_true(caught)


def test_parse_ipv6_zone_rejected() raises:
    var caught = False
    try:
        _ = parse_ipv6("fe80::1%eth0")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.ZONE_NOT_SUPPORTED)
        assert_equal(e.position, 7)
    assert_true(caught)


def test_parse_ipv6_invalid_character() raises:
    var caught = False
    try:
        _ = parse_ipv6("2001:db8::g")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.INVALID_CHARACTER)
    assert_true(caught)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
