# Concern: `ReadResult` and the `Reader` trait — the explicit read outcome and
# the one-required-method read contract with its provided helpers `read_exact`
# and `read_to_end` (docs blocks in `../read_result.mojo`, `../reader.mojo`).
#
# Covers: the three documented result shapes (data+eof, zero+eof, short read
# is not eof); a `count = 0, eof = False` read is rejected by the helpers as
# `OTHER`; `ReadResult` prints count and eof; `read` fills at most `len(buf)`;
# `read_exact` raises `UNEXPECTED_EOF` on premature EOF, retries `INTERRUPTED`,
# and does NOT retry `WOULD_BLOCK`; `read_to_end` reads until eof and raises
# `OTHER` on no progress.
#
# The `ScriptedReader` below is a test-local concrete `Reader` used to drive the
# provided helpers. Its body is real (not a stub) so the assertions express the
# documented behaviour; the RED baseline comes from the library's own
# `read_exact`/`read_to_end`/`write_to` stubs.

from std.testing import assert_equal, assert_not_equal, assert_true, assert_false, TestSuite
from io_core import ReadResult, Reader, IoError, IoErrorKind


# Byte helper — a list literal is an `Array` in Mojo 1.x, so tests build a
# `List[UInt8]` explicitly.
def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


# ScriptedReader — a concrete Reader that returns at most `chunk` bytes per
# call, can inject `INTERRUPTED` before a read, can inject `WOULD_BLOCK`, and
# can be made to report `{0, False}` forever (a non-conforming reader) to
# exercise the helpers' no-progress guard.
struct ScriptedReader(Reader):
    var _data: List[UInt8]
    var _pos: Int
    var _chunk: Int
    var _interrupts: Int
    var _would_blocks: Int
    var _no_progress: Bool

    def __init__(
        out self,
        var data: List[UInt8],
        chunk: Int = 1073741824,
        interrupts: Int = 0,
        would_blocks: Int = 0,
        no_progress: Bool = False,
    ):
        self._data = data^
        self._pos = 0
        self._chunk = chunk
        self._interrupts = interrupts
        self._would_blocks = would_blocks
        self._no_progress = no_progress

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        if self._interrupts > 0:
            self._interrupts -= 1
            raise IoError(IoErrorKind.INTERRUPTED, "read", "injected interrupt")
        if self._would_blocks > 0:
            self._would_blocks -= 1
            raise IoError(IoErrorKind.WOULD_BLOCK, "read", "injected would-block")
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


# --- ReadResult -----------------------------------------------------------


def test_read_result_data_then_eof() raises:
    # count > 0, eof = True — the final bytes, source ended in the call.
    var result = ReadResult(3, True)
    assert_equal(result.count, 3)
    assert_true(result.eof)


def test_read_result_zero_count_is_eof() raises:
    # count = 0, eof = True — end of input, no bytes.
    var result = ReadResult(0, True)
    assert_equal(result.count, 0)
    assert_true(result.eof)


def test_read_result_short_read_is_not_eof() raises:
    # count > 0, eof = False — a short read is normal, not EOF.
    var result = ReadResult(2, False)
    assert_equal(result.count, 2)
    assert_false(result.eof)


def test_read_result_zero_false_is_rejected_by_helpers() raises:
    # A non-conforming read of {0, False} must not make the helpers spin; both
    # read_exact and read_to_end report it as OTHER.
    var buf = Array[UInt8, 4](fill=0)
    var exact_reader = ScriptedReader(bytes_of(), no_progress=True)
    var exact_kind = IoErrorKind.UNEXPECTED_EOF
    var exact_caught = False
    try:
        exact_reader.read_exact(buf)
    except e:
        exact_caught = True
        exact_kind = e.kind
    assert_true(exact_caught)
    assert_equal(exact_kind, IoErrorKind.OTHER)

    var end_reader = ScriptedReader(bytes_of(), no_progress=True)
    var end_kind = IoErrorKind.UNEXPECTED_EOF
    var end_caught = False
    try:
        _ = end_reader.read_to_end()
    except e:
        end_caught = True
        end_kind = e.kind
    assert_true(end_caught)
    assert_equal(end_kind, IoErrorKind.OTHER)


