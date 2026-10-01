from std.sys import CompilationTarget as _Target
from std.ffi import (
    external_call as _call, c_int as _c_int, c_uint as _c_uint,
    c_size_t as _c_size_t, c_ssize_t as _c_ssize_t,
)
from akku.time_clock import Deadline as _Deadline, Duration as _Duration
from akku.os_poll import PollEvents as _PollEvents
from akku.net_ip import (
    AddressFamily as _AddressFamily, IpAddress as _IpAddress,
    Ipv4Address as _Ipv4Address, Ipv6Address as _Ipv6Address,
)
from akku.io_core import (
    Reader as _Reader, ByteWriter as _ByteWriter,
    ReadResult as _ReadResult, IoError as _IoError, IoErrorKind as _IoErrorKind,
)
from .socket_address import SocketAddress as _SocketAddress
from ._internal.native import (
    errno_value as _errno, map_error as _map_error, await_ready as _await_ready,
    AF_INET, AF_INET6, SOCK_STREAM, IPPROTO_TCP, IPPROTO_IPV6, IPV6_V6ONLY,
    SOL_SOCKET, SO_NOSIGPIPE, SO_ERROR, MSG_NOSIGNAL, SHUT_WR,
    O_NONBLOCK, SOCK_NONBLOCK, SOCK_CLOEXEC, F_GETFD, F_SETFD, FD_CLOEXEC,
    F_GETFL, F_SETFL, EAGAIN, EINTR, EINPROGRESS,
)

# MissingMojo - v1.1.0 - Start
# kind: FFI
# need: stable native Mojo owned POSIX sockets and numeric endpoint operations
# optimal: replace the private libc boundary with stable native Mojo socket APIs
# track: https://mojolang.org/docs/std/
# MissingMojo - End
# Private FFI safety invariants; measured layouts are recorded in _dev/ABI.md.
# Address storage is 128 bytes, UInt32-aligned (4 bytes), sufficient for the
# 16/28-byte sockaddr structs used here. Fixed address offsets are below 28;
# decoding validates the returned family and required length before address reads.
# Spans, options and socklen pointers remain valid for each synchronous libc call;
# libc does not retain them. recv/send use exactly the borrowed span's byte length.
# errno is read immediately after failure and is never retained. Every descriptor
# is non-blocking from creation, so no native call can block the thread; the only
# blocking is the bounded wait inside _await_ready, driven by os_poll.
# Each adopted descriptor already passed configuration and has exactly one owner.


def _configure_handle(fd: _c_int, op: String) raises _IoError:
    # Linux flags are atomic at socket/accept4; Darwin supplies the other policy.
    comptime if _Target.is_macos():
        var flags = _call["fcntl", _c_int, num_fixed_args=2](fd, _c_int(1))
        if flags < 0:
            raise _map_error(_errno(), op)
        if _call["fcntl", _c_int, num_fixed_args=2](fd, _c_int(2), flags | _c_int(1)) < 0:
            raise _map_error(_errno(), op)
        var enabled = _c_int(1)
        if _call["setsockopt", _c_int](fd, _c_int(65535), _c_int(4130), Pointer(to=enabled).unsafe_bitcast[NoneType](), _c_uint(4)) < 0:
            raise _map_error(_errno(), op)


def _set_nonblocking(fd: _c_int, op: String) raises _IoError:
    # Linux already passed SOCK_NONBLOCK at creation; macOS sets it via fcntl.
    comptime if _Target.is_macos():
        var flags = _call["fcntl", _c_int, num_fixed_args=2](fd, _c_int(F_GETFL))
        if flags < 0:
            raise _map_error(_errno(), op)
        if _call["fcntl", _c_int, num_fixed_args=2](fd, _c_int(F_SETFL), flags | _c_int(O_NONBLOCK)) < 0:
            raise _map_error(_errno(), op)


