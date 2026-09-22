# Concern: `encode` — borrowed bytes/text to an owned String
# (BASE64_DOCS.md `### encode`).
#
# Covers: both overloads (Span[UInt8], StringSpan); empty input returns an
# empty String; the result length equals encoded_len; input is borrowed (the
# caller's buffer/text stays intact and usable); no hidden state; encode cannot
# fail for any input.

from std.testing import assert_equal, assert_true, TestSuite
from base64 import (
    Alphabet,
    Padding,
    encode,
    encoded_len,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_encode_empty_input_is_empty_string() raises:
    assert_equal(encode(""), "")
    var empty = List[UInt8]()
    assert_equal(encode(Span(empty)), "")

def test_encode_standard_vectors() raises:
    assert_equal(encode("f"), "Zg==")
    assert_equal(encode("fo"), "Zm8=")
    assert_equal(encode("foo"), "Zm9v")
    assert_equal(encode("foob"), "Zm9vYg==")
    assert_equal(encode("fooba"), "Zm9vYmE=")
    assert_equal(encode("foobar"), "Zm9vYmFy")

def test_encode_byte_overload_matches_string_overload() raises:
    var data = bytes_of("foobar")
    assert_equal(encode(Span(data)), encode("foobar"))

def test_encode_borrows_input_and_leaves_it_usable() raises:
    var data = bytes_of("foobar")
    var before = List[UInt8]()
    for b in data:
        before.append(b)
    _ = encode(Span(data))
    assert_equal(data, before)
    assert_equal(len(data), 6)

def test_encode_result_length_matches_encoded_len() raises:
    for n in range(0, 17):
        var data = List[UInt8]()
        for i in range(n):
            data.append(UInt8(i))
        assert_equal(
            encode(Span(data)).byte_length(),
            encoded_len(n),
            "encoded output length must equal encoded_len(n)",
        )

def test_encode_uppercase_and_lowercase_letters_are_distinct() raises:
    assert_equal(encode("Z"), "Wg==")
    assert_equal(encode("z"), "eg==")
    assert_true(encode("Z") != encode("z"))

def test_encode_treats_text_as_raw_bytes() raises:
    # Each byte is encoded; no UTF-8 conversion or normalisation happens.
    var data = bytes_of("foobar")
    assert_equal(encode(Span(data)), encode("foobar"))

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
