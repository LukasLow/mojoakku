# net_socket research: C

## 1. Standard library support

ISO C has no socket interface; the relevant Linux libc interface is POSIX/BSD `<sys/socket.h>`, with address families `AF_INET` and `AF_INET6`. This research concerns that OS interface, not a portable ISO C facility. [socket(2)](https://man7.org/linux/man-pages/man2/socket.2.html)

## 2. Relevant community libraries

libuv is a maintained cross-platform asynchronous C I/O library, stewarded by the libuv project. Its published 1.x API and versioned documentation are maturity evidence, not a guarantee. Its main license is MIT, with separately attributed included components. [project](https://libuv.org/), [license](https://github.com/libuv/libuv/blob/v1.x/LICENSE), [design](https://docs.libuv.org/en/v1.x/design.html)

## 3. Exposed APIs

The kernel-facing surface includes `socket`, `bind`, `connect`, `listen`, `accept`, `send`, `recv`, `getsockname`, `getpeername`, `setsockopt`, `getsockopt`, and `close`. `shutdown` separately disables receive, send, or both directions. [socket(2)](https://man7.org/linux/man-pages/man2/socket.2.html), [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)

libuv supplies `uv_tcp_t`, initialization, bind, connect, socket-name access, keepalive and nodelay controls; stream read/write and listening are layered on its handle abstraction. [TCP API](https://docs.libuv.org/en/v1.x/tcp.html)

## 4. Error representation

Native calls return `-1` and set `errno`; successful send/receive return byte counts. Capture the error before cleanup can overwrite it. Short transfers are successful results, not errors. A stream receive into a nonempty buffer returning zero denotes orderly peer shutdown. [send(2)](https://man7.org/linux/man-pages/man2/send.2.html), [recv(2)](https://man7.org/linux/man-pages/man2/recv.2.html)

## 5. Ownership semantics

A successful socket/accept creates an owned descriptor requiring closure; receive writes caller-supplied storage. On Linux a failed `close` must not be retried: descriptor release can precede the reported error, and retry could close a reused descriptor. The Linux manual explicitly identifies a difference from POSIX.1-2024's EINTR requirement; portable code must choose documented OS-specific policy. [accept(2)](https://man7.org/linux/man-pages/man2/accept.2.html), [recv(2)](https://man7.org/linux/man-pages/man2/recv.2.html), [close(2)](https://man7.org/linux/man-pages/man2/close.2.html)

libuv handle memory cannot move while operations refer to it and must survive until the close callback. This is a distinct lifetime model from a simple synchronous owned descriptor. [handle API](https://docs.libuv.org/en/v1.x/handle.html)

## 6. Blocking / non-blocking

Socket calls can block; `O_NONBLOCK` changes descriptor behavior and `MSG_DONTWAIT` is per call. EINTR before progress can be retried for send/receive/accept, but not mechanically for every operation. After failed `connect`, portable applications close and create a fresh socket because its state is unspecified. [recv(2)](https://man7.org/linux/man-pages/man2/recv.2.html), [accept(2)](https://man7.org/linux/man-pages/man2/accept.2.html), [connect(2)](https://man7.org/linux/man-pages/man2/connect.2.html)

libuv uses a nonblocking event loop; network activity is driven by readiness polling rather than a blocking call per request. [design](https://docs.libuv.org/en/v1.x/design.html)

## 7. IPv4 / IPv6

Separate native address structures represent IPv4/IPv6; `sockaddr_storage` provides suitably sized storage. IPv6 has scope IDs and `IPV6_V6ONLY`; dual-stack behavior is a policy requiring explicit treatment, not an assumption. [ipv6(7)](https://man7.org/linux/man-pages/man7/ipv6.7.html)

## 8. Timeouts

`SO_RCVTIMEO`/`SO_SNDTIMEO` limit blocking socket I/O and may yield partial progress or would-block errors. They do not provide a general end-to-end deadline for poll/select or a retrying operation. Cancellation needs a separate application policy; blocking close from another thread is unsafe as a universal cancellation primitive. [socket(7)](https://man7.org/linux/man-pages/man7/socket.7.html), [close(2)](https://man7.org/linux/man-pages/man2/close.2.html)

## 9. TLS

TLS is a separate layer: OpenSSL's `SSL_set_fd` associates its TLS object with an existing descriptor. Socket creation alone gives no encryption or authentication. [OpenSSL](https://docs.openssl.org/master/man3/SSL_set_fd/)

## 10. Interesting design decisions

Candidate principles: preserve partial byte counts, distinguish EOF from error, and keep shutdown separate from resource destruction. Suppress SIGPIPE locally: Linux `MSG_NOSIGNAL` affects a send call; Apple offers per-socket `SO_NOSIGPIPE`, which returns EPIPE instead of signalling. Accepted descriptors need the chosen policy too. These are proposed lessons from the cited native behavior, not frozen API decisions. [send(2)](https://man7.org/linux/man-pages/man2/send.2.html), [Apple options](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/setsockopt.2.html), [shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)

## 11. Decisions NOT to copy

Recommendation: do not expose arbitrary integer descriptors as freely copyable owners, globally ignore SIGPIPE, blindly retry close/connect, or assume Linux flags and native address layout apply on Apple. The ownership/retry and signal hazards above motivate these exclusions. [close(2)](https://man7.org/linux/man-pages/man2/close.2.html), [connect(2)](https://man7.org/linux/man-pages/man2/connect.2.html), [Apple options](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/setsockopt.2.html)

## 12. Ideas fitting Mojo

Candidate: one movable, noncopyable owner, explicit raising close plus nonraising destruction, borrowed byte buffers, and a small private native boundary with correct `c_*` types. These are research suggestions; Mojo ownership, errors and FFI facts come solely from the local buch. [ownership](</Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/memory/ownership-and-lifetimes.md>), [destruction](</Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/lifecycle/death.md>), [raising](</Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/errors/raising-and-propagation.md>), [FFI](</Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/stdlib/ffi.md>)

## Sources

Sources are linked at each claim above. Linux man-pages are the upstream Linux API documentation; Apple pages are official archived OS documentation. POSIX online pages returned HTTP 403 during this pass, so Linux/Apple claims are kept platform-specific. No native socket implementation or ABI constants are derived from unsourced assumptions.
