# Concern: `Alignment` — the closed alignment discriminant (docs block in
# `../alignment.mojo`).
#
# Covers: the five members are the complete set; parse_format_spec maps
# '<', '>', '^', '=' to the right members; a fill character is accepted before
# the alignment; `print(alignment)` shows the symbolic name.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.text_format import Alignment, parse_format_spec


def test_alignment_distinct_members() raises:
    var kinds = List[Alignment]()
    kinds.append(Alignment.DEFAULT)
    kinds.append(Alignment.LEFT)
    kinds.append(Alignment.RIGHT)
    kinds.append(Alignment.CENTER)
    kinds.append(Alignment.SIGN_AWARE)
    assert_equal(len(kinds), 5)
    for i in range(len(kinds)):
        for j in range(len(kinds)):
            if i == j:
                assert_true(kinds[i] == kinds[j])
            else:
                assert_false(kinds[i] == kinds[j])


def test_alignment_parse_letters() raises:
    assert_true(parse_format_spec("<5").align == Alignment.LEFT)
    assert_true(parse_format_spec(">5").align == Alignment.RIGHT)
    assert_true(parse_format_spec("^5").align == Alignment.CENTER)
    assert_true(parse_format_spec("=5").align == Alignment.SIGN_AWARE)


def test_alignment_default_when_no_letter() raises:
    assert_true(parse_format_spec("5").align == Alignment.DEFAULT)
    assert_true(parse_format_spec("").align == Alignment.DEFAULT)


def test_alignment_parse_fill_before_letter() raises:
    var spec = parse_format_spec("*>5")
    assert_true(spec.align == Alignment.RIGHT)
    assert_equal(String(spec.fill), "*")


def test_alignment_writable() raises:
    assert_true("DEFAULT" in String(Alignment.DEFAULT))
    assert_true("CENTER" in String(Alignment.CENTER))
    assert_true("SIGN_AWARE" in String(Alignment.SIGN_AWARE))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
