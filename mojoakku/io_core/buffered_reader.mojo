from .io_error import IoError
from .io_error_kind import IoErrorKind
from .read_result import ReadResult
from .reader import Reader
from io_core._internal.bounds import Stream


# BufferedReader — buffered wrapper with an inline, compile-time-sized buffer.
struct BufferedReader[R: Stream, capacity: Int = 4096](Reader):
    var _inner: Self.R
    var _buf: Array[UInt8, Self.capacity]
    var _start: Int
    var _end: Int
    # Private: records that the inner reader has reported eof, so EOF can be
    # reported once the buffer drains (never before).
    var _eof: Bool

    def __init__(out self, var inner: Self.R):
        self._inner = inner^
        self._buf = Array[UInt8, Self.capacity](fill=0)
        self._start = 0
        self._end = 0
        self._eof = False

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        # Serve from the buffer; refill only when empty.
        if self._start >= self._end:
            if self._eof:
                return ReadResult(0, True)
            _ = self._refill()
        var n = len(buf)
        if self._end - self._start < n:
            n = self._end - self._start
        for i in range(n):
            buf[i] = self._buf[self._start + i]
        self._start += n
        return ReadResult(n, self._eof and self._start >= self._end)

    def _refill(mut self) raises IoError -> Bool:
        # Fill the buffer from the inner reader. Returns False on inner EOF.
        # INTERRUPTED is retried; a zero-length non-EOF inner read is OTHER.
        while True:
            var result: ReadResult
            try:
                result = self._inner.read(MutSpan(self._buf))
            except e:
                if e.kind == IoErrorKind.INTERRUPTED:
                    continue
                raise e^
            if result.count > 0:
                self._start = 0
                self._end = result.count
                self._eof = result.eof
                return True
            if result.eof:
                self._start = 0
                self._end = 0
                self._eof = True
                return False
            raise IoError(
                IoErrorKind.OTHER, "read", "buffered reader made no progress"
            )

# API-DOCS-START
# BufferedReader — buffer reads from any Reader to reduce call overhead.
# Signature:
#   struct BufferedReader[R: Stream, capacity: Int = 4096](Reader):
#       var _inner: Self.R
#       var _buf: Array[UInt8, Self.capacity]
#       var _start: Int
#       var _end: Int
#       def __init__(out self, var inner: Self.R)
#       def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
# What it does:
#   Wraps any Reader. `capacity` is a compile-time value parameter with a
#   default of 4096 bytes. Reads are served from the internal buffer, refilling
#   from the inner reader only when the buffer is empty; a short inner read is
#   normal. EOF is reported only when the inner reader reports EOF and the buffer
#   is drained, so no buffered data is silently dropped while the reader is live.
#   It owns its inline buffer and inner reader as a value-semantics struct; there
#   is no close. INTERRUPTED is retried on refill; WOULD_BLOCK is surfaced.
# Returns:
#   A ReadResult per read; the bytes are written into your buffer.
# Errors:
#   raises IoError — passed through from the inner reader; OTHER if the inner
#   reader reports a zero-length non-EOF read.
# Example:
#   var buffered = BufferedReader[SomeReader](inner)
#   var buf = Array[UInt8, 1024](fill=0)
#   var result = buffered.read(buf)
# API-DOCS-END
