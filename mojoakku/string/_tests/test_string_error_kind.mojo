# Concern: `StringErrorKind` — the closed four-value failure discriminant
# (docs block in `../string_error_kind.mojo`; shared error surface in
# `../__init__.mojo`).
#
# Covers: the four members are the complete, closed set; every pair differs and
# each member equals itself; equality is discriminant-only; `String(error_kind)`
# prints the symbolic name, never the numeric `_id`; and the `Writable`
# conformance used by `print(kind)`.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from string import StringErrorKind


def test_string_error_kind_distinct_ids() raises:
    # The four comptime members are the complete, closed set. Every pair must
    # differ; a member must equal itself.
    var kinds = List[StringErrorKind]()
    kinds.append(StringErrorKind.INDEX_OUT_OF_BOUNDS)
    kinds.append(StringErrorKind.BAD_RANGE)
    kinds.append(StringErrorKind.NOT_A_BOUNDARY)
    kinds.append(StringErrorKind.INVALID_UTF8)
    assert_equal(len(kinds), 4)
    for i in range(len(kinds)):
        for j in range(len(kinds)):
            if i == j:
                assert_true(kinds[i] == kinds[j])
            else:
                assert_false(kinds[i] == kinds[j])


def test_string_error_kind_eq() raises:
    assert_true(StringErrorKind.INDEX_OUT_OF_BOUNDS == StringErrorKind.INDEX_OUT_OF_BOUNDS)
    assert_true(StringErrorKind.INVALID_UTF8 == StringErrorKind.INVALID_UTF8)
    assert_false(StringErrorKind.INDEX_OUT_OF_BOUNDS == StringErrorKind.BAD_RANGE)
    assert_false(StringErrorKind.NOT_A_BOUNDARY == StringErrorKind.INVALID_UTF8)


def test_string_error_kind_writable() raises:
    # The symbolic name is printed, never the numeric _id.
    assert_true("INDEX_OUT_OF_BOUNDS" in String(StringErrorKind.INDEX_OUT_OF_BOUNDS))
    assert_true("BAD_RANGE" in String(StringErrorKind.BAD_RANGE))
    assert_true("NOT_A_BOUNDARY" in String(StringErrorKind.NOT_A_BOUNDARY))
    assert_true("INVALID_UTF8" in String(StringErrorKind.INVALID_UTF8))


def test_string_error_kind_conforms_writable() raises:
    assert_true(conforms_to(StringErrorKind, Writable))
    assert_true(conforms_to(StringErrorKind, Equatable))
    assert_true(conforms_to(StringErrorKind, ImplicitlyCopyable))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