def test_read_result_write_to_reports_count_and_eof() raises:
    # The diagnostic string carries the count and distinguishes an EOF result
    # from a non-EOF one (exact wording is not part of the API surface).
    var with_eof = String(ReadResult(3, True))
    var without_eof = String(ReadResult(3, False))
    assert_true("3" in with_eof)
    assert_true("3" in without_eof)
    assert_not_equal(with_eof, without_eof)


# --- Reader ---------------------------------------------------------------


def test_read_short_read_is_not_eof() raises:
    # Five bytes, but the reader yields at most two per call.
    var reader = ScriptedReader(bytes_of(1, 2, 3, 4, 5), chunk=2)
    var buf = Array[UInt8, 8](fill=0)
    var result = reader.read(buf)
    assert_equal(result.count, 2)
    assert_false(result.eof)
    assert_equal(buf[0], 1)
    assert_equal(buf[1], 2)


def test_read_fills_at_most_len_buf() raises:
    # Five bytes available, but the destination holds only two; the reader must
    # never report more than len(buf) and must not touch beyond it.
    var reader = ScriptedReader(bytes_of(9, 8, 7, 6, 5))
    var buf = Array[UInt8, 2](fill=0)
    var result = reader.read(buf)
    assert_equal(result.count, 2)
    assert_false(result.eof)
    assert_equal(buf[0], 9)
    assert_equal(buf[1], 8)


def test_read_exact_raises_unexpected_eof() raises:
    # Three bytes available, five requested: the stream ends before the buffer
    # is filled, so read_exact raises UNEXPECTED_EOF.
    var reader = ScriptedReader(bytes_of(1, 2, 3))
    var buf = Array[UInt8, 5](fill=0)
    var kind = IoErrorKind.OTHER
    var caught = False
    try:
        reader.read_exact(buf)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, IoErrorKind.UNEXPECTED_EOF)


def test_read_exact_retries_interrupted() raises:
    # The reader interrupts once before delivering its bytes; read_exact retries
    # internally and still fills the buffer.
    var reader = ScriptedReader(bytes_of(4, 5, 6), interrupts=1)
    var buf = Array[UInt8, 3](fill=0)
    reader.read_exact(buf)
    assert_equal(buf[0], 4)
    assert_equal(buf[1], 5)
    assert_equal(buf[2], 6)


def test_read_exact_does_not_retry_would_block() raises:
    # Only INTERRUPTED is retried; WOULD_BLOCK is surfaced, never hidden or
    # retried (which would hang on a non-blocking handle).
    var reader = ScriptedReader(bytes_of(4, 5, 6), would_blocks=1)
    var buf = Array[UInt8, 3](fill=0)
    var kind = IoErrorKind.OTHER
    var op = ""
    var caught = False
    try:
        reader.read_exact(buf)
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, IoErrorKind.WOULD_BLOCK)
    assert_equal(op, "read")


def test_read_to_end_reads_until_eof() raises:
    var reader = ScriptedReader(bytes_of(1, 2, 3, 4, 5), chunk=2)
    var all = reader.read_to_end()
    assert_equal(len(all), 5)
    assert_equal(all[0], 1)
    assert_equal(all[4], 5)


def test_read_to_end_raises_other_on_no_progress() raises:
    # A reader that always answers {0, False} must make read_to_end raise OTHER
    # rather than loop forever.
    var reader = ScriptedReader(bytes_of(), no_progress=True)
    var kind = IoErrorKind.UNEXPECTED_EOF
    var caught = False
    try:
        _ = reader.read_to_end()
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, IoErrorKind.OTHER)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
