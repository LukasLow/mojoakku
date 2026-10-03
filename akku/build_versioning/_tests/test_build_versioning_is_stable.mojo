# Concern: `is_stable` — the documented stability convention (docs block in
# `../is_stable.mojo`).
#
# Covers: major > 0 with no prerelease is stable; a 0.x.y release is not; any
# prerelease is not; and stability implies not is_prerelease and major > 0.

from std.testing import assert_true, assert_false, TestSuite
from akku.build_versioning import is_stable, is_prerelease, parse


def test_is_stable_major_positive() raises:
    assert_true(is_stable(parse("1.0.0")))
    assert_true(is_stable(parse("2.5.9")))
    assert_true(is_stable(parse("1.0.0+build.5")))


def test_is_stable_zero_major() raises:
    # 0.x.y is not stable by the documented convention.
    assert_false(is_stable(parse("0.1.0")))
    assert_false(is_stable(parse("0.0.0")))


def test_is_stable_prerelease() raises:
    assert_false(is_stable(parse("1.0.0-rc.1")))
    assert_false(is_stable(parse("2.0.0-alpha")))


def test_is_stable_implies_not_prerelease() raises:
    for text in ["1.0.0", "2.5.9", "0.1.0", "1.0.0-rc.1"]:
        var v = parse(text)
        if is_stable(v):
            assert_true(not is_prerelease(v))
            assert_true(v.major() > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
