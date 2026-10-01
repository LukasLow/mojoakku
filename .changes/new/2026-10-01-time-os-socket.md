NEW: time_clock — monotonic Clock, signed Duration with unit conversion, and Deadline instants with overflow-checked arithmetic.
NEW: os_poll — synchronous file-descriptor readiness (poll) with bounded millisecond waits, portable Linux/macOS event masks.
NEW: net_socket — owned IPv4/IPv6 stream sockets with bounded waits: non-blocking internals, absolute read/write deadlines (set_read_deadline/set_write_deadline/set_deadline/clear_deadline), EINTR/EAGAIN absorbed into the readiness wait, and a reached deadline raising TIMED_OUT. Consumer needs only `mojo build` (no third-party native library, no linker flags).
FIX: CI — full checks run on Linux x86-64 and macOS ARM64 before a release; smart tests reuse only tags certified on both platforms.
INTERNAL: catalogue — net_socket now depends on io_core, net_ip, time_clock and os_poll; time_clock and os_poll added and marked done.
