# Concern: `format` — textual rendering, IPv6 in RFC 5952 canonical form
# (docs block in `../format.mojo`).
#
# Covers: dotted-quad IPv4; RFC 5952 cases (longest-run compression, leftmost
# tie-break, single zero group not compressed); lowercase hex; the mixed
# '::ffff:a.b.c.d' form for IPv4-mapped addresses; parse/format round trips.

from std.testing import assert_equal, TestSuite
from akku.net_ip import format, parse, Ipv4Address, Ipv6Address


def test_format_ipv4() raises:
    assert_equal(format(parse("192.168.1.1")), "192.168.1.1")
    assert_equal(format(parse("0.0.0.0")), "0.0.0.0")
    assert_equal(format(parse("255.255.255.255")), "255.255.255.255")


def test_format_ipv6_full_no_compression() raises:
    assert_equal(format(parse("1:2:3:4:5:6:7:8")), "1:2:3:4:5:6:7:8")


def test_format_ipv6_lowercase_no_leading_zeros() raises:
    assert_equal(format(parse("2001:0DB8:0000:0000:0000:0000:0000:0001")), "2001:db8::1")


def test_format_ipv6_longest_run_wins() raises:
    # The three-zero run in the middle is the longest, so it is compressed.
    assert_equal(format(parse("2001:db8:0:0:1:0:0:1")), "2001:db8::1:0:0:1")


def test_format_ipv6_leftmost_tie() raises:
    # Two runs of length one: neither is compressed (a single zero is kept).
    assert_equal(format(parse("0:0:0:1:0:0:0:1")), "::1:0:0:0:1")


def test_format_ipv6_single_zero_not_compressed() raises:
    assert_equal(format(parse("2001:0:0:1:0:0:1:1")), "2001::1:0:0:1:1")


def test_format_ipv6_special_cases() raises:
    assert_equal(format(parse("::")), "::")
    assert_equal(format(parse("::1")), "::1")


def test_format_ipv6_mapped_uses_mixed_notation() raises:
    assert_equal(format(parse("::ffff:127.0.0.1")), "::ffff:127.0.0.1")
    assert_equal(format(parse("::ffff:192.168.1.1")), "::ffff:192.168.1.1")


def test_format_roundtrip() raises:
    var samples = List[String]()
    samples.append("192.168.1.1")
    samples.append("2001:db8::1")
    samples.append("::")
    samples.append("::1")
    samples.append("::ffff:10.0.0.1")
    samples.append("fe80::1")
    for i in range(len(samples)):
        var s: StringSpan = samples[i]
        var once = format(parse(s))
        var twice = format(parse(once))
        assert_equal(once, twice)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
