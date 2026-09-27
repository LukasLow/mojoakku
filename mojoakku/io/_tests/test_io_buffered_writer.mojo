# Concern: `BufferedWriter` — the buffered wrapper with an explicit, fallible
# `flush`/`close` (docs block in `../buffered_writer.mojo`).
#
# Covers: `write` appends and flushes only when the buffer is full; `flush`
# pushes the buffered bytes to the inner writer and calls its flush; a failing
# inner flush surfaces; `close` flushes and marks the writer closed; `close` is
# idempotent; `write`/`flush` after `close` raise `CLOSED`.
#
# `TrackingSink` is a test-local concrete ByteWriter whose observable state
# (written bytes, flush count) lives in caller-owned spans, so a test can see
# what actually reached the inner writer while the wrapper still owns it.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from io import BufferedWriter, ByteWriter, IoError, IoErrorKind


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


# TrackingSink — appends bytes into an externally owned destination and records
# the total written and the flush count in an externally owned stats array:
#   stats[0] = bytes written
#   stats[1] = flush calls
# It can fail its flush to exercise the explicit, fallible contract.
struct TrackingSink[
    dst_origin: Origin[mut=True], stat_origin: Origin[mut=True]
](ByteWriter):
    var _dst: MutSpan[UInt8, Self.dst_origin]
    var _stats: MutSpan[Int, Self.stat_origin]
    var _fail_flush: Bool

    def __init__(
        out self,
        dst: MutSpan[UInt8, Self.dst_origin],
        stats: MutSpan[Int, Self.stat_origin],
        fail_flush: Bool = False,
    ):
        self._dst = dst
        self._stats = stats
        self._fail_flush = fail_flush

    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int:
        var start = self._stats[0]
        for i in range(len(data)):
            self._dst[start + i] = data[i]
        self._stats[0] = start + len(data)
        return len(data)

    def flush(mut self) raises IoError:
        self._stats[1] += 1
        if self._fail_flush:
            raise IoError(IoErrorKind.CLOSED, "flush", "handle is closed")


def test_buffered_writer_flushes_when_full() raises:
    # Capacity 4, five bytes written: the buffer cannot hold them all, so at
    # least a full buffer must already have reached the inner writer before any
    # explicit flush. write_all drives the (possibly short) write loop.
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 2](fill=0)
    var writer = BufferedWriter[
        TrackingSink[origin_of(dst), origin_of(stats)], 4
    ](TrackingSink(MutSpan(dst), MutSpan(stats)))
    var data = bytes_of(1, 2, 3, 4, 5)
    writer.write_all(Span(data))
    assert_true(stats[0] >= 4)
    writer.flush()
    assert_equal(stats[0], 5)
    assert_equal(dst[0], 1)
    assert_equal(dst[4], 5)


def test_buffered_writer_flush_writes_to_inner() raises:
    # Capacity 8, three bytes written: they stay buffered until the explicit
    # flush, which writes them and calls the inner flush.
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 2](fill=0)
    var writer = BufferedWriter[
        TrackingSink[origin_of(dst), origin_of(stats)], 8
    ](TrackingSink(MutSpan(dst), MutSpan(stats)))
    var data = bytes_of(1, 2, 3)
    _ = writer.write(Span(data))
    assert_equal(stats[0], 0)
    assert_equal(stats[1], 0)
    writer.flush()
    assert_equal(stats[0], 3)
    assert_equal(stats[1], 1)
    assert_equal(dst[0], 1)
    assert_equal(dst[2], 3)


def test_buffered_writer_flush_reports_inner_error() raises:
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 2](fill=0)
    var writer = BufferedWriter[
        TrackingSink[origin_of(dst), origin_of(stats)], 8
    ](TrackingSink(MutSpan(dst), MutSpan(stats), fail_flush=True))
    _ = writer.write(Span(bytes_of(1)))
    var kind = IoErrorKind.OTHER
    var op = ""
    var caught = False
    try:
        writer.flush()
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, IoErrorKind.CLOSED)
    assert_equal(op, "flush")


def test_buffered_writer_close_flushes_and_marks_closed() raises:
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 2](fill=0)
    var writer = BufferedWriter[
        TrackingSink[origin_of(dst), origin_of(stats)], 8
    ](TrackingSink(MutSpan(dst), MutSpan(stats)))
    _ = writer.write(Span(bytes_of(1, 2, 3)))
    writer.close()
    assert_equal(stats[0], 3)
    assert_equal(stats[1], 1)
    assert_equal(dst[0], 1)
    assert_equal(dst[2], 3)


def test_buffered_writer_close_is_idempotent() raises:
    # A second close must not raise and must not replay the buffered data or
    # flush again.
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 2](fill=0)
    var writer = BufferedWriter[
        TrackingSink[origin_of(dst), origin_of(stats)], 8
    ](TrackingSink(MutSpan(dst), MutSpan(stats)))
    _ = writer.write(Span(bytes_of(1, 2, 3)))
    writer.close()
    writer.close()
    assert_equal(stats[0], 3)
    assert_equal(stats[1], 1)


def test_buffered_writer_after_close_raises_closed() raises:
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 2](fill=0)
    var writer = BufferedWriter[
        TrackingSink[origin_of(dst), origin_of(stats)], 8
    ](TrackingSink(MutSpan(dst), MutSpan(stats)))
    writer.close()

    var write_kind = IoErrorKind.OTHER
    var write_caught = False
    try:
        _ = writer.write(Span(bytes_of(1)))
    except e:
        write_caught = True
        write_kind = e.kind
    assert_true(write_caught)
    assert_equal(write_kind, IoErrorKind.CLOSED)

    var flush_kind = IoErrorKind.OTHER
    var flush_caught = False
    try:
        writer.flush()
    except e:
        flush_caught = True
        flush_kind = e.kind
    assert_true(flush_caught)
    assert_equal(flush_kind, IoErrorKind.CLOSED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
