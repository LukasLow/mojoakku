# Concern: `EndianError` — the one typed error carrying `kind`, `op` and
# `detail` (docs block in `../endian_error.mojo`; `Error Surface` in
# `../__init__.mojo`).
#
# Covers: the three fields are readable; `print(err)` yields kind + op +
# detail; EndianError is Copyable and Deinitable but deliberately NOT
# ImplicitlyCopyable, so a re-raise transfers with `^`.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.prim_endian import EndianError, EndianErrorKind


def rethrow_bad_length() raises EndianError:
    # A caught error must be re-raised by transfer, not copy.
    try:
        raise EndianError(EndianErrorKind.BAD_LENGTH, "to_bytes_into", "re-raised")
    except e:
        raise e^


def test_error_fields_kind_op_detail() raises:
    var err = EndianError(EndianErrorKind.BAD_LENGTH, "to_bytes_into", "2 != 4")
    assert_equal(err.kind, EndianErrorKind.BAD_LENGTH)
    assert_equal(err.op, "to_bytes_into")
    assert_equal(err.detail, "2 != 4")


def test_error_writable() raises:
    # print(e) yields kind + operation + detail.
    var err = EndianError(EndianErrorKind.BAD_LENGTH, "from_bytes", "short span")
    var text = String(err)
    assert_true("BAD_LENGTH" in text)
    assert_true("from_bytes" in text)
    assert_true("short span" in text)


def test_error_copyable_not_implicit() raises:
    var err = EndianError(EndianErrorKind.OTHER, "from_bytes", "context")
    var copied = err.copy()
    assert_equal(copied.kind, EndianErrorKind.OTHER)
    assert_true(conforms_to(EndianError, Copyable))
    assert_true(conforms_to(EndianError, Deinitable))
    assert_false(conforms_to(EndianError, ImplicitlyCopyable))


def test_error_reraise_transfer() raises:
    var caught = False
    try:
        rethrow_bad_length()
    except e:
        caught = True
        assert_equal(e.kind, EndianErrorKind.BAD_LENGTH)
        assert_equal(e.op, "to_bytes_into")
    assert_true(caught)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
