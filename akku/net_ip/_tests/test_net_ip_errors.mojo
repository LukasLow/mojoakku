# Concern: `try_parse`, `is_valid` and the `IpParseError` /
# `IpParseErrorKind` surface (docs blocks in `../try_parse.mojo`,
# `../is_valid.mojo`, `../ip_parse_error.mojo`, `../ip_parse_error_kind.mojo`).
#
# Covers: the non-throwing paths never raise; the error carries a kind and a
# byte position; `print(err)` shows the symbolic kind name.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.net_ip import (
    try_parse,
    is_valid,
    parse,
    IpParseError,
    IpParseErrorKind,
)


def test_try_parse_valid() raises:
    var a = try_parse("10.0.0.1")
    assert_true(a)
    assert_equal(String(a.value()), "10.0.0.1")
    var b = try_parse("2001:db8::1")
    assert_true(b)
    assert_equal(String(b.value()), "2001:db8::1")


def test_try_parse_invalid_returns_none() raises:
    assert_false(try_parse("10.0.0"))
    assert_false(try_parse("256.1.1.1"))
    assert_false(try_parse(""))
    assert_false(try_parse("nope"))


def test_is_valid() raises:
    assert_true(is_valid("192.168.1.1"))
    assert_true(is_valid("::1"))
    assert_true(is_valid("::ffff:10.0.0.1"))
    assert_false(is_valid("256.1.1.1"))
    assert_false(is_valid("1.2.3"))
    assert_false(is_valid("2001:db8::g"))


def test_error_kind_symbolic_names() raises:
    assert_true("OCTET_OUT_OF_RANGE" in String(IpParseErrorKind.OCTET_OUT_OF_RANGE))
    assert_true("EMPTY_INPUT" in String(IpParseErrorKind.EMPTY_INPUT))
    assert_true("BAD_IPV6_COMPRESSION" in String(IpParseErrorKind.BAD_IPV6_COMPRESSION))
    assert_true("ZONE_NOT_SUPPORTED" in String(IpParseErrorKind.ZONE_NOT_SUPPORTED))


def test_error_write_to_reports_kind_and_position() raises:
    var err = IpParseError(IpParseErrorKind.OCTET_OUT_OF_RANGE, 3)
    var text = String(err)
    assert_true("OCTET_OUT_OF_RANGE" in text)
    assert_true("3" in text)


def test_error_position_is_byte_index() raises:
    var caught = False
    try:
        _ = parse("12.34.56.7x")
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.INVALID_CHARACTER)
        assert_equal(e.position, 10)
    assert_true(caught)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
