# Concern: `rsplit_once` — split at the LAST separator into an Optional
# `(before, after)` pair of views (docs block in `../rsplit_once.mojo`).
#
# Covers: the pair at the last separator (so `before` keeps earlier separators);
# a single-separator string behaves like `split_once`; absence yields None; an
# empty separator yields None; both halves are views into the input.

from std.testing import assert_true, assert_false, TestSuite
from text_string import rsplit_once


def test_rsplit_once_basic() raises:
    var r = rsplit_once("a=b=c", "=")
    assert_true(r)
    var pair = r.value()
    assert_true(pair[0] == "a=b")
    assert_true(pair[1] == "c")


def test_rsplit_once_single_separator_matches_split_once() raises:
    var r = rsplit_once("a=b", "=")
    assert_true(r)
    assert_true(r.value()[0] == "a")
    assert_true(r.value()[1] == "b")


def test_rsplit_once_absent_is_none() raises:
    assert_false(rsplit_once("abc", "="))
    assert_false(rsplit_once("", "="))


def test_rsplit_once_empty_separator_is_none() raises:
    assert_false(rsplit_once("abc", ""))


def test_rsplit_once_halves_are_views_into_input() raises:
    var r = rsplit_once("hello=world", "=")
    assert_true(r)
    assert_true(String(r.value()[0]) == "hello")
    assert_true(String(r.value()[1]) == "world")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
