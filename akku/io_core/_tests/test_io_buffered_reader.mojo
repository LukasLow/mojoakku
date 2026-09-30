# Concern: `BufferedReader` — the buffered wrapper with an inline,
# compile-time-sized buffer (docs block in `../buffered_reader.mojo`).
#
# Covers: reads are served from the internal buffer and only refill the inner
# reader when it is empty; a short inner read is normal; EOF is reported only
# after the inner reader reports EOF AND the buffer is drained; `INTERRUPTED`
# is retried on refill; an inner reader that reports a zero-length non-EOF read
# raises `OTHER`.
#
# `CountingSource` is a test-local concrete Reader with a real body; its read
# count is recorded in a caller-owned counter so a test can tell "served from
# buffer" (no refill) from "refilled". The RED baseline comes from the
# library's own `BufferedReader.__init__`/`read` stubs.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.io_core import BufferedReader, Reader, ReadResult, IoError, IoErrorKind


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


# CountingSource — returns at most `chunk` bytes per call, injects
# `INTERRUPTED` when asked, can report `{0, False}` forever, and records the
# number of inner `read` calls in an externally owned counter.
struct CountingSource[count_origin: Origin[mut=True]](Reader):
    var _data: List[UInt8]
    var _pos: Int
    var _chunk: Int
    var _interrupts: Int
    var _no_progress: Bool
    var _reads: MutSpan[Int, Self.count_origin]

    def __init__(
        out self,
        var data: List[UInt8],
        reads: MutSpan[Int, Self.count_origin],
        chunk: Int = 1073741824,
        interrupts: Int = 0,
        no_progress: Bool = False,
    ):
        self._data = data^
        self._pos = 0
        self._chunk = chunk
        self._interrupts = interrupts
        self._no_progress = no_progress
        self._reads = reads

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        self._reads[0] += 1
        if self._interrupts > 0:
            self._interrupts -= 1
            raise IoError(IoErrorKind.INTERRUPTED, "read", "injected interrupt")
        if self._no_progress:
            return ReadResult(0, False)
        var remaining = len(self._data) - self._pos
        if remaining <= 0:
            return ReadResult(0, True)
        var n = len(buf)
        if remaining < n:
            n = remaining
        if self._chunk < n:
            n = self._chunk
        for i in range(n):
            buf[i] = self._data[self._pos + i]
        self._pos += n
        return ReadResult(n, self._pos >= len(self._data))


def test_buffered_reader_serves_from_buffer() raises:
    # Inner yields four bytes at once; the second caller read must be served
    # from the buffer, so the inner read count stays 1.
    var counter = Array[Int, 1](fill=0)
    var buffered = BufferedReader[
        CountingSource[origin_of(counter)], 4
    ](CountingSource(bytes_of(1, 2, 3, 4), MutSpan(counter)))
    var buf = Array[UInt8, 2](fill=0)
    var first = buffered.read(buf)
    assert_equal(first.count, 2)
    assert_equal(buf[0], 1)
    assert_equal(buf[1], 2)
    var second = buffered.read(buf)
    assert_equal(second.count, 2)
    assert_equal(buf[0], 3)
    assert_equal(buf[1], 4)
    assert_equal(counter[0], 1)


def test_buffered_reader_refills_when_empty() raises:
    # Buffer capacity is two; a third and fourth byte force a second refill.
    var counter = Array[Int, 1](fill=0)
    var buffered = BufferedReader[
        CountingSource[origin_of(counter)], 2
    ](CountingSource(bytes_of(1, 2, 3, 4), MutSpan(counter)))
    var buf = Array[UInt8, 2](fill=0)
    _ = buffered.read(buf)
    _ = buffered.read(buf)
    assert_equal(counter[0], 2)


def test_buffered_reader_short_inner_read_is_normal() raises:
    # The inner reader yields one byte per call; that short read is not EOF and
    # not an error, and draining still yields every byte.
    var counter = Array[Int, 1](fill=0)
    var buffered = BufferedReader[
        CountingSource[origin_of(counter)], 4
    ](CountingSource(bytes_of(1, 2, 3), MutSpan(counter), chunk=1))
    var buf = Array[UInt8, 8](fill=0)
    var first = buffered.read(buf)
    assert_true(first.count >= 1)
    assert_false(first.eof)
    var seen = List[UInt8]()
    for i in range(first.count):
        seen.append(buf[i])
    var eof = first.eof
    while not eof:
        var result = buffered.read(buf)
        for i in range(result.count):
            seen.append(buf[i])
        eof = result.eof
    assert_equal(seen, bytes_of(1, 2, 3))


def test_buffered_reader_eof_only_after_drain() raises:
    # Inner ends in the same call that fills the buffer, but only two of the
    # three bytes are requested first: EOF must wait until the buffer drains.
    var counter = Array[Int, 1](fill=0)
    var buffered = BufferedReader[
        CountingSource[origin_of(counter)], 4
    ](CountingSource(bytes_of(1, 2, 3), MutSpan(counter)))
    var buf = Array[UInt8, 2](fill=0)
    var first = buffered.read(buf)
    assert_equal(first.count, 2)
    assert_false(first.eof)
    var second = buffered.read(buf)
    assert_equal(second.count, 1)
    assert_true(second.eof)
    assert_equal(buf[0], 3)


def test_buffered_reader_retries_interrupted_on_refill() raises:
    # The inner reader interrupts once before its first refill; the wrapper
    # retries and still delivers the bytes.
    var counter = Array[Int, 1](fill=0)
    var buffered = BufferedReader[
        CountingSource[origin_of(counter)], 4
    ](CountingSource(bytes_of(1, 2, 3), MutSpan(counter), interrupts=1))
    var buf = Array[UInt8, 4](fill=0)
    var result = buffered.read(buf)
    assert_equal(result.count, 3)
    assert_equal(buf[0], 1)
    assert_equal(buf[2], 3)


def test_buffered_reader_raises_other_on_no_progress() raises:
    # An inner reader that answers {0, False} must make the wrapper raise OTHER
    # rather than spin.
    var counter = Array[Int, 1](fill=0)
    var buffered = BufferedReader[
        CountingSource[origin_of(counter)], 4
    ](CountingSource(bytes_of(), MutSpan(counter), no_progress=True))
    var buf = Array[UInt8, 4](fill=0)
    var kind = IoErrorKind.UNEXPECTED_EOF
    var caught = False
    try:
        _ = buffered.read(buf)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, IoErrorKind.OTHER)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
