# Concern: `encode_into` — encode into a caller-owned `mut result: String` and
# return the number of characters appended (BASE64_DOCS.md `### encode_into`).
#
# Covers: both overloads; append semantics (prior contents kept, capacity may
# be zero on entry); the returned count equals the appended characters; empty
# input appends nothing; encode cannot fail.

from std.testing import assert_equal, TestSuite
from base64 import (
    Alphabet,
    Padding,
    encode,
    encode_into,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_encode_into_appends_to_existing_contents() raises:
    var result = String("prefix:")
    var n = encode_into("foobar", result)
    assert_equal(n, 8)
    assert_equal(result, "prefix:Zm9vYmFy")

def test_encode_into_returns_characters_appended() raises:
    var result = String()
    assert_equal(encode_into("f", result), 4)
    assert_equal(encode_into("", result), 0)
    assert_equal(encode_into("foo", result), 4)

def test_encode_into_matches_encode() raises:
    var result = String()
    _ = encode_into("foobar", result)
    assert_equal(result, encode("foobar"))

def test_encode_into_can_be_called_repeatedly() raises:
    var result = String()
    _ = encode_into("foo", result)
    _ = encode_into("bar", result)
    assert_equal(result, "Zm9vYmFy")

def test_encode_into_byte_overload() raises:
    var data = bytes_of("foobar")
    var result = String()
    var n = encode_into(Span(data), result)
    assert_equal(n, 8)
    assert_equal(result, "Zm9vYmFy")

def test_encode_into_empty_input_leaves_result_unchanged() raises:
    var result = String("keep")
    var n = encode_into[Alphabet.HEX_UPPER]("", result)
    assert_equal(n, 0)
    assert_equal(result, "keep")

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
