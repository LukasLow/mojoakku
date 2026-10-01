from std.ffi import (
    external_call as _external_call, c_int as _c_int, c_uint as _c_uint,
    c_size_t as _c_size_t, c_ssize_t as _c_ssize_t,
)
from std.sys import CompilationTarget as _Target
from akku.net_ip import (
    AddressFamily as _AddressFamily, IpAddress as _IpAddress,
    Ipv4Address as _Ipv4Address, Ipv6Address as _Ipv6Address,
)
from akku.io_core import (
    Reader as _Reader, ByteWriter as _ByteWriter,
    ReadResult as _ReadResult, IoError as _IoError, IoErrorKind as _IoErrorKind,
)
from .socket_address import SocketAddress as _SocketAddress


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
# The errno TLS pointer is read immediately after failure and is never retained.
# Each adopted descriptor already passed configuration and has exactly one owner;
# deinit-move transfers that owner, and explicit close invalidates before release.
comptime _AF6 = _c_int(30 if _Target.is_macos() else 10)
comptime _V6ONLY = _c_int(27 if _Target.is_macos() else 26)
comptime _EAGAIN = _c_int(35 if _Target.is_macos() else 11)
comptime _ETIMEDOUT = _c_int(60 if _Target.is_macos() else 110)


def _errno() -> _c_int:
    comptime if _Target.is_macos():
        return _external_call["__error", Pointer[_c_int, MutUntrackedOrigin]]()[]
    else:
        return _external_call["__errno_location", Pointer[_c_int, MutUntrackedOrigin]]()[]


def _native_error(code: _c_int, op: String) -> _IoError:
    var kind = _IoErrorKind.OTHER
    if code == 4:
        kind = _IoErrorKind.INTERRUPTED
    elif code == _EAGAIN:
        kind = _IoErrorKind.WOULD_BLOCK
    elif code == _ETIMEDOUT:
        kind = _IoErrorKind.TIMED_OUT
    elif code == 9:
        kind = _IoErrorKind.CLOSED
    return _IoError(kind, op, String("native errno ", code))


def _configure_handle(fd: _c_int, op: String) raises _IoError:
    # Linux flags are atomic at socket/accept4; Darwin supplies the other policy.
    comptime if _Target.is_macos():
        var flags = _external_call["fcntl", _c_int, num_fixed_args=2](fd, _c_int(1))
        if flags < 0:
            var code = _errno()
            raise _native_error(code, op)
        if _external_call["fcntl", _c_int, num_fixed_args=2](fd, _c_int(2), flags | _c_int(1)) < 0:
            var code = _errno()
            raise _native_error(code, op)
        var enabled = _c_int(1)
        if _external_call["setsockopt", _c_int](fd, _c_int(65535), _c_int(4130), Pointer(to=enabled).unsafe_bitcast[NoneType](), _c_uint(4)) < 0:
            var code = _errno()
            raise _native_error(code, op)


def _pack(address: _SocketAddress) -> Array[UInt32, 32]:
    var storage = Array[UInt32, 32](fill=0)
    var bytes = storage.unsafe_ptr().unsafe_bitcast[UInt8]()
    var ip = address.address()
    var size = 16 if ip.is_ipv4() else 28
    var family = _c_int(2) if ip.is_ipv4() else _AF6
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
    if family == 2 and length >= 16:
        var ip = _Ipv4Address.from_octets(bytes[unsafe_offset=4], bytes[unsafe_offset=5], bytes[unsafe_offset=6], bytes[unsafe_offset=7])
        return _SocketAddress(_IpAddress.from_ipv4(ip), port)
    if family == _AF6 and length >= 28:
        var value = UInt128(0)
        for i in range(16):
            value = (value << 8) | UInt128(bytes[unsafe_offset=8+i])
        return _SocketAddress(_IpAddress.from_ipv6(_Ipv6Address.from_u128(value)), port, storage[6])
    raise _IoError(_IoErrorKind.OTHER, "local_address", "unsupported native address family or length")


