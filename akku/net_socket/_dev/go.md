# net_socket research: Go

## 1. Standard library support

`net` provides connections, listeners and TCP/UDP/IP addresses; `io` provides byte-stream contracts. Lower-level Unix socket calls are exposed by the Go-maintained `golang.org/x/sys/unix` module. [net](https://pkg.go.dev/net), [io](https://pkg.go.dev/io), [unix](https://pkg.go.dev/golang.org/x/sys/unix)

## 2. Relevant community libraries

Matt Layher's `mdlayher/socket` is an established Linux-oriented low-level socket package integrating Go's runtime poller; it is MIT licensed. Its repository documents its support policy rather than promising platform parity. [repository](https://github.com/mdlayher/socket)

## 3. Exposed APIs

High-level APIs include `Dial`, `Listen`, `Conn.Read/Write/Close`, and `TCPConn.CloseRead/CloseWrite`. The low-level module exposes `Socket`, `Bind`, `Listen`, `Accept`, `Connect`, `Sendto`, `Recvfrom`, `Shutdown`, `Close` and sockaddr types. [net](https://pkg.go.dev/net), [unix](https://pkg.go.dev/golang.org/x/sys/unix)

## 4. Error representation

Operations return errors; `net.OpError` retains operation/network/address context and wraps the cause. `io.Reader` permits data and an error together: callers process `n > 0` before the error. EOF is `io.EOF`; writers must report an error for short writes. [net](https://pkg.go.dev/net#OpError), [io](https://pkg.go.dev/io#Reader), [io.Writer](https://pkg.go.dev/io#Writer)

## 5. Ownership semantics

Callers provide slices; Reader/Writer contracts forbid retaining them. A connection has explicit `Close`; closing it unblocks pending reads/writes with errors. Raw Unix descriptors require explicit `Close`, unlike buffer ownership. [io](https://pkg.go.dev/io), [net.Conn](https://pkg.go.dev/net#Conn), [unix.Close](https://pkg.go.dev/golang.org/x/sys/unix#Close)

## 6. Blocking / non-blocking

`net` presents synchronous operations and permits concurrent connection methods. `mdlayher/socket` integrates asynchronous poller I/O behind its connection API; this is runtime infrastructure, not merely a syscall wrapper. [net.Conn](https://pkg.go.dev/net#Conn), [socket](https://github.com/mdlayher/socket)

## 7. IPv4 / IPv6

Networks distinguish `tcp`, `tcp4`, `tcp6`; TCP addresses carry IP, port and IPv6 zone. Low-level `SockaddrInet4`/`SockaddrInet6` expose separate OS families. [net](https://pkg.go.dev/net#TCPAddr), [unix](https://pkg.go.dev/golang.org/x/sys/unix)

## 8. Timeouts

Connections expose absolute read/write deadlines. Dialer supports context cancellation during establishment; that context does not govern an already established connection. The community package exposes context-bearing `Accept`, `Connect`, `Recvfrom` and `Sendto`. [net.Dialer](https://pkg.go.dev/net#Dialer), [socket APIs](https://pkg.go.dev/github.com/mdlayher/socket)

## 9. TLS

`crypto/tls` layers a `Conn` over an existing `net.Conn`; encryption is separate from raw socket transport. [tls.Client](https://pkg.go.dev/crypto/tls#Client)

## 10. Interesting design decisions

Research inference: retain byte counts and EOF distinctly; expose low-level operations without inventing framing. SIGPIPE is a specific runtime policy: ordinary network-descriptor failures become EPIPE rather than terminating Go. A Mojo wrapper must establish its own policy. [io](https://pkg.go.dev/io), [SIGPIPE](https://pkg.go.dev/os/signal#hdr-SIGPIPE)

## 11. Decisions NOT to copy

Research recommendation: do not copy Go's concurrency, close-cancellation or poller guarantees without implementing their machinery. Keep hostname resolution and TLS out of a first numeric-address socket layer; their reference APIs are distinct. [net.Conn](https://pkg.go.dev/net#Conn), [socket](https://github.com/mdlayher/socket), [tls](https://pkg.go.dev/crypto/tls)

## 12. Ideas fitting Mojo

Candidate, not an API decision: a single owner for the descriptor, explicit close, borrowed call-scoped buffers and returned byte counts. Raise OS failures without treating EOF as failure. Mojo feasibility must be checked by the Manager against the local `mojov1` buch; no Mojo syntax or capability is asserted here. [ownership/byte-count evidence](https://pkg.go.dev/io), [raw descriptor evidence](https://pkg.go.dev/golang.org/x/sys/unix)

## Sources

Primary links above were read on 2026-10-01. Go runtime semantics are reference evidence, not a proposed guarantee for MojoAkku.
