# Concern: `precedence` — SemVer clause 11 ordering of two versions (docs block
# in `../precedence.mojo`; `Conventions` in `../__init__.mojo`).
#
# Covers: numeric ordering; equality; a prerelease is lower than its release;
# numeric vs numeric identifiers compared numerically; alphanumeric identifiers
# in ASCII order; numeric below alphanumeric; fewer identifiers lower; the
# spec's full example chain; build metadata ignored; antisymmetry.

from std.testing import assert_equal, assert_true, TestSuite
from akku.build_versioning import precedence, parse


def cmp(a: StringSpan, b: StringSpan) raises -> Int:
    return precedence(parse(a), parse(b))


def test_precedence_numeric_order() raises:
    assert_equal(cmp("1.0.0", "2.0.0"), -1)
    assert_equal(cmp("2.0.0", "2.1.0"), -1)
    assert_equal(cmp("2.1.0", "2.1.1"), -1)


def test_precedence_equal() raises:
    assert_equal(cmp("1.2.3", "1.2.3"), 0)


def test_precedence_prerelease_lower() raises:
    assert_equal(cmp("1.0.0-alpha", "1.0.0"), -1)


def test_precedence_numeric_identifiers_numeric() raises:
    # Numeric identifiers compare as numbers: 2 < 10, not "10" < "2".
    assert_equal(cmp("1.0.0-2", "1.0.0-10"), -1)


def test_precedence_alphanumeric_ascii() raises:
    # Alphanumeric identifiers compare lexically in ASCII order.
    assert_equal(cmp("1.0.0-alpha", "1.0.0-beta"), -1)
    # Uppercase sorts before lowercase.
    assert_equal(cmp("1.0.0-BETA", "1.0.0-alpha"), -1)


def test_precedence_numeric_below_alphanumeric() raises:
    assert_equal(cmp("1.0.0-1", "1.0.0-alpha"), -1)


def test_precedence_fewer_identifiers_lower() raises:
    assert_equal(cmp("1.0.0-alpha", "1.0.0-alpha.1"), -1)


def test_precedence_spec_chain() raises:
    # The full example chain from semver.org item 11.
    var chain = [
        "1.0.0-alpha",
        "1.0.0-alpha.1",
        "1.0.0-alpha.beta",
        "1.0.0-beta",
        "1.0.0-beta.2",
        "1.0.0-beta.11",
        "1.0.0-rc.1",
        "1.0.0",
    ]
    for i in range(len(chain) - 1):
        # Copy the two elements out: indexing a List yields references, and
        # passing two references from the same List would alias.
        var a = String(chain[i])
        var b = String(chain[i + 1])
        assert_equal(cmp(a, b), -1)


def test_precedence_ignores_build() raises:
    assert_equal(cmp("1.2.3+a", "1.2.3+b"), 0)
    assert_equal(cmp("1.2.3", "1.2.3+b"), 0)
    # Build is also ignored once a prerelease is present.
    assert_equal(cmp("1.2.3-alpha+a", "1.2.3-alpha+b"), 0)


def test_precedence_antisymmetric() raises:
    for pair in [
        ("1.0.0", "2.0.0"),
        ("1.0.0-alpha", "1.0.0"),
        ("1.0.0-2", "1.0.0-10"),
        ("1.2.3+a", "1.2.3+b"),
    ]:
        var forward = cmp(pair[0], pair[1])
        var backward = cmp(pair[1], pair[0])
        assert_equal(forward, -backward)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
