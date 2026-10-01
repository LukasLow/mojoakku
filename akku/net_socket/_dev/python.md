# net_socket research: Python

## 1. Standard library support

`socket` exposes the BSD socket layer; `socketserver` is a higher-level server helper. `asyncio` adds stream readers/writers. [P1][P2]

## 2. Relevant community libraries

Trio, maintained in the python-trio project, offers structured asynchronous I/O, including low-level sockets and higher-level streams. Its documented release API indicates an established implementation, not a new experimental wrapper; this is a maturity assessment, not a support guarantee. License: MIT OR Apache-2.0. [P4][P5][P6]

## 3. Exposed APIs

`socket.socket`, `bind`, `listen`, `accept`, `connect`, `send`, `sendall`, `recv`, `recv_into`, `shutdown`, `close`, `getsockname`, `getpeername`, and socket options cover handle-level operations. `asyncio.open_connection` instead returns stream objects. [P1][P2]

## 4. Error representation

Socket failures raise `OSError` subclasses with OS error information; `connect_ex` returns an error indicator. Successful stream receive returning empty bytes means peer EOF, not a syscall error. [P1][P3]

## 5. Ownership semantics

Explicit close/context management releases sockets; destructor cleanup should not be relied upon. `accept` creates a separate connected socket. `recv` returns owned bytes; `recv_into` writes caller storage. [P1][P3]

## 6. Blocking / non-blocking

Sockets support blocking and nonblocking modes. `send`/`recv` may transfer fewer bytes than requested; `sendall` loops. A stream has no inherent message boundaries. Asyncio streams are asynchronous higher-level wrappers. [P1][P2][P3]

## 7. IPv4 / IPv6

`AF_INET` uses host/port; `AF_INET6` adds flowinfo and scope ID. Numeric addresses avoid hostname-resolution ambiguity; scoped IPv6 needs explicit consideration. [P1]

## 8. Timeouts

`settimeout` combines blocking-mode control with operation time limits. Trio provides cancellation scopes rather than per-socket timeout state. [P1][P5]

## 9. TLS

`ssl.SSLContext.wrap_socket` layers TLS over sockets; certificate/hostname policy belongs to that layer. [P7]

## 10. Interesting design decisions

Research inference: separate short I/O from complete-transfer helpers and separate EOF from error. Explicit close and newly owned accepted handles are useful contracts. [P3]

## 11. Decisions NOT to copy

Research recommendation: avoid arbitrary address tuples, implicit DNS, destructor-dependent cleanup and assuming one receive equals one message. These would hide validation or lifecycle obligations. [P1][P3]

## 12. Ideas fitting Mojo

Design candidates, not Mojo capability claims: owned socket handle, explicit close, byte-span send/receive, structured raised OS errors, address values; later `send_all`, `recv_exact`, timeout, nonblocking and cancellation APIs. Validate Mojo feasibility through mojov1 before design. [P1][P3][P5]

## Sources

- [P1] https://docs.python.org/3/library/socket.html
- [P2] https://docs.python.org/3/library/asyncio-stream.html
- [P3] https://docs.python.org/3/howto/sockets.html
- [P4] https://github.com/python-trio/trio
- [P5] https://trio.readthedocs.io/en/stable/reference-io.html
- [P6] https://github.com/python-trio/trio/blob/main/LICENSE
- [P7] https://docs.python.org/3/library/ssl.html
