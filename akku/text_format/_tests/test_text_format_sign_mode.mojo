# Concern: `SignMode` — the closed sign discriminant (docs block in
# `../sign_mode.mojo`).
#
# Covers: the three members are the complete set; parse_format_spec maps '+',
# an explicit '-', and a leading space to the right members; `print(sign)` shows
# the symbolic name.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.text_format import SignMode, parse_format_spec


def test_sign_mode_distinct_members() raises:
    var kinds = List[SignMode]()
    kinds.append(SignMode.NEGATIVE_ONLY)
    kinds.append(SignMode.ALWAYS)
    kinds.append(SignMode.SPACE)
    assert_equal(len(kinds), 3)
    for i in range(len(kinds)):
        for j in range(len(kinds)):
            if i == j:
                assert_true(kinds[i] == kinds[j])
            else:
                assert_false(kinds[i] == kinds[j])


def test_sign_mode_parse() raises:
    assert_true(parse_format_spec("+d").sign == SignMode.ALWAYS)
    assert_true(parse_format_spec("-d").sign == SignMode.NEGATIVE_ONLY)
    assert_true(parse_format_spec(" d").sign == SignMode.SPACE)
    assert_true(parse_format_spec("d").sign == SignMode.NEGATIVE_ONLY)


def test_sign_mode_writable() raises:
    assert_true("NEGATIVE_ONLY" in String(SignMode.NEGATIVE_ONLY))
    assert_true("ALWAYS" in String(SignMode.ALWAYS))
    assert_true("SPACE" in String(SignMode.SPACE))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
