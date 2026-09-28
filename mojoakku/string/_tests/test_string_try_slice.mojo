# Concern: `try_slice` — checked byte-range extraction returning Optional, never
# raising (docs block in `../try_slice.mojo`).
#
# Covers the same inputs as `slice` but every invalid range is None: a valid
# range yields Some(view); the empty range is a valid Some; out-of-bounds,
# reversed and mid-codepoint ranges all yield None; None is distinguishable from
# an empty successful slice.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from string import try_slice


def test_try_slice_valid() raises:
    var r = try_slice("hello", 1, 3)
    assert_true(r)
    assert_true(r.value() == "el")


def test_try_slice_empty_range_some() raises:
    var r = try_slice("hello", 2, 2)
    assert_true(r)
    assert_equal(r.value().byte_length(), 0)


def test_try_slice_out_of_bounds_none() raises:
    assert_false(try_slice("hello", 0, 99))
    assert_false(try_slice("hello", -1, 2))


def test_try_slice_reversed_none() raises:
    assert_false(try_slice("hello", 3, 1))


def test_try_slice_non_boundary_none() raises:
    assert_false(try_slice("hé", 0, 2))
    assert_false(try_slice("hé", 2, 3))


def test_try_slice_full_range() raises:
    var r = try_slice("hello", 0, 5)
    assert_true(r)
    assert_true(String(r.value()) == "hello")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
