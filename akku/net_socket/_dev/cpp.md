# net_socket research: C++

## 1. Standard library support

The current C++ working draft's standard-library catalogue has no socket/networking facility. OS sockets or an external library are therefore the relevant interfaces for this research. [working draft](https://eel.is/c++draft/library)

## 2. Relevant community libraries

Boost.Asio is a maintained, documented C++ networking library by Christopher Kohlhoff in the Boost project. Its versioned Boost documentation and broad synchronous/asynchronous API are maturity evidence. It uses the Boost Software License 1.0. This research focuses on this widely documented library rather than inventing a ranking of alternatives. [Asio](https://www.boost.org/doc/libs/latest/doc/html/boost_asio.html), [license](https://www.boost.org/LICENSE_1_0.txt)

## 3. Exposed APIs

`ip::tcp`, `ip::udp`, protocol endpoints and sockets model networking. `basic_stream_socket` exposes connect, send, receive, shutdown, close, options, native handles and corresponding async operations; acceptors model listening. These are candidate reference surfaces, not the proposed first MojoAkku scope. [protocols](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/networking/protocols.html), [stream socket](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/reference/basic_stream_socket.html)

## 4. Error representation

Asio supports throwing synchronous overloads and overloads accepting `boost::system::error_code`; asynchronous operations deliver completion errors through the selected completion mechanism. The byte count remains relevant to partial operations. [stream socket](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/reference/basic_stream_socket.html)

## 5. Ownership semantics

The socket object owns its native resource; move construction transfers ownership, `close` releases it, and `release` relinquishes ownership to the caller. Async buffers require lifetime coordination and must not be confused with ownership of the socket itself. [stream socket](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/reference/basic_stream_socket.html), [buffer API](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/reference/buffer.html)

## 6. Blocking / non-blocking

Asio provides synchronous send/receive/connect and asynchronous alternatives. A socket's nonblocking controls and native nonblocking mode are separate exposed concepts. Sharing a single socket object across arbitrary concurrent calls is not generally safe; operation-specific guarantees matter. [stream socket](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/reference/basic_stream_socket.html)

## 7. IPv4 / IPv6

`ip::address` covers either address family and protocol endpoints hold an address and port. TCP's protocol abstraction provides v4/v6 choices. This separation is a useful precedent for a sibling address library plus socket library. [protocols](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/networking/protocols.html)

## 8. Timeouts

`steady_timer` provides monotonic timer waits/cancellation; Asio per-operation cancellation signals/slots let supported operations receive cancellation requests. Cancellation guarantees vary by operation and cancellation type, so a timer is not itself a universal socket timeout contract. [timer](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/reference/steady_timer.html), [cancellation](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/cancellation.html)

## 9. TLS

`ssl::stream` layers SSL/TLS over another stream and uses OpenSSL. This separates transport from encrypted protocol behavior. [SSL overview](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/ssl.html)

## 10. Interesting design decisions

Research suggestions: adopt explicit ownership transfer, independent endpoint values and separate TLS layering. Study send/receive byte counts, half-close, endpoint inspection, socket options and eventual async cancellation as distinct capabilities rather than one giant operation. [stream socket](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/reference/basic_stream_socket.html), [protocols](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/networking/protocols.html), [SSL overview](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/ssl.html)

## 11. Decisions NOT to copy

Recommendation: defer Asio's executor/completion-token ecosystem, native-handle escape hatches and arbitrary options until actual consumers require them. Exposing them in the first blocking library would expand the ownership/concurrency contract substantially. Keep Linux/Apple ABI and SIGPIPE differences hidden, while preserving actionable errors. [Asio overview](https://www.boost.org/doc/libs/latest/doc/html/boost_asio.html), [cancellation](https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/cancellation.html), [C research](c.md#10-interesting-design-decisions)

## 12. Ideas fitting Mojo

Research suggestion: translate resource ownership to a movable noncopyable Mojo struct and exceptions to `raises`; use sibling `net_ip` value types instead of duplicating address parsing. Async buffer lifetimes deserve a later dedicated contract. These are candidates for design review, not claims that an API has already been approved. Mojo facts are anchored in the local buch. [ownership](</Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/memory/ownership-and-lifetimes.md>), [raising](</Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/errors/raising-and-propagation.md>), [FFI](</Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/stdlib/ffi.md>)

## Sources

All factual claims link to the C++ working draft, official Boost documentation/license, or the local Mojo buch. Design recommendations are explicitly marked as recommendations or suggestions. Latest-version URLs were checked during this research pass; they are conceptual evidence, not a dependency installation or version pin.
