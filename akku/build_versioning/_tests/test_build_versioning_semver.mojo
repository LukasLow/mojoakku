# Concern: `SemVer` — the version value type (docs block in `../semver.mojo`;
# `Overview` / `Conventions` in `../__init__.mojo`).
#
# Covers: the validating component constructor (valid input; a negative
# component raises BAD_NUMBER; a malformed prerelease raises INVALID_FORMAT or
# LEADING_ZERO); the accessors major/minor/patch/prerelease/build; equality
# follows precedence, so build metadata is ignored and a prerelease is not equal
# to its release; Writable renders the strict canonical form (round-trip).

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.build_versioning import SemVer, VersionError, VersionErrorKind


def test_semver_construct_valid_empty_qualifiers() raises:
    # A three-component version has no prerelease and no build.
    var v = SemVer(1, 2, 3)
    assert_equal(v.major(), 1)
    assert_equal(v.minor(), 2)
    assert_equal(v.patch(), 3)
    assert_equal(String(v.prerelease()), "")
    assert_equal(String(v.build()), "")


def test_semver_construct_with_qualifiers() raises:
    var v = SemVer(1, 2, 3, "alpha.1", "build.5")
    assert_equal(String(v.prerelease()), "alpha.1")
    assert_equal(String(v.build()), "build.5")


def test_semver_construct_rejects_negative_component() raises:
    # A negative numeric component is a data error, not a silent wrap.
    var kind = VersionErrorKind.OTHER
    var caught = False
    try:
        _ = SemVer(1, -2, 3)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, VersionErrorKind.BAD_NUMBER)


def test_semver_construct_rejects_empty_prerelease_identifier() raises:
    # "alpha..1" has an empty identifier, which the grammar forbids.
    var kind = VersionErrorKind.OTHER
    var caught = False
    try:
        _ = SemVer(1, 2, 3, "alpha..1")
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, VersionErrorKind.INVALID_FORMAT)


def test_semver_construct_rejects_leading_zero_prerelease() raises:
    # A numeric prerelease identifier may not have a leading zero.
    var kind = VersionErrorKind.OTHER
    var caught = False
    try:
        _ = SemVer(1, 2, 3, "01")
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, VersionErrorKind.LEADING_ZERO)


def test_semver_eq_ignores_build() raises:
    # Clause 10: build metadata does not affect precedence, so it does not
    # affect equality either.
    var a = SemVer(1, 2, 3, "", "a")
    var b = SemVer(1, 2, 3, "", "b")
    assert_true(a == b)
    assert_false(a != b)


def test_semver_eq_prerelease_lower_not_equal() raises:
    # A prerelease has lower precedence than its release, so they are unequal.
    var pre = SemVer(1, 2, 3, "alpha")
    var rel = SemVer(1, 2, 3)
    assert_false(pre == rel)
    assert_true(pre != rel)


def test_semver_eq_numeric_components() raises:
    assert_true(SemVer(1, 2, 3) == SemVer(1, 2, 3))
    assert_false(SemVer(1, 2, 3) == SemVer(1, 2, 4))


def test_semver_writable_canonical() raises:
    # Writable renders the strict canonical form, with the qualifiers only when
    # they are present.
    assert_equal(String(SemVer(1, 2, 3)), "1.2.3")
    assert_equal(String(SemVer(1, 2, 3, "alpha")), "1.2.3-alpha")
    assert_equal(String(SemVer(1, 2, 3, "alpha", "build.5")), "1.2.3-alpha+build.5")
    assert_equal(String(SemVer(2, 0, 0, "", "build.5")), "2.0.0+build.5")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
