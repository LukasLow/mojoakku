# net_socket — design record

## Purpose

Own blocking POSIX byte-stream sockets with numeric IPv4/IPv6 endpoints. The
first release supports Linux and macOS; the container and CI verify Linux.
Native ABI behavior on macOS requires an independent native probe before a
macOS support claim can be released. No Python runtime or external C library.

## Status legend

planned → scaffolded → tested → implemented; benchmarked is optional.
The design and docs phases record planned API only; no implementation exists.

## Dependencies

- `akku.net_ip`: public `IpAddress` and `AddressFamily` carry validated numeric
  addresses; public conversions provide network-order bytes without private imports.
- `akku.io_core`: `Reader`, `ByteWriter`, `ReadResult`, `IoError`, `IoErrorKind`
  supply shared byte-transfer contracts and their provided complete-transfer helpers.

These are flat sibling graph edges, never physical nesting. MojoAkku uses these
edges because rebuilding address parsing and stream/error protocols in sockets
would create incompatible duplicated abstractions.

## Overview

Two public entries: copyable `SocketAddress`, movable/noncopyable `Socket`.
Create a socket for one address family. Bind/listen/accept for a server, or
connect for a client; transfer borrowed bytes, half-close writes, then close.
The kernel validates operation state. No user-level state machine hides native
failures; only closed state and successful write shutdown are tracked locally.

## Goals

Numeric endpoints, single-owner handles, short I/O, explicit EOF, independent
accepted handles, local endpoint discovery, typed raising errors, deterministic
best-effort cleanup, and call-scoped borrowed buffers.

## Non-Goals

No hostname resolution, UDP, Unix domains, Windows, asynchronous polling,
nonblocking configuration, deadlines, cancellation, TLS, arbitrary socket
options, native-descriptor adoption/release/duplication, vectored I/O, or
user-defined framing. Concrete later candidates appear in TODO.md.
MojoAkku does not copy Node queued writes/events or Go concurrent close/poller
cancellation: those guarantees require machinery absent from this blocking layer.
MojoAkku does not copy Python's freely shareable object owners or expose native
integer descriptors, because ownership should be explicit and unique.
MojoAkku does not copy arbitrary IPv6 flowinfo configuration; zero is sufficient
for the initial ordinary stream endpoint. IPv6 scope IDs are supported now.

## Reference APIs

POSIX socket/bind/listen/connect/accept/send/recv/getsockname/shutdown/close
(`c.md` §§3–10); Python raw socket (`python.md` §§3–7); Rust SocketAddr,
OwnedFd and Read/Write (`rust.md` §§3–7); Asio movable sockets (`cpp.md` §§3–5);
Go io byte counts (`go.md` §§3–5); Node half-close (`js_ts.md` §§3–5).
Mojo facts: local mojov1 `lifecycle/life.md`, `lifecycle/initialization.md`,
`lifecycle/death.md`, `memory/ownership-and-lifetimes.md`, `interop/calling-c.md`.

## Public API

- `SocketAddress`: `IpAddress`, `UInt16` port, optional `UInt32` IPv6 scope ID.
- `Socket`: owned blocking stream socket, constructed for `AddressFamily`.
  Methods: `bind`, `listen`, `connect`, `accept`, `local_address`, `read`,
  `write`, `shutdown_write`, `close`, `is_closed`; provided Reader/ByteWriter
  helpers `read_exact`, `read_to_end`, `write_all`, `flush`.

## Error Surface

Every fallible socket call raises existing `IoError`; address construction raises
it only for an IPv4 nonzero scope ID. `op` names the actual public operation.
Native errno is captured immediately and included numerically in opaque `detail`;
callers inspect `kind`, never parse detail. EINTR → INTERRUPTED; EAGAIN/EWOULDBLOCK
→ WOULD_BLOCK; ETIMEDOUT → TIMED_OUT; local closed handle → CLOSED; native EBADF
→ CLOSED; all other errno values → OTHER, including refused connections, broken
pipes, address errors and resets. EOF is `ReadResult(0, True)`, never an error.
No operation silently retries EINTR. Reader/ByteWriter provided helpers retry
INTERRUPTED for their transfer calls. All other failures surface to the caller.
A failed connect closes and invalidates the socket before raising the original
error; retry requires a fresh Socket. Failed close also leaves a closed owner.

## Conventions

