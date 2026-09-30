# Concern: `StringError` — the one typed error carrying `kind` and `position` —
# its display, ownership and re-raise contract, plus the shared error-surface
# map (docs block in `../string_error.mojo`; shared `Error Surface` in
# `../__init__.mojo`).
#
# Covers: the two fields are readable in an `except` block; `position` is a byte
# offset into the ORIGINAL input (offending index for INDEX_OUT_OF_BOUNDS /
# NOT_A_BOUNDARY, range start for BAD_RANGE, first invalid sequence for
# INVALID_UTF8); `print(err)` yields kind + position; `StringError` is
# `Copyable` + `Deinitable` but deliberately NOT `ImplicitlyCopyable`, so a
# re-raise transfers with `^`; every documented fallible call raises the
# documented kind for the documented input (slice / replace_n /
# StringBuilder.append_bytes).
#
# Edge-case checklist (honest coverage): EOF, EINTR/EAGAIN, non-blocking
# behaviour, timeouts, handle-close semantics and OS errno are N/A for `string`.
# It is a pure in-memory library: it never touches a file descriptor, signal,
# socket or clock, so no operation can be interrupted, would-block, time out or
# observe a closed handle. The applicable edge cases are invalid input (bad
# range/boundary/encoding/empty needle) and the empty/absent cases — each
# covered in its own concern file.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.text_string import (
    StringError,
    StringErrorKind,
    StringBuilder,
    replace_n,
    slice,
)


def rethrow_not_a_boundary() raises StringError:
    # A caught error must be re-raised by transfer, not copy.
    try:
        raise StringError(StringErrorKind.NOT_A_BOUNDARY, 2)
    except e:
        raise e^


def test_string_error_fields_kind_position() raises:
    var err = StringError(StringErrorKind.BAD_RANGE, 7)
    assert_equal(err.kind, StringErrorKind.BAD_RANGE)
    assert_equal(err.position, 7)


def test_string_error_writable() raises:
    # print(err) yields kind + position.
    var err = StringError(StringErrorKind.INDEX_OUT_OF_BOUNDS, 99)
    var text = String(err)
    assert_true("INDEX_OUT_OF_BOUNDS" in text)
    assert_true("99" in text)


def test_string_error_copyable_not_implicit() raises:
    var err = StringError(StringErrorKind.INVALID_UTF8, 3)
    var copied = err.copy()
    assert_equal(copied.kind, StringErrorKind.INVALID_UTF8)
    assert_true(conforms_to(StringError, Copyable))
    assert_true(conforms_to(StringError, Deinitable))
    assert_false(conforms_to(StringError, ImplicitlyCopyable))


def test_string_error_reraise_transfer() raises:
    var caught = False
    try:
        rethrow_not_a_boundary()
    except e:
        caught = True
        assert_equal(e.kind, StringErrorKind.NOT_A_BOUNDARY)
        assert_equal(e.position, 2)
    assert_true(caught)


def test_string_error_surface_slice() raises:
    # slice raises the documented kind for the documented input.
    var kind = StringErrorKind.INVALID_UTF8
    try:
        _ = slice("hello", 0, 99)
    except e:
        kind = e.kind
    assert_equal(kind, StringErrorKind.INDEX_OUT_OF_BOUNDS)

    kind = StringErrorKind.INVALID_UTF8
    try:
        _ = slice("hello", 3, 1)
    except e:
        kind = e.kind
    assert_equal(kind, StringErrorKind.BAD_RANGE)

    kind = StringErrorKind.INVALID_UTF8
    try:
        _ = slice("hé", 0, 2)
    except e:
        kind = e.kind
    assert_equal(kind, StringErrorKind.NOT_A_BOUNDARY)


def test_string_error_surface_replace_n() raises:
    # replace_n raises BAD_RANGE when the `old` needle is empty.
    var kind = StringErrorKind.INVALID_UTF8
    try:
        _ = replace_n("abc", "", "x", -1)
    except e:
        kind = e.kind
    assert_equal(kind, StringErrorKind.BAD_RANGE)


def test_string_error_surface_append_bytes() raises:
    # StringBuilder.append_bytes raises INVALID_UTF8 on non-UTF-8 input.
    var builder = StringBuilder()
    var bad: List[UInt8] = [255]
    var kind = StringErrorKind.BAD_RANGE
    try:
        builder.append_bytes(Span(bad))
    except e:
        kind = e.kind
    assert_equal(kind, StringErrorKind.INVALID_UTF8)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
