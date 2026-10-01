# Concern: real OS descriptor security, SIGPIPE safety and signal interruption.
# Isolated program: the per-library runner adds a bounded outer watchdog.
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


from std.ffi import OwnedDLHandle
from std.sys.info import platform_map

comptime SIGALRM = c_int(platform_map["SIGALRM", linux=14, macos=14]())
comptime SIGPIPE = c_int(platform_map["SIGPIPE", linux=13, macos=13]())
comptime SignalPointer = Optional[OpaquePointer[MutUntrackedOrigin]]


def alarm_handler(signum: c_int) abi("C"):
    # No Mojo allocations, I/O, locks or other non-signal-safe work.
    pass


def arm_interrupt() raises:
    # POSIX signal() returns a nullable handler pointer. The erased pointer is
    # never dereferenced; code/data pointer ABI is verified for the two targets.
    var libc = OwnedDLHandle()
    var signal = libc.get_function[SignalPointer]("signal")
    _ = signal(SIGALRM, alarm_handler)
    assert_equal(external_call["siginterrupt", c_int](SIGALRM, c_int(1)), c_int(0))
    _ = external_call["alarm", c_uint](c_uint(1))


def disarm_interrupt():
    _ = external_call["alarm", c_uint](c_uint(0))


def test_cloexec_created_and_accepted() raises:
    var before = open_descriptors()
    var listener = Socket(AddressFamily.IPV4)
    var listener_fd = added_descriptor(before)
    assert_equal(fd_flags(listener_fd) & 1, 1)
    listener.bind(SocketAddress(loopback4(), 0))
    listener.listen()
    before = open_descriptors()
    var client = Socket(AddressFamily.IPV4)
    var client_fd = added_descriptor(before)
    assert_equal(fd_flags(client_fd) & 1, 1)
    client.connect(listener.local_address())
    before = open_descriptors()
    var peer = listener.accept()
    var accepted_fd = added_descriptor(before)
    assert_equal(fd_flags(accepted_fd) & 1, 1)
    listener.close()
    client.close()
    peer.close()


def test_ipv6_only_configuration() raises:
    var before = open_descriptors()
    var socket = Socket(AddressFamily.IPV6)
    var fd = added_descriptor(before)
    var value = c_int(0)
    var length = c_uint(4)
    comptime V6ONLY = c_int(platform_map["IPV6_V6ONLY", linux=26, macos=27]())
    assert_equal(external_call["getsockopt", c_int](c_int(fd), c_int(41), V6ONLY, Pointer(to=value), Pointer(to=length)), c_int(0))
    assert_equal(value, c_int(1))
    assert_false(socket.is_closed())
    socket.close()


def test_sigpipe_safe_with_default_process_signal_policy() raises:
    var listener = Socket(AddressFamily.IPV4)
    listener.bind(SocketAddress(loopback4(), 0))
    listener.listen()
    var client = Socket(AddressFamily.IPV4)
    client.connect(listener.local_address())
    var before = open_descriptors()
    var peer = listener.accept()
    var peer_fd = added_descriptor(before)
    var libc = OwnedDLHandle()
    var signal = libc.get_function[SignalPointer]("signal")
    var default_handler = SignalPointer()
    _ = signal(SIGPIPE, default_handler)
    # Independent peer's kernel shutdown induces EPIPE on later writes. Socket
    # ownership stays with peer: no private fd field is accessed or modified.
    assert_equal(external_call["shutdown", c_int](c_int(peer_fd), c_int(2)), c_int(0))
    var input = List[UInt8](length=1, fill=0)
    var eof = client.read(MutSpan(input))
    assert_true(eof.eof)
    var payload: List[UInt8] = [42]
    var raised = False
    for _ in range(8):
        var accepted: Int
        try:
            accepted = client.write(Span(payload))
        except e:
            raised = True
            assert_equal(e.kind, IoErrorKind.OTHER)
            assert_equal(e.op, "write")
            break
        assert_true(accepted > 0)
    assert_true(raised)
    assert_false(client.is_closed())
    # The accepted owner must suppress SIGPIPE too. The independently issued
    # SHUT_RDWR makes its native send fail even though public local state is open.
    var accepted_raised = False
    try:
        var count = peer.write(Span(payload))
        print(count)
    except e:
        accepted_raised = True
        assert_equal(e.kind, IoErrorKind.OTHER)
        assert_equal(e.op, "write")
    assert_true(accepted_raised)
    assert_false(peer.is_closed())
    client.close()
    peer.close()
    listener.close()


