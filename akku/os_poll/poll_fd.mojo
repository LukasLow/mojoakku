from std.os import abort

from .poll_events import PollEvents


# PollFd — one descriptor record: fd, interest events and result revents.
struct PollFd(Copyable, Deinitable, Writable):
    var fd: Int
    var events: PollEvents
    var revents: PollEvents

    def __init__(out self, fd: Int, events: PollEvents):
        self.fd = fd
        self.events = events
        self.revents = PollEvents.NONE

    def is_ready(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def clear(self):
        abort("MojoAkku: this API is not yet implemented")

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# PollFd — one descriptor record: fd, interest events and result revents.
# Signature:
#   struct PollFd(Copyable, Deinitable, Writable):
#       var fd: Int
#       var events: PollEvents
#       var revents: PollEvents
#       def __init__(out self, fd: Int, events: PollEvents)
#       def is_ready(self) -> Bool
#       def clear(self)
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   The record you put in the set handed to wait_many. `fd` is the descriptor
#   number you own (the library never closes or duplicates it); `events` is the
#   interest mask; `revents` starts empty and holds the result that wait_many
#   writes back. is_ready() is true when revents is non-empty. clear() resets
#   revents to NONE so a record can be reused unchanged across loop iterations.
#   A negative fd is allowed: poll(2) skips that entry, so you can mask a slot
#   for one call without rebuilding the array.
# Returns:
#   A value type; construction returns a PollFd owned by the caller.
# Errors:
#   none — it is a plain record and cannot fail.
# Example:
#   var fds = List[PollFd]()
#   fds.append(PollFd(fd_a, PollEvents.READ))
#   fds.append(PollFd(fd_b, PollEvents.READ | PollEvents.WRITE))
#   _ = wait_many(fds, PollTimeout(100))
#   for i in range(len(fds)):
#       if fds[i].is_ready():
#           print("fd", fds[i].fd, "->", fds[i].revents)
# API-DOCS-END
