# codec_base64url — frozen run configuration

Selected languages: C, C++, Go, Rust, Python, JS/TS, Mojo.
C/C++: byte-buffer and error conventions; mandatory systems group.
Go/Rust: raw-vs-padded URL-safe policies; mandatory modern systems group.
Python/JS/TS: convenient URL-safe encode/decode and validation; mandatory scripting group.
Mojo: ownership, generics and typed errors, exclusively from local mojov1 buch.
Optional languages omitted: this narrow RFC 4648 codec variant adds no further platform model.
No new runtime dependencies: intended consumer of the sibling codec_base64 public API.
Questions: the 12 numbered sections of NewLibPhase1Research.md, in fixed order.
User waived the Phase 3 API approval gate for this session on 2026-10-01.
All other phases and reviews remain required. Pure Mojo; no I/O, networking or shared native code.
