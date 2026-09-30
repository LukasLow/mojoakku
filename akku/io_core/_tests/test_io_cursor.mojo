# Concern: `Cursor` and `SpanCursor` — the owned in-memory reader+writer+seeker
# and its borrowed, read-only counterpart (docs blocks in `../cursor.mojo`,
# `../span_cursor.mojo`).
#
# Covers: read/write move the cursor position; a read at the end reports
# `{0, eof: True}`; an out-of-range (negative) seek raises `OTHER`; `Cursor`
# owns its `List`; `SpanCursor` reads and seeks over borrowed data, never owns
# or mutates it, has no `write` (a type-level property), and reports EOF at its
# end.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.io_core import (
    Cursor,
    SpanCursor,
    SeekFrom,
    Reader,
    ByteWriter,
    Seeker,
    IoErrorKind,
)


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


# --- Cursor ---------------------------------------------------------------


def test_cursor_read_moves_position() raises:
    var cursor = Cursor(bytes_of(1, 2, 3, 4, 5))
    var buf = Array[UInt8, 3](fill=0)
    var result = cursor.read(buf)
    assert_equal(result.count, 3)
    assert_false(result.eof)
    assert_equal(buf[0], 1)
    assert_equal(buf[1], 2)
    assert_equal(buf[2], 3)
    # The next read continues from the moved position and consumes the rest.
    var second = cursor.read(buf)
    assert_equal(second.count, 2)
    assert_equal(buf[0], 4)
    assert_equal(buf[1], 5)
    # A read at the end reports EOF.
    var third = cursor.read(buf)
    assert_equal(third.count, 0)
    assert_true(third.eof)


def test_cursor_read_at_end_reports_eof() raises:
    var cursor = Cursor(bytes_of(1, 2, 3))
    var buf = Array[UInt8, 8](fill=0)
    _ = cursor.read(buf)
    var result = cursor.read(buf)
    assert_equal(result.count, 0)
    assert_true(result.eof)


def test_cursor_write_moves_position() raises:
    var cursor = Cursor(bytes_of())
    var data = bytes_of(1, 2, 3)
    var accepted = cursor.write(Span(data))
    assert_equal(accepted, 3)
    # The next read starts after what was written.
    var buf = Array[UInt8, 8](fill=0)
    var result = cursor.read(buf)
    assert_equal(result.count, 0)
    assert_true(result.eof)


def test_cursor_seek_out_of_range_raises_other() raises:
    var cursor = Cursor(bytes_of(1, 2, 3))
    var kind = IoErrorKind.CLOSED
    var caught = False
    try:
        _ = cursor.seek(SeekFrom.start(-1))
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, IoErrorKind.OTHER)


def test_cursor_owns_buffer() raises:
    # Cursor is constructed from an owned List and keeps the data alive.
    var owned = bytes_of(10, 20, 30)
    var cursor = Cursor(owned^)
    var buf = Array[UInt8, 3](fill=0)
    var result = cursor.read(buf)
    assert_equal(result.count, 3)
    assert_equal(buf[0], 10)
    assert_equal(buf[2], 30)


# --- SpanCursor -----------------------------------------------------------


def test_span_cursor_read_moves_position() raises:
    var backing = bytes_of(1, 2, 3, 4, 5)
    var cursor = SpanCursor(Span(backing))
    var buf = Array[UInt8, 3](fill=0)
    var result = cursor.read(buf)
    assert_equal(result.count, 3)
    assert_false(result.eof)
    assert_equal(buf[0], 1)
    assert_equal(buf[2], 3)
    var second = cursor.read(buf)
    assert_equal(second.count, 2)
    assert_equal(buf[0], 4)
    assert_equal(buf[1], 5)
    # A read at the end reports EOF.
    var third = cursor.read(buf)
    assert_equal(third.count, 0)
    assert_true(third.eof)


def test_span_cursor_read_at_end_reports_eof() raises:
    var backing = bytes_of(1, 2, 3)
    var cursor = SpanCursor(Span(backing))
    var buf = Array[UInt8, 8](fill=0)
    _ = cursor.read(buf)
    var result = cursor.read(buf)
    assert_equal(result.count, 0)
    assert_true(result.eof)


def test_span_cursor_has_no_write() raises:
    # "Read-only" is a type-level property: SpanCursor does not conform to
    # ByteWriter at all.
    assert_false(conforms_to(SpanCursor, ByteWriter))
    assert_true(conforms_to(SpanCursor, Reader))
    assert_true(conforms_to(SpanCursor, Seeker))


def test_span_cursor_seek_out_of_range_raises_other() raises:
    var backing = bytes_of(1, 2, 3)
    var cursor = SpanCursor(Span(backing))
    var kind = IoErrorKind.CLOSED
    var caught = False
    try:
        _ = cursor.seek(SeekFrom.start(-1))
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, IoErrorKind.OTHER)


def test_span_cursor_borrows_buffer() raises:
    # The cursor never owns or mutates the data; reading it leaves the source
    # list untouched.
    var backing = bytes_of(1, 2, 3)
    var cursor = SpanCursor(Span(backing))
    var buf = Array[UInt8, 3](fill=0)
    _ = cursor.read(buf)
    assert_equal(buf[0], 1)
    assert_equal(backing, bytes_of(1, 2, 3))
    # Seeking is allowed over the borrowed data.
    assert_equal(cursor.seek(SeekFrom.START), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