def _pack(address: _SocketAddress) -> Array[UInt32, 32]:
    var storage = Array[UInt32, 32](fill=0)
    var bytes = storage.unsafe_ptr().unsafe_bitcast[UInt8]()
    var ip = address.address()
    var size = 16 if ip.is_ipv4() else 28
    var family = _c_int(AF_INET) if ip.is_ipv4() else _c_int(AF_INET6)
    comptime if _Target.is_macos():
        bytes[unsafe_offset=0] = UInt8(size)
        bytes[unsafe_offset=1] = UInt8(family)
    else:
        storage.unsafe_ptr().unsafe_bitcast[UInt16]()[] = UInt16(family)
    bytes[unsafe_offset=2] = UInt8(address.port() >> 8)
    bytes[unsafe_offset=3] = UInt8(address.port() & 255)
    if ip.is_ipv4():
        var octets = ip.to_ipv4().value().octets()
        for i in range(4):
            bytes[unsafe_offset=4+i] = octets[i]
    else:
        var octets = ip.to_ipv6().value().octets()
        for i in range(16):
            bytes[unsafe_offset=8+i] = octets[i]
        storage[6] = address.scope_id()
    return storage^


def _unpack(storage: Array[UInt32, 32], length: _c_uint) raises _IoError -> _SocketAddress:
    if length < 2 or length > 128:
        raise _IoError(_IoErrorKind.OTHER, "local_address", "invalid native address length")
    var bytes = storage.unsafe_ptr().unsafe_bitcast[UInt8]()
    var family: _c_int
    comptime if _Target.is_macos():
        family = _c_int(bytes[unsafe_offset=1])
    else:
        family = _c_int(storage.unsafe_ptr().unsafe_bitcast[UInt16]()[])
    var port = (UInt16(bytes[unsafe_offset=2]) << 8) | UInt16(bytes[unsafe_offset=3])
    if family == _c_int(AF_INET) and length >= 16:
        var ip = _Ipv4Address.from_octets(bytes[unsafe_offset=4], bytes[unsafe_offset=5], bytes[unsafe_offset=6], bytes[unsafe_offset=7])
        return _SocketAddress(_IpAddress.from_ipv4(ip), port)
    if family == _c_int(AF_INET6) and length >= 28:
        var value = UInt128(0)
        for i in range(16):
            value = (value << 8) | UInt128(bytes[unsafe_offset=8+i])
        return _SocketAddress(_IpAddress.from_ipv6(_Ipv6Address.from_u128(value)), port, storage[6])
    raise _IoError(_IoErrorKind.OTHER, "local_address", "unsupported native address family or length")


def _create_fd(family: _AddressFamily) raises _IoError -> _c_int:
    var domain = _c_int(AF_INET) if family == _AddressFamily.IPV4 else _c_int(AF_INET6)
    var flags = _c_int(1)  # SOCK_STREAM
    comptime if _Target.is_linux():
        flags |= _c_int(SOCK_CLOEXEC) | _c_int(SOCK_NONBLOCK)
    var fd = _call["socket", _c_int](domain, flags, _c_int(0))
    if fd < 0:
        raise _map_error(_errno(), "socket")
    try:
        _configure_handle(fd, "socket")
        _set_nonblocking(fd, "socket")
        if family == _AddressFamily.IPV6:
            var enabled = _c_int(1)
            if _call["setsockopt", _c_int](fd, _c_int(IPPROTO_IPV6), _c_int(IPV6_V6ONLY), Pointer(to=enabled).unsafe_bitcast[NoneType](), _c_uint(4)) < 0:
                raise _map_error(_errno(), "socket")
    except error:
        _ = _call["close", _c_int](fd)
        raise error^
    return fd


