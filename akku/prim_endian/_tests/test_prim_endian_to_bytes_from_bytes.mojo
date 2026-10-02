# Concern: `to_bytes_into` + `from_bytes` — the length-checked buffer layer
# (docs blocks in `../to_bytes_into.mojo`, `../from_bytes.mojo`; `Error
# Surface` in `../__init__.mojo`).
#
# Covers: BIG/LITTLE byte layouts for a UInt16; the two calls are inverses per
# order; a wrong-length span raises EndianError with kind BAD_LENGTH and op
# naming the call; a short/empty span raises BAD_LENGTH; a failing write
# leaves `dst` untouched; the explicit `[dtype: DType]` parameter.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from akku.prim_endian import (
    EndianOrder,
    EndianError,
    EndianErrorKind,
    host_order,
    to_bytes_into,
    from_bytes,
)


def test_to_bytes_into_uint16_big_layout() raises:
    # For BIG, dst[0] is the most significant byte.
    var dst: List[UInt8] = [0, 0]
    var span = MutSpan(dst)
    to_bytes_into(UInt16(0x0102), span, EndianOrder.BIG)
    assert_equal(dst[0], UInt8(0x01))
    assert_equal(dst[1], UInt8(0x02))


def test_to_bytes_into_uint16_little_layout() raises:
    # For LITTLE, dst[0] is the least significant byte.
    var dst: List[UInt8] = [0, 0]
    var span = MutSpan(dst)
    to_bytes_into(UInt16(0x0102), span, EndianOrder.LITTLE)
    assert_equal(dst[0], UInt8(0x02))
    assert_equal(dst[1], UInt8(0x01))


def test_from_bytes_uint16_layouts() raises:
    # src[0] is the most significant byte for BIG, least significant for LITTLE.
    var bytes: List[UInt8] = [0x01, 0x02]
    assert_equal(from_bytes[DType.uint16](Span(bytes), EndianOrder.BIG), UInt16(0x0102))
    assert_equal(
        from_bytes[DType.uint16](Span(bytes), EndianOrder.LITTLE), UInt16(0x0201)
    )


def test_bytes_roundtrip_per_order() raises:
    # from_bytes is the inverse of to_bytes_into for every explicit order.
    var value: UInt32 = 0xDEADBEEF
    for order in [EndianOrder.LITTLE, EndianOrder.BIG]:
        var dst: List[UInt8] = [0, 0, 0, 0]
        var span = MutSpan(dst)
        to_bytes_into(value, span, order)
        assert_equal(from_bytes[DType.uint32](Span(dst), order), value)


def test_to_bytes_into_wrong_length_raises_bad_length() raises:
    # A 4-byte carrier into a 2-byte dst raises BAD_LENGTH, before writing.
    var dst: List[UInt8] = [0xAA, 0xAA]
    var kind = EndianErrorKind.OTHER
    var op = ""
    try:
        var span = MutSpan(dst)
        to_bytes_into(UInt32(1), span, EndianOrder.BIG)
    except e:
        kind = e.kind
        op = e.op
    assert_equal(kind, EndianErrorKind.BAD_LENGTH)
    assert_equal(op, "to_bytes_into")
    # The failed call must have left dst untouched.
    assert_equal(dst[0], UInt8(0xAA))
    assert_equal(dst[1], UInt8(0xAA))


def test_from_bytes_wrong_length_raises_bad_length() raises:
    # A 3-byte src for a UInt16 carrier raises BAD_LENGTH.
    var bytes: List[UInt8] = [0x01, 0x02, 0x03]
    var kind = EndianErrorKind.OTHER
    var op = ""
    try:
        _ = from_bytes[DType.uint16](Span(bytes), EndianOrder.BIG)
    except e:
        kind = e.kind
        op = e.op
    assert_equal(kind, EndianErrorKind.BAD_LENGTH)
    assert_equal(op, "from_bytes")


def test_from_bytes_empty_span_raises_bad_length() raises:
    # An empty span cannot hold any carrier, so it raises BAD_LENGTH.
    var empty: List[UInt8] = []
    var kind = EndianErrorKind.OTHER
    var caught = False
    try:
        _ = from_bytes[DType.uint16](Span(empty), EndianOrder.BIG)
    except e:
        caught = True
        kind = e.kind
    assert_true(caught)
    assert_equal(kind, EndianErrorKind.BAD_LENGTH)


def test_to_bytes_into_too_long_raises_bad_length() raises:
    # dst longer than the carrier's width is also BAD_LENGTH (exact length
    # required, not a minimum), and the buffer is left untouched.
    var dst: List[UInt8] = [0xAA, 0xAA, 0xAA, 0xAA]
    var kind = EndianErrorKind.OTHER
    try:
        to_bytes_into(UInt16(0x0102), MutSpan(dst), EndianOrder.BIG)
    except e:
        kind = e.kind
    assert_equal(kind, EndianErrorKind.BAD_LENGTH)
    assert_equal(dst[0], UInt8(0xAA))


def test_to_bytes_into_native_matches_host_layout() raises:
    # NATIVE is the host order; its byte layout equals writing the host order.
    var value: UInt32 = 0x01020304
    var host = host_order()
    var native_dst: List[UInt8] = [0, 0, 0, 0]
    var host_dst: List[UInt8] = [0, 0, 0, 0]
    to_bytes_into(value, MutSpan(native_dst), EndianOrder.NATIVE)
    to_bytes_into(value, MutSpan(host_dst), host)
    for i in range(4):
        assert_equal(native_dst[i], host_dst[i])
    assert_equal(
        from_bytes[DType.uint32](Span(native_dst), EndianOrder.NATIVE), value
    )


def test_from_bytes_native_matches_host_layout() raises:
    # Reading with NATIVE reads the host layout: for a host-order byte list it
    # returns the value unchanged.
    var value: UInt32 = 0xDEADBEEF
    var host = host_order()
    var bytes: List[UInt8] = [0, 0, 0, 0]
    to_bytes_into(value, MutSpan(bytes), host)
    assert_equal(from_bytes[DType.uint32](Span(bytes), EndianOrder.NATIVE), value)


def test_bytes_per_width() raises:
    # Round-trip for 2-, 4- and 8-byte carriers in both explicit orders.
    for order in [EndianOrder.LITTLE, EndianOrder.BIG]:
        var d2: List[UInt8] = [0, 0]
        to_bytes_into(UInt16(0x0102), MutSpan(d2), order)
        assert_equal(from_bytes[DType.uint16](Span(d2), order), UInt16(0x0102))

        var d4: List[UInt8] = [0, 0, 0, 0]
        to_bytes_into(UInt32(0x01020304), MutSpan(d4), order)
        assert_equal(from_bytes[DType.uint32](Span(d4), order), UInt32(0x01020304))

        var d8: List[UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
        to_bytes_into(UInt64(0x0102030405060708), MutSpan(d8), order)
        assert_equal(
            from_bytes[DType.uint64](Span(d8), order), UInt64(0x0102030405060708)
        )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