struct Socket(Movable, Deinitable, _Reader, _ByteWriter):
    var _fd: _c_int
    var _family: _AddressFamily
    var _write_shutdown: Bool

    def __init__(out self, family: _AddressFamily) raises _IoError:
        self._fd = -1
        self._family = family
        self._write_shutdown = False
        if family != _AddressFamily.IPV4 and family != _AddressFamily.IPV6:
            raise _IoError(_IoErrorKind.OTHER, "socket", "invalid address family")
        comptime if not _Target.is_linux() and not _Target.is_macos():
            raise _IoError(_IoErrorKind.OTHER, "socket", "unsupported target")
        var domain = _c_int(2) if family == _AddressFamily.IPV4 else _AF6
        var flags = _c_int(1)
        comptime if _Target.is_linux():
            flags |= _c_int(524288)
        self._fd = _external_call["socket", _c_int](domain, flags, _c_int(0))
        if self._fd < 0:
            var code = _errno()
            raise _native_error(code, "socket")
        try:
            _configure_handle(self._fd, "socket")
            if family == _AddressFamily.IPV6:
                var enabled = _c_int(1)
                if _external_call["setsockopt", _c_int](self._fd, _c_int(41), _V6ONLY, Pointer(to=enabled).unsafe_bitcast[NoneType](), _c_uint(4)) < 0:
                    var code = _errno()
                    raise _native_error(code, "socket")
        except error:
            var fd = self._fd
            self._fd = -1
            _ = _external_call["close", _c_int](fd)
            raise error^

    @doc_hidden
    def __init__(out self, *, _accepted_fd: _c_int, _family: _AddressFamily):
        self._fd = _accepted_fd
        self._family = _family
        self._write_shutdown = False

    def __init__(out self, *, deinit move: Self):
        self._fd = move._fd
        self._family = move._family
        self._write_shutdown = move._write_shutdown

    def __deinit__(deinit self):
        if self._fd >= 0:
            _ = _external_call["close", _c_int](self._fd)

    def _check_open(self, op: String) raises _IoError:
        if self._fd < 0:
            raise _IoError(_IoErrorKind.CLOSED, op, "socket is closed")

    def _check_family(self, address: _SocketAddress, op: String) raises _IoError:
        if address.address().family() != self._family:
            raise _IoError(_IoErrorKind.OTHER, op, "address family mismatch")

    def bind(mut self, address: _SocketAddress) raises _IoError:
        self._check_open("bind")
        self._check_family(address, "bind")
        var storage = _pack(address)
        var length = _c_uint(16 if self._family == _AddressFamily.IPV4 else 28)
        if _external_call["bind", _c_int](self._fd, storage.unsafe_ptr().unsafe_bitcast[NoneType](), length) < 0:
            var code = _errno()
            raise _native_error(code, "bind")

    def listen(mut self, backlog: Int = 128) raises _IoError:
        self._check_open("listen")
        if backlog <= 0:
            raise _IoError(_IoErrorKind.OTHER, "listen", "backlog must be positive")
        var capped = min(backlog, 2147483647)
        if _external_call["listen", _c_int](self._fd, _c_int(capped)) < 0:
            var code = _errno()
            raise _native_error(code, "listen")

    def connect(mut self, address: _SocketAddress) raises _IoError:
        self._check_open("connect")
        self._check_family(address, "connect")
        var storage = _pack(address)
        var length = _c_uint(16 if self._family == _AddressFamily.IPV4 else 28)
        if _external_call["connect", _c_int](self._fd, storage.unsafe_ptr().unsafe_bitcast[NoneType](), length) < 0:
            var code = _errno()
            var fd = self._fd
            self._fd = -1
            _ = _external_call["close", _c_int](fd)
            raise _native_error(code, "connect")

    def accept(mut self) raises _IoError -> Socket:
        self._check_open("accept")
        var storage = Array[UInt32, 32](fill=0)
        var length = _c_uint(128)
        var fd: _c_int
        comptime if _Target.is_linux():
            fd = _external_call["accept4", _c_int](self._fd, storage.unsafe_ptr().unsafe_bitcast[NoneType](), Pointer(to=length), _c_int(524288))
        else:
            fd = _external_call["accept", _c_int](self._fd, storage.unsafe_ptr().unsafe_bitcast[NoneType](), Pointer(to=length))
        if fd < 0:
            var code = _errno()
            raise _native_error(code, "accept")
        # Accepted IPv6 sockets already inherit V6ONLY; do not set it after bind.
        try:
            _configure_handle(fd, "accept")
        except error:
            _ = _external_call["close", _c_int](fd)
            raise error^
        return Socket(_accepted_fd=fd, _family=self._family)

    def local_address(mut self) raises _IoError -> _SocketAddress:
        self._check_open("local_address")
        var storage = Array[UInt32, 32](fill=0)
        var length = _c_uint(128)
        if _external_call["getsockname", _c_int](self._fd, storage.unsafe_ptr().unsafe_bitcast[NoneType](), Pointer(to=length)) < 0:
            var code = _errno()
            raise _native_error(code, "local_address")
        return _unpack(storage, length)

    def read(mut self, buf: MutSpan[UInt8, _]) raises _IoError -> _ReadResult:
        self._check_open("read")
        if len(buf) == 0:
            raise _IoError(_IoErrorKind.OTHER, "read", "empty destination")
        var count = _external_call["recv", _c_ssize_t](self._fd, buf.unsafe_ptr().unsafe_bitcast[NoneType](), _c_size_t(len(buf)), _c_int(0))
        if count < 0:
            var code = _errno()
            raise _native_error(code, "read")
        return _ReadResult(Int(count), count == 0)

    def write(mut self, data: Span[UInt8, _]) raises _IoError -> Int:
        self._check_open("write")
        if self._write_shutdown:
            raise _IoError(_IoErrorKind.CLOSED, "write", "socket writes are shut down")
        if len(data) == 0:
            return 0
        var flags = _c_int(16384) if _Target.is_linux() else _c_int(0)
        var count = _external_call["send", _c_ssize_t](self._fd, data.unsafe_ptr().unsafe_bitcast[NoneType](), _c_size_t(len(data)), flags)
        if count < 0:
            var code = _errno()
            raise _native_error(code, "write")
        if count == 0:
            raise _IoError(_IoErrorKind.OTHER, "write", "write made no progress")
        return Int(count)

    def shutdown_write(mut self) raises _IoError:
        self._check_open("shutdown_write")
        if self._write_shutdown:
            return
        if _external_call["shutdown", _c_int](self._fd, _c_int(1)) < 0:
            var code = _errno()
            raise _native_error(code, "shutdown_write")
        self._write_shutdown = True

    def close(mut self) raises _IoError:
        if self._fd < 0:
            return
        var fd = self._fd
        self._fd = -1
        if _external_call["close", _c_int](fd) < 0:
            var code = _errno()
            raise _native_error(code, "close")

    def is_closed(self) -> Bool:
        return self._fd < 0

    def flush(mut self) raises _IoError:
        self._check_open("flush")