struct Socket(Movable, Deinitable, _Reader, _ByteWriter):
    var _fd: _c_int
    var _family: _AddressFamily
    var _write_shutdown: Bool
    var _read_deadline: Optional[_Deadline]
    var _write_deadline: Optional[_Deadline]

    def __init__(out self, family: _AddressFamily) raises _IoError:
        self._fd = -1
        self._family = family
        self._write_shutdown = False
        self._read_deadline = None
        self._write_deadline = None
        if family != _AddressFamily.IPV4 and family != _AddressFamily.IPV6:
            raise _IoError(_IoErrorKind.OTHER, "socket", "invalid address family")
        comptime if not _Target.is_linux() and not _Target.is_macos():
            raise _IoError(_IoErrorKind.OTHER, "socket", "unsupported target")
        self._fd = _create_fd(family)

    @doc_hidden
    def __init__(out self, *, _accepted_fd: _c_int, _family: _AddressFamily):
        self._fd = _accepted_fd
        self._family = _family
        self._write_shutdown = False
        self._read_deadline = None
        self._write_deadline = None

    def __init__(out self, *, deinit move: Self):
        self._fd = move._fd
        self._family = move._family
        self._write_shutdown = move._write_shutdown
        self._read_deadline = move._read_deadline
        self._write_deadline = move._write_deadline

    def __deinit__(deinit self):
        if self._fd >= 0:
            _ = _call["close", _c_int](self._fd)

    def _check_open(self, op: String) raises _IoError:
        if self._fd < 0:
            raise _IoError(_IoErrorKind.CLOSED, op, "socket is closed")

    def _check_family(self, address: _SocketAddress, op: String) raises _IoError:
        if address.address().family() != self._family:
            raise _IoError(_IoErrorKind.OTHER, op, "address family mismatch")

    # --- deadlines ---------------------------------------------------------

    def set_read_deadline(mut self, deadline: _Deadline):
        self._read_deadline = deadline

    def set_write_deadline(mut self, deadline: _Deadline):
        self._write_deadline = deadline

    def set_deadline(mut self, deadline: _Deadline):
        self._read_deadline = deadline
        self._write_deadline = deadline

    def clear_deadline(mut self):
        self._read_deadline = None
        self._write_deadline = None

    def has_read_deadline(self) -> Bool:
        return self._read_deadline is not None

    def has_write_deadline(self) -> Bool:
        return self._write_deadline is not None

    # --- bounded waits -----------------------------------------------------

    def _wait(
        mut self, events: _PollEvents, deadline: Optional[_Deadline], op: String
    ) raises _IoError:
        _await_ready(Int(self._fd), events, deadline, op)

    # --- server side -------------------------------------------------------

    def bind(mut self, address: _SocketAddress) raises _IoError:
        self._check_open("bind")
        self._check_family(address, "bind")
        var storage = _pack(address)
        var length = _c_uint(16 if self._family == _AddressFamily.IPV4 else 28)
        if _call["bind", _c_int](self._fd, storage.unsafe_ptr().unsafe_bitcast[NoneType](), length) < 0:
            raise _map_error(_errno(), "bind")

    def listen(mut self, backlog: Int = 128) raises _IoError:
        self._check_open("listen")
        if backlog <= 0:
            raise _IoError(_IoErrorKind.OTHER, "listen", "backlog must be positive")
        var capped = min(backlog, 2147483647)
        if _call["listen", _c_int](self._fd, _c_int(capped)) < 0:
            raise _map_error(_errno(), "listen")

    def connect(mut self, address: _SocketAddress) raises _IoError:
        self._check_open("connect")
        self._check_family(address, "connect")
        var storage = _pack(address)
        var length = _c_uint(16 if self._family == _AddressFamily.IPV4 else 28)
        # Non-blocking connect: EINPROGRESS means "in flight", then wait.
        if _call["connect", _c_int](self._fd, storage.unsafe_ptr().unsafe_bitcast[NoneType](), length) == 0:
            return
        var code = _errno()
        if code == EINPROGRESS:
            var write_deadline = self._write_deadline
            try:
                self._wait(_PollEvents.WRITE, write_deadline, "connect")
            except error:
                self._invalidate()
                raise error^
            # Readiness only means the attempt finished; SO_ERROR carries the result.
            var result = _c_int(0)
            var result_length = _c_uint(4)
            if _call["getsockopt", _c_int](self._fd, _c_int(SOL_SOCKET), _c_int(SO_ERROR), Pointer(to=result).unsafe_bitcast[NoneType](), Pointer(to=result_length)) < 0:
                var code2 = _errno()
                self._invalidate()
                raise _map_error(code2, "connect")
            if result != 0:
                var connect_error = _map_error(Int(result), "connect")
                self._invalidate()
                raise connect_error^
            return
        self._invalidate()
        raise _map_error(code, "connect")

    def accept(mut self) raises _IoError -> Socket:
        self._check_open("accept")
        while True:
            var storage = Array[UInt32, 32](fill=0)
            var length = _c_uint(128)
            var fd: _c_int
            comptime if _Target.is_linux():
                fd = _call["accept4", _c_int](self._fd, storage.unsafe_ptr().unsafe_bitcast[NoneType](), Pointer(to=length), _c_int(SOCK_CLOEXEC | SOCK_NONBLOCK))
            else:
                fd = _call["accept", _c_int](self._fd, storage.unsafe_ptr().unsafe_bitcast[NoneType](), Pointer(to=length))
            if fd < 0:
                var code = _errno()
                if code == EAGAIN or code == EINTR:
                    var read_deadline = self._read_deadline
                    self._wait(_PollEvents.READ, read_deadline, "accept")
                    continue
                raise _map_error(code, "accept")
            try:
                _configure_handle(fd, "accept")
                _set_nonblocking(fd, "accept")
            except error:
                _ = _call["close", _c_int](fd)
                raise error^
            return Socket(_accepted_fd=fd, _family=self._family)

    def local_address(mut self) raises _IoError -> _SocketAddress:
        self._check_open("local_address")
        var storage = Array[UInt32, 32](fill=0)
        var length = _c_uint(128)
        if _call["getsockname", _c_int](self._fd, storage.unsafe_ptr().unsafe_bitcast[NoneType](), Pointer(to=length)) < 0:
            raise _map_error(_errno(), "local_address")
        return _unpack(storage, length)

    # --- transfers ---------------------------------------------------------

    def read(mut self, buf: MutSpan[UInt8, _]) raises _IoError -> _ReadResult:
        self._check_open("read")
        if len(buf) == 0:
            raise _IoError(_IoErrorKind.OTHER, "read", "empty destination")
        var read_deadline = self._read_deadline
        while True:
            var count = _call["recv", _c_ssize_t](self._fd, buf.unsafe_ptr().unsafe_bitcast[NoneType](), _c_size_t(len(buf)), _c_int(0))
            if count >= 0:
                return _ReadResult(Int(count), count == 0)
            var code = _errno()
            if code == EAGAIN or code == EINTR:
                self._wait(_PollEvents.READ, read_deadline, "read")
                continue
            raise _map_error(code, "read")

    def write(mut self, data: Span[UInt8, _]) raises _IoError -> Int:
        self._check_open("write")
        if self._write_shutdown:
            raise _IoError(_IoErrorKind.CLOSED, "write", "socket writes are shut down")
        if len(data) == 0:
            return 0
        var flags = _c_int(MSG_NOSIGNAL) if _Target.is_linux() else _c_int(0)
        var write_deadline = self._write_deadline
        while True:
            var count = _call["send", _c_ssize_t](self._fd, data.unsafe_ptr().unsafe_bitcast[NoneType](), _c_size_t(len(data)), flags)
            if count > 0:
                return Int(count)
            if count == 0:
                raise _IoError(_IoErrorKind.OTHER, "write", "write made no progress")
            var code = _errno()
            if code == EAGAIN or code == EINTR:
                self._wait(_PollEvents.WRITE, write_deadline, "write")
                continue
            raise _map_error(code, "write")

    def shutdown_write(mut self) raises _IoError:
        self._check_open("shutdown_write")
        if self._write_shutdown:
            return
        if _call["shutdown", _c_int](self._fd, _c_int(SHUT_WR)) < 0:
            raise _map_error(_errno(), "shutdown_write")
        self._write_shutdown = True

    def close(mut self) raises _IoError:
        if self._fd < 0:
            return
        var fd = self._fd
        self._fd = -1
        if _call["close", _c_int](fd) < 0:
            raise _map_error(_errno(), "close")

    def is_closed(self) -> Bool:
        return self._fd < 0

    def flush(mut self) raises _IoError:
        self._check_open("flush")

    def _invalidate(mut self):
        if self._fd >= 0:
            _ = _call["close", _c_int](self._fd)
            self._fd = -1

