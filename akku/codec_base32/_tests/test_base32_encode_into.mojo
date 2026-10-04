# Concern: `encode_into` — encode into a caller-owned `mut result: String` and
# return the number of characters appended (docs block in `../encode_into.mojo`).
#
# Covers: both overloads; append semantics (prior contents kept, capacity may be
# zero on entry); the returned count equals the appended characters; empty input
# appends nothing; encode cannot fail.

from std.testing import assert_equal, TestSuite
from akku.codec_base32 import (
    Alphabet,
    encode,
    encode_into,
)

def test_encode_into_appends_to_existing_contents() raises:
    var result = String("prefix:")
    var n = encode_into("foobar", result)
    assert_equal(n, 16)
    assert_equal(result, "prefix:MZXW6YTBOI======")

def test_encode_into_returns_characters_appended() raises:
    var result = String()
    assert_equal(encode_into("f", result), 8)
    assert_equal(encode_into("", result), 0)
    assert_equal(encode_into("fooba", result), 8)

def test_encode_into_matches_encode() raises:
    var result = String()
    _ = encode_into("foobar", result)
    assert_equal(result, encode("foobar"))

def test_encode_into_can_be_called_repeatedly() raises:
    # Each call encodes and pads independently; the results concatenate in the
    # buffer (this differs from one-shot encoding of the concatenated input).
    var result = String()
    _ = encode_into("foo", result)
    _ = encode_into("bar", result)
    # "foo" -> "MZXW6===", "bar" -> "MJQXE===" (independently padded).
    assert_equal(result, "MZXW6===" + "MJQXE===")
    assert_equal(result, "MZXW6===MJQXE===")

def test_encode_into_byte_overload() raises:
    var text = String("foobar")
    var data = List[UInt8]()
    for b in text.bytes():
        data.append(b)
    var result = String()
    var n = encode_into(Span(data), result)
    assert_equal(n, 16)
    assert_equal(result, "MZXW6YTBOI======")

def test_encode_into_empty_input_leaves_result_unchanged() raises:
    var result = String("keep")
    var n = encode_into[Alphabet.B32_HEX]("", result)
    assert_equal(n, 0)
    assert_equal(result, "keep")

def test_encode_into_hex_alphabet() raises:
    var result = String()
    var n = encode_into[Alphabet.B32_HEX]("foobar", result)
    assert_equal(n, 16)
    assert_equal(result, "CPNMUOJ1E8======")

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
