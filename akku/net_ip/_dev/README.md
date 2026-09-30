# net_ip research — frozen run configuration

Phase: `NewLibPhase1Research` for the MojoAkku library `net_ip`.

## What the library is

`akku/net_ip` is **IP addressing**: the IPv4 and IPv6 address value type. It is
the address model every later networking library builds on — `net_socket`,
`net_tcp`, `net_udp`, `proto_dns`, `web_url`. It is a leaf library (no sibling
dependencies) and a pure, deterministic, in-process value library: parse text to
an address, format an address to text, classify it, and do address arithmetic.

## Positioning fact (found during phase setup)

Mojo's standard library ships **37 top-level packages and none of them is a
network package**. The list is `algorithm, atomic, base64, benchmark, bit,
builtin, collections, compile, complex, documentation, ffi, format, gpu, hashlib,
io, iter, itertools, logger, math, memory, origin, os, pathlib, prelude, pwd,
python, random, reflection, runtime, stat, subprocess, sys, tempfile, testing,
time, traits, utils`. There is no `socket`, no `net`, no `ip`, no `inet`. Source:
`mojov1/stdlib/overview`.

Consequence: the *whole* address model is a gap. The library's reason to exist is
the missing IP-address type, and the research must establish what every reference
language does so the Mojo design can be defensible. The library is nevertheless
buildable in pure Mojo today: it is integer arithmetic, bit masking, byte
storage, text parsing and text formatting — all `have` capabilities
(`pure-mojo`, `c-ffi` not required). No socket is needed to parse or format an
address; the socket dependency only appears when `net_ip` is consumed by
`net_socket`.

## Selected languages (frozen)

IP addressing exists in every language. Presence is not a discriminator; the
languages below are the ones whose **address model differs in a way worth
studying** — in particular whether the address is a *value type* or an *opaque
handle*, whether IPv4 and IPv6 share **one abstraction**, and how parse/format,
classification and arithmetic are split.

Mandatory languages, always present in this run: **C, C++, Go, Rust, JS/TS,
Python** — plus **Mojo**, covered by the `mojov1` buch (no researcher).

| group | languages | reason |
| --- | --- | --- |
| systems-lowlevel | C, C++ | C is the origin: `struct in_addr`/`in6_addr` are raw 32/128-bit integers, text is `inet_pton`/`inet_ntop` (stringly, no error type); C++ adds `std::net` (never standardized in practice) and Boost.Asio's `address`/`address_v4`/`address_v6` — the earliest "one abstraction over both" design |
| systems-modern | Go, Rust | Go has **two** address models side by side: the legacy `net.IP` (`[]byte`, the famous slice-aliasing trap) and the modern `net/netip.Addr` (a comparable value type, `netip.Addr.Is4In6`, `Unmap`) — the strongest before/after case. Rust's `std::net::{IpAddr, Ipv4Addr, Ipv6Addr}` is the value-typed enum model with rich classification |
| scripting-web | Python, JS/TS | Python's `ipaddress` module is the canonical **rich** model: `IPv4Address`/`IPv6Address` with networks, hosts, arithmetic; JS has **no built-in** address type at all (the sharpest "stdlib does nothing" case — a signal for what a minimal core must cover) |
| managed-JVM | Java | `java.net.InetAddress` is the cautionary tale: a *host* abstraction (DNS-resolving constructor, `getByName`, blocking lookup, equality against a name) rather than a pure address value — the clearest "decision NOT to copy" |
| functional/BEAM | Elixir | `:inet` parses to tagged tuples (`{a,b,c,d}`, `{a,b,c,d,e,f,g,h}`) and has separate `:inet.parse_ipv4_address` / `parse_ipv6_address` — tagged-tuple addresses and family-split parsing |
| data/science | Julia | `Sockets.IPv4`/`IPv6` are distinct value types with `parse`, `tryparse`, and a rich predicate set (`isloopback`, `islinklocal`, …) — a close modern analogue to the intended Mojo shape |

All six groups are selected this run. No group is dropped: the split between
"one abstraction over both families" (Go `netip`, Rust, C++ Asio) and "two
separate types" (Julia, Elixir) is the central design question for Mojo.

## Question set (adapted for IP)

The standard 12 questions apply in order. The socket-specific questions are
replaced by IP equivalents; everything else is unchanged:

- Q7 (was IPv4/IPv6) → **the family model**: is there one address type or two,
  how does the type signal its family, how is an IPv4-mapped IPv6 address
  handled, and how is the family compared/printed.
- Q8 (was timeouts) → **bounds, overflow and validity**: what makes an address
  invalid at parse time, out-of-range octets, prefix/number parsing overflow,
  and what is defined vs undefined.
- Q9 (was TLS) → **classification and arithmetic**: loopback / private /
  link-local / multicast / unspecified / broadcast predicates, and which
  numeric operations (successor, next, bitwise over the address, network math)
  the language provides.

Q1–Q6, Q10–Q12 are kept verbatim.

## Writing contract

Each researcher writes its language files **directly** into
`akku/net_ip/_dev/<lang>.md`, one file per language of its group, using exactly
this section structure:

```
# ip research: <lang>
## 1. Standard library support
## 2. Relevant community libraries
## 3. Exposed APIs
## 4. Error representation
## 5. Ownership semantics
## 6. Blocking / non-blocking
## 7. Family model (one type or two; mapped addresses)
## 8. Bounds, overflow and validity
## 9. Classification and arithmetic
## 10. Interesting design decisions
## 11. Decisions NOT to copy
## 12. Ideas fitting Mojo
## Sources
```

There is no reporting-project and no `docs` materialization pass. Every factual
claim cites a source (URL, RFC, or `repo/path:line`). Derived statements are
marked `(Assessment: derived from <sources>)`; unsourced statements are marked
`GUESS:` with the reason no source exists.

The Mojo side is **not** a researcher-written file: the facts live in the
`mojov1` buch (`mojov1/stdlib/overview`, `mojov1/interop/calling-c`,
`mojov1/types/*`). `mojo.md` is a small pointer note that records what the buch
answers and which parts of the question set it does not — those unanswered parts
are the library's gap premise.

## Status

| lang | group | file | state |
| --- | --- | --- | --- |
| C | systems-lowlevel | `c.md` | done |
| C++ | systems-lowlevel | `cpp.md` | done |
| Go | systems-modern | `go.md` | done |
| Rust | systems-modern | `rust.md` | done |
| Python | scripting-web | `python.md` | done |
| JS/TS | scripting-web | `js-ts.md` | done |
| Java | managed-JVM | `java.md` | done |
| Elixir | functional/BEAM | `elixir.md` | done |
| Julia | data/science | `julia.md` | done |
| Mojo | (buch) | `mojo.md` → `mojov1/stdlib/overview` | covered by buch |

Researchers started: primary agent wrote the corpus directly (user requested no
subagents for this run).

Phase 1 is complete; the review happens in
`.agents/workflows/NewLibPhase2ResearchReview.md`.
