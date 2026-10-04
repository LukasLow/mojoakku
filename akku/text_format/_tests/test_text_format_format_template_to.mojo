# Concern: `format_template_to` — bind a runtime template and write it through a
# Writer, with the documented partial-output behaviour (docs block in
# `../format_template_to.mojo`).
#
# Covers: output written through a Writer equals format_template; the
# allocation-free path accepts any Writer (here a borrowed StringBuilder); a
# template/spec error found while parsing writes nothing (atomic up to the first
# write); and a TYPE_MISMATCH in a later field leaves the prefix already written
# in the destination.

from std.testing import assert_equal, assert_true, TestSuite
from akku.text_format import (
    FormatArgs,
    FormatErrorKind,
    format_template,
    format_template_to,
)
from akku.text_string import StringBuilder


def args_int_and_string() raises -> FormatArgs:
    var args = FormatArgs()
    args.push_int(42)
    args.push_string(String("mojo"))
    return args^


def test_format_template_to_writer_matches_format_template() raises:
    var args = args_int_and_string()
    var b = StringBuilder()
    format_template_to(b, "n = {} s = {}", args)
    assert_equal(String(b), format_template("n = {} s = {}", args))
    assert_equal(String(b), "n = 42 s = mojo")


def test_format_template_to_writes_through_the_writer() raises:
    var args = args_int_and_string()
    var b = StringBuilder()
    format_template_to(b, "{1}-{0}", args)
    assert_equal(String(b), "mojo-42")


def test_format_template_to_malformed_writes_nothing() raises:
    # A parse-stage failure precedes the first write, so the destination is
    # untouched.
    var args = args_int_and_string()
    var b = StringBuilder()
    var caught = False
    var kind = FormatErrorKind.TYPE_MISMATCH
    try:
        format_template_to(b, "pre {", args)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, FormatErrorKind.MALFORMED_TEMPLATE)
    assert_equal(String(b), "")


def test_format_template_to_partial_output_on_later_type_mismatch() raises:
    # The first literal and field are already written when a later field's
    # TYPE_MISMATCH is detected; the writer then holds the prefix so far.
    var args = args_int_and_string()
    var b = StringBuilder()
    var caught = False
    var kind = FormatErrorKind.TYPE_MISMATCH
    try:
        format_template_to(b, "pre {} {:x}", args)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, FormatErrorKind.TYPE_MISMATCH)
    # Partial output is possible: the earlier segment is present.
    assert_true(String(b).byte_length() > 0)
    assert_true("pre" in String(b))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
