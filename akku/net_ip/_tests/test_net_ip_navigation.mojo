# Concern: `next` / `prev` navigation and ordering/equality across families
# (docs blocks in `../ipv4_address.mojo`, `../ipv6_address.mojo`,
# `../ip_address.mojo`).
#
# Covers: one-step successor/predecessor; None at both range ends (never wrap,
# never panic); the total order IPv4-before-IPv6 then numeric; equality.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.net_ip import parse, Ipv4Address, Ipv6Address


def test_ipv4_next_prev() raises:
    var a = Ipv4Address.from_u32(5)
    assert_equal(a.next().value().to_u32(), UInt32(6))
    assert_equal(a.prev().value().to_u32(), UInt32(4))


def test_ipv4_next_at_max_is_none() raises:
    var a = Ipv4Address.from_u32(UInt32(0xFFFFFFFF))
    assert_false(a.next())


def test_ipv4_prev_at_zero_is_none() raises:
    var a = Ipv4Address.from_u32(0)
    assert_false(a.prev())


def test_ipv6_next_prev() raises:
    var a = Ipv6Address.from_u128(5)
    assert_equal(a.next().value().to_u128(), UInt128(6))
    assert_equal(a.prev().value().to_u128(), UInt128(4))


def test_ipv6_next_at_max_is_none() raises:
    var a = Ipv6Address.from_u128(UInt128(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
    assert_false(a.next())


def test_ipv6_prev_at_zero_is_none() raises:
    var a = Ipv6Address.from_u128(0)
    assert_false(a.prev())


def test_ordering_ipv4_before_ipv6() raises:
    var v4 = parse("255.255.255.255")
    var v6 = parse("::")
    assert_true(v4.compare(v6) == -1)
    assert_true(v6.compare(v4) == 1)


def test_ordering_within_family() raises:
    assert_true(parse("1.0.0.0").compare(parse("2.0.0.0")) == -1)
    assert_true(parse("::2").compare(parse("::1")) == 1)
    assert_true(parse("1.0.0.0").compare(parse("1.0.0.0")) == 0)


def test_equality() raises:
    assert_true(parse("10.0.0.1") == parse("10.0.0.1"))
    assert_false(parse("10.0.0.1") == parse("10.0.0.2"))
    assert_false(parse("10.0.0.1") == parse("::1"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
