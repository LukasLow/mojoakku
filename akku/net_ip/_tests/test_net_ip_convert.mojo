# Concern: construction and conversion on all three value types (docs blocks in
# `../ipv4_address.mojo`, `../ipv6_address.mojo`, `../ip_address.mojo`).
#
# Covers: every from_*/to_* round trip; the byte and segment views; wrong-length
# slices raise; family queries; to_ipv4/to_ipv6 presence and absence.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.net_ip import (
    parse,
    Ipv4Address,
    Ipv6Address,
    IpAddress,
    IpParseErrorKind,
)


def test_ipv4_from_octets_and_u32() raises:
    var a = Ipv4Address.from_octets(192, 168, 1, 1)
    assert_equal(a.to_u32(), UInt32(0xC0A80101))
    assert_equal(Ipv4Address.from_u32(UInt32(0xC0A80101)), a)


def test_ipv4_octets() raises:
    var a = Ipv4Address.from_octets(1, 2, 3, 4)
    var o = a.octets()
    assert_equal(o[0], UInt8(1))
    assert_equal(o[1], UInt8(2))
    assert_equal(o[2], UInt8(3))
    assert_equal(o[3], UInt8(4))


def test_ipv4_from_bytes() raises:
    var bytes: List[UInt8] = [10, 0, 0, 1]
    var a = Ipv4Address.from_bytes(Span(bytes))
    assert_equal(a.to_u32(), UInt32(0x0A000001))


def test_ipv4_from_bytes_wrong_length_raises() raises:
    var caught = False
    try:
        var bytes: List[UInt8] = [1, 2, 3]
        _ = Ipv4Address.from_bytes(Span(bytes))
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.TOO_FEW_GROUPS)
    assert_true(caught)


def test_ipv6_from_segments_and_u128() raises:
    var a = Ipv6Address.from_segments(0x2001, 0x0db8, 0, 0, 0, 0, 0, 1)
    assert_equal(a.to_u128(), UInt128(0x20010db8000000000000000000000001))
    assert_equal(Ipv6Address.from_u128(UInt128(0x20010db8000000000000000000000001)), a)


def test_ipv6_segments_view() raises:
    var a = Ipv6Address.from_segments(1, 2, 3, 4, 5, 6, 7, 8)
    var s = a.segments()
    assert_equal(s[0], UInt16(1))
    assert_equal(s[7], UInt16(8))


def test_ipv6_octets_view() raises:
    var a = Ipv6Address.from_segments(0x2001, 0x0db8, 0, 0, 0, 0, 0, 1)
    var o = a.octets()
    assert_equal(o[0], UInt8(0x20))
    assert_equal(o[1], UInt8(0x01))
    assert_equal(o[15], UInt8(1))


def test_ipv6_from_bytes() raises:
    var bytes = List[UInt8]()
    for _ in range(16):
        bytes.append(UInt8(0))
    bytes[0] = UInt8(0x20)
    bytes[1] = UInt8(0x01)
    var a = Ipv6Address.from_bytes(Span(bytes))
    assert_equal(a.to_u128(), UInt128(0x20010000000000000000000000000000))


def test_ipv6_from_bytes_wrong_length_raises() raises:
    var caught = False
    try:
        var bytes = List[UInt8]()
        for _ in range(4):
            bytes.append(UInt8(0))
        _ = Ipv6Address.from_bytes(Span(bytes))
    except e:
        caught = True
        assert_equal(e.kind, IpParseErrorKind.TOO_FEW_GROUPS)
    assert_true(caught)


def test_ip_address_to_concrete() raises:
    var v4 = IpAddress.from_ipv4(Ipv4Address.from_u32(7))
    assert_true(v4.to_ipv4())
    assert_false(v4.to_ipv6())
    var v6 = IpAddress.from_ipv6(Ipv6Address.from_u128(7))
    assert_true(v6.to_ipv6())
    assert_false(v6.to_ipv4())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
