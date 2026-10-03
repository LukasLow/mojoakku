# Concern: `VersionErrorKind` — the closed six-value failure discriminant
# (docs block in `../version_error_kind.mojo`; `Error Surface` in
# `../__init__.mojo`).
#
# Covers: the six comptime members are distinct and the complete closed set;
# equality compares the discriminant only; `print(kind)` shows the symbolic
# name, never the numeric id.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.build_versioning import VersionErrorKind


def test_error_kind_six_distinct() raises:
    var kinds = List[VersionErrorKind]()
    kinds.append(VersionErrorKind.EMPTY)
    kinds.append(VersionErrorKind.INVALID_FORMAT)
    kinds.append(VersionErrorKind.BAD_NUMBER)
    kinds.append(VersionErrorKind.LEADING_ZERO)
    kinds.append(VersionErrorKind.OVERFLOW)
    kinds.append(VersionErrorKind.OTHER)
    assert_equal(len(kinds), 6)
    for i in range(len(kinds)):
        for j in range(len(kinds)):
            if i == j:
                assert_true(kinds[i] == kinds[j])
            else:
                assert_false(kinds[i] == kinds[j])


def test_error_kind_eq_discriminant_only() raises:
    assert_true(VersionErrorKind.BAD_NUMBER == VersionErrorKind.BAD_NUMBER)
    assert_false(VersionErrorKind.BAD_NUMBER == VersionErrorKind.LEADING_ZERO)
    assert_false(VersionErrorKind.LEADING_ZERO == VersionErrorKind.BAD_NUMBER)


def test_error_kind_writable_symbolic_names() raises:
    # The symbolic name is printed, never the numeric _id.
    assert_true("EMPTY" in String(VersionErrorKind.EMPTY))
    assert_true("INVALID_FORMAT" in String(VersionErrorKind.INVALID_FORMAT))
    assert_true("BAD_NUMBER" in String(VersionErrorKind.BAD_NUMBER))
    assert_true("LEADING_ZERO" in String(VersionErrorKind.LEADING_ZERO))
    assert_true("OVERFLOW" in String(VersionErrorKind.OVERFLOW))
    assert_true("OTHER" in String(VersionErrorKind.OTHER))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
