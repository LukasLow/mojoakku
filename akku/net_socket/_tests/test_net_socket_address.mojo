# Concern: independent numeric endpoint values and scope invariants.
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.net_socket import Socket, SocketAddress
from akku.net_ip import AddressFamily, IpAddress, Ipv4Address, Ipv6Address
from akku.io_core import IoErrorKind


def loopback4() -> IpAddress:
    return IpAddress.from_ipv4(Ipv4Address.from_u32(0x7f000001))


def loopback6() -> IpAddress:
    return IpAddress.from_ipv6(Ipv6Address.from_u128(1))


def test_address_ipv4_values() raises:
    var ip = loopback4()
    var endpoint = SocketAddress(ip, 80)
    ip = IpAddress.from_ipv4(Ipv4Address.from_u32(0))
    assert_equal(endpoint.address(), loopback4())
    assert_equal(endpoint.port(), UInt16(80))
    assert_equal(endpoint.scope_id(), UInt32(0))
    assert_equal(String(endpoint), "127.0.0.1:80")
    var copy = endpoint.copy()
    assert_equal(copy, endpoint)
    var extracted = endpoint.address()
    endpoint = SocketAddress(ip, 0)
    assert_equal(extracted, loopback4())
    assert_equal(copy.port(), UInt16(80))
    assert_equal(endpoint.port(), UInt16(0))
    assert_equal(SocketAddress(loopback4(), 65535).port(), UInt16(65535))
    assert_false(copy == endpoint)


def test_address_ipv6_values() raises:
    var simple = SocketAddress(loopback6(), 80)
    assert_equal(simple.address(), loopback6())
    assert_equal(simple.scope_id(), UInt32(0))
    assert_equal(String(simple), "[::1]:80")
    var link = IpAddress.from_ipv6(Ipv6Address.from_segments(0xfe80, 0, 0, 0, 0, 0, 0, 1))
    var scoped = SocketAddress(link, 443, 3)
    assert_equal(scoped.scope_id(), UInt32(3))
    assert_equal(String(scoped), "[fe80::1%3]:443")
    assert_false(scoped == SocketAddress(link, 443, 4))
    assert_false(scoped == SocketAddress(link, 444, 3))
    assert_equal(scoped, scoped.copy())


def test_address_ipv4_scope_rejected() raises:
    var caught = False
    try:
        var invalid = SocketAddress(loopback4(), 80, 1)
        print(invalid)
    except e:
        caught = True
        assert_equal(e.kind, IoErrorKind.OTHER)
        assert_equal(e.op, "address")
    assert_true(caught)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
