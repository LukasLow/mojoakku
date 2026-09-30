# Concern: the classification predicate set on Ipv4Address, Ipv6Address and
# IpAddress (docs blocks in `../ipv4_address.mojo`, `../ipv6_address.mojo`,
# `../ip_address.mojo`).
#
# Covers: one RFC-backed example per predicate per family, plus negatives; the
# predicate set is closed and each name is RFC-precise.

from std.testing import assert_true, assert_false, TestSuite
from akku.net_ip import parse, Ipv4Address, Ipv6Address


def test_ipv4_unspecified() raises:
    assert_true(Ipv4Address.from_u32(0).is_unspecified())
    assert_false(parse("0.0.0.1").to_ipv4().value().is_unspecified())


def test_ipv4_loopback() raises:
    assert_true(parse("127.0.0.1").to_ipv4().value().is_loopback())
    assert_true(parse("127.255.255.255").to_ipv4().value().is_loopback())
    assert_false(parse("128.0.0.1").to_ipv4().value().is_loopback())


def test_ipv4_private() raises:
    assert_true(parse("10.0.0.1").to_ipv4().value().is_private())
    assert_true(parse("10.255.255.255").to_ipv4().value().is_private())
    assert_true(parse("172.16.0.1").to_ipv4().value().is_private())
    assert_true(parse("172.31.255.255").to_ipv4().value().is_private())
    assert_true(parse("192.168.0.1").to_ipv4().value().is_private())
    assert_false(parse("172.32.0.1").to_ipv4().value().is_private())
    assert_false(parse("11.0.0.1").to_ipv4().value().is_private())
    assert_false(parse("192.169.0.1").to_ipv4().value().is_private())


def test_ipv4_link_local() raises:
    assert_true(parse("169.254.1.1").to_ipv4().value().is_link_local())
    assert_false(parse("169.255.1.1").to_ipv4().value().is_link_local())


def test_ipv4_multicast() raises:
    assert_true(parse("224.0.0.1").to_ipv4().value().is_multicast())
    assert_true(parse("239.255.255.255").to_ipv4().value().is_multicast())
    assert_false(parse("223.255.255.255").to_ipv4().value().is_multicast())


def test_ipv4_broadcast() raises:
    assert_true(parse("255.255.255.255").to_ipv4().value().is_broadcast())
    assert_false(parse("255.255.255.254").to_ipv4().value().is_broadcast())


def test_ipv6_unspecified_loopback() raises:
    assert_true(parse("::").to_ipv6().value().is_unspecified())
    assert_true(parse("::1").to_ipv6().value().is_loopback())
    assert_false(parse("::2").to_ipv6().value().is_loopback())


def test_ipv6_private_ula() raises:
    assert_true(parse("fc00::1").to_ipv6().value().is_private())
    assert_true(parse("fd00::1").to_ipv6().value().is_private())
    assert_false(parse("fe00::1").to_ipv6().value().is_private())


def test_ipv6_link_local() raises:
    assert_true(parse("fe80::1").to_ipv6().value().is_link_local())
    assert_false(parse("fec0::1").to_ipv6().value().is_link_local())


def test_ipv6_multicast() raises:
    assert_true(parse("ff02::1").to_ipv6().value().is_multicast())
    assert_false(parse("fe80::1").to_ipv6().value().is_multicast())


def test_ipv6_ipv4_mapped() raises:
    assert_true(parse("::ffff:10.0.0.1").to_ipv6().value().is_ipv4_mapped())
    assert_false(parse("2001:db8::1").to_ipv6().value().is_ipv4_mapped())


def test_ip_address_shared_predicates() raises:
    assert_true(parse("127.0.0.1").is_loopback())
    assert_true(parse("::1").is_loopback())
    assert_true(parse("10.0.0.1").is_private())
    assert_true(parse("fc00::1").is_private())
    assert_true(parse("224.0.0.1").is_multicast())
    assert_true(parse("ff02::1").is_multicast())
    assert_true(parse("::").is_unspecified())
    assert_true(parse("0.0.0.0").is_unspecified())
    assert_true(parse("fe80::1").is_link_local())
    assert_true(parse("169.254.1.1").is_link_local())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