# API-DOCS-START
# Socket — one owner of a blocking numeric-IP stream socket.
# Signature:
#   struct Socket(Movable, Deinitable, Reader, ByteWriter):
#       def __init__(out self, family: AddressFamily) raises IoError
#       def __init__(out self, *, deinit move: Self)
#       def __deinit__(deinit self)
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
#   - Constructor creates an unconnected/unbound blocking SOCK_STREAM socket for the
#     selected valid IPv4/IPv6 family, with close-on-exec and per-platform SIGPIPE
#     protection. IPv6 is explicitly IPv6-only. Configuration failure closes the fd.
#   - bind requires the same family; wildcard and port zero are allowed. Kernel
#     operation-state and address errors surface; failure retains an owned socket.
#   - listen requests a positive backlog, default 128. Kernel may bind an unbound
#     socket and cap the queue. Failure retains the socket.
#   - connect requires the same family and a numeric remote endpoint. Pre-call family
#     validation failure retains ownership. Any native connect failure captures errno,
#     invalidates/closes the handle without retry, then raises the original failure;
#     cleanup errors never replace it. No automatic EINTR retry on connect.
#   - accept waits for an incoming connection; returned handle is independently owned,
#     blocking, same family, close-on-exec and SIGPIPE-protected. Listener remains
#     usable on failure. EINTR/EAGAIN surface without consuming a returned handle.
#   - local_address uses getsockname and returns a new endpoint preserving returned
#     IPv6 scope. Particularly useful after bind(port=0). Native errors surface.
#   - read borrows a nonempty mutable destination only for recv. Writes only returned
#     prefix. Positive short reads return `(count, False)`; native zero returns
#     `(0, True)`. EOF is repeatable. Empty destination raises OTHER without syscall;
#     it cannot fabricate EOF or the forbidden `(0, False)` Reader outcome. EINTR and
#     EAGAIN raise without progress, never hidden retries or made-up byte counts.
#   - write borrows bytes for send and returns the accepted prefix count; positive
#     short writes are normal. Empty input returns zero on an open writable socket
#     without syscall. After successful shutdown_write all writes, including empty
#     writes, raise CLOSED. A nonempty native zero write raises OTHER to avoid stalling
#     write_all. Native failure does not claim progress; SIGPIPE never terminates the
#     process. Bytes returned count as accepted by the OS, not delivered to the peer.
#   - shutdown_write performs SHUT_WR; once successful it is idempotent and further
#     write calls raise CLOSED. Incoming reads remain possible. Failure does not mark
#     shutdown successful and can be retried according to its surfaced error.
#   - close is idempotent; invalidates before one native close; a failure raises with
#     owner still closed, never retries. Later operations raise CLOSED. is_closed is
#     nonfallible and reports local ownership state, not peer connectivity or EOF.
#   - flush checks open ownership then succeeds without a syscall: no user-space
#     buffered bytes exist. It does not guarantee peer receipt and works after
#     shutdown_write while the handle remains open.
#   - Provided read_exact/read_to_end/write_all retain io_core semantics including
#     INTERRUPTED retries. read_exact reports UNEXPECTED_EOF for missing trailing
#     bytes; partially consumed prefix remains consumed. Empty exact-read/write-all
#     helpers may perform no underlying call and therefore follow their existing
#     io_core contract even on a closed Socket.
#   - No concurrency, nonblocking or timeout configuration is provided. No close from
#     another thread cancellation promise. Parameter invalidity raises before a
#     syscall; CLOSED checks take priority on every direct handle operation.
# Returns:
#   accept returns a new owned Socket; local_address returns an independent endpoint.
#   read returns ReadResult; write returns accepted byte count.
#   read_to_end returns a new owned List[UInt8]. is_closed returns local ownership
#   state; other ordinary methods return nothing.
# Errors:
#   Raises IoError: EINTR → INTERRUPTED; EAGAIN/EWOULDBLOCK → WOULD_BLOCK;
#   ETIMEDOUT → TIMED_OUT; native EBADF or local closed owner → CLOSED;
#   all other native failures → OTHER. Native errno is captured immediately and
#   included numerically in opaque detail; callers inspect kind, never parse detail.
#   INTERRUPTED and WOULD_BLOCK may be retried except connect (fresh socket required)
#   and close (never retry). OTHER requires caller-specific recovery; EBADF becomes
#   CLOSED. Peer EOF is a value; broken pipe/reset are errors. No destructor errors. The public operation labels are `socket` (construction),
#   `bind`, `listen`, `connect`, `accept`, `local_address`, `read`, `write`,
#   `shutdown_write`, `close`, and `flush`. Native configuration performed for a newly
#   created/accepted handle uses the initiating `socket`/`accept` label, preserving
#   which public action failed. `is_closed` and move/destruction do not raise.
#   Provided helpers preserve their existing io_core error labels and semantics.
#   Closed-handle calls use their invoked method's op; a locally write-shut socket
#   reports CLOSED with op write. Validation failures use the invoked method's op.
# Example:
#   from akku.net_ip import AddressFamily, IpAddress, Ipv4Address
#   from akku.net_socket import Socket, SocketAddress
#   var listener = Socket(AddressFamily.IPV4)
#   listener.bind(SocketAddress(IpAddress.from_ipv4(Ipv4Address.from_u32(0x7f000001)), 0))
#   listener.listen()
#   var endpoint = listener.local_address()
#   var client = Socket(AddressFamily.IPV4)
#   client.connect(endpoint)
#   var accepted = listener.accept()
#   client.shutdown_write()
#   var bytes = accepted.read_to_end()  # empty after client write EOF
#   accepted.close()
#   client.close()
#   listener.close()
# API-DOCS-END
