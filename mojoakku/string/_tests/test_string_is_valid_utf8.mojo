# Concern: `is_valid_utf8` — allocation-free validity predicate over raw bytes
# (docs block in `../is_valid_utf8.mojo`).
#
# Covers: ASCII is valid; 2/3/4-byte sequences are valid; an empty span is
# valid; a truncated multi-byte sequence is invalid; a lone continuation byte is
# invalid; an overlong form is invalid; a surrogate encoding is invalid; a value
# above U+10FFFF is invalid. The predicate never raises.

from std.testing import assert_true, assert_false, TestSuite
from string import is_valid_utf8


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for v in values:
        out.append(v)
    return out^


def test_is_valid_utf8_ascii() raises:
    assert_true(is_valid_utf8(Span(bytes_of(104, 105))))            # "hi"
    assert_true(is_valid_utf8(Span(bytes_of(0))))                   # NUL


def test_is_valid_utf8_multibyte() raises:
    # 2-byte 'é', 3-byte '€', 4-byte U+1F44B.
    assert_true(is_valid_utf8(Span(bytes_of(0xC3, 0xA9))))
    assert_true(is_valid_utf8(Span(bytes_of(0xE2, 0x82, 0xAC))))
    assert_true(is_valid_utf8(Span(bytes_of(0xF0, 0x9F, 0x91, 0x8B))))


def test_is_valid_utf8_empty_true() raises:
    assert_true(is_valid_utf8(Span(List[UInt8]())))


def test_is_valid_utf8_truncated_false() raises:
    # A leading byte without the required continuation bytes.
    assert_false(is_valid_utf8(Span(bytes_of(0xC3))))
    assert_false(is_valid_utf8(Span(bytes_of(0xE2, 0x82))))
    assert_false(is_valid_utf8(Span(bytes_of(0xF0, 0x9F, 0x91))))


def test_is_valid_utf8_continuation_only_false() raises:
    # A lone continuation byte (0b10xxxxxx) is not a valid start.
    assert_false(is_valid_utf8(Span(bytes_of(0x80))))
    assert_false(is_valid_utf8(Span(bytes_of(0xA9))))


def test_is_valid_utf8_overlong_false() raises:
    # Overlong NUL: 0xC0 0x80 must be rejected.
    assert_false(is_valid_utf8(Span(bytes_of(0xC0, 0x80))))


def test_is_valid_utf8_surrogate_false() raises:
    # UTF-8 encoding of U+D800 (a surrogate) must be rejected.
    assert_false(is_valid_utf8(Span(bytes_of(0xED, 0xA0, 0x80))))


def test_is_valid_utf8_above_max_false() raises:
    # 0xF5 starts a sequence above U+10FFFF.
    assert_false(is_valid_utf8(Span(bytes_of(0xF5, 0x80, 0x80, 0x80))))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