# API-DOCS-START
# Socket — one owner of a POSIX byte-stream socket with bounded waits.
# Signature:
#   struct Socket(Movable, Deinitable, Reader, ByteWriter):
#       def __init__(out self, family: AddressFamily) raises IoError
#       def __init__(out self, *, deinit move: Self)
#       def __deinit__(deinit self)
#       def set_read_deadline(mut self, deadline: Deadline)
#       def set_write_deadline(mut self, deadline: Deadline)
#       def set_deadline(mut self, deadline: Deadline)
#       def clear_deadline(mut self)
#       def has_read_deadline(self) -> Bool
#       def has_write_deadline(self) -> Bool
#       def bind(mut self, address: SocketAddress) raises IoError
#       def listen(mut self, backlog: Int = 128) raises IoError
#       def connect(mut self, address: SocketAddress) raises IoError
#       def accept(mut self) raises IoError -> Socket
#       def local_address(mut self) raises IoError -> SocketAddress
#       def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
#       def write(mut self, data: Span[UInt8, _]) raises IoError -> Int
#       def shutdown_write(mut self) raises IoError
#       def close(mut self) raises IoError
#       def is_closed(self) -> Bool
#       def flush(mut self) raises IoError
#       # Inherited signatures from Reader and ByteWriter:
#       def read_exact(mut self, buf: MutSpan[UInt8, _]) raises IoError
#       def read_to_end(mut self) raises IoError -> List[UInt8]
#       def write_all(mut self, data: Span[UInt8, _]) raises IoError
# What it does:
#   - Constructor creates an unconnected/unbound byte-stream socket for the
#     selected valid IPv4/IPv6 family, close-on-exec and SIGPIPE-protected.
#     Every descriptor is non-blocking from creation, so a native call never
#     blocks the thread; IPv6 is explicitly IPv6-only. Configuration failure
#     closes the fd.
#   - Deadlines make waits bounded, in the Go net.Conn style. set_deadline sets
#     both directions; set_read_deadline/set_write_deadline set one. A deadline
#     is an absolute monotonic instant (Clock.now() + Duration). While a
#     deadline is set, a wait that reaches it raises IoError(TIMED_OUT, op).
#     clear_deadline restores unbounded blocking; has_* report the current state.
#     Deadlines apply to connect, accept, read and write. Timeouts never leave a
#     stale descriptor: the owner stays usable for a retry.
#   - bind requires the same family; wildcard and port zero are allowed.
#   - listen requests a positive backlog, default 128.
#   - connect requires the same family. It issues a non-blocking connect, waits
#     for writability under the write deadline, then reads SO_ERROR. Refused or
#     failed connect invalidates and closes the handle (retry needs a fresh
#     Socket); a deadline raises TIMED_OUT and also invalidates.
#   - accept waits for an incoming connection under the read deadline; returned
#     handle is independently owned, non-blocking, same family, close-on-exec and
#     SIGPIPE-protected. Listener stays usable on failure.
#   - local_address uses getsockname and returns a new endpoint preserving scope.
#   - read borrows a nonempty mutable destination for recv. On EAGAIN it waits
#     for readability under the read deadline, then retries, so a positive short
#     read is normal and EOF is `(0, True)`. Empty destination raises OTHER.
#   - write borrows bytes for send and returns the accepted prefix. On EAGAIN it
#     waits for writability under the write deadline, then retries. Empty input
#     returns zero on an open writable socket. After shutdown_write all writes
#     raise CLOSED. SIGPIPE never terminates the process.
#   - shutdown_write performs SHUT_WR; idempotent; reads remain possible.
#   - close is idempotent; invalidates before one native close. is_closed reports
#     local ownership state. flush checks open ownership then succeeds without a
#     syscall.
# Returns:
#   accept returns a new owned Socket; local_address returns an independent
#   endpoint; read returns ReadResult; write returns the accepted byte count.
# Errors:
#   Raises IoError: EINTR → INTERRUPTED (retried internally where the owner stays
#   usable); EAGAIN/EWOULDBLOCK → WOULD_BLOCK; a reached deadline → TIMED_OUT;
#   native EBADF or a locally closed owner → CLOSED; all other native failures →
#   OTHER. Native errno is captured immediately and included numerically in opaque
#   detail. Operation labels are `socket`, `bind`, `listen`, `connect`, `accept`,
#   `local_address`, `read`, `write`, `shutdown_write`, `close`, `flush`.
# Example:
#   from akku.net_ip import AddressFamily, IpAddress, Ipv4Address
#   from akku.time_clock import Clock, Duration
#   from akku.net_socket import Socket, SocketAddress
#   var listener = Socket(AddressFamily.IPV4)
#   listener.bind(SocketAddress(IpAddress.from_ipv4(Ipv4Address.from_u32(0x7f000001)), 0))
#   listener.listen()
#   var endpoint = listener.local_address()
#   var client = Socket(AddressFamily.IPV4)
#   client.set_deadline(Clock.now() + Duration.from_seconds(5))
#   client.connect(endpoint)
#   var accepted = listener.accept()
#   client.write_all(Span(List[UInt8](3, fill=1)))
#   accepted.close()
#   client.close()
#   listener.close()
# API-DOCS-END
