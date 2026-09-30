# Consumer regression: the repository root is the only import search path.
# Libraries remain flat siblings; no source-root shortcut is needed.
from std.testing import assert_equal, TestSuite
from akku.codec_base64 import encode, decode
from akku.codec_base64.encode import encode as encode_direct
from akku.io_core import Cursor
from akku.prim_bit import get_bits, set_bits
from akku.text_string import to_ascii_lower, to_ascii_upper


def bytes_of(*values: UInt8) -> List[UInt8]:
    var out = List[UInt8]()
    for value in values:
        out.append(value)
    return out^


def test_namespaced_base64_public_and_direct_imports() raises:
    assert_equal(encode("foobar"), "Zm9vYmFy")
    assert_equal(encode_direct("foobar"), encode("foobar"))
    assert_equal(decode(encode("foobar")), bytes_of(102, 111, 111, 98, 97, 114))


def test_namespaced_io_reads_bytes() raises:
    var cursor = Cursor(bytes_of(1, 2, 3))
    var buffer = Array[UInt8, 3](fill=0)
    var result = cursor.read(buffer)
    assert_equal(result.count, 3)
    assert_equal(buffer[0], 1)
    assert_equal(buffer[1], 2)
    assert_equal(buffer[2], 3)


def test_namespaced_bit_fields_use_private_helpers() raises:
    assert_equal(get_bits(UInt8(0b1011_0100), 5, 2), UInt8(13))
    assert_equal(set_bits(UInt8(0), 5, 2, UInt8(13)), UInt8(0b0011_0100))


def test_namespaced_string_helpers_preserve_behavior() raises:
    assert_equal(to_ascii_lower("AbC"), "abc")
    assert_equal(to_ascii_upper("AbC"), "ABC")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
