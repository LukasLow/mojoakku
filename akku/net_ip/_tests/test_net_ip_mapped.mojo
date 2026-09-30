# Concern: IPv4-mapped handling — `is_ipv4_mapped`, `to_ipv4_mapped`,
# `to_ipv4` and `IpAddress.unmap` (docs blocks in `../ipv6_address.mojo`,
# `../ip_address.mojo`).
#
# Covers: the mapped form converts; a non-mapped address yields None; unmap is
# a no-op on a plain IPv4 address; nothing converts implicitly.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.net_ip import parse, Ipv6Address, Ipv4Address


def test_to_ipv4_mapped_present() raises:
    var a = parse("::ffff:127.0.0.1").to_ipv6().value().copy()
    assert_true(a.is_ipv4_mapped())
    var v4 = a.to_ipv4_mapped()
    assert_true(v4)
    assert_equal(v4.value().to_u32(), UInt32(0x7F000001))
    assert_equal(String(v4.value()), "127.0.0.1")


def test_to_ipv4_mapped_absent() raises:
    var a = parse("2001:db8::1").to_ipv6().value().copy()
    assert_false(a.is_ipv4_mapped())
    assert_false(a.to_ipv4_mapped())
    assert_false(a.to_ipv4())


def test_to_ipv4_accepts_compatible_form() raises:
    # The deprecated IPv4-compatible form ::a.b.c.d still converts via to_ipv4.
    var a = Ipv6Address.from_segments(0, 0, 0, 0, 0, 0, 0x0102, 0x0304)
    assert_true(a.to_ipv4())
    assert_equal(String(a.to_ipv4().value()), "1.2.3.4")


def test_unmap_mapped() raises:
    var a = parse("::ffff:10.0.0.1")
    var u = a.unmap()
    assert_true(u.is_ipv4())
    assert_equal(String(u), "10.0.0.1")


def test_unmap_plain_ipv4_is_noop() raises:
    var a = parse("10.0.0.1")
    var u = a.unmap()
    assert_true(u.is_ipv4())
    assert_equal(String(u), "10.0.0.1")


def test_unmap_plain_ipv6_is_noop() raises:
    var a = parse("2001:db8::1")
    var u = a.unmap()
    assert_true(u.is_ipv6())
    assert_equal(String(u), "2001:db8::1")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
