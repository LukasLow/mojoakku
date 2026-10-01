# net_socket research: Rust

## 1. Standard library support

`std::net` provides TCP streams/listeners, UDP sockets and numeric socket addresses. `std::io` defines byte reading/writing. `std::os::fd::OwnedFd` models owned Unix descriptors. [stream](https://doc.rust-lang.org/std/net/struct.TcpStream.html), [listener](https://doc.rust-lang.org/std/net/struct.TcpListener.html), [OwnedFd](https://doc.rust-lang.org/std/os/fd/struct.OwnedFd.html)

## 2. Relevant community libraries

The rust-lang `socket2` project provides advanced socket configuration under MIT/Apache-2.0. Tokio supplies a mature async networking/runtime ecosystem under MIT. Rustls is an established TLS project under Apache-2.0/ISC/MIT. These are reference choices, not proposed dependencies. [socket2](https://github.com/rust-lang/socket2), [Tokio](https://github.com/tokio-rs/tokio), [Rustls](https://github.com/rustls/rustls)

## 3. Exposed APIs

`TcpStream` exposes connect, peer/local addresses, shutdown, timeouts, nonblocking mode and `try_clone`; `TcpListener` exposes bind/accept. `socket2::Socket` adds explicit domain/type/protocol creation, bind/listen/connect/accept, send/recv and socket options. [stream](https://doc.rust-lang.org/std/net/struct.TcpStream.html), [listener](https://doc.rust-lang.org/std/net/struct.TcpListener.html), [Socket](https://docs.rs/socket2/latest/socket2/struct.Socket.html)

## 4. Error representation

Socket methods return `io::Result`. Reading returns a count; zero for a nonempty destination indicates EOF, while an empty destination can also return zero. Writing may be partial; `write_all` loops, while `Interrupted` has defined retry treatment. [Read](https://doc.rust-lang.org/std/io/trait.Read.html), [Write](https://doc.rust-lang.org/std/io/trait.Write.html)

## 5. Ownership semantics

`OwnedFd` closes on destruction and distinguishes borrowing from ownership transfer. `TcpStream::try_clone` creates an independently owned handle to the same stream; it does not duplicate the underlying connection. Caller-owned buffers are borrowed by I/O methods. [OwnedFd](https://doc.rust-lang.org/std/os/fd/struct.OwnedFd.html), [stream](https://doc.rust-lang.org/std/net/struct.TcpStream.html), [Read](https://doc.rust-lang.org/std/io/trait.Read.html)

## 6. Blocking / non-blocking

Std streams support explicit nonblocking mode and WouldBlock. Tokio separates readiness from actual I/O and documents retry after readiness produces WouldBlock. A readiness event alone is not successful byte transfer. [stream](https://doc.rust-lang.org/std/net/struct.TcpStream.html), [Tokio stream](https://docs.rs/tokio/latest/tokio/net/struct.TcpStream.html)

## 7. IPv4 / IPv6

`SocketAddr` has V4/V6 variants. V6 addresses include scope ID and flowinfo. `socket2` distinguishes domains and exposes IPv6-only configuration; dual-stack behavior is therefore a policy to specify rather than assume. [address](https://doc.rust-lang.org/std/net/enum.SocketAddr.html), [Socket](https://docs.rs/socket2/latest/socket2/struct.Socket.html)

## 8. Timeouts

Std exposes connect/read/write timeouts; zero read/write duration is invalid. Read/write timeout errors can differ between Unix and Windows. Tokio read/readiness documentation identifies cancellation-safe operations, so cancellation guarantees are operation-specific. [stream](https://doc.rust-lang.org/std/net/struct.TcpStream.html), [Tokio stream](https://docs.rs/tokio/latest/tokio/net/struct.TcpStream.html)

## 9. TLS

Rustls provides TLS separately from std socket ownership and transport; its repository documents integration choices and crypto providers. [Rustls](https://github.com/rustls/rustls)

## 10. Interesting design decisions

Research inference: deterministic handle cleanup plus explicit ownership transfer is a useful socket boundary. Rust suppresses SIGPIPE for TcpStream writes with MSG_NOSIGNAL on Unix according to its documentation; wrappers must avoid relying on an unrelated host runtime policy. [OwnedFd](https://doc.rust-lang.org/std/os/fd/struct.OwnedFd.html), [stream platform behavior](https://doc.rust-lang.org/std/net/struct.TcpStream.html)

## 11. Decisions NOT to copy

Research recommendation: do not expose unrestricted raw-handle adoption, cloning, every socket option or Tokio's runtime in the first library. Their ownership and concurrency costs exceed a minimal blocking transport. Higher-level TCP convenience and framing can remain separate consumers. [OwnedFd](https://doc.rust-lang.org/std/os/fd/struct.OwnedFd.html), [Socket](https://docs.rs/socket2/latest/socket2/struct.Socket.html), [Tokio stream](https://docs.rs/tokio/latest/tokio/net/struct.TcpStream.html)

## 12. Ideas fitting Mojo

Candidate, not an API decision: a movable single-owner socket, deterministic best-effort cleanup, explicit close, numeric address value and byte-count I/O. OS error information should survive raised failures. The Manager must establish Mojo feasibility from the local `mojov1` buch; no Mojo syntax is inferred from Rust. [OwnedFd](https://doc.rust-lang.org/std/os/fd/struct.OwnedFd.html), [Read](https://doc.rust-lang.org/std/io/trait.Read.html), [address](https://doc.rust-lang.org/std/net/enum.SocketAddr.html)

## Sources

Primary links above were read on 2026-10-01. Recommendations and cross-language conclusions are explicitly marked research inferences/candidates.
