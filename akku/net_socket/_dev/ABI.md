# Native socket ABI evidence

## macOS header and OS probes

Command: `xcrun clang -Wall -Wextra -Werror .tmp/socket-darwin-abi.c -o .tmp/socket-darwin-abi`, then native binary with local-socket permissions.
The C probe uses only SDK headers sys/socket.h, netinet/in.h, stddef.h, fcntl.h, errno.h, stdio.h, unistd.h. It measures sizeof/offsetof and constants, creates AF_INET6 SOCK_STREAM, sets SO_NOSIGPIPE/IPV6_V6ONLY/FD_CLOEXEC, binds ::1:0 and validates getsockname and descriptor flags.

```
socklen_t=4 sockaddr_in=16 sockaddr_in6=28
v4 offsets len=0 family=1 port=2 addr=4
v6 offsets len=0 family=1 port=2 flow=4 addr=8 scope=24
AF_INET=2 AF_INET6=30 SOCK_STREAM=1 SOL_SOCKET=65535 SO_NOSIGPIPE=4130 IPPROTO_IPV6=41 IPV6_V6ONLY=27 SHUT_WR=1
F_GETFD=1 F_SETFD=2 FD_CLOEXEC=1 EINTR=4 EAGAIN=35 EWOULDBLOCK=35 ETIMEDOUT=60 EBADF=9
native IPv6 bind/options/CLOEXEC passed; port=50053 returned length=28
```

An isolated second C process restores SIGPIPE to SIG_DFL, uses a socketpair with SO_NOSIGPIPE, shuts down writes, and confirms send returns -1/EPIPE while the process survives:

```
native macOS SO_NOSIGPIPE: EPIPE returned with default SIGPIPE disposition; process survived
```

## Close policy

Linux close releases the descriptor before errors; never retry a close error:
[upstream Linux close documentation](https://man7.org/linux/man-pages/man2/close.2.html).
The supported Darwin kernel close path calls fp_close_and_unlock; fdrelse runs before fg_drop returns a per-file close error. Therefore another close risks a reused descriptor. This is a platform-specific policy, not a claim about every POSIX system:
[Apple XNU kern_descrip.c](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_descrip.c) (`sys_close`, `close_nocancel`, `fp_close_and_unlock`, `fg_drop`; source read 2026-10-01).

## Limits

These native probes establish current macOS C ABI and option behavior. They do not certify a Mojo macOS binary. The Mojo suite runs in the Linux smd container and GitHub Linux CI. Linux direct syscall paths still require integration evidence before release.

## Linux ctypes/libc probe

Command: `smd -t '{python3 .tmp/socket-linux-abi.py}'`. stdlib ctypes describes c_int/c_uint/c_size_t/c_ssize_t and aligned IPv4/IPv6 C structures; direct libc socket/setsockopt/bind/getsockname validate layout against kernel output. Default SIGPIPE plus MSG_NOSIGNAL returns EPIPE without terminating the probe.

```
socklen_t 4 v4 16 v6 28
v4 offsets [('family', 0), ('port', 2), ('address', 4), ('zero', 8)]
v6 offsets [('family', 0), ('port', 2), ('flow', 4), ('address', 8), ('scope', 24)]
AF4 2 AF6 10 STREAM 1 CLOEXEC 524288 MSG_NOSIGNAL 16384 V6ONLY 26 NONBLOCK 2048
errno EINTR 4 EAGAIN 11 ETIMEDOUT 110 EBADF 9
native Linux IPv6 layout/bind/V6ONLY/CLOEXEC passed
native Linux MSG_NOSIGNAL: EPIPE returned, default SIGPIPE process survived
```

## Linux independent ABI and OS probe

The independent Python ctypes probe reads native socket constants, checks exact
ctypes layout, creates libc IPv6 sockets, sets IPV6_V6ONLY, binds ::1:0,
checks getsockname and FD_CLOEXEC, then checks MSG_NOSIGNAL in an isolated
process with SIGPIPE restored to its default disposition. This is development
evidence only; Python is never imported by the shipped Mojo implementation.

```
socklen_t 4 v4 16 v6 28
v4 offsets [('family', 0), ('port', 2), ('address', 4), ('zero', 8)]
v6 offsets [('family', 0), ('port', 2), ('flow', 4), ('address', 8), ('scope', 24)]
AF4 2 AF6 10 STREAM 1 CLOEXEC 524288 MSG_NOSIGNAL 16384 V6ONLY 26 NONBLOCK 2048
errno EINTR 4 EAGAIN 11 ETIMEDOUT 110 EBADF 9
native Linux IPv6 layout/bind/V6ONLY/CLOEXEC passed
native Linux MSG_NOSIGNAL: EPIPE returned, default SIGPIPE process survived
```
