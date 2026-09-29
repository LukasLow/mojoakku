# Concern: `IoErrorKind` and `IoError` — the closed seven-value failure
# discriminant and the single typed error that carries `kind`, `op` and
# `detail` (docs blocks in `../io_error_kind.mojo`, `../io_error.mojo`; shared
# in `../__init__.mojo`).
#
# Covers: equality is discriminant-only and all seven members are distinct;
# `print(kind)` shows the symbolic name; the three error fields are readable in
# an `except` block; `print(err)` includes kind and op; `IoError` is `Copyable`
# and `Deinitable` but deliberately NOT `ImplicitlyCopyable`, so a re-raise must
# transfer with `^`.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from io_core import IoErrorKind, IoError


def test_error_kind_eq() raises:
    # __eq__ is written explicitly and mirrors the discriminant.
    assert_true(IoErrorKind.CLOSED == IoErrorKind.CLOSED)
    assert_true(IoErrorKind.OTHER == IoErrorKind.OTHER)
    assert_false(IoErrorKind.CLOSED == IoErrorKind.OTHER)


def test_error_kind_all_members_distinct() raises:
    # The seven comptime members are the complete, closed set; every pair
    # differs, and every member equals itself.
    var kinds = List[IoErrorKind]()
    kinds.append(IoErrorKind.INTERRUPTED)
    kinds.append(IoErrorKind.WOULD_BLOCK)
    kinds.append(IoErrorKind.CLOSED)
    kinds.append(IoErrorKind.TIMED_OUT)
    kinds.append(IoErrorKind.INVALID_UTF8)
    kinds.append(IoErrorKind.UNEXPECTED_EOF)
    kinds.append(IoErrorKind.OTHER)
    assert_equal(len(kinds), 7)
    for i in range(len(kinds)):
        for j in range(len(kinds)):
            if i == j:
                assert_true(kinds[i] == kinds[j])
            else:
                assert_false(kinds[i] == kinds[j])


def test_error_kind_write_to_names_kind() raises:
    assert_true("CLOSED" in String(IoErrorKind.CLOSED))
    assert_true("INTERRUPTED" in String(IoErrorKind.INTERRUPTED))
    assert_true("WOULD_BLOCK" in String(IoErrorKind.WOULD_BLOCK))
    assert_true("TIMED_OUT" in String(IoErrorKind.TIMED_OUT))
    assert_true("INVALID_UTF8" in String(IoErrorKind.INVALID_UTF8))
    assert_true("OTHER" in String(IoErrorKind.OTHER))


def test_error_kind_unexpected_eof_write_to() raises:
    # The symbolic name is the full member name, not a bare "EOF".
    assert_true("UNEXPECTED_EOF" in String(IoErrorKind.UNEXPECTED_EOF))


def test_error_fields_kind_op_detail() raises:
    var err = IoError(IoErrorKind.INTERRUPTED, "read", "interrupted by signal")
    assert_equal(err.kind, IoErrorKind.INTERRUPTED)
    assert_equal(err.op, "read")
    assert_equal(err.detail, "interrupted by signal")


def test_error_write_to_includes_op() raises:
    var err = IoError(IoErrorKind.OTHER, "seek", "no such position")
    var text = String(err)
    assert_true("OTHER" in text)
    assert_true("seek" in text)


def test_error_copyable_and_deinitable() raises:
    var err = IoError(IoErrorKind.CLOSED, "flush", "handle is closed")
    var copied = err.copy()
    assert_equal(copied.kind, IoErrorKind.CLOSED)
    assert_true(conforms_to(IoError, Copyable))
    assert_true(conforms_to(IoError, Deinitable))


def test_error_not_implicitly_copyable() raises:
    # A re-raise must transfer with `raise e^`.
    assert_false(conforms_to(IoError, ImplicitlyCopyable))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
