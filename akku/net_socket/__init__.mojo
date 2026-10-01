from .socket_address import SocketAddress
from .socket import Socket

# API-DOCS-START
# Purpose — own POSIX byte-stream sockets for numeric IPv4/IPv6 endpoints, with
#   bounded waits. SocketAddress is a copyable value; Socket is a movable single
#   owner. Bind/listen/accept for servers or connect for clients. Transfer
#   borrowed bytes, half-close writes, then close. Targets Linux and macOS;
#   Windows needs a separate Winsock backend and is deferred.
# Overview — every descriptor is non-blocking internally, so a native call never
#   blocks the thread. Blocking behaviour is provided by an explicit, bounded
#   readiness wait (os_poll) that is driven by an optional deadline. With a
#   deadline set, a wait that reaches it raises IoError(TIMED_OUT, op); with none
#   set, the wait repeats until readiness, which is ordinary blocking semantics
#   but never an unbounded syscall. Deadlines are absolute monotonic instants
#   (Clock.now() + Duration) in the Go net.Conn style.
# Dependencies — akku.io_core supplies Reader/ByteWriter, ReadResult and typed
#   errors; akku.net_ip supplies numeric IP values/families; akku.time_clock
#   supplies Deadline/Duration/Clock; akku.os_poll supplies the bounded readiness
#   wait. Libraries are siblings; no third-party native library is linked.
# Public API — SocketAddress: numeric IP, UInt16 port, UInt32 IPv6 scope ID.
#   Socket: construction, deadline control (set_read_deadline, set_write_deadline,
#   set_deadline, clear_deadline, has_*), bind/listen/connect/accept/local_address,
#   read/write, shutdown_write/close/is_closed and Reader/ByteWriter helpers plus
#   flush.
# Error Surface — fallible calls raise akku.io_core.IoError with operation labels.
#   Native errno is captured immediately after failure; its numeric value is
#   included in opaque detail for diagnostics. Inspect kind, never parse detail.
#   EAGAIN/EWOULDBLOCK and EINTR are handled internally: the call waits for the
#   readiness it needs and retries, so they do not surface on read/write/accept/
#   connect while the owner stays usable. A reached deadline raises TIMED_OUT.
#   Native EBADF or a locally closed handle maps to CLOSED; ETIMEDOUT maps to
#   TIMED_OUT; all other native failures map to OTHER, including refused
#   connections, broken pipes and resets. EOF is ReadResult(0, True), never an
#   error. Native connect failure consumes the owner; create a fresh Socket to
#   retry. Explicit close reports errors but leaves the owner closed and never
#   retries.
# Conventions — IPv6-only sockets, numeric scope IDs; port zero allows dynamic
#   bind. With no deadline set, waits are unbounded in time but still issue only
#   bounded poll slices. No DNS/UDP, no asynchronous event loop, no cancellation
#   and no concurrent shared-handle guarantees. No native descriptor escape hatch.
#   Buffers are borrowed only for each synchronous call. SIGPIPE is suppressed
#   per call/socket; close-on-exec is enabled before return. Empty direct read
#   raises OTHER; empty write returns zero on an open writable socket. Closed
#   direct operations raise CLOSED; close is idempotent. Write shutdown is
#   idempotent and leaves reads available. Destructor never raises.
# API-DOCS-END
