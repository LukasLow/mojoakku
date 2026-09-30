# Concern: `copy` — pumps a reader into a writer until EOF (docs block in
# `../copy.mojo`).
#
# Covers: the reader is drained into the writer until it reports eof; the
# returned Int is the total number of bytes copied; short reads and short
# writes are handled internally by continuing the loop; `INTERRUPTED` is
# retried on either side but `WOULD_BLOCK` is not; when a side fails, the raised
# `IoError` has an `op` naming which side failed; on a mid-copy failure no count
# is returned while the writer keeps the chunks already written.
#
# `ScriptedReader` and `TrackingSink` are test-local concrete streams with real
# bodies, so the assertions express the documented pump behaviour.

from std.testing import assert_equal, assert_true, TestSuite
from akku.io_core import copy, Reader, ReadResult, ByteWriter, IoError, IoErrorKind


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


# ScriptedReader — yields from an owned list, at most `chunk` bytes per call,
# and can inject `INTERRUPTED` or `WOULD_BLOCK` before a read.
struct ScriptedReader(Reader):
    var _data: List[UInt8]
    var _pos: Int
    var _chunk: Int
    var _interrupts: Int
    var _would_blocks: Int

    def __init__(
        out self,
        var data: List[UInt8],
        chunk: Int = 1073741824,
        interrupts: Int = 0,
        would_blocks: Int = 0,
    ):
        self._data = data^
        self._pos = 0
        self._chunk = chunk
        self._interrupts = interrupts
        self._would_blocks = would_blocks

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        if self._interrupts > 0:
            self._interrupts -= 1
            raise IoError(IoErrorKind.INTERRUPTED, "read", "injected interrupt")
        if self._would_blocks > 0:
            self._would_blocks -= 1
            raise IoError(IoErrorKind.WOULD_BLOCK, "read", "injected would-block")
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


# TrackingSink — accepts at most `chunk` bytes per call into an externally
# owned destination and records the total in stats[0]; can inject `INTERRUPTED`
# or `WOULD_BLOCK`.
struct TrackingSink[
    dst_origin: Origin[mut=True], stat_origin: Origin[mut=True]
](ByteWriter):
    var _dst: MutSpan[UInt8, Self.dst_origin]
    var _stats: MutSpan[Int, Self.stat_origin]
    var _chunk: Int
    var _interrupts: Int
    var _would_blocks: Int

    def __init__(
        out self,
        dst: MutSpan[UInt8, Self.dst_origin],
        stats: MutSpan[Int, Self.stat_origin],
        chunk: Int = 1073741824,
        interrupts: Int = 0,
        would_blocks: Int = 0,
    ):
        self._dst = dst
        self._stats = stats
        self._chunk = chunk
        self._interrupts = interrupts
        self._would_blocks = would_blocks

    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int:
        if self._interrupts > 0:
            self._interrupts -= 1
            raise IoError(IoErrorKind.INTERRUPTED, "write", "injected interrupt")
        if self._would_blocks > 0:
            self._would_blocks -= 1
            raise IoError(IoErrorKind.WOULD_BLOCK, "write", "injected would-block")
        var n = len(data)
        if self._chunk < n:
            n = self._chunk
        var start = self._stats[0]
        for i in range(n):
            self._dst[start + i] = data[i]
        self._stats[0] = start + n
        return n

    def flush(mut self) raises IoError:
        pass


# FailingReader / FailingSink — assert which side the raised error names.
struct FailingReader(Reader):
    def __init__(out self):
        pass

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        raise IoError(IoErrorKind.OTHER, "read", "reader failed")


struct FailingSink(ByteWriter):
    def __init__(out self):
        pass

    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int:
        raise IoError(IoErrorKind.OTHER, "write", "sink failed")

    def flush(mut self) raises IoError:
        pass


# FailOnSecondWriteSink — records the first accepted chunk into an externally
# owned destination, then fails on the next write. Used to prove that copy
# returns no count on failure while the already-written chunk is retained.
struct FailOnSecondWriteSink[
    dst_origin: Origin[mut=True], stat_origin: Origin[mut=True]
](ByteWriter):
    var _dst: MutSpan[UInt8, Self.dst_origin]
    var _stats: MutSpan[Int, Self.stat_origin]
    var _writes: Int

    def __init__(
        out self,
        dst: MutSpan[UInt8, Self.dst_origin],
        stats: MutSpan[Int, Self.stat_origin],
    ):
        self._dst = dst
        self._stats = stats
        self._writes = 0

    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int:
        self._writes += 1
        if self._writes > 1:
            raise IoError(IoErrorKind.OTHER, "write", "sink failed after first chunk")
        var start = self._stats[0]
        for i in range(len(data)):
            self._dst[start + i] = data[i]
        self._stats[0] = start + len(data)
        return len(data)

    def flush(mut self) raises IoError:
        pass


