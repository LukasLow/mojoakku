# Concern: `ErrorKind` and `Base64Error` — the single typed error with a `kind`
# discriminant and a `position` (BASE64_DOCS.md `### ErrorKind`,
# `### Base64Error`, `## Error Surface`).
#
# Covers: the three kinds; `kind` and `position` are readable in an except
# block; `print(err)` writes the symbolic kind name; position points at the
# offending symbol / quantum in the original stream. `Base64Error` is
# `Copyable` but deliberately not `ImplicitlyCopyable`, so re-raise uses `^`.

from std.testing import assert_equal, assert_true, TestSuite
from base64 import (
    Alphabet,
    Padding,
    PaddingMode,
    Whitespace,
    ErrorKind,
    Base64Error,
    decode,
)

def test_invalid_symbol_kind_and_position() raises:
    var caught = False
    try:
        _ = decode("Zm!v")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 2)
    assert_true(caught)

def test_invalid_length_kind_and_position() raises:
    var caught = False
    try:
        _ = decode("AAAAA")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
        # The impossible remainder begins at the first symbol after the last
        # complete quantum (index 4).
        assert_equal(e.position, 4)
    assert_true(caught)

def test_invalid_padding_kind_and_position() raises:
    var caught = False
    try:
        _ = decode("Zg")
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

def test_base64_error_write_to_reports_kind_and_position() raises:
    var err = Base64Error(ErrorKind.INVALID_PADDING, 7)
    var text = String(err)
    assert_true("INVALID_PADDING" in text)
    assert_true("7" in text)

def test_base64_error_fields_are_readable() raises:
    var err = Base64Error(ErrorKind.INVALID_SYMBOL, 3)
    assert_equal(err.kind, ErrorKind.INVALID_SYMBOL)
    assert_equal(err.position, 3)

def rethrow() raises Base64Error:
    try:
        raise Base64Error(ErrorKind.INVALID_LENGTH, 2)
    except e:
        raise e^

def test_reraising_with_transfer_sigil_preserves_error() raises:
    # Base64Error is Copyable but not ImplicitlyCopyable; a re-raise transfers.
    var outer_caught = False
    try:
        rethrow()
    except e:
        outer_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
        assert_equal(e.position, 2)
    assert_true(outer_caught)

def test_position_at_first_complete_quantum_is_zero() raises:
    # A bad symbol in the very first quantum reports position 0.
    var caught = False
    try:
        _ = decode("!AAA")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 0)
    assert_true(caught)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
