# Concern: `FormatType` — the closed presentation discriminant (docs block in
# `../format_type.mojo`).
#
# Covers: the twelve members are the complete set; parse_format_spec maps every
# accepted letter; 'F' is an alias of 'f' (same member, never an uppercase form);
# `print(presentation)` shows the symbolic name.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.text_format import FormatType, parse_format_spec


def test_format_type_distinct_members() raises:
    var kinds = List[FormatType]()
    kinds.append(FormatType.DEFAULT)
    kinds.append(FormatType.BINARY)
    kinds.append(FormatType.OCTAL)
    kinds.append(FormatType.DECIMAL)
    kinds.append(FormatType.LOWER_HEX)
    kinds.append(FormatType.UPPER_HEX)
    kinds.append(FormatType.CHAR)
    kinds.append(FormatType.STRING)
    kinds.append(FormatType.REPR)
    kinds.append(FormatType.FIXED)
    kinds.append(FormatType.SCIENTIFIC)
    kinds.append(FormatType.UPPER_SCIENTIFIC)
    assert_equal(len(kinds), 12)
    for i in range(len(kinds)):
        for j in range(len(kinds)):
            if i == j:
                assert_true(kinds[i] == kinds[j])
            else:
                assert_false(kinds[i] == kinds[j])


def test_format_type_parse_letters() raises:
    assert_true(parse_format_spec("b").presentation == FormatType.BINARY)
    assert_true(parse_format_spec("o").presentation == FormatType.OCTAL)
    assert_true(parse_format_spec("d").presentation == FormatType.DECIMAL)
    assert_true(parse_format_spec("x").presentation == FormatType.LOWER_HEX)
    assert_true(parse_format_spec("X").presentation == FormatType.UPPER_HEX)
    assert_true(parse_format_spec("c").presentation == FormatType.CHAR)
    assert_true(parse_format_spec("s").presentation == FormatType.STRING)
    assert_true(parse_format_spec("r").presentation == FormatType.REPR)
    assert_true(parse_format_spec("f").presentation == FormatType.FIXED)
    assert_true(parse_format_spec("e").presentation == FormatType.SCIENTIFIC)
    assert_true(parse_format_spec("E").presentation == FormatType.UPPER_SCIENTIFIC)


def test_format_type_uppercase_f_is_an_alias_of_lowercase_f() raises:
    # 'F' maps to the SAME member as 'f': it never selects an uppercase form.
    assert_true(parse_format_spec("F").presentation == FormatType.FIXED)
    assert_true(parse_format_spec("F").presentation == parse_format_spec("f").presentation)


def test_format_type_writable() raises:
    assert_true("FIXED" in String(FormatType.FIXED))
    assert_true("UPPER_HEX" in String(FormatType.UPPER_HEX))
    assert_true("UPPER_SCIENTIFIC" in String(FormatType.UPPER_SCIENTIFIC))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
