# Concern: `FormatArgs` — the ordered, typed argument list for format_template
# (docs block in `../format_args.mojo`).
#
# Covers: a new list is empty; each push_* appends one argument in order;
# count() tracks the pushes; a pushed String is owned by the list and independent
# of the caller's buffer; the struct is move-only (not implicitly copyable).

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.text_format import FormatArgs, format_template


def test_format_args_starts_empty() raises:
    var args = FormatArgs()
    assert_equal(args.count(), 0)


def test_format_args_count_tracks_pushes() raises:
    var args = FormatArgs()
    args.push_int(1)
    assert_equal(args.count(), 1)
    args.push_float(2.5)
    assert_equal(args.count(), 2)
    args.push_string(String("three"))
    assert_equal(args.count(), 3)
    args.push_bool(True)
    assert_equal(args.count(), 4)


def test_format_args_accepts_all_four_kinds() raises:
    var args = FormatArgs()
    args.push_int(7)
    args.push_float(7.5)
    args.push_string(String("s"))
    args.push_bool(False)
    assert_equal(args.count(), 4)


def test_format_args_string_is_owned_by_list() raises:
    # The pushed String is owned by the list (the caller transfers it with `^`),
    # and the list still renders its value.
    var args = FormatArgs()
    var text = String("owned")
    args.push_string(text^)
    assert_equal(args.count(), 1)
    assert_equal(format_template("{}", args), "owned")


def test_format_args_is_move_only() raises:
    assert_true(conforms_to(FormatArgs, Deinitable))
    assert_false(conforms_to(FormatArgs, ImplicitlyCopyable))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
