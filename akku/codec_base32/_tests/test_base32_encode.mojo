# Concern: `encode` — borrowed bytes/text to an owned String
# (docs block in `../encode.mojo`).
#
# Covers: both overloads (Span[UInt8], StringSpan); empty input returns an
# empty String; the result length equals encoded_len; the RFC 4648 §10 vectors;
# both alphabets; input is borrowed (the caller's buffer/text stays intact);
# encode cannot fail for any input.

from std.testing import assert_equal, TestSuite
from akku.codec_base32 import (
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
    assert_equal(encode("f"), "MY======")
    assert_equal(encode("fo"), "MZXQ====")
    assert_equal(encode("foo"), "MZXW6===")
    assert_equal(encode("foob"), "MZXW6YQ=")
    assert_equal(encode("fooba"), "MZXW6YTB")
    assert_equal(encode("foobar"), "MZXW6YTBOI======")

def test_encode_hex_vectors() raises:
    assert_equal(encode[Alphabet.B32_HEX]("f"), "CO======")
    assert_equal(encode[Alphabet.B32_HEX]("fo"), "CPNG====")
    assert_equal(encode[Alphabet.B32_HEX]("foo"), "CPNMU===")
    assert_equal(encode[Alphabet.B32_HEX]("foob"), "CPNMUOG=")
    assert_equal(encode[Alphabet.B32_HEX]("fooba"), "CPNMUOJ1")
    assert_equal(encode[Alphabet.B32_HEX]("foobar"), "CPNMUOJ1E8======")

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
    for n in range(0, 21):
        var data = List[UInt8]()
        for i in range(n):
            data.append(UInt8(i))
        assert_equal(
            encode(Span(data)).byte_length(),
            encoded_len(n),
            "encoded output length must equal encoded_len(n)",
        )

def test_encode_omitted_padding_matches_encoded_len() raises:
    for n in range(0, 21):
        var data = List[UInt8]()
        for i in range(n):
            data.append(UInt8(i))
        assert_equal(
            encode[Alphabet.B32_STANDARD, Padding.OMITTED](Span(data)).byte_length(),
            encoded_len[Padding.OMITTED](n),
        )

def test_encode_treats_text_as_raw_bytes() raises:
    # Each byte is encoded; no UTF-8 conversion or normalisation happens.
    var data = bytes_of("foobar")
    assert_equal(encode(Span(data)), encode("foobar"))

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
