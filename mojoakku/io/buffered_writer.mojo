from std.os import abort

from .io_error import IoError
from .byte_writer import ByteWriter
from io._internal.bounds import Sink


# BufferedWriter — buffered wrapper with an explicit, fallible flush/close.
struct BufferedWriter[W: Sink, capacity: Int = 4096](ByteWriter):
    var _inner: Self.W
    var _buf: Array[UInt8, Self.capacity]
    var _len: Int

    def __init__(out self, var inner: Self.W):
        abort("MojoAkku: this API is not yet implemented")

    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def flush(mut self) raises IoError:
        abort("MojoAkku: this API is not yet implemented")

    def close(mut self) raises IoError:
        abort("MojoAkku: this API is not yet implemented")

# API-DOCS-START
# BufferedWriter — buffer writes to any ByteWriter with an explicit terminal
# flush.
# Signature:
#   struct BufferedWriter[W: Sink, capacity: Int = 4096](ByteWriter):
#       var _inner: Self.W
#       var _buf: Array[UInt8, Self.capacity]
#       var _len: Int
#       def __init__(out self, var inner: Self.W)
#       def write(mut self, data: Span[UInt8, _]) raises IoError -> Int
#       def flush(mut self) raises IoError
#       def close(mut self) raises IoError
# What it does:
#   Wraps any ByteWriter. `capacity` is a compile-time value parameter (default
#   4096). `write` appends into the buffer and flushes when it is full; it
#   returns the number of bytes accepted. `flush` writes the buffered bytes to
#   the inner writer and calls the inner flush — it is explicit and fallible.
#   `close` flushes and marks the writer closed so later calls raise CLOSED; it
#   is idempotent. There is no destructor flush: flush (or close) is the
#   terminal, explicit call, and dropping a writer with unflushed bytes is a
#   documented, accepted loss. `write_all` is inherited from ByteWriter and is
#   not re-declared.
# Returns:
#   `write` returns the number of bytes accepted; `flush` and `close` return
#   nothing.
# Errors:
#   raises IoError — from the inner writer; OTHER ("write zero"); CLOSED from
#   write/flush after close.
# Example:
#   var out = BufferedWriter[SomeWriter](inner)
#   _ = out.write(data)      # buffered
#   out.flush()              # push to inner, fallible
#   out.close()              # flush and mark closed (idempotent)
# API-DOCS-END
