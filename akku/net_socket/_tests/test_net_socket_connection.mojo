# Concern: real loopback connections, kernel-assigned endpoints, validation.
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.net_socket import Socket, SocketAddress
from akku.net_ip import AddressFamily, IpAddress, Ipv4Address, Ipv6Address
from akku.io_core import IoErrorKind


def loopback4() -> IpAddress:
    return IpAddress.from_ipv4(Ipv4Address.from_u32(0x7f000001))


def loopback6() -> IpAddress:
    return IpAddress.from_ipv6(Ipv6Address.from_u128(1))


def exercise_loopback(family: AddressFamily, ip: IpAddress) raises:
    var listener = Socket(family)
    listener.bind(SocketAddress(ip, 0))
    var endpoint = listener.local_address()
    assert_equal(endpoint.address(), ip)
    assert_equal(endpoint.address().family(), family)
    assert_true(endpoint.port() > 0)
    assert_equal(endpoint.scope_id(), UInt32(0))
    listener.listen()
    var client = Socket(family)
    client.connect(endpoint)
    var accepted = listener.accept()
    assert_equal(accepted.local_address(), endpoint)
    assert_equal(client.local_address().address().family(), family)
    assert_true(client.local_address().port() > 0)
    listener.close()
    var payload: List[UInt8] = [0, 127, 255]
    client.write_all(Span(payload))
    client.shutdown_write()
    assert_equal(accepted.read_to_end(), payload)
    accepted.close()
    client.close()


def test_loopback_ipv4_local_address_and_accepted_independence() raises:
    exercise_loopback(AddressFamily.IPV4, loopback4())


def test_loopback_ipv6_local_address_and_accepted_independence() raises:
    exercise_loopback(AddressFamily.IPV6, loopback6())


def test_wildcard_dynamic_bind() raises:
    var listener = Socket(AddressFamily.IPV4)
    var any_ip = IpAddress.from_ipv4(Ipv4Address.from_u32(0))
    listener.bind(SocketAddress(any_ip, 0))
    var endpoint = listener.local_address()
    assert_equal(endpoint.address(), any_ip)
    assert_true(endpoint.port() > 0)
    listener.close()


def test_family_mismatch_retains_owner() raises:
    var socket = Socket(AddressFamily.IPV4)
    var wrong = SocketAddress(loopback6(), 1)
    for action in range(2):
        var caught = False
        try:
            if action == 0:
                socket.bind(wrong)
            else:
                socket.connect(wrong)
        except e:
            caught = True
            assert_equal(e.kind, IoErrorKind.OTHER)
            if action == 0:
                assert_equal(e.op, "bind")
            else:
                assert_equal(e.op, "connect")
        assert_true(caught)
        assert_false(socket.is_closed())
    socket.bind(SocketAddress(loopback4(), 0))
    assert_true(socket.local_address().port() > 0)
    socket.close()


def test_listen_invalid_backlog_retains_owner() raises:
    var socket = Socket(AddressFamily.IPV4)
    for backlog in [-1, 0]:
        var caught = False
        try:
            socket.listen(backlog)
        except e:
            caught = True
            assert_equal(e.kind, IoErrorKind.OTHER)
            assert_equal(e.op, "listen")
        assert_true(caught)
        assert_false(socket.is_closed())
    socket.bind(SocketAddress(loopback4(), 0))
    socket.listen(1)
    # Positive Mojo Int values remain valid even beyond the native C int width.
    socket.listen(1 << 40)
    socket.close()


def test_native_connect_error_closes() raises:
    # TCP destination port zero cannot name a listener. Linux refuses it and
    # Darwin rejects the destination; both are immediate native OTHER failures.
    # A bound non-listening TCP port can instead stall until timeout on Darwin.
    var target = SocketAddress(loopback4(), 0)
    var client = Socket(AddressFamily.IPV4)
    var caught = False
    try:
        client.connect(target)
    except e:
        caught = True
        assert_equal(e.kind, IoErrorKind.OTHER)
        assert_equal(e.op, "connect")
    assert_true(caught)
    assert_true(client.is_closed())
    client.close()


def test_native_bind_error_retains_owner() raises:
    var first = Socket(AddressFamily.IPV4)
    first.bind(SocketAddress(loopback4(), 0))
    var second = Socket(AddressFamily.IPV4)
    var caught = False
    try:
        second.bind(first.local_address())
    except e:
        caught = True
        assert_equal(e.kind, IoErrorKind.OTHER)
        assert_equal(e.op, "bind")
    assert_true(caught)
    assert_false(second.is_closed())
    second.close()
    first.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
