# Concern: borrowed byte transfers, real EOF, provided io_core helpers.
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.net_socket import Socket, SocketAddress
from akku.net_ip import AddressFamily, IpAddress, Ipv4Address, Ipv6Address
from akku.io_core import IoErrorKind


def loopback4() -> IpAddress:
    return IpAddress.from_ipv4(Ipv4Address.from_u32(0x7f000001))


def loopback6() -> IpAddress:
    return IpAddress.from_ipv6(Ipv6Address.from_u128(1))


def test_binary_short_read_and_untouched_suffix() raises:
    var listener = Socket(AddressFamily.IPV4)
    listener.bind(SocketAddress(loopback4(), 0))
    listener.listen()
    var client = Socket(AddressFamily.IPV4)
    client.connect(listener.local_address())
    var peer = listener.accept()
    var payload: List[UInt8] = [0, 128, 255]
    client.write_all(Span(payload))
    payload[0] = 99
    var destination = List[UInt8](length=12, fill=77)
    var result = peer.read(MutSpan(destination)[2:10])
    assert_true(result.count > 0)
    assert_true(result.count <= 3)
    assert_false(result.eof)
    var expected: List[UInt8] = [0, 128, 255]
    for i in range(result.count):
        assert_equal(destination[2 + i], expected[i])
    assert_equal(destination[0], UInt8(77))
    assert_equal(destination[1], UInt8(77))
    for i in range(2 + result.count, len(destination)):
        assert_equal(destination[i], UInt8(77))
    # Complete the consumed prefix without assuming TCP read packet boundaries.
    if result.count < 3:
        peer.read_exact(MutSpan(destination)[2 + result.count:5])
    for i in range(3):
        assert_equal(destination[2 + i], expected[i])
    assert_equal(len(destination), 12)
    client.close()
    peer.close()
    listener.close()


def test_write_returned_prefix_and_borrowed_subspan() raises:
    var listener = Socket(AddressFamily.IPV4)
    listener.bind(SocketAddress(loopback4(), 0))
    listener.listen()
    var client = Socket(AddressFamily.IPV4)
    client.connect(listener.local_address())
    var peer = listener.accept()
    var source: List[UInt8] = [99, 1, 2, 3, 4, 88]
    var count = client.write(Span(source)[1:5])
    assert_true(count > 0)
    assert_true(count <= 4)
    var received = List[UInt8](length=count, fill=0)
    peer.read_exact(MutSpan(received))
    for i in range(count):
        assert_equal(received[i], source[i + 1])
    assert_equal(len(source), 6)
    assert_equal(source[0], UInt8(99))
    assert_equal(source[5], UInt8(88))
    client.close()
    peer.close()
    listener.close()


def test_empty_direct_transfers_and_flush() raises:
    var socket = Socket(AddressFamily.IPV4)
    var empty = List[UInt8]()
    assert_equal(socket.write(Span(empty)), 0)
    socket.flush()
    var caught = False
    try:
        var result = socket.read(MutSpan(empty))
        print(result)
    except e:
        caught = True
        assert_equal(e.kind, IoErrorKind.OTHER)
        assert_equal(e.op, "read")
    assert_true(caught)
    assert_false(socket.is_closed())
    socket.close()


def test_write_all_read_exact_and_repeatable_eof() raises:
    var listener = Socket(AddressFamily.IPV4)
    listener.bind(SocketAddress(loopback4(), 0))
    listener.listen()
    var client = Socket(AddressFamily.IPV4)
    client.connect(listener.local_address())
    var peer = listener.accept()
    var payload: List[UInt8] = [0, 1, 2, 128, 255]
    client.write_all(Span(payload))
    client.shutdown_write()
    var destination = List[UInt8](length=5, fill=0)
    peer.read_exact(MutSpan(destination))
    assert_equal(destination, payload)
    for _ in range(2):
        var eof = peer.read(MutSpan(destination))
        assert_equal(eof.count, 0)
        assert_true(eof.eof)
        assert_equal(destination, payload)
    assert_false(peer.is_closed())
    client.close()
    peer.close()
    listener.close()


def test_read_exact_unexpected_eof_preserves_prefix() raises:
    var listener = Socket(AddressFamily.IPV4)
    listener.bind(SocketAddress(loopback4(), 0))
    listener.listen()
    var client = Socket(AddressFamily.IPV4)
    client.connect(listener.local_address())
    var peer = listener.accept()
    var payload: List[UInt8] = [42, 255]
    client.write_all(Span(payload))
    client.shutdown_write()
    var destination = List[UInt8](length=4, fill=77)
    var caught = False
    try:
        peer.read_exact(MutSpan(destination))
    except e:
        caught = True
        assert_equal(e.kind, IoErrorKind.UNEXPECTED_EOF)
        assert_equal(e.op, "read")
    assert_true(caught)
    assert_equal(destination[0], UInt8(42))
    assert_equal(destination[1], UInt8(255))
    assert_equal(destination[2], UInt8(77))
    assert_equal(destination[3], UInt8(77))
    client.close()
    peer.close()
    listener.close()


def test_read_to_end_owned_binary_result() raises:
    var listener = Socket(AddressFamily.IPV4)
    listener.bind(SocketAddress(loopback4(), 0))
    listener.listen()
    var client = Socket(AddressFamily.IPV4)
    client.connect(listener.local_address())
    var peer = listener.accept()
    var payload: List[UInt8] = [0, 255, 195, 169]
    client.write_all(Span(payload))
    client.shutdown_write()
    var result = peer.read_to_end()
    peer.close()
    assert_equal(result, payload)
    payload[0] = 77
    assert_equal(result[0], UInt8(0))
    client.close()
    listener.close()


def test_empty_helpers_keep_existing_contract_on_closed_owner() raises:
    var socket = Socket(AddressFamily.IPV4)
    socket.close()
    var empty = List[UInt8]()
    socket.read_exact(MutSpan(empty))
    socket.write_all(Span(empty))
    assert_true(socket.is_closed())


def test_write_shutdown_idempotence_eof_and_response_read() raises:
    var listener = Socket(AddressFamily.IPV4)
    listener.bind(SocketAddress(loopback4(), 0))
    listener.listen()
    var client = Socket(AddressFamily.IPV4)
    client.connect(listener.local_address())
    var peer = listener.accept()
    client.shutdown_write()
    client.shutdown_write()
    client.flush()
    var buffer = List[UInt8](length=1, fill=77)
    var eof = peer.read(MutSpan(buffer))
    assert_true(eof.eof)
    assert_equal(eof.count, 0)
    var reply: List[UInt8] = [250]
    peer.write_all(Span(reply))
    client.read_exact(MutSpan(buffer))
    assert_equal(buffer[0], UInt8(250))
    var empty = List[UInt8]()
    for nonempty in range(2):
        var caught = False
        try:
            if nonempty == 0:
                var ignored = client.write(Span(empty))
                print(ignored)
            else:
                var ignored = client.write(Span(reply))
                print(ignored)
        except e:
            caught = True
            assert_equal(e.kind, IoErrorKind.CLOSED)
            assert_equal(e.op, "write")
        assert_true(caught)
    assert_false(client.is_closed())
    client.close()
    peer.close()
    listener.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