Ports are host-order UInt16; port zero requests a kernel-selected local port on
bind. Numeric IPs are supplied as public net_ip values. IPv6 scope ID is host-order
UInt32 (interface index), default zero; IPv4 requires zero. No DNS or interface
name lookup. IPv6 sockets set IPV6_V6ONLY to true, so families never silently mix.
IPv6 flowinfo is zero. Listen backlog must be positive; the kernel may cap it.
Family mismatch, nonpositive backlog and empty read destinations raise OTHER
before a native call. All handle operations check CLOSED first, including empty
read/write and flush; close itself is idempotent. Unknown forged AddressFamily
values are rejected as OTHER before creating a descriptor.

Blocking calls have no timeout and may wait indefinitely. Calls borrow `mut self`
and are not concurrently callable. No guarantee of cancellation by close from
another thread. WOULD_BLOCK/TIMED_OUT mapping remains defensive for native
failures; no nonblocking/deadline API exists, so configured-path tests are N/A.
Every socket and accepted socket has close-on-exec enabled before publication.
Linux uses atomic SOCK_CLOEXEC/accept4 when available; macOS uses fcntl
FD_CLOEXEC, with an explicitly accepted concurrent-fork race during initialization.
Creation/accept configuration failures close the unpublished handle before raising.
No process-global signal policy changes: Linux writes use MSG_NOSIGNAL; macOS
sockets including accepted handles receive SO_NOSIGPIPE. Errors are raised.

## Ownership and Lifecycle

A Socket is Movable and Deinitable, never Copyable. `var transferred = socket^`
ends the source lifetime. The current Mojo move constructor uses
`__init__(out self, *, deinit move: Self)`; deinit arguments do not run their
old owner's destructor after moving (mojov1 lifecycle/life.md §Moving).
The receiver becomes the sole fd owner. No shared native handle escape hatch.
Accept yields a new owned Socket; closing the listener does not close it.
Endpoint values are independent copies. Buffers remain caller-owned and are never
retained, resized, freed or passed to an asynchronous native call.
Destructor closes any still-owned descriptor exactly once, suppressing errors;
explicit close releases exactly once and reports errors. Mark fd invalid before
native close and never retry close, even EINTR. This policy follows the supported
Linux/macOS close contracts rather than promising all POSIX variants. Destructor
never flushes or raises. Explicit write shutdown leaves receiving usable.

## Open Questions

None for API design. Platform probes must validate sockaddr layout, constants,
errno access, descriptor flags and signal suppression before implementation is
accepted. If a supported target cannot be verified, return to design rather than
silently shipping assumed ABI support.

## SocketAddress

Status: planned

Signature:
```mojo
struct SocketAddress(Copyable, Movable, Deinitable, Equatable, Writable):
    def __init__(out self, address: IpAddress, port: UInt16,
                 scope_id: UInt32 = 0) raises IoError
    def address(self) -> IpAddress
    def port(self) -> UInt16
    def scope_id(self) -> UInt32
    def __eq__(self, other: Self) -> Bool
    def write_to(self, mut writer: Some[Writer])
```

Semantics: Copies the numeric IP; stores host-order port and scope ID. Port 0–65535
is representable without narrowing arbitrary Int input. IPv4 scope must be zero.
Accessor values do not borrow from the endpoint. Equality includes IP, port and
scope. Writable produces `127.0.0.1:80`, `[::1]:80`, or `[fe80::1%3]:80` with
numeric nonzero scope inside brackets. Formatting performs no lookup and never
round-trips through a hostname. No I/O, interruption, EOF or close behavior applies.

Errors: Constructor raises IoError(OTHER, "address", opaque detail) for IPv4 scope.
Accessors, equality and formatting cannot fail.

Tests:
- `test_address_ipv4_values`: independent IP/accessor copies, port zero/65535,
  equality and `127.0.0.1:80` formatting.
- `test_address_ipv6_values`: IPv6 address copies, scope default/nonzero,
  scope-sensitive equality and bracketed numeric-scope formatting.
- `test_address_ipv4_scope_rejected`: OTHER with op address for nonzero IPv4 scope.
- `test_local_address_ipv4` / `test_local_address_ipv6`: native local endpoint
  preserves family, IP and assigned nonzero bind(port=0) port.

These are planned assertions, not claims that tests already exist. The same
SocketAddress contract applies when a value is returned by local_address.

Implementation status: not implemented

