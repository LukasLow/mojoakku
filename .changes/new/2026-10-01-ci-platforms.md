INTERNAL: net_socket — current implementation moved to akku_later/net_socket while its timeout-bounded rewrite waits for the time_clock and os_poll dependencies.
INTERNAL: catalogue — added os_poll (Readiness); net_socket now depends on io_core, net_ip, time_clock and os_poll; time_clock and os_poll set current.
INTERNAL: CI — two-platform (Linux x86-64, macOS ARM64) full checks gate releases; smart tests reuse only tags certified on both platforms.
