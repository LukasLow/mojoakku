# Concern: the `ByteWriter` trait — the one-required-method write contract with
# its provided helpers `write_all` and `flush` (docs block in
# `../byte_writer.mojo`).
#
# Covers: a short `write` return is normal and not an error; `write_all` loops
# until every byte is accepted; `write_all` raises `OTHER` ("write zero") when a
# `write` returns 0 without an error; `write_all` retries `INTERRUPTED` but not
# `WOULD_BLOCK`; `flush` is explicit and fallible, so an implementation's flush
# failure surfaces instead of being swallowed.
#
# The `CollectingSink` fixture below carries a real body so the assertions
# express the documented behaviour; the RED baseline comes from the library's
# own `write_all`/`flush` stubs.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.io_core import ByteWriter, IoError, IoErrorKind


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


# CollectingSink — a concrete ByteWriter that accepts at most `chunk` bytes per
# write (a short write), can inject `INTERRUPTED` or `WOULD_BLOCK`, and can be
# told to always accept zero bytes without an error.
struct CollectingSink(ByteWriter):
    var _data: List[UInt8]
    var _chunk: Int
    var _interrupts: Int
    var _would_blocks: Int
    var _zero: Bool
    var _flush_error: Bool

    def __init__(
        out self,
        chunk: Int = 1073741824,
        interrupts: Int = 0,
        would_blocks: Int = 0,
        zero: Bool = False,
        flush_error: Bool = False,
    ):
        self._data = List[UInt8]()
        self._chunk = chunk
        self._interrupts = interrupts
        self._would_blocks = would_blocks
        self._zero = zero
        self._flush_error = flush_error

    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int:
        if self._interrupts > 0:
            self._interrupts -= 1
            raise IoError(IoErrorKind.INTERRUPTED, "write", "injected interrupt")
        if self._would_blocks > 0:
            self._would_blocks -= 1
            raise IoError(IoErrorKind.WOULD_BLOCK, "write", "injected would-block")
        if self._zero:
            return 0
        var n = len(data)
        if self._chunk < n:
            n = self._chunk
        for i in range(n):
            self._data.append(data[i])
        return n

    def flush(mut self) raises IoError:
        if self._flush_error:
            raise IoError(IoErrorKind.CLOSED, "flush", "handle is closed")

    def written(self) -> List[UInt8]:
        return self._data.copy()


def test_write_short_write_is_not_error() raises:
    # The sink accepts at most two of the three bytes; the short return is
    # normal and is not an error. The caller continues with write_all, which
    # must loop until the rest is accepted.
    var sink = CollectingSink(chunk=2)
    var data = bytes_of(1, 2, 3)
    var accepted = sink.write(Span(data))
    assert_equal(accepted, 2)
    var rest = bytes_of(3)
    sink.write_all(Span(rest))
    assert_equal(sink.written(), bytes_of(1, 2, 3))


def test_write_all_loops_until_written() raises:
    # The sink accepts two bytes per call; write_all loops until all are in.
    var sink = CollectingSink(chunk=2)
    var data = bytes_of(1, 2, 3, 4, 5)
    sink.write_all(Span(data))
    assert_equal(sink.written(), bytes_of(1, 2, 3, 4, 5))


def test_write_all_raises_other_on_zero_write() raises:
    # A write that accepts nothing without an error must not make write_all
    # spin: it raises OTHER ("write zero").
    var sink = CollectingSink(zero=True)
    var data = bytes_of(1, 2, 3)
    var kind = IoErrorKind.UNEXPECTED_EOF
    var caught = False
    try:
        sink.write_all(Span(data))
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, IoErrorKind.OTHER)
    assert_equal(len(sink.written()), 0)


def test_write_all_retries_interrupted() raises:
    # The sink interrupts once before accepting; write_all retries and still
    # writes every byte.
    var sink = CollectingSink(interrupts=1)
    var data = bytes_of(7, 8, 9)
    sink.write_all(Span(data))
    assert_equal(sink.written(), bytes_of(7, 8, 9))


def test_write_all_does_not_retry_would_block() raises:
    # Only INTERRUPTED is retried; WOULD_BLOCK is surfaced, never retried
    # (retrying would spin on a non-blocking handle).
    var sink = CollectingSink(would_blocks=1)
    var data = bytes_of(7, 8, 9)
    var kind = IoErrorKind.OTHER
    var op = ""
    var caught = False
    try:
        sink.write_all(Span(data))
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, IoErrorKind.WOULD_BLOCK)
    assert_equal(op, "write")
    assert_equal(len(sink.written()), 0)


def test_flush_reports_error() raises:
    # flush is explicit and fallible; a failing implementation surfaces its
    # error (including the operation name) instead of swallowing it.
    var sink = CollectingSink(flush_error=True)
    var kind = IoErrorKind.OTHER
    var op = ""
    var caught = False
    try:
        sink.flush()
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, IoErrorKind.CLOSED)
    assert_equal(op, "flush")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