Rationale: MojoAkku uses SocketAddress because Rust SocketAddr and Python address
tuples separate numeric endpoints from handles (`rust.md` §7, `python.md` §7).
MojoAkku uses UInt16 and UInt32 because ports and scope IDs have bounded native
representations. MojoAkku includes IPv6 scope because a numeric link-local endpoint
otherwise loses necessary routing context (`c.md` §7). MojoAkku uses private fields
and accessor copies because callers should not bypass the scope invariant.

## Socket

Status: planned

Signature:
```mojo
struct Socket(Movable, Deinitable, Reader, ByteWriter):
    def __init__(out self, family: AddressFamily) raises IoError
    def __init__(out self, *, deinit move: Self)
    def __deinit__(deinit self)
    def bind(mut self, address: SocketAddress) raises IoError
    def listen(mut self, backlog: Int = 128) raises IoError
    def connect(mut self, address: SocketAddress) raises IoError
    def accept(mut self) raises IoError -> Socket
    def local_address(mut self) raises IoError -> SocketAddress
    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int
    def shutdown_write(mut self) raises IoError
    def close(mut self) raises IoError
    def is_closed(self) -> Bool
    def flush(mut self) raises IoError
    # Inherited signatures from Reader and ByteWriter:
    def read_exact(mut self, buf: MutSpan[UInt8, _]) raises IoError
    def read_to_end(mut self) raises IoError -> List[UInt8]
    def write_all(mut self, data: Span[UInt8, _]) raises IoError
```

Semantics:
- Constructor creates an unconnected/unbound blocking SOCK_STREAM socket for the
  selected valid IPv4/IPv6 family, with close-on-exec and per-platform SIGPIPE
  protection. IPv6 is explicitly IPv6-only. Configuration failure closes the fd.
- bind requires the same family; wildcard and port zero are allowed. Kernel
  operation-state and address errors surface; failure retains an owned socket.
- listen requests a positive backlog, default 128. Kernel may bind an unbound
  socket and cap the queue. Failure retains the socket.
- connect requires the same family and a numeric remote endpoint. Pre-call family
  validation failure retains ownership. Any native connect failure captures errno,
  invalidates/closes the handle without retry, then raises the original failure;
  cleanup errors never replace it. No automatic EINTR retry on connect.
- accept waits for an incoming connection; returned handle is independently owned,
  blocking, same family, close-on-exec and SIGPIPE-protected. Listener remains
  usable on failure. EINTR/EAGAIN surface without consuming a returned handle.
- local_address uses getsockname and returns a new endpoint preserving returned
  IPv6 scope. Particularly useful after bind(port=0). Native errors surface.
- read borrows a nonempty mutable destination only for recv. Writes only returned
  prefix. Positive short reads return `(count, False)`; native zero returns
  `(0, True)`. EOF is repeatable. Empty destination raises OTHER without syscall;
  it cannot fabricate EOF or the forbidden `(0, False)` Reader outcome. EINTR and
  EAGAIN raise without progress, never hidden retries or made-up byte counts.
- write borrows bytes for send and returns the accepted prefix count; positive
  short writes are normal. Empty input returns zero on an open writable socket
  without syscall. After successful shutdown_write all writes, including empty
  writes, raise CLOSED. A nonempty native zero write raises OTHER to avoid stalling
  write_all. Native failure does not claim progress; SIGPIPE never terminates the
  process. Bytes returned count as accepted by the OS, not delivered to the peer.
- shutdown_write performs SHUT_WR; once successful it is idempotent and further
  write calls raise CLOSED. Incoming reads remain possible. Failure does not mark
  shutdown successful and can be retried according to its surfaced error.
- close is idempotent; invalidates before one native close; a failure raises with
  owner still closed, never retries. Later operations raise CLOSED. is_closed is
  nonfallible and reports local ownership state, not peer connectivity or EOF.
- flush checks open ownership then succeeds without a syscall: no user-space
  buffered bytes exist. It does not guarantee peer receipt and works after
  shutdown_write while the handle remains open.
- Provided read_exact/read_to_end/write_all retain io_core semantics including
  INTERRUPTED retries. read_exact reports UNEXPECTED_EOF for missing trailing
  bytes; partially consumed prefix remains consumed. Empty exact-read/write-all
  helpers may perform no underlying call and therefore follow their existing
  io_core contract even on a closed Socket.
- No concurrency, nonblocking or timeout configuration is provided. No close from
  another thread cancellation promise. Parameter invalidity raises before a
  syscall; CLOSED checks take priority on every direct handle operation.

