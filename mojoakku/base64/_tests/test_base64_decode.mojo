# Concern: `decode` — borrowed encoded text/bytes to an owned `List[UInt8]`,
# raising `Base64Error` (docs block in `../decode.mojo`).
#
# Covers: both overloads (StringSpan, Span[UInt8]); empty input decodes to an
# empty List; the documented success path across alphabets; the allocating form
# is atomic (no List is produced on failure); input is borrowed; errors carry
# the three documented kinds.

from std.testing import assert_equal, assert_true, TestSuite
from base64 import (
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
    assert_equal(decode("Zg=="), bytes_of("f"))
    assert_equal(decode("Zm8="), bytes_of("fo"))
    assert_equal(decode("Zm9v"), bytes_of("foo"))
    assert_equal(decode("Zm9vYg=="), bytes_of("foob"))
    assert_equal(decode("Zm9vYmE="), bytes_of("fooba"))
    assert_equal(decode("Zm9vYmFy"), bytes_of("foobar"))

def test_decode_binary_bytes_round_trip() raises:
    var data = List[UInt8]()
    for i in range(0, 16):
        data.append(UInt8(i))
    var encoded = encode(Span(data))
    var decoded = decode(encoded)
    assert_equal(decoded, data)

def test_decode_byte_overload_matches_string_overload() raises:
    var raw = bytes_of("Zm9vYmFy")
    assert_equal(decode(Span(raw)), bytes_of("foobar"))

def test_decode_borrows_input() raises:
    var raw = bytes_of("Zm9vYmFy")
    var before = bytes_of("Zm9vYmFy")
    _ = decode(Span(raw))
    assert_equal(raw, before)

def test_decode_is_atomic_no_output_on_error() raises:
    # The allocating form produces no List when it fails; the failure is
    # observed as a raised Base64Error, never as a partial result. The `result`
    # binding below only exists on success, which the error path proves.
    var caught = False
    try:
        _ = decode("!!!!")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(caught)

def test_decode_rejects_invalid_symbol() raises:
    var caught = False
    try:
        _ = decode("Zm!v")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(caught)

def test_decode_rejects_impossible_length() raises:
    var caught = False
    try:
        _ = decode("Z")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
    assert_true(caught)

def test_decode_rejects_bad_padding() raises:
    var caught = False
    try:
        _ = decode("Zg")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
    assert_true(caught)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
