from .io_error import IoError
from .io_error_kind import IoErrorKind
from .byte_writer import ByteWriter
from io_core._internal.bounds import Sink


# BufferedWriter — buffered wrapper with an explicit, fallible flush/close.
struct BufferedWriter[W: Sink, capacity: Int = 4096](ByteWriter):
    var _inner: Self.W
    var _buf: Array[UInt8, Self.capacity]
    var _len: Int
    # Private: set by close(); write/flush after it raise CLOSED.
    var _closed: Bool

    def __init__(out self, var inner: Self.W):
        self._inner = inner^
        self._buf = Array[UInt8, Self.capacity](fill=0)
        self._len = 0
        self._closed = False

    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int:
        if self._closed:
            raise IoError(IoErrorKind.CLOSED, "write", "writer is closed")
        var offset = 0
        var total = len(data)
        while offset < total:
            if self._len == Self.capacity:
                self._write_buffer()
            var space = Self.capacity - self._len
            var n = total - offset
            if space < n:
                n = space
            for i in range(n):
                self._buf[self._len + i] = data[offset + i]
            self._len += n
            offset += n
        return total

    def flush(mut self) raises IoError:
        if self._closed:
            raise IoError(IoErrorKind.CLOSED, "flush", "writer is closed")
        self._write_buffer()
        self._inner.flush()

    def close(mut self) raises IoError:
        # Idempotent: a second close is a no-op.
        if self._closed:
            return
        self._write_buffer()
        self._inner.flush()
        self._closed = True

    def _write_buffer(mut self) raises IoError:
        # Push the buffered bytes to the inner writer (handling short writes)
        # and clear the buffer. Does not call inner.flush — the explicit
        # flush()/close() own that.
        if self._len == 0:
            return
        self._inner.write_all(Span(self._buf)[0 : self._len])
        self._len = 0

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
