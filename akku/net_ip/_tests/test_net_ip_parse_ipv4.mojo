# Concern: `parse` / `parse_ipv4` — IPv4 dotted-quad parsing (docs blocks in
# `../parse.mojo` and `../parse_ipv4.mojo`).
#
# Covers: every valid octet boundary; leading-zero groups; the whole error
# surface reachable through the IPv4 path; position points at the failure byte;
# a failure never yields a value.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.net_ip import parse, parse_ipv4, IpParseErrorKind


def test_parse_ipv4_valid() raises:
    assert_equal(String(parse("192.168.1.1")), "192.168.1.1")
    assert_equal(String(parse("0.0.0.0")), "0.0.0.0")
    assert_equal(String(parse("255.255.255.255")), "255.255.255.255")
    assert_equal(String(parse("1.2.3.4")), "1.2.3.4")
    assert_equal(String(parse_ipv4("10.0.0.7")), "10.0.0.7")


def test_parse_ipv4_leading_zeros_accepted() raises:
    assert_equal(String(parse("192.168.001.001")), "192.168.1.1")


def test_parse_ipv4_family_is_ipv4() raises:
    var a = parse("1.2.3.4")
    assert_true(a.is_ipv4())
    assert_false(a.is_ipv6())
    assert_equal(String(a.family()), "IPV4")


def test_parse_ipv4_out_of_range() raises:
    var caught = False
    try:
        _ = parse_ipv4("256.1.1.1")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.OCTET_OUT_OF_RANGE)
        assert_equal(e.position, 2)
    assert_true(caught)


def test_parse_ipv4_too_few_groups() raises:
    var caught = False
    try:
        _ = parse_ipv4("1.2.3")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.TOO_FEW_GROUPS)
    assert_true(caught)


def test_parse_ipv4_too_many_groups() raises:
    var caught = False
    try:
        _ = parse_ipv4("1.2.3.4.5")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.TOO_MANY_GROUPS)
    assert_true(caught)


def test_parse_ipv4_invalid_character() raises:
    var caught = False
    try:
        _ = parse_ipv4("1.2.3.x")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.INVALID_CHARACTER)
        assert_equal(e.position, 6)
    assert_true(caught)


def test_parse_ipv4_bad_separator() raises:
    var caught = False
    try:
        _ = parse_ipv4("1..3.4")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.BAD_GROUP_SEPARATOR)
    assert_true(caught)


def test_parse_ipv4_empty() raises:
    var caught = False
    try:
        _ = parse_ipv4("")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.EMPTY_INPUT)
    assert_true(caught)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
