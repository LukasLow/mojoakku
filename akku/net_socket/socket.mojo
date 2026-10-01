from std.os import abort
from akku.net_ip import AddressFamily as _AddressFamily
from akku.io_core import (
    Reader as _Reader, ByteWriter as _ByteWriter,
    ReadResult as _ReadResult, IoError as _IoError,
)
from .socket_address import SocketAddress as _SocketAddress


struct Socket(Movable, Deinitable, _Reader, _ByteWriter):
    var _fd: Int32
    var _family: _AddressFamily
    var _write_shutdown: Bool

    def __init__(out self, family: _AddressFamily) raises _IoError:
        abort("MojoAkku: this API is not yet implemented")

    def __init__(out self, *, deinit move: Self):
        abort("MojoAkku: this API is not yet implemented")

    def __deinit__(deinit self):
        abort("MojoAkku: this API is not yet implemented")

    def bind(mut self, address: _SocketAddress) raises _IoError:
        abort("MojoAkku: this API is not yet implemented")

    def listen(mut self, backlog: Int = 128) raises _IoError:
        abort("MojoAkku: this API is not yet implemented")

    def connect(mut self, address: _SocketAddress) raises _IoError:
        abort("MojoAkku: this API is not yet implemented")

    def accept(mut self) raises _IoError -> Socket:
        abort("MojoAkku: this API is not yet implemented")

    def local_address(mut self) raises _IoError -> _SocketAddress:
        abort("MojoAkku: this API is not yet implemented")

    def read(mut self, buf: MutSpan[UInt8, _]) raises _IoError -> _ReadResult:
        abort("MojoAkku: this API is not yet implemented")

    def write(mut self, data: Span[UInt8, _]) raises _IoError -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def shutdown_write(mut self) raises _IoError:
        abort("MojoAkku: this API is not yet implemented")

    def close(mut self) raises _IoError:
        abort("MojoAkku: this API is not yet implemented")

    def is_closed(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def flush(mut self) raises _IoError:
        abort("MojoAkku: this API is not yet implemented")

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