Errors: IoError mappings, op and recoverability follow Error Surface above.
INTERRUPTED and WOULD_BLOCK may be retried except connect (fresh socket required)
and close (never retry). OTHER requires caller-specific recovery; EBADF becomes
CLOSED. Peer EOF is a value; broken pipe/reset are errors. No destructor errors. The public operation labels are `socket` (construction),
`bind`, `listen`, `connect`, `accept`, `local_address`, `read`, `write`,
`shutdown_write`, `close`, and `flush`. Native configuration performed for a newly
created/accepted handle uses the initiating `socket`/`accept` label, preserving
which public action failed. `is_closed` and move/destruction do not raise.
Provided helpers preserve their existing io_core error labels and semantics.
Closed-handle calls use their invoked method's op; a locally write-shut socket
reports CLOSED with op write. Validation failures use the invoked method's op.

Tests: Loopback IPv4/IPv6 bind/listen/connect/accept; dynamic-port/local-address
roundtrip; scope representation; binary/partial I/O and untouched buffer suffix;
Reader/ByteWriter helper interoperability; empty transfer behavior; peer EOF;
shutdown_write idempotence and response reads; closed operations; invalid backlog
and family mismatch; refused-connect invalidation; move/destructor fd ownership;
accepted independence; native close-on-exec flags and SIGPIPE subprocess safety;
controlled EINTR with an isolated alarm/signal fixture. Timeout/nonblocking paths
are excluded APIs and their configured-path tests are N/A, not reported as skips.
Planned concern-to-test names:
- lifecycle: `test_socket_creation`, `test_socket_invalid_family`,
  `test_socket_move_owner`, `test_socket_destructor_closes`,
  `test_socket_close_idempotent`, `test_socket_closed_operations`.
- connection: `test_loopback_ipv4`, `test_loopback_ipv6`,
  `test_local_address_ipv4`, `test_local_address_ipv6`,
  `test_family_mismatch_retains_owner`, `test_listen_invalid_backlog`,
  `test_connect_refused_closes`, `test_accepted_independent`.
- transfers: `test_binary_short_read`, `test_short_write_count`,
  `test_read_suffix_untouched`, `test_empty_read_rejected`,
  `test_empty_write`, `test_peer_eof_repeated`, `test_flush_open`.
- interoperability: `test_read_exact`, `test_read_exact_unexpected_eof`,
  `test_read_to_end`, `test_write_all`, `test_empty_helpers_existing_contract`.
- shutdown: `test_shutdown_write_idempotent`,
  `test_shutdown_response_read`, `test_shutdown_empty_write_closed`.
- native contracts: `test_cloexec_created_and_accepted`,
  `test_sigpipe_safe_subprocess`, `test_interrupted_read`,
  `test_interrupted_accept`; ABI layout/constants and errno mapping are verified
  by an independent native probe rather than by self-referential Mojo assertions.

The interrupted-read/accept fixture runs in an isolated process with an explicit
bounded watchdog. Real signal interruption must be observed, never counted as a
pass merely because the signal was configured. Loopback tests use dynamic ports,
fixed byte expectations and a bounded outer timeout; they need no external host.
Descriptor ownership/security tests use independent OS observations or a native
peer fixture, without importing the library's private implementation. Names may
be refined before the reviewed test baseline; semantics remain frozen.

Implementation status: not implemented

Rationale: MojoAkku uses a movable Socket because Rust OwnedFd and C++ RAII
explicitly model single ownership (`rust.md` §5, `cpp.md` §5). MojoAkku uses
Reader/ByteWriter because Go io and Rust Read/Write favor interoperable borrowed
byte operations (`go.md` §5, `rust.md` §5), and io_core already specifies EOF and
helper behavior. MojoAkku uses typed IoError because errno must become recoverable
structured failure (`c.md` §4) without growing another overlapping error type.
MojoAkku uses write shutdown separately from close because POSIX and Node expose
half-close for request/response protocols (`c.md` §3, `js_ts.md` §5). MojoAkku
suppresses SIGPIPE locally because Rust and POSIX send establish a per-operation
policy rather than mutating application-wide signal handlers (`rust.md` §10,
`c.md` §10). MojoAkku closes failed connects because portable native state is
unspecified (`c.md` §6). MojoAkku never retries close because descriptor reuse can
turn a retry into closing another resource (`c.md` §5). MojoAkku sets close-on-exec
because sockets must not accidentally transfer ownership into a child executable;
Linux atomic flags narrow that initialization race, while macOS fcntl leaves the
explicitly stated process-spawn race for a later spawn integration.
