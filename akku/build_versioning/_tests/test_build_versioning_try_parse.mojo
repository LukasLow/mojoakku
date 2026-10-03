# Concern: `try_parse` — the non-raising parser twin (docs block in
# `../try_parse.mojo`; `Error Surface` in `../__init__.mojo`).
#
# Covers: a valid string yields Some with the expected fields; an invalid or
# empty string yields None; `try_parse` is Some exactly when `parse` does not
# raise; and it never raises.
#
# Note on the documented "same grammar as parse": this file's negative cases
# overlap with `test_build_versioning_parse.mojo` on purpose -- they assert the
# absence result rather than the error kind.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.build_versioning import try_parse, parse


def test_try_parse_valid_some_fields() raises:
    var v = try_parse("1.2.3")
    assert_true(v)
    assert_equal(v.value().major(), 1)
    assert_equal(v.value().minor(), 2)
    assert_equal(v.value().patch(), 3)

    var r = try_parse("1.2.3-alpha.1+build.5")
    assert_true(r)
    assert_equal(String(r.value().prerelease()), "alpha.1")
    assert_equal(String(r.value().build()), "build.5")


def test_try_parse_invalid_none() raises:
    for text in ["1.2", "not-a-version", "v1.2.3", "1.2.3-", "01.2.3"]:
        assert_false(try_parse(text))


def test_try_parse_empty_none() raises:
    assert_false(try_parse(""))


def test_try_parse_matches_parse() raises:
    # try_parse is Some exactly when parse does not raise, over a mixed corpus.
    for text in [
        "1.2.3",
        "0.0.0",
        "1.2.3-alpha",
        "1.2.3+build.5",
        "1.2.3-alpha+build.5",
        "1",
        "1.2",
        "v1.2.3",
        "",
        "01.2.3",
        "1.2.3-",
        "1.2.x",
    ]:
        var parsed_ok: Bool
        try:
            _ = parse(text)
            parsed_ok = True
        except e:
            parsed_ok = False
        assert_equal(Bool(try_parse(text)), parsed_ok)


def test_try_parse_never_raises() raises:
    # try_parse has no `raises` clause, so it cannot raise by construction; this
    # exercises the documented invalid cases directly.
    _ = try_parse("not-a-version")
    _ = try_parse("")
    _ = try_parse("1.2.3-")
    _ = try_parse("99999999999999999999999999.0.0")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
