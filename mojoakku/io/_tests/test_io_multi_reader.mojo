# Concern: `MultiReader` — concatenates a homogeneous set of readers (docs
# block in `../multi_reader.mojo`).
#
# Covers: readers are read in order; when the current reader reports EOF the
# wrapper advances to the next and retries; EOF is reported only after the last
# reader ends; the variadic constructor accepts any number of homogeneous
# readers; an error from the active reader surfaces.
#
# `ScriptedReader` is a test-local concrete Reader with a real body;
# `FailingReader` asserts the active-reader error path.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from io import MultiReader, Reader, ReadResult, IoError, IoErrorKind


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


# ScriptedReader — yields from an owned list, at most `chunk` bytes per call.
struct ScriptedReader(Reader):
    var _data: List[UInt8]
    var _pos: Int
    var _chunk: Int

    def __init__(
        out self, var data: List[UInt8], chunk: Int = 1073741824
    ):
        self._data = data^
        self._pos = 0
        self._chunk = chunk

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
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


# FailingReader — every read raises.
struct FailingReader(Reader):
    def __init__(out self):
        pass

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult:
        raise IoError(IoErrorKind.OTHER, "read", "active reader failed")


def test_multi_reader_concatenates_in_order() raises:
    var multi = MultiReader[ScriptedReader](
        ScriptedReader(bytes_of(1, 2), chunk=2), ScriptedReader(bytes_of(3, 4, 5), chunk=2)
    )
    var seen = List[UInt8]()
    var buf = Array[UInt8, 8](fill=0)
    var result = multi.read(buf)
    while not result.eof:
        for i in range(result.count):
            seen.append(buf[i])
        result = multi.read(buf)
    assert_equal(seen, bytes_of(1, 2, 3, 4, 5))


def test_multi_reader_advances_on_inner_eof() raises:
    # The first reader is already empty and reports EOF immediately; the same
    # read must advance to the second and return its bytes (not {0, True}).
    var multi = MultiReader[ScriptedReader](
        ScriptedReader(bytes_of()), ScriptedReader(bytes_of(7, 8))
    )
    var buf = Array[UInt8, 8](fill=0)
    var result = multi.read(buf)
    assert_equal(result.count, 2)
    assert_equal(buf[0], 7)
    assert_equal(buf[1], 8)


def test_multi_reader_eof_only_after_last_reader() raises:
    # The first reader still has bytes after its first (short) call, so EOF
    # must not be reported until every reader has ended.
    var multi = MultiReader[ScriptedReader](
        ScriptedReader(bytes_of(1, 2), chunk=1), ScriptedReader(bytes_of(3))
    )
    var seen = List[UInt8]()
    var buf = Array[UInt8, 8](fill=0)
    var first = multi.read(buf)
    assert_equal(first.count, 1)
    assert_false(first.eof)
    for i in range(first.count):
        seen.append(buf[i])
    var eof = first.eof
    while not eof:
        var result = multi.read(buf)
        for i in range(result.count):
            seen.append(buf[i])
        eof = result.eof
    assert_equal(seen, bytes_of(1, 2, 3))


def test_multi_reader_variadic_construct() raises:
    # Three readers are accepted and read in order.
    var multi = MultiReader[ScriptedReader](
        ScriptedReader(bytes_of(1)),
        ScriptedReader(bytes_of(2)),
        ScriptedReader(bytes_of(3)),
    )
    var seen = List[UInt8]()
    var buf = Array[UInt8, 8](fill=0)
    var result = multi.read(buf)
    while not result.eof:
        for i in range(result.count):
            seen.append(buf[i])
        result = multi.read(buf)
    assert_equal(seen, bytes_of(1, 2, 3))


def test_multi_reader_active_reader_error_surfaces() raises:
    var multi = MultiReader[FailingReader](FailingReader())
    var buf = Array[UInt8, 8](fill=0)
    var kind = IoErrorKind.CLOSED
    var op = ""
    var caught = False
    try:
        _ = multi.read(buf)
    except e:
        caught = True
        kind = e.kind
        op = e.op
    assert_true(caught)
    assert_equal(kind, IoErrorKind.OTHER)
    assert_equal(op, "read")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
