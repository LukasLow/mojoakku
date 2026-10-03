# Concern: `parse` — the strict SemVer 2.0.0 parser (docs block in
# `../parse.mojo`; `Conventions` / `Error Surface` in `../__init__.mojo`).
#
# Covers: every documented success form (core, prerelease, build, both); every
# documented rejection and its VersionErrorKind (EMPTY, INVALID_FORMAT,
# LEADING_ZERO, BAD_NUMBER, OVERFLOW); the leading-zero-in-build allowance;
# round-trip (parse then print equals the input); and `op == "parse"` on
# failure.

from std.testing import assert_equal, assert_true, TestSuite
from akku.build_versioning import parse, VersionErrorKind


def test_parse_basic() raises:
    var v = parse("1.2.3")
    assert_equal(v.major(), 1)
    assert_equal(v.minor(), 2)
    assert_equal(v.patch(), 3)
    assert_equal(String(v.prerelease()), "")
    assert_equal(String(v.build()), "")


def test_parse_prerelease() raises:
    var v = parse("1.2.3-alpha.1")
    assert_equal(String(v.prerelease()), "alpha.1")
    assert_equal(String(v.build()), "")


def test_parse_build() raises:
    var v = parse("1.2.3+build.5")
    assert_equal(String(v.prerelease()), "")
    assert_equal(String(v.build()), "build.5")


def test_parse_prerelease_and_build() raises:
    var v = parse("1.2.3-alpha+build.5")
    assert_equal(String(v.prerelease()), "alpha")
    assert_equal(String(v.build()), "build.5")


def test_parse_rejects_empty() raises:
    var kind = VersionErrorKind.OTHER
    var caught = False
    try:
        _ = parse("")
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, VersionErrorKind.EMPTY)


def test_parse_rejects_partial() raises:
    # `1` and `1.2` are not SemVer 2.0.0: all three core components are required.
    for text in ["1", "1.2"]:
        var kind = VersionErrorKind.OTHER
        var caught = False
        try:
            _ = parse(text)
        except e:
            caught = True
            kind = e.kind
        assert_true(caught)
        assert_equal(kind, VersionErrorKind.INVALID_FORMAT)


def test_parse_rejects_four_components() raises:
    var kind = VersionErrorKind.OTHER
    try:
        _ = parse("1.2.3.4")
    except e:
        kind = e.kind
    assert_equal(kind, VersionErrorKind.INVALID_FORMAT)


def test_parse_rejects_v_prefix() raises:
    # semver.org: v1.2.3 is not a semantic version.
    var kind = VersionErrorKind.OTHER
    try:
        _ = parse("v1.2.3")
    except e:
        kind = e.kind
    assert_equal(kind, VersionErrorKind.INVALID_FORMAT)


def test_parse_rejects_equals_prefix() raises:
    var kind = VersionErrorKind.OTHER
    try:
        _ = parse("=1.2.3")
    except e:
        kind = e.kind
    assert_equal(kind, VersionErrorKind.INVALID_FORMAT)


def test_parse_rejects_surrounding_whitespace() raises:
    for text in [" 1.2.3", "1.2.3 ", "\t1.2.3"]:
        var kind = VersionErrorKind.OTHER
        try:
            _ = parse(text)
        except e:
            kind = e.kind
        assert_equal(kind, VersionErrorKind.INVALID_FORMAT)


def test_parse_rejects_leading_zero_core() raises:
    for text in ["01.2.3", "1.02.3", "1.2.03"]:
        var kind = VersionErrorKind.OTHER
        try:
            _ = parse(text)
        except e:
            kind = e.kind
        assert_equal(kind, VersionErrorKind.LEADING_ZERO)


def test_parse_rejects_leading_zero_prerelease() raises:
    var kind = VersionErrorKind.OTHER
    try:
        _ = parse("1.2.3-01")
    except e:
        kind = e.kind
    assert_equal(kind, VersionErrorKind.LEADING_ZERO)


def test_parse_rejects_bad_char() raises:
    # A non-digit in a core component is a number error, not a format error.
    var kind = VersionErrorKind.OTHER
    try:
        _ = parse("1.2.x")
    except e:
        kind = e.kind
    assert_equal(kind, VersionErrorKind.BAD_NUMBER)


def test_parse_rejects_empty_identifier() raises:
    for text in ["1.2.3-", "1.2.3+", "1.2.3-a..b"]:
        var kind = VersionErrorKind.OTHER
        try:
            _ = parse(text)
        except e:
            kind = e.kind
        assert_equal(kind, VersionErrorKind.INVALID_FORMAT)


def test_parse_rejects_second_plus() raises:
    # Only one '+' separator is allowed: build exists only after the core/
    # prerelease, so a second '+' is INVALID_FORMAT.
    var kind = VersionErrorKind.OTHER
    try:
        _ = parse("1.2.3-a+b+c")
    except e:
        kind = e.kind
    assert_equal(kind, VersionErrorKind.INVALID_FORMAT)


def test_parse_rejects_overflow() raises:
    # A component larger than the Int range is a distinct OVERFLOW error.
    var kind = VersionErrorKind.OTHER
    try:
        _ = parse("99999999999999999999999999.0.0")
    except e:
        kind = e.kind
    assert_equal(kind, VersionErrorKind.OVERFLOW)


def test_parse_accepts_build_leading_zero() raises:
    # Leading zeros are allowed in build identifiers (unlike the core).
    var v = parse("1.2.3+01")
    assert_equal(String(v.build()), "01")


def test_parse_accepts_build_hyphen() raises:
    # Clause 10 allows '-' inside a build identifier: build over [0-9A-Za-z-].
    var a = parse("1.2.3+build-1")
    assert_equal(String(a.build()), "build-1")
    var b = parse("1.2.3+1-2")
    assert_equal(String(b.build()), "1-2")
    var c = parse("1.2.3+a-b.c-d")
    assert_equal(String(c.build()), "a-b.c-d")
    # A hyphen-bearing build combined with a prerelease is still valid.
    var d = parse("1.2.3-alpha+build-1")
    assert_equal(String(d.prerelease()), "alpha")
    assert_equal(String(d.build()), "build-1")


def test_parse_roundtrip() raises:
    for text in [
        "1.2.3",
        "0.0.0",
        "1.2.3-alpha",
        "1.2.3-alpha.1",
        "1.2.3+build.5",
        "1.2.3-alpha.1+build.5",
        "1.2.3+01",
        "1.2.3+build-1",
        "1.2.3+1-2",
        "1.2.3+a-b.c-d",
    ]:
        assert_equal(String(parse(text)), text)


def test_parse_error_op_is_parse() raises:
    var op = ""
    try:
        _ = parse("1.2")
    except e:
        op = e.op
    assert_equal(op, "parse")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
