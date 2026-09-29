# Concern: `BitErrorKind` — the closed five-value failure discriminant — and
# `BitError` — the single typed error carrying `kind`, `op` and `detail`
# (docs blocks in `../bit_error_kind.mojo`, `../bit_error.mojo`; shared in
# `../__init__.mojo`).
#
# Covers: all five members are distinct and equality is discriminant-only;
# `print(kind)` shows the symbolic name, never the number; the three error
# fields are readable in an `except` block; `op` names the failing call for
# every documented fallible operation; `print(err)` includes kind, op and
# detail; `BitError` is `Copyable` and `Deinitable` but deliberately NOT
# `ImplicitlyCopyable`, so a re-raise must transfer with `^`.
#
# Edge-case checklist (honest coverage): EINTR, EAGAIN, non-blocking behaviour,
# timeouts, handle-close/ownership semantics and OS errno are N/A for this
# library. `bit` is a pure in-memory library: it never touches a file
# descriptor, signal, socket or clock, so no operation can be interrupted,
# would-block, time out or observe a closed handle. The edge cases that *are*
# applicable to `bit` are EOF (bit readers only), invalid input (negative
# index/lo, reversed range, field overflow, read/write count outside 1..64) and
# the empty-set / empty-buffer cases — each covered in its own concern file.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from prim_bit import BitErrorKind, BitError, BitSet, get_bits, set_bits, BitReader, BitWriter, BitOrder


def rethrow_range() raises BitError:
    # A caught error must be re-raised by transfer, not copy.
    try:
        raise BitError(BitErrorKind.RANGE, "set", "re-raised")
    except e:
        raise e^


def test_error_kind_distinct_ids() raises:
    # The five comptime members are the complete, closed set; every pair
    # differs, and every member equals itself.
    var kinds = List[BitErrorKind]()
    kinds.append(BitErrorKind.RANGE)
    kinds.append(BitErrorKind.BAD_RANGE)
    kinds.append(BitErrorKind.OVERFLOW)
    kinds.append(BitErrorKind.EOF)
    kinds.append(BitErrorKind.OTHER)
    assert_equal(len(kinds), 5)
    for i in range(len(kinds)):
        for j in range(len(kinds)):
            if i == j:
                assert_true(kinds[i] == kinds[j])
            else:
                assert_false(kinds[i] == kinds[j])


def test_error_kind_eq() raises:
    # __eq__ is written explicitly and mirrors the discriminant.
    assert_true(BitErrorKind.RANGE == BitErrorKind.RANGE)
    assert_true(BitErrorKind.OTHER == BitErrorKind.OTHER)
    assert_false(BitErrorKind.RANGE == BitErrorKind.OTHER)
    assert_false(BitErrorKind.EOF == BitErrorKind.OVERFLOW)


def test_error_kind_writable() raises:
    # The symbolic name is printed, never the numeric _id.
    assert_true("RANGE" in String(BitErrorKind.RANGE))
    assert_true("BAD_RANGE" in String(BitErrorKind.BAD_RANGE))
    assert_true("OVERFLOW" in String(BitErrorKind.OVERFLOW))
    assert_true("EOF" in String(BitErrorKind.EOF))
    assert_true("OTHER" in String(BitErrorKind.OTHER))


def test_error_fields_kind_op_detail() raises:
    var err = BitError(BitErrorKind.RANGE, "set", "index -1 is negative")
    assert_equal(err.kind, BitErrorKind.RANGE)
    assert_equal(err.op, "set")
    assert_equal(err.detail, "index -1 is negative")


def test_error_writable() raises:
    # print(e) yields kind + op + detail.
    var err = BitError(BitErrorKind.OVERFLOW, "set_bits", "field too wide")
    var text = String(err)
    assert_true("OVERFLOW" in text)
    assert_true("set_bits" in text)
    assert_true("field too wide" in text)


def test_error_copyable_not_implicit() raises:
    var err = BitError(BitErrorKind.EOF, "read_bits", "short read")
    var copied = err.copy()
    assert_equal(copied.kind, BitErrorKind.EOF)
    assert_true(conforms_to(BitError, Copyable))
    assert_true(conforms_to(BitError, Deinitable))
    assert_false(conforms_to(BitError, ImplicitlyCopyable))


def test_error_reraise_transfer() raises:
    var caught = False
    try:
        rethrow_range()
    except e:
        caught = True
        assert_equal(e.kind, BitErrorKind.RANGE)
        assert_equal(e.op, "set")
    assert_true(caught)


def test_error_op_names_call() raises:
    # `op` names whichever fallible call failed (illustrative, not a closed
    # enum). Every documented raising operation reports its own name.
    var bits = BitSet()

    var op = ""
    try:
        bits.set(-1)
    except e:
        op = e.op
    assert_equal(op, "set")

    try:
        bits.clear(-1)
    except e:
        op = e.op
    assert_equal(op, "clear")

    try:
        bits.toggle(-1)
    except e:
        op = e.op
    assert_equal(op, "toggle")

    try:
        bits.set_to(-1, True)
    except e:
        op = e.op
    assert_equal(op, "set_to")

    try:
        _ = bits.test(-1)
    except e:
        op = e.op
    assert_equal(op, "test")

    try:
        bits.set_range(-1, 3)
    except e:
        op = e.op
    assert_equal(op, "set_range")

    try:
        bits.clear_range(-1, 3)
    except e:
        op = e.op
    assert_equal(op, "clear_range")

    try:
        bits.toggle_range(-1, 3)
    except e:
        op = e.op
    assert_equal(op, "toggle_range")

    try:
        _ = get_bits(UInt64(0), -1, 0)
    except e:
        op = e.op
    assert_equal(op, "get_bits")

    try:
        _ = set_bits(UInt64(0), -1, 0, UInt64(0))
    except e:
        op = e.op
    assert_equal(op, "set_bits")

    var empty: List[UInt8] = []
    var reader = BitReader(Span(empty), BitOrder.MSB_FIRST)
    try:
        _ = reader.read_bit()
    except e:
        op = e.op
    assert_equal(op, "read_bit")

    var reader2 = BitReader(Span(empty), BitOrder.MSB_FIRST)
    try:
        _ = reader2.read_bits(0)
    except e:
        op = e.op
    assert_equal(op, "read_bits")

    var writer = BitWriter(BitOrder.MSB_FIRST)
    try:
        writer.write_bits(UInt64(0), -1)
    except e:
        op = e.op
    assert_equal(op, "write_bits")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
