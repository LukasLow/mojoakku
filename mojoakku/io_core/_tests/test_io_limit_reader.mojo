# Concern: `LimitReader` — reads at most n bytes from an inner reader (docs
# block in `../limit_reader.mojo`).
#
# Covers: the total returned never exceeds the limit; once the limit is
# exhausted it reports `{0, eof: True}`; a negative limit behaves as limit = 0
# (immediate EOF, not a trap); after the limit is reached the inner reader is
# never touched again.
#
# `CountingSource` is a test-local concrete Reader whose read count is recorded
# in a caller-owned counter, so the "never touches inner after limit" contract
# is observable.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from io_core import LimitReader, Reader, ReadResult, IoError, IoErrorKind


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


# CountingSource — yields from an owned list and records how many times its
# read was called.
struct CountingSource[count_origin: Origin[mut=True]](Reader):
    var _data: List[UInt8]
    var _pos: Int
    var _reads: MutSpan[Int, Self.count_origin]

    def __init__(
        out self, var data: List[UInt8], reads: MutSpan[Int, Self.count_origin]
    ):
        self._data = data^
        self._pos = 0
        self._reads = reads

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        self._reads[0] += 1
        var remaining = len(self._data) - self._pos
        if remaining <= 0:
            return ReadResult(0, True)
        var n = len(buf)
        if remaining < n:
            n = remaining
        for i in range(n):
            buf[i] = self._data[self._pos + i]
        self._pos += n
        return ReadResult(n, self._pos >= len(self._data))


def test_limit_reader_reads_at_most_limit() raises:
    # The inner source holds five bytes but the limit is three.
    var counter = Array[Int, 1](fill=0)
    var limited = LimitReader[CountingSource[origin_of(counter)]](
        CountingSource(bytes_of(1, 2, 3, 4, 5), MutSpan(counter)), 3
    )
    var buf = Array[UInt8, 8](fill=0)
    var first = limited.read(buf)
    assert_equal(first.count, 3)
    assert_equal(buf[0], 1)
    assert_equal(buf[2], 3)


def test_limit_reader_exhausted_reports_eof() raises:
    var counter = Array[Int, 1](fill=0)
    var limited = LimitReader[CountingSource[origin_of(counter)]](
        CountingSource(bytes_of(1, 2, 3, 4, 5), MutSpan(counter)), 3
    )
    var buf = Array[UInt8, 8](fill=0)
    var first = limited.read(buf)
    assert_equal(first.count, 3)
    # After the limit is exhausted, the next read reports EOF without touching
    # the inner reader.
    var second = limited.read(buf)
    assert_equal(second.count, 0)
    assert_true(second.eof)


def test_limit_reader_negative_limit_behaves_as_zero() raises:
    # A negative limit is defined to behave as limit = 0: immediate EOF.
    var counter = Array[Int, 1](fill=0)
    var limited = LimitReader[CountingSource[origin_of(counter)]](
        CountingSource(bytes_of(1, 2, 3), MutSpan(counter)), -5
    )
    var buf = Array[UInt8, 8](fill=0)
    var result = limited.read(buf)
    assert_equal(result.count, 0)
    assert_true(result.eof)


def test_limit_reader_never_touches_inner_after_limit() raises:
    # Once the limit is exhausted the wrapper must not call the inner reader
    # again: the read count is 1 after the data read and stays 1 at EOF.
    var counter = Array[Int, 1](fill=0)
    var limited = LimitReader[CountingSource[origin_of(counter)]](
        CountingSource(bytes_of(1, 2, 3, 4, 5), MutSpan(counter)), 2
    )
    var buf = Array[UInt8, 8](fill=0)
    var first = limited.read(buf)
    assert_equal(first.count, 2)
    assert_equal(counter[0], 1)
    var second = limited.read(buf)
    assert_equal(second.count, 0)
    assert_true(second.eof)
    assert_equal(counter[0], 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
