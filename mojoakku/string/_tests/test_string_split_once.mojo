# Concern: `split_once` — split at the FIRST separator into an Optional
# `(before, after)` pair of views (docs block in `../split_once.mojo`).
#
# Covers: the pair at the first separator; a second separator stays inside
# `after`; absence yields None; an empty separator yields None (no defined
# split); both halves are VIEWS into the input, so slicing a longer string
# leaves the surrounding bytes untouched and allocates nothing.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from string import split_once

def test_split_once_basic() raises:
    var r = split_once("a=b", "=")
    assert_true(r)
    var pair = r.value()
    assert_true(pair[0] == "a")
    assert_true(pair[1] == "b")


def test_split_once_first_separator() raises:
    # Only the first separator splits; a later one stays inside `after`.
    var r = split_once("a=b=c", "=")
    assert_true(r)
    var pair = r.value()
    assert_true(pair[0] == "a")
    assert_true(pair[1] == "b=c")


def test_split_once_absent_is_none() raises:
    assert_false(split_once("abc", "="))
    assert_false(split_once("", "="))


def test_split_once_empty_separator_is_none() raises:
    # An empty separator has no defined split.
    assert_false(split_once("abc", ""))


def test_split_once_leading_and_trailing_separator() raises:
    # A separator at the very front gives an empty `before`; at the very end an
    # empty `after` — both are valid pairs, not None.
    var lead = split_once("=b", "=")
    assert_true(lead)
    assert_true(lead.value()[0] == "")
    assert_true(lead.value()[1] == "b")

    var trail = split_once("a=", "=")
    assert_true(trail)
    assert_true(trail.value()[0] == "a")
    assert_true(trail.value()[1] == "")


def test_split_once_halves_are_views_into_input() raises:
    # The halves are views, so their byte content is exactly the input slices.
    var r = split_once("hello=world", "=")
    assert_true(r)
    var pair = r.value()
    assert_equal(pair[0].byte_length(), 5)
    assert_equal(pair[1].byte_length(), 5)
    assert_true(String(pair[0]) == "hello")
    assert_true(String(pair[1]) == "world")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
