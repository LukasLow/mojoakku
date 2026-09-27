# Concern: `SeekFrom` and the `Seeker` trait — the seek origin value and the
# one-required-method seek contract (docs blocks in `../seek_from.mojo`,
# `../seeker.mojo`).
#
# Covers: the three comptime bases; the signed offset constructors; equality
# compares both origin and offset; `seek` returns the new absolute position;
# past-the-end seeks are allowed; a negative target raises `OTHER`.
#
# The concrete release-1 library call is `Cursor.seek`. The non-seekable and
# closed-handle contracts have no release-1 library target to test: `CLOSED`
# belongs to the future file/socket layer that owns a descriptor, and a
# non-seekable stream is an `OTHER` condition of a future source. Asserting
# those kinds against a test-local fixture would only echo the fixture's own
# hard-coded kind, so they are deliberately not tested here (see the note in
# `_dev/DESIGN.md`, `Seeker`).

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from io import SeekFrom, Cursor, IoErrorKind


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


# --- SeekFrom -------------------------------------------------------------


def test_seek_from_comptime_bases() raises:
    # The three bases are the origin at offset zero.
    assert_true(SeekFrom.START == SeekFrom.start(0))
    assert_true(SeekFrom.CURRENT == SeekFrom.current(0))
    assert_true(SeekFrom.END == SeekFrom.end(0))
    assert_true(SeekFrom.CURRENT == SeekFrom.CURRENT)


def test_seek_from_start_with_offset() raises:
    assert_equal(SeekFrom.start(5).offset, 5)
    assert_equal(SeekFrom.current(3).offset, 3)
    # A non-zero offset differs from the zero-offset base.
    assert_false(SeekFrom.start(5) == SeekFrom.START)


def test_seek_from_end_negative_offset() raises:
    # The offset is signed, so end(-1) means "one byte before the end".
    assert_equal(SeekFrom.end(-1).offset, -1)
    assert_false(SeekFrom.end(-1) == SeekFrom.END)
    assert_false(SeekFrom.end(-1) == SeekFrom.start(-1))


def test_seek_from_eq_compares_offset() raises:
    # Equality compares both the origin and the offset.
    assert_false(SeekFrom.start(5) == SeekFrom.start(6))
    assert_false(SeekFrom.start(0) == SeekFrom.current(0))
    assert_true(SeekFrom.start(5) == SeekFrom.start(5))


# --- Seeker ---------------------------------------------------------------


def test_seek_returns_new_absolute_position() raises:
    var cursor = Cursor(bytes_of(1, 2, 3, 4, 5))
    var pos = cursor.seek(SeekFrom.start(2))
    assert_equal(pos, 2)
    pos = cursor.seek(SeekFrom.START)
    assert_equal(pos, 0)


def test_seek_negative_target_raises_other() raises:
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


def test_seek_past_end_allowed() raises:
    # Seeking past the end is allowed; the resulting position is returned.
    var cursor = Cursor(bytes_of(1, 2, 3))
    var pos = cursor.seek(SeekFrom.start(10))
    assert_equal(pos, 10)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
