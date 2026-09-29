# Concern: `TeeReader` — mirrors everything read into a writer (docs block in
# `../tee_reader.mojo`).
#
# Covers: every byte read from the inner reader is also written to the sink;
# the ReadResult returned is the inner reader's; a sink write failure raises
# `IoError` (the read is not delivered); an inner reader error surfaces.
#
# `TrackingSink` writes into an externally owned destination so the mirrored
# bytes are observable; `FailingSink` and `FailingReader` assert the two error
# paths.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from io_core import (
    TeeReader,
    SpanCursor,
    Reader,
    ReadResult,
    ByteWriter,
    IoError,
    IoErrorKind,
)


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


# TrackingSink — appends into an externally owned destination and records the
# total written in stats[0].
struct TrackingSink[
    dst_origin: Origin[mut=True], stat_origin: Origin[mut=True]
](ByteWriter):
    var _dst: MutSpan[UInt8, Self.dst_origin]
    var _stats: MutSpan[Int, Self.stat_origin]

    def __init__(
        out self, dst: MutSpan[UInt8, Self.dst_origin], stats: MutSpan[Int, Self.stat_origin]
    ):
        self._dst = dst
        self._stats = stats

    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int:
        var start = self._stats[0]
        for i in range(len(data)):
            self._dst[start + i] = data[i]
        self._stats[0] = start + len(data)
        return len(data)

    def flush(mut self) raises IoError:
        pass


# FailingSink — every write raises.
struct FailingSink(ByteWriter):
    def __init__(out self):
        pass

    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int:
        raise IoError(IoErrorKind.OTHER, "write", "sink failed")

    def flush(mut self) raises IoError:
        raise IoError(IoErrorKind.OTHER, "flush", "sink failed")


# FailingReader — every read raises.
struct FailingReader(Reader):
    def __init__(out self):
        pass

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        raise IoError(IoErrorKind.CLOSED, "read", "inner is closed")


def test_tee_reader_mirrors_read_bytes_to_sink() raises:
    var backing = bytes_of(1, 2, 3)
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 1](fill=0)
    var tee = TeeReader(SpanCursor(Span(backing)), TrackingSink(MutSpan(dst), MutSpan(stats)))
    var buf = Array[UInt8, 8](fill=0)
    var result = tee.read(buf)
    assert_equal(result.count, 3)
    assert_equal(buf[0], 1)
    assert_equal(buf[2], 3)
    assert_equal(stats[0], 3)
    assert_equal(dst[0], 1)
    assert_equal(dst[2], 3)


def test_tee_reader_returns_inner_read_result() raises:
    # The returned result is the inner reader's: a short read is not EOF, and
    # EOF is eventually reported once the inner reader ends.
    var backing = bytes_of(1, 2, 3)
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 1](fill=0)
    var tee = TeeReader(SpanCursor(Span(backing)), TrackingSink(MutSpan(dst), MutSpan(stats)))
    var buf = Array[UInt8, 2](fill=0)
    var first = tee.read(buf)
    assert_equal(first.count, 2)
    assert_false(first.eof)
    var seen = List[UInt8]()
    for i in range(first.count):
        seen.append(buf[i])
    var eof = first.eof
    while not eof:
        var result = tee.read(buf)
        for i in range(result.count):
            seen.append(buf[i])
        eof = result.eof
    assert_equal(seen, bytes_of(1, 2, 3))
    assert_equal(stats[0], 3)


def test_tee_reader_sink_error_surfaces() raises:
    var backing = bytes_of(1, 2, 3)
    var tee = TeeReader(SpanCursor(Span(backing)), FailingSink())
    var buf = Array[UInt8, 8](fill=0)
    var kind = IoErrorKind.CLOSED
    var op = ""
    var caught = False
    try:
        _ = tee.read(buf)
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, IoErrorKind.OTHER)
    assert_equal(op, "write")


def test_tee_reader_inner_error_surfaces() raises:
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 1](fill=0)
    var tee = TeeReader[FailingReader, TrackingSink[origin_of(dst), origin_of(stats)]](
        FailingReader(), TrackingSink(MutSpan(dst), MutSpan(stats))
    )
    var buf = Array[UInt8, 8](fill=0)
    var kind = IoErrorKind.OTHER
    var op = ""
    var caught = False
    try:
        _ = tee.read(buf)
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, IoErrorKind.CLOSED)
    assert_equal(op, "read")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
