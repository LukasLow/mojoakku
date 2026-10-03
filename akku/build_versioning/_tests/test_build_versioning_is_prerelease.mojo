# Concern: `is_prerelease` — does a version carry a prerelease? (docs block in
# `../is_prerelease.mojo`).
#
# Covers: a prerelease version is true; a release is false; build-only is not a
# prerelease; and the predicate agrees with the clause-11 ordering (a
# prerelease compares lower than the same core without one).

from std.testing import assert_true, assert_false, TestSuite
from akku.build_versioning import is_prerelease, precedence, parse


def test_is_prerelease_true() raises:
    assert_true(is_prerelease(parse("1.2.3-alpha")))
    assert_true(is_prerelease(parse("1.2.3-alpha.1")))
    assert_true(is_prerelease(parse("1.2.3-rc.1+build.5")))


def test_is_prerelease_false_for_release() raises:
    assert_false(is_prerelease(parse("1.2.3")))
    assert_false(is_prerelease(parse("0.0.0")))


def test_is_prerelease_false_for_build_only() raises:
    # Build metadata alone does not make a version a prerelease.
    assert_false(is_prerelease(parse("1.2.3+build")))


def test_is_prerelease_agrees_with_precedence() raises:
    # A prerelease is exactly the clause-11 condition that makes the version
    # compare lower than its release counterpart.
    var pre = parse("1.0.0-alpha")
    var rel = parse("1.0.0")
    assert_true(is_prerelease(pre))
    assert_true(precedence(pre, rel) < 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
