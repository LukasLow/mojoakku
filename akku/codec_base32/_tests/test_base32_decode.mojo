# Concern: `decode` — borrowed encoded text/bytes to an owned `List[UInt8]`,
# raising `Base32Error` (docs block in `../decode.mojo`).
#
# Covers: both overloads (StringSpan, Span[UInt8]); empty input decodes to an
# empty List; the RFC 4648 §10 success vectors for both alphabets; the
# allocating form is atomic (no List on failure); input is borrowed; errors
# carry the three documented kinds.

from std.testing import assert_equal, assert_true, TestSuite
from akku.codec_base32 import (
    ErrorKind,
    encode,
    decode,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_decode_empty_input_is_empty_list() raises:
    var empty = decode("")
    assert_equal(len(empty), 0)
    var raw = List[UInt8]()
    var empty_bytes = decode(Span(raw))
    assert_equal(len(empty_bytes), 0)

def test_decode_standard_vectors() raises:
    assert_equal(decode("MY======"), bytes_of("f"))
    assert_equal(decode("MZXQ===="), bytes_of("fo"))
    assert_equal(decode("MZXW6==="), bytes_of("foo"))
    assert_equal(decode("MZXW6YQ="), bytes_of("foob"))
    assert_equal(decode("MZXW6YTB"), bytes_of("fooba"))
    assert_equal(decode("MZXW6YTBOI======"), bytes_of("foobar"))

def test_decode_hex_vectors() raises:
    assert_equal(decode("CO======"), bytes_of("f"))
    assert_equal(decode("CPNG===="), bytes_of("fo"))
    assert_equal(decode("CPNMU==="), bytes_of("foo"))
    assert_equal(decode("CPNMUOG="), bytes_of("foob"))
    assert_equal(decode("CPNMUOJ1"), bytes_of("fooba"))
    assert_equal(decode("CPNMUOJ1E8======"), bytes_of("foobar"))

def test_decode_binary_bytes_round_trip() raises:
    var data = List[UInt8]()
    for i in range(0, 16):
        data.append(UInt8(i))
    var encoded = encode(Span(data))
    var decoded = decode(encoded)
    assert_equal(decoded, data)

def test_decode_byte_overload_matches_string_overload() raises:
    var raw = bytes_of("MZXW6YTBOI======")
    assert_equal(decode(Span(raw)), bytes_of("foobar"))

def test_decode_borrows_input() raises:
    var raw = bytes_of("MZXW6YTBOI======")
    var before = bytes_of("MZXW6YTBOI======")
    _ = decode(Span(raw))
    assert_equal(raw, before)

def test_decode_is_atomic_no_output_on_error() raises:
    # The allocating form produces no List when it fails; the failure is
    # observed as a raised Base32Error, never as a partial result.
    var caught = False
    try:
        _ = decode("!!!!!!!!")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(caught)

def test_decode_rejects_invalid_symbol() raises:
    var caught = False
    try:
        _ = decode("MZ!W6===")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(caught)

def test_decode_rejects_impossible_length() raises:
    var caught = False
    try:
        _ = decode("A")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
    assert_true(caught)

def test_decode_rejects_bad_padding() raises:
    var caught = False
    try:
        _ = decode("MY")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
    assert_true(caught)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
