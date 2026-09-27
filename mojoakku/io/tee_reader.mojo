from .io_error import IoError
from .read_result import ReadResult
from .reader import Reader
from io._internal.bounds import Stream, Sink


# TeeReader — mirror everything read into a writer.
struct TeeReader[R: Stream, W: Sink](Reader):
    var _inner: Self.R
    var _sink: Self.W

    def __init__(out self, var inner: Self.R, var sink: Self.W):
        self._inner = inner^
        self._sink = sink^

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        # Read from the inner reader, then mirror exactly the bytes delivered.
        # A sink failure surfaces before the result is returned.
        var result = self._inner.read(buf)
        if result.count > 0:
            self._sink.write_all(Span(buf)[0 : result.count])
        return result^

# API-DOCS-START
# TeeReader — mirror every byte read into a second stream.
# Signature:
#   struct TeeReader[R: Stream, W: Sink](Reader):
#       var _inner: Self.R
#       var _sink: Self.W
#       def __init__(out self, var inner: Self.R, var sink: Self.W)
#       def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
# What it does:
#   Every byte read from the inner reader is also written to the sink, which is
#   useful for hashing or logging a stream as it is consumed. The ReadResult from
#   the inner reader is returned after the bytes are mirrored; if the sink write
#   fails the read is not delivered. It owns both the inner reader and the sink.
#   There is no close.
# Returns:
#   The inner reader's ReadResult; the bytes are written into your buffer.
# Errors:
#   raises IoError — from the inner reader or the sink.
# Example:
#   var tee = TeeReader[SomeReader, SomeWriter](inner, sink)
#   var buf = Array[UInt8, 1024](fill=0)
#   var result = tee.read(buf)     # buf holds the bytes; sink has seen them too
# API-DOCS-END
