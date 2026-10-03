# Concern: `VersionError` — the one typed error carrying `kind`, `op` and
# `detail` (docs block in `../version_error.mojo`; `Error Surface` in
# `../__init__.mojo`).
#
# Covers: the three fields are readable; `print(err)` yields kind + op + detail;
# VersionError is Copyable and Deinitable but deliberately NOT ImplicitlyCopyable,
# so a re-raise transfers with `^`; `op` names the call that failed; `detail` is
# opaque context.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.build_versioning import (
    VersionError,
    VersionErrorKind,
    SemVer,
    parse,
)


def rethrow_error() raises VersionError:
    # A caught error must be re-raised by transfer, not copy.
    try:
        raise VersionError(VersionErrorKind.INVALID_FORMAT, "parse", "re-raised")
    except e:
        raise e^


def test_error_fields_kind_op_detail() raises:
    var err = VersionError(VersionErrorKind.LEADING_ZERO, "parse", "01.2.3")
    assert_equal(err.kind, VersionErrorKind.LEADING_ZERO)
    assert_equal(err.op, "parse")
    assert_equal(err.detail, "01.2.3")


def test_error_writable() raises:
    var err = VersionError(VersionErrorKind.BAD_NUMBER, "SemVer", "negative major")
    var text = String(err)
    assert_true("BAD_NUMBER" in text)
    assert_true("SemVer" in text)
    assert_true("negative major" in text)


def test_error_copyable_not_implicit() raises:
    var err = VersionError(VersionErrorKind.OTHER, "parse", "context")
    var copied = err.copy()
    assert_equal(copied.kind, VersionErrorKind.OTHER)
    assert_true(conforms_to(VersionError, Copyable))
    assert_true(conforms_to(VersionError, Deinitable))
    assert_false(conforms_to(VersionError, ImplicitlyCopyable))


def test_error_reraise_transfer() raises:
    var caught = False
    try:
        rethrow_error()
    except e:
        caught = True
        assert_equal(e.kind, VersionErrorKind.INVALID_FORMAT)
        assert_equal(e.op, "parse")
    assert_true(caught)


def test_error_op_names_parse_call() raises:
    var op = ""
    var caught = False
    try:
        _ = parse("1.2")
    except e:
        caught = True
        op = e.op
    assert_true(caught)
    assert_equal(op, "parse")


def test_error_op_names_semver_constructor() raises:
    var op = ""
    var caught = False
    try:
        _ = SemVer(1, -2, 3)
    except e:
        caught = True
        op = e.op
    assert_true(caught)
    assert_equal(op, "SemVer")


def test_error_detail_is_opaque_context() raises:
    # `detail` carries context and is non-empty; callers must not parse it.
    var detail = ""
    var caught = False
    try:
        _ = parse("not-a-version")
    except e:
        caught = True
        detail = e.detail
    assert_true(caught)
    assert_true(detail.byte_length() > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
