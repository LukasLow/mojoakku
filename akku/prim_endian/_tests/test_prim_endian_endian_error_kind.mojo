# Concern: `EndianErrorKind` — the closed two-value failure discriminant
# (docs block in `../endian_error_kind.mojo`; `Error Surface` in
# `../__init__.mojo`).
#
# Covers: BAD_LENGTH and OTHER are distinct and the complete closed set;
# equality compares the discriminant only; `print(kind)` shows the symbolic
# name, never the number.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.prim_endian import EndianErrorKind


def test_error_kind_distinct_ids() raises:
    # The two comptime members are the complete, closed set; every member
    # equals itself and differs from the other.
    var kinds = List[EndianErrorKind]()
    kinds.append(EndianErrorKind.BAD_LENGTH)
    kinds.append(EndianErrorKind.OTHER)
    assert_equal(len(kinds), 2)
    for i in range(len(kinds)):
        for j in range(len(kinds)):
            if i == j:
                assert_true(kinds[i] == kinds[j])
            else:
                assert_false(kinds[i] == kinds[j])


def test_error_kind_eq_discriminant_only() raises:
    # __eq__ is written explicitly and mirrors the discriminant.
    assert_true(EndianErrorKind.BAD_LENGTH == EndianErrorKind.BAD_LENGTH)
    assert_true(EndianErrorKind.OTHER == EndianErrorKind.OTHER)
    assert_false(EndianErrorKind.BAD_LENGTH == EndianErrorKind.OTHER)
    assert_false(EndianErrorKind.OTHER == EndianErrorKind.BAD_LENGTH)


def test_error_kind_writable() raises:
    # The symbolic name is printed, never the numeric _id.
    assert_true("BAD_LENGTH" in String(EndianErrorKind.BAD_LENGTH))
    assert_true("OTHER" in String(EndianErrorKind.OTHER))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
