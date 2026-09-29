# Concern: `is_char_boundary` — is a byte index a valid codepoint start (or the
# end)? (docs block in `../is_char_boundary.mojo`).
#
# Covers: index 0 is a boundary; the end (`byte_length()`) is a boundary; every
# index in pure ASCII is a boundary; the first byte of a multi-byte codepoint is
# a boundary while its continuation bytes are not; a negative index and an index
# past the end are False rather than errors; the empty string's only boundary is
# index 0.

from std.testing import assert_true, assert_false, TestSuite
from text_string import is_char_boundary


def test_is_char_boundary_start_true() raises:
    assert_true(is_char_boundary("hello", 0))
    assert_true(is_char_boundary("", 0))


def test_is_char_boundary_end_true() raises:
    assert_true(is_char_boundary("hello", 5))
    assert_true(is_char_boundary("hé", 3))


def test_is_char_boundary_ascii_all() raises:
    var s = String("hello")
    for i in range(6):
        assert_true(is_char_boundary(s, i))


def test_is_char_boundary_continuation_false() raises:
    # "é" is two UTF-8 bytes; index 1 starts it, index 2 is the continuation.
    assert_true(is_char_boundary("hé", 1))
    assert_false(is_char_boundary("hé", 2))
    # A 3-byte codepoint: only its first byte is a boundary.
    assert_true(is_char_boundary("€", 0))
    assert_false(is_char_boundary("€", 1))
    assert_false(is_char_boundary("€", 2))
    assert_true(is_char_boundary("€", 3))


def test_is_char_boundary_negative_false() raises:
    assert_false(is_char_boundary("hi", -1))
    assert_false(is_char_boundary("", -1))


def test_is_char_boundary_past_end_false() raises:
    assert_false(is_char_boundary("hi", 3))
    assert_false(is_char_boundary("hi", 999))
    assert_false(is_char_boundary("", 1))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
