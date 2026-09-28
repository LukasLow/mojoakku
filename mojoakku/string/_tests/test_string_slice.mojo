# Concern: `slice` — checked byte-range extraction raising StringError (docs
# block in `../slice.mojo`).
#
# Covers: a mid-string byte range; the empty range (`start == end`) is legal;
# the whole string; a range whose ends are codepoint boundaries across a
# multi-byte codepoint; INDEX_OUT_OF_BOUNDS for `start < 0` or
# `end > byte_length()`; BAD_RANGE for `start > end`; NOT_A_BOUNDARY for an end
# that splits a codepoint; the result is a view into the input (mutating the
# owner is visible through it once implemented — here we assert the documented
# byte content).

from std.testing import assert_equal, assert_true, TestSuite
from string import slice, StringErrorKind


def test_slice_basic() raises:
    assert_true(slice("hello", 1, 3) == "el")
    assert_true(String(slice("hello", 1, 3)) == "el")


def test_slice_empty_range() raises:
    assert_equal(slice("hello", 2, 2).byte_length(), 0)


def test_slice_full_range() raises:
    assert_true(String(slice("hello", 0, 5)) == "hello")
    assert_true(String(slice("", 0, 0)) == "")


def test_slice_on_codepoint_boundaries() raises:
    # "hé": h(0..1) é(1..3); [0:3] is the whole string, [1:3] is "é".
    var s = String("hé")
    assert_true(String(slice(s, 0, 3)) == "hé")
    assert_true(String(slice(s, 1, 3)) == "é")


def test_slice_out_of_bounds_raises() raises:
    var kind = StringErrorKind.INVALID_UTF8
    var caught = False
    try:
        _ = slice("hello", 0, 99)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_true(kind == StringErrorKind.INDEX_OUT_OF_BOUNDS)

    kind = StringErrorKind.INVALID_UTF8
    caught = False
    try:
        _ = slice("hello", -1, 2)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_true(kind == StringErrorKind.INDEX_OUT_OF_BOUNDS)


def test_slice_reversed_raises_bad_range() raises:
    var kind = StringErrorKind.INVALID_UTF8
    var caught = False
    try:
        _ = slice("hello", 3, 1)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_true(kind == StringErrorKind.BAD_RANGE)


def test_slice_non_boundary_raises() raises:
    # "hé": byte 2 is inside 'é'.
    var kind = StringErrorKind.INVALID_UTF8
    var pos = -1
    var caught = False
    try:
        _ = slice("hé", 0, 2)
    except e:
        caught = True
        kind = e.kind
        pos = e.position
    assert_true(caught)
    assert_true(kind == StringErrorKind.NOT_A_BOUNDARY)
    assert_equal(pos, 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
