# Concern: `Grouping` — the closed digit-grouping discriminant (docs block in
# `../grouping.mojo`).
#
# Covers: the three members are the complete set; parse_format_spec maps ',' and
# '_' to the right members; `print(grouping)` shows the symbolic name.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.text_format import Grouping, parse_format_spec


def test_grouping_distinct_members() raises:
    var kinds = List[Grouping]()
    kinds.append(Grouping.NONE)
    kinds.append(Grouping.COMMA)
    kinds.append(Grouping.UNDERSCORE)
    assert_equal(len(kinds), 3)
    for i in range(len(kinds)):
        for j in range(len(kinds)):
            if i == j:
                assert_true(kinds[i] == kinds[j])
            else:
                assert_false(kinds[i] == kinds[j])


def test_grouping_parse() raises:
    assert_true(parse_format_spec(",d").grouping == Grouping.COMMA)
    assert_true(parse_format_spec("_d").grouping == Grouping.UNDERSCORE)
    assert_true(parse_format_spec("d").grouping == Grouping.NONE)


def test_grouping_writable() raises:
    assert_true("NONE" in String(Grouping.NONE))
    assert_true("COMMA" in String(Grouping.COMMA))
    assert_true("UNDERSCORE" in String(Grouping.UNDERSCORE))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
