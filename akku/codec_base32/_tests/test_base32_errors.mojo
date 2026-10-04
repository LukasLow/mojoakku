# Concern: `ErrorKind` and `Base32Error` — the single typed error with a `kind`
# discriminant and a `position` (docs blocks in `../error_kind.mojo`,
# `../base32_error.mojo`; shared in `../__init__.mojo`).
#
# Covers: the three kinds; `kind` and `position` are readable in an except
# block; `print(err)` writes the symbolic kind name and the position; position
# points at the offending symbol / quantum in the original stream. `Base32Error`
# is Copyable but deliberately not ImplicitlyCopyable, so re-raise uses `^`.

from std.testing import assert_equal, assert_true, TestSuite
from akku.codec_base32 import (
    ErrorKind,
    Base32Error,
    decode,
)

def test_invalid_symbol_kind_and_position() raises:
    var caught = False
    try:
        _ = decode("MZ!W6===")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 2)
    assert_true(caught)

def test_invalid_length_kind_and_position() raises:
    var caught = False
    try:
        _ = decode("MZXW6YTBA")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
        # The impossible remainder begins at the first symbol after the last
        # complete quantum (index 8).
        assert_equal(e.position, 8)
    assert_true(caught)

def test_invalid_padding_kind_and_position() raises:
    var caught = False
    try:
        _ = decode("MY")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
        # The partial final quantum begins at index 0.
        assert_equal(e.position, 0)
    assert_true(caught)

def test_error_kind_write_to_uses_symbolic_name() raises:
    assert_true("INVALID_SYMBOL" in String(ErrorKind.INVALID_SYMBOL))
    assert_true("INVALID_LENGTH" in String(ErrorKind.INVALID_LENGTH))
    assert_true("INVALID_PADDING" in String(ErrorKind.INVALID_PADDING))

def test_base32_error_write_to_reports_kind_and_position() raises:
    var err = Base32Error(ErrorKind.INVALID_PADDING, 7)
    var text = String(err)
    assert_true("INVALID_PADDING" in text)
    assert_true("7" in text)

def test_base32_error_fields_are_readable() raises:
    var err = Base32Error(ErrorKind.INVALID_SYMBOL, 3)
    assert_equal(err.kind, ErrorKind.INVALID_SYMBOL)
    assert_equal(err.position, 3)

def rethrow() raises Base32Error:
    try:
        raise Base32Error(ErrorKind.INVALID_LENGTH, 2)
    except e:
        raise e^

def test_reraising_with_transfer_sigil_preserves_error() raises:
    # Base32Error is Copyable but not ImplicitlyCopyable; a re-raise transfers.
    var outer_caught = False
    try:
        rethrow()
    except e:
        outer_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
        assert_equal(e.position, 2)
    assert_true(outer_caught)

def test_position_at_first_symbol_is_zero() raises:
    var caught = False
    try:
        _ = decode("!XW6====")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 0)
    assert_true(caught)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
