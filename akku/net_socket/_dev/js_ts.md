# net_socket research: JS/TS

## 1. Standard library support

Node.js provides `node:net` for TCP/IPC streams and `node:dgram` for UDP. These are runtime APIs available to JavaScript and TypeScript, rather than a language-defined BSD socket interface. [J1][J2]

## 2. Relevant community libraries

Socket.IO, maintained by the socketio project, is an established higher-level messaging implementation with a substantial published source history, MIT licensed. It is relevant as a boundary comparison, not as a raw OS-socket implementation. Maturity is a research assessment, not a compatibility guarantee. [J5][J6]

## 3. Exposed APIs

`net.Socket`, `net.Server`, `createConnection`, `createServer`, `connect`, `listen`, `address`, `end`, `destroy` and connection events expose TCP/IPC operations. Duplex `write`/readable events supply I/O. UDP instead has `dgram.createSocket`, `send`, `bind` and message events. [J1][J2][J3]

## 4. Error representation

Socket errors use events. Readable stream `end` indicates no more incoming data; `close` indicates resource closure. `write(false)` indicates backpressure rather than a native short-write count. [J1][J3]

## 5. Ownership semantics

`destroy` closes the stream/resource; `end` ends the writable side and can allow incoming data to continue. Buffers participate in queued stream writes and readable chunks; callers must follow stream completion/backpressure contracts. [J3]

## 6. Blocking / non-blocking

Node's stream model uses callbacks/events and asynchronous readiness. Writable buffering, `drain` and chunked readable delivery belong to that model; they are not a blocking syscall-count contract. [J1][J3]

## 7. IPv4 / IPv6

TCP supports both IP families; UDP distinguishes `udp4` and `udp6`. Dual-stack and address-family policy require runtime/platform awareness. [J1][J2]

## 8. Timeouts

Socket inactivity timeout emits a timeout notification without closing automatically. `destroy`/abort mechanisms perform termination. These are different from a synchronous operation deadline. [J1]

## 9. TLS

`node:tls` supplies `TLSSocket`, TLS connection and server APIs as a layer over transport. [J4]

## 10. Interesting design decisions

Research inference: keep half-close, final close and EOF distinct; explicit backpressure is essential for buffered asynchronous layers. [J3]

## 11. Decisions NOT to copy

Research recommendation: a minimal blocking socket library should not inherit EventEmitter callbacks, implicit buffering or an inactivity timeout named like an operation deadline. Those contracts belong to a different I/O model. [J1][J3]

## 12. Ideas fitting Mojo

Design candidates, not Mojo capability claims: explicit shutdown/close, owned accepted socket and IPv4/IPv6 address policy. Defer event-loop integration, queued writes, cancellation and higher-level framed messaging; validate feasibility in mojov1. Socket.IO's protocol layer is outside raw socket scope. [J1][J3][J5]

## Sources

- [J1] https://nodejs.org/api/net.html
- [J2] https://nodejs.org/api/dgram.html
- [J3] https://nodejs.org/api/stream.html
- [J4] https://nodejs.org/api/tls.html
- [J5] https://github.com/socketio/socket.io
- [J6] https://github.com/socketio/socket.io/blob/main/LICENSE
