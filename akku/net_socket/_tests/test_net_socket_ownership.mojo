# Concern: unique native ownership observed independently through kernel fcntl.
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.ffi import external_call, c_int, c_uint
from akku.net_socket import Socket, SocketAddress
from akku.net_ip import AddressFamily, IpAddress, Ipv4Address, Ipv6Address
from akku.io_core import IoErrorKind


def loopback4() -> IpAddress:
    return IpAddress.from_ipv4(Ipv4Address.from_u32(0x7f000001))


def open_descriptors() -> List[Int]:
    # Independent kernel observations, never the socket implementation's fd.
    var result = List[Int]()
    for fd in range(4096):
        if external_call["fcntl", c_int, num_fixed_args=2](c_int(fd), c_int(1)) >= 0:
            result.append(fd)
    return result^


def added_descriptor(before: List[Int]) raises -> Int:
    var found = -1
    var after = open_descriptors()
    for fd in after:
        var existed = False
        for old in before:
            if old == fd:
                existed = True
        if not existed:
            assert_equal(found, -1)
            found = fd
    assert_true(found >= 0)
    return found


def fd_flags(fd: Int) -> Int:
    return Int(external_call["fcntl", c_int, num_fixed_args=2](c_int(fd), c_int(1)))


def test_creation_close_idempotence_and_native_release() raises:
    var before = open_descriptors()
    var socket = Socket(AddressFamily.IPV4)
    var fd = added_descriptor(before)
    assert_false(socket.is_closed())
    socket.close()
    assert_equal(fd_flags(fd), -1)
    assert_true(socket.is_closed())
    socket.close()
    assert_equal(fd_flags(fd), -1)


def test_invalid_family_rejected_without_descriptor() raises:
    var before = open_descriptors()
    var caught = False
    try:
        var socket = Socket(AddressFamily(255))
        socket.close()
    except e:
        caught = True
        assert_equal(e.kind, IoErrorKind.OTHER)
        assert_equal(e.op, "socket")
    assert_true(caught)
    assert_equal(open_descriptors(), before)


def test_move_preserves_single_native_owner() raises:
    var before = open_descriptors()
    var original = Socket(AddressFamily.IPV4)
    var fd = added_descriptor(before)
    var transferred = original^
    assert_true(fd_flags(fd) >= 0)
    assert_false(transferred.is_closed())
    transferred.bind(SocketAddress(loopback4(), 0))
    assert_true(transferred.local_address().port() > 0)
    transferred.close()
    assert_equal(fd_flags(fd), -1)
    assert_equal(open_descriptors(), before)


def create_then_destroy() raises -> Int:
    var before = open_descriptors()
    var socket = Socket(AddressFamily.IPV4)
    var fd = added_descriptor(before)
    assert_false(socket.is_closed())
    # Socket's last use has ended; destruction must happen by function return.
    return fd


def test_destructor_releases_native_descriptor() raises:
    var before = open_descriptors()
    var destroyed_fd = create_then_destroy()
    assert_equal(fd_flags(destroyed_fd), -1)
    assert_equal(open_descriptors(), before)


def test_closed_direct_operations_and_validation_priority() raises:
    var socket = Socket(AddressFamily.IPV4)
    socket.close()
    var empty = List[UInt8]()
    var data: List[UInt8] = [42]
    var wrong_family = SocketAddress(IpAddress.from_ipv6(Ipv6Address.from_u128(1)), 0)
    var names: List[String] = ["bind", "listen", "connect", "accept", "local_address", "read", "read", "write", "write", "shutdown_write", "flush"]
    for action in range(len(names)):
        var caught = False
        try:
            if action == 0:
                socket.bind(wrong_family)
            elif action == 1:
                socket.listen(0)
            elif action == 2:
                socket.connect(wrong_family)
            elif action == 3:
                var accepted = socket.accept()
                accepted.close()
            elif action == 4:
                var address = socket.local_address()
                print(address)
            elif action == 5:
                var read = socket.read(MutSpan(empty))
                print(read)
            elif action == 6:
                var read = socket.read(MutSpan(data))
                print(read)
            elif action == 7:
                var written = socket.write(Span(empty))
                print(written)
            elif action == 8:
                var written = socket.write(Span(data))
                print(written)
            elif action == 9:
                socket.shutdown_write()
            else:
                socket.flush()
        except e:
            caught = True
            assert_equal(e.kind, IoErrorKind.CLOSED)
            assert_equal(e.op, names[action])
        assert_true(caught)
        assert_true(socket.is_closed())
    socket.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