def test_copy_pumps_until_eof() raises:
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 1](fill=0)
    var reader = ScriptedReader(bytes_of(1, 2, 3, 4, 5))
    var sink = TrackingSink(MutSpan(dst), MutSpan(stats))
    var copied = copy(reader, sink)
    assert_equal(copied, 5)
    assert_equal(stats[0], 5)
    assert_equal(dst[0], 1)
    assert_equal(dst[4], 5)


def test_copy_returns_total_bytes() raises:
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 1](fill=0)
    var reader = ScriptedReader(bytes_of(7, 8, 9))
    var sink = TrackingSink(MutSpan(dst), MutSpan(stats))
    var copied = copy(reader, sink)
    assert_equal(copied, 3)
    assert_equal(stats[0], 3)


def test_copy_handles_short_reads_and_writes() raises:
    # The reader yields two bytes at a time and the sink accepts one at a time;
    # copy loops internally until all five are written.
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 1](fill=0)
    var reader = ScriptedReader(bytes_of(1, 2, 3, 4, 5), chunk=2)
    var sink = TrackingSink(MutSpan(dst), MutSpan(stats), chunk=1)
    var copied = copy(reader, sink)
    assert_equal(copied, 5)
    assert_equal(stats[0], 5)
    assert_equal(dst[0], 1)
    assert_equal(dst[4], 5)


def test_copy_retries_interrupted() raises:
    # Both sides interrupt once; copy retries and still transfers every byte.
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 1](fill=0)
    var reader = ScriptedReader(bytes_of(1, 2, 3), interrupts=1)
    var sink = TrackingSink(MutSpan(dst), MutSpan(stats), interrupts=1)
    var copied = copy(reader, sink)
    assert_equal(copied, 3)
    assert_equal(stats[0], 3)


def test_copy_does_not_retry_would_block() raises:
    # Only INTERRUPTED is retried; WOULD_BLOCK from the reader is surfaced
    # (retrying would spin on a non-blocking handle).
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 1](fill=0)
    var reader = ScriptedReader(bytes_of(1, 2, 3), would_blocks=1)
    var sink = TrackingSink(MutSpan(dst), MutSpan(stats))
    var kind = IoErrorKind.OTHER
    var op = ""
    var caught = False
    try:
        _ = copy(reader, sink)
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, IoErrorKind.WOULD_BLOCK)
    assert_equal(op, "read")


def test_copy_partial_progress_writer_keeps_first_chunk() raises:
    # A sink that succeeds on the first write then fails: copy raises (no count
    # is returned), but the first chunk is already observable in the writer.
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 1](fill=0)
    # Two-byte chunks force copy into a second write after the first succeeds.
    var reader = ScriptedReader(bytes_of(1, 2, 3, 4), chunk=2)
    var sink = FailOnSecondWriteSink(MutSpan(dst), MutSpan(stats))
    var kind = IoErrorKind.UNEXPECTED_EOF
    var op = ""
    var caught = False
    try:
        _ = copy(reader, sink)
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, IoErrorKind.OTHER)
    assert_equal(op, "write")
    # The partial progress is not returned, but the first chunk is retained.
    assert_equal(stats[0], 2)
    assert_equal(dst[0], 1)
    assert_equal(dst[1], 2)


def test_copy_error_op_names_failing_side() raises:
    var dst = Array[UInt8, 8](fill=0)
    var stats = Array[Int, 1](fill=0)

    var read_op = ""
    var read_caught = False
    try:
        var reader = FailingReader()
        var sink = TrackingSink(MutSpan(dst), MutSpan(stats))
        _ = copy(reader, sink)
    except e:
        read_caught = True
        read_op = e.op
    assert_true(read_caught)
    assert_equal(read_op, "read")

    var write_op = ""
    var write_caught = False
    try:
        var reader = ScriptedReader(bytes_of(1, 2, 3))
        var sink = FailingSink()
        _ = copy(reader, sink)
    except e:
        write_caught = True
        write_op = e.op
    assert_true(write_caught)
    assert_equal(write_op, "write")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
