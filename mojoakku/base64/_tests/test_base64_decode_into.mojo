# Concern: `decode_into` — decode into a caller-owned `mut result:
# List[UInt8]` and return the number of bytes appended (BASE64_DOCS.md
# `### decode_into`).
#
# Covers: both overloads; append semantics (prior contents kept); the returned
# count equals the bytes appended; partial-commit semantics on error (complete
# quanta already appended remain, and the appended prefix is a whole number of
# bytes); raising `Base64Error`.

from std.testing import assert_equal, assert_true, TestSuite
from base64 import (
    Alphabet,
    PaddingMode,
    Whitespace,
    ErrorKind,
    Base64Error,
    decode,
    decode_into,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_decode_into_appends_to_existing_contents() raises:
    var result = List[UInt8]()
    result.append(UInt8(0xAA))
    var n = decode_into("Zm9vYmFy", result)
    assert_equal(n, 6)
    assert_equal(len(result), 7)
    assert_equal(result[0], UInt8(0xAA))
    assert_equal(result[1], UInt8(0x66))

def test_decode_into_matches_decode() raises:
    var result = List[UInt8]()
    var n = decode_into("Zm9vYmFy", result)
    assert_equal(n, 6)
    assert_equal(result, decode("Zm9vYmFy"))

def test_decode_into_empty_input_appends_nothing() raises:
    var result = List[UInt8]()
    result.append(UInt8(1))
    var n = decode_into("", result)
    assert_equal(n, 0)
    assert_equal(len(result), 1)

def test_decode_into_byte_overload() raises:
    var raw = bytes_of("Zm9vYmFy")
    var result = List[UInt8]()
    var n = decode_into(Span(raw), result)
    assert_equal(n, 6)
    assert_equal(result, bytes_of("foobar"))

def test_decode_into_partial_commit_on_error() raises:
    # Complete quanta decoded before the invalid quantum remain appended.
    # "Zm9v" is one complete quantum ("foo"); "!" then fails.
    var result = List[UInt8]()
    var caught = False
    try:
        _ = decode_into("Zm9v!AAA", result)
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 4)
    assert_true(caught)
    assert_equal(result, bytes_of("foo"))

def test_decode_into_appended_prefix_is_whole_bytes() raises:
    var result = List[UInt8]()
    var caught = False
    try:
        _ = decode_into("Zm9vYmFy!!!", result)
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(caught)
    # Two complete quanta were appended; the third partial quantum is not.
    assert_equal(len(result), 6)
    assert_equal(result, bytes_of("foobar"))

def test_decode_into_error_keeps_result_valid() raises:
    var result = List[UInt8]()
    result.append(UInt8(7))
    var caught = False
    try:
        _ = decode_into("!!!!", result)
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(caught)
    assert_equal(len(result), 1)
    assert_equal(result[0], UInt8(7))

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