def test_native_ebadf_maps_closed_and_failed_close_invalidates() raises:
    var before = open_descriptors()
    var socket = Socket(AddressFamily.IPV4)
    var fd = added_descriptor(before)
    assert_false(socket.is_closed())
    # Independent kernel close; absolutely no descriptor allocations between
    # this close and the library calls, so a reused fd cannot be harmed.
    assert_equal(external_call["close", c_int](c_int(fd)), c_int(0))
    var buffer = List[UInt8](length=1, fill=77)
    var caught_read = False
    try:
        var result = socket.read(MutSpan(buffer))
        print(result)
    except e:
        caught_read = True
        assert_equal(e.kind, IoErrorKind.CLOSED)
        assert_equal(e.op, "read")
    assert_true(caught_read)
    var caught_close = False
    try:
        socket.close()
    except e:
        caught_close = True
        assert_equal(e.kind, IoErrorKind.CLOSED)
        assert_equal(e.op, "close")
    assert_true(caught_close)
    assert_true(socket.is_closed())
    socket.close()
    assert_equal(buffer[0], UInt8(77))


def test_native_would_block_preserves_buffer_and_owner() raises:
    var listener = Socket(AddressFamily.IPV4)
    listener.bind(SocketAddress(loopback4(), 0))
    listener.listen()
    var client = Socket(AddressFamily.IPV4)
    client.connect(listener.local_address())
    var before = open_descriptors()
    var peer = listener.accept()
    var fd = added_descriptor(before)
    # Only the fixture alters OS flags: there is no public nonblocking API.
    var flags = external_call["fcntl", c_int, num_fixed_args=2](c_int(fd), c_int(3))
    assert_true(flags >= 0)
    comptime NONBLOCK = c_int(platform_map["O_NONBLOCK", linux=2048, macos=4]())
    assert_equal(external_call["fcntl", c_int, num_fixed_args=2](c_int(fd), c_int(4), flags | NONBLOCK), c_int(0))
    var buffer = List[UInt8](length=2, fill=77)
    var caught = False
    try:
        var result = peer.read(MutSpan(buffer))
        print(result)
    except e:
        caught = True
        assert_equal(e.kind, IoErrorKind.WOULD_BLOCK)
        assert_equal(e.op, "read")
    assert_equal(external_call["fcntl", c_int, num_fixed_args=2](c_int(fd), c_int(4), flags), c_int(0))
    assert_true(caught)
    assert_equal(buffer[0], UInt8(77))
    assert_equal(buffer[1], UInt8(77))
    assert_false(peer.is_closed())
    var payload: List[UInt8] = [0, 255]
    client.write_all(Span(payload))
    peer.read_exact(MutSpan(buffer))
    assert_equal(buffer, payload)
    peer.close()
    client.close()
    listener.close()


def test_interrupted_accept_surfaces_real_eintr_and_retains_owner() raises:
    var listener = Socket(AddressFamily.IPV4)
    listener.bind(SocketAddress(loopback4(), 0))
    listener.listen()
    arm_interrupt()
    var interrupted = False
    try:
        var peer = listener.accept()
        peer.close()
    except e:
        disarm_interrupt()
        interrupted = True
        assert_equal(e.kind, IoErrorKind.INTERRUPTED)
        assert_equal(e.op, "accept")
    disarm_interrupt()
    assert_true(interrupted)
    assert_false(listener.is_closed())
    var client = Socket(AddressFamily.IPV4)
    client.connect(listener.local_address())
    var accepted = listener.accept()
    accepted.close()
    client.close()
    listener.close()


def test_interrupted_read_preserves_buffer_and_connection() raises:
    var listener = Socket(AddressFamily.IPV4)
    listener.bind(SocketAddress(loopback4(), 0))
    listener.listen()
    var client = Socket(AddressFamily.IPV4)
    client.connect(listener.local_address())
    var peer = listener.accept()
    var destination = List[UInt8](length=2, fill=77)
    arm_interrupt()
    var interrupted = False
    try:
        var result = peer.read(MutSpan(destination))
        print(result)
    except e:
        disarm_interrupt()
        interrupted = True
        assert_equal(e.kind, IoErrorKind.INTERRUPTED)
        assert_equal(e.op, "read")
    disarm_interrupt()
    assert_true(interrupted)
    assert_equal(destination[0], UInt8(77))
    assert_equal(destination[1], UInt8(77))
    assert_false(peer.is_closed())
    var payload: List[UInt8] = [0, 255]
    client.write_all(Span(payload))
    peer.read_exact(MutSpan(destination))
    assert_equal(destination, payload)
    peer.close()
    client.close()
    listener.close()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
