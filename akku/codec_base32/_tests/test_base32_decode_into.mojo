# Concern: `decode_into` — decode into a caller-owned `mut result:
# List[UInt8]` and return the number of bytes appended (docs block in
# `../decode_into.mojo`).
#
# Covers: both overloads; append semantics (prior contents kept); the returned
# count equals the bytes appended; partial-commit semantics on error (complete
# quanta already appended remain, and the appended prefix is a whole number of
# bytes); raising Base32Error.

from std.testing import assert_equal, assert_true, TestSuite
from akku.codec_base32 import (
    ErrorKind,
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
    var n = decode_into("MZXW6YTBOI======", result)
    assert_equal(n, 6)
    assert_equal(len(result), 7)
    assert_equal(result[0], UInt8(0xAA))
    assert_equal(result[1], UInt8(0x66))

def test_decode_into_matches_decode() raises:
    var result = List[UInt8]()
    var n = decode_into("MZXW6YTBOI======", result)
    assert_equal(n, 6)
    assert_equal(result, decode("MZXW6YTBOI======"))

def test_decode_into_empty_input_appends_nothing() raises:
    var result = List[UInt8]()
    result.append(UInt8(1))
    var n = decode_into("", result)
    assert_equal(n, 0)
    assert_equal(len(result), 1)

def test_decode_into_byte_overload() raises:
    var raw = bytes_of("MZXW6YTBOI======")
    var result = List[UInt8]()
    var n = decode_into(Span(raw), result)
    assert_equal(n, 6)
    assert_equal(result, bytes_of("foobar"))

def test_decode_into_partial_commit_on_error() raises:
    # Complete quanta decoded before the invalid quantum remain appended.
    # "MZXW6YTB" is one complete 8-symbol quantum ("fooba"); then '!' fails.
    var result = List[UInt8]()
    var caught = False
    try:
        _ = decode_into("MZXW6YTB!OI======", result)
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 8)
    assert_true(caught)
    assert_equal(result, bytes_of("fooba"))

def test_decode_into_appended_prefix_is_whole_bytes() raises:
    var result = List[UInt8]()
    var caught = False
    try:
        _ = decode_into("MZXW6YTBMZXW6YTB!!!", result)
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(caught)
    # Two complete 8-symbol quanta ("fooba" twice) were appended; the trailing
    # invalid symbols are not.
    assert_equal(len(result), 10)
    assert_equal(result, bytes_of("foobafooba"))

def test_decode_into_error_keeps_result_valid() raises:
    var result = List[UInt8]()
    result.append(UInt8(7))
    var caught = False
    try:
        _ = decode_into("!!!!!!!!", result)
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(caught)
    assert_equal(len(result), 1)
    assert_equal(result[0], UInt8(7))

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
