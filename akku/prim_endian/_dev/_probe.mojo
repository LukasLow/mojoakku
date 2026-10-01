from std.bit import byte_swap
from std.sys import is_little_endian, is_big_endian, size_of


def probe_where[dtype: DType](x: Scalar[dtype]) -> Scalar[dtype] where dtype.is_integral():
    return x


def main() raises:
    print("is_little_endian:", is_little_endian())
    print("is_big_endian:", is_big_endian())
    print("size_of UInt16:", size_of[Scalar[DType.uint16]]())
    print("size_of UInt8:", size_of[Scalar[DType.uint8]]())

    # where-clause conformance
    print("is_integral where u16:", probe_where[DType.uint16](UInt16(0x0102)))
    print("is_integral where u8:", probe_where[DType.uint8](UInt8(0x01)))

    # byte_swap on a 2-byte value
    print("byte_swap u16 0x0102:", byte_swap(UInt16(0x0102)))

    # byte_swap on an odd (1-byte) width -- does it compile / what does it do?
    print("byte_swap u8 0x01:", byte_swap(UInt8(0x01)))

    # is_integral on a float dtype (compile-time predicate value)
    print("is_integral float32:", DType.float32.is_integral())
    print("is_integral uint16:", DType.uint16.is_integral())
