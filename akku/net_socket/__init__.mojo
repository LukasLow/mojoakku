from .socket_address import SocketAddress
from .socket import Socket

# API-DOCS-START
# Purpose — own blocking POSIX byte-stream sockets for numeric IPv4/IPv6 endpoints.
# Overview — SocketAddress is a copyable value; Socket is a movable single owner.
#   Bind/listen/accept for servers or connect for clients. Transfer borrowed bytes,
#   half-close writes, then close. Targets Linux and macOS; native macOS ABI is
#   probed independently, while Mojo macOS runtime certification remains pending.
# Dependencies — akku.net_ip supplies numeric IP values/families; akku.io_core
#   supplies Reader/ByteWriter, ReadResult and typed errors. Libraries are siblings.
# Public API — SocketAddress: numeric IP, UInt16 port, UInt32 IPv6 scope ID.
#   Socket: construction, bind/listen/connect/accept/local_address, read/write,
#   shutdown_write/close/is_closed and Reader/ByteWriter helpers plus flush.
# Error Surface — fallible calls raise akku.io_core.IoError with operation labels.
#   EOF is ReadResult(0, True). EINTR/WOULD_BLOCK/TIMED_OUT are typed failures.
#   Native connect failure consumes the owner; create a fresh Socket to retry.
#   Explicit close reports errors but leaves the owner closed and never retries.
# Conventions — IPv6-only sockets, numeric scope IDs; port zero allows dynamic bind.
#   Blocking operations have no deadline and may wait indefinitely. No DNS/UDP,
#   nonblocking, cancellation or concurrent shared-handle guarantees. No native
#   descriptor escape hatch. Buffers are borrowed only for each synchronous call.
#   SIGPIPE is suppressed per call/socket; close-on-exec is enabled before return.
#   macOS close-on-exec configuration has a concurrent-fork initialization race.
#   Empty direct read raises OTHER; empty write returns zero on an open writable
#   socket. Closed direct operations raise CLOSED; close is idempotent. Write
#   shutdown is idempotent and leaves reads available. Destructor never raises.
# API-DOCS-END
