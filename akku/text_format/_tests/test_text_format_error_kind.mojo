# Concern: `FormatErrorKind` — the closed five-value failure discriminant
# (docs block in `../format_error_kind.mojo`; shared error surface in
# `../__init__.mojo`).
#
# Covers: the five members are the complete, closed set; every pair differs and
# each member equals itself; `print(kind)` shows the symbolic name, never the
# numeric id; and the Writable/Equatable conformance a caller relies on.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.text_format import FormatErrorKind


def test_error_kind_distinct_members() raises:
    var kinds = List[FormatErrorKind]()
    kinds.append(FormatErrorKind.MALFORMED_TEMPLATE)
    kinds.append(FormatErrorKind.INVALID_SPEC)
    kinds.append(FormatErrorKind.MISSING_ARGUMENT)
    kinds.append(FormatErrorKind.EXTRA_ARGUMENT)
    kinds.append(FormatErrorKind.TYPE_MISMATCH)
    assert_equal(len(kinds), 5)
    for i in range(len(kinds)):
        for j in range(len(kinds)):
            if i == j:
                assert_true(kinds[i] == kinds[j])
            else:
                assert_false(kinds[i] == kinds[j])


def test_error_kind_eq_is_memberwise() raises:
    assert_true(FormatErrorKind.INVALID_SPEC == FormatErrorKind.INVALID_SPEC)
    assert_false(FormatErrorKind.INVALID_SPEC == FormatErrorKind.TYPE_MISMATCH)
    assert_false(FormatErrorKind.MISSING_ARGUMENT == FormatErrorKind.EXTRA_ARGUMENT)


def test_error_kind_writable_uses_symbolic_name() raises:
    assert_true("MALFORMED_TEMPLATE" in String(FormatErrorKind.MALFORMED_TEMPLATE))
    assert_true("INVALID_SPEC" in String(FormatErrorKind.INVALID_SPEC))
    assert_true("MISSING_ARGUMENT" in String(FormatErrorKind.MISSING_ARGUMENT))
    assert_true("EXTRA_ARGUMENT" in String(FormatErrorKind.EXTRA_ARGUMENT))
    assert_true("TYPE_MISMATCH" in String(FormatErrorKind.TYPE_MISMATCH))


def test_error_kind_conforms() raises:
    assert_true(conforms_to(FormatErrorKind, Writable))
    assert_true(conforms_to(FormatErrorKind, Equatable))
    assert_true(conforms_to(FormatErrorKind, ImplicitlyCopyable))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
