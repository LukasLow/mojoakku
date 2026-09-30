from std.testing import assert_equal, assert_true, TestSuite
from akku.codec_base64url import encode, decode

from akku.codec_base64 import ErrorKind

def bytes_of(values: List[Int]) -> List[UInt8]:
    var result = List[UInt8]()
    for value in values:
        result.append(UInt8(value))
    return result^

def expect_error(input: StringSpan, expected: ErrorKind, position: Int) raises:
    var caught = False
    try:
        _ = decode(input)
    except e:
        caught = True
        assert_equal(e.kind, expected)
        assert_equal(e.position, position)
    assert_true(caught)
    # Repeat each same malformed byte sequence through the binary overload.
    var caught_bytes = False
    try:
        _ = decode(input.as_bytes())
    except e:
        caught_bytes = True
        assert_equal(e.kind, expected)
        assert_equal(e.position, position)
    assert_true(caught_bytes)

def test_decode_nonzero_trailing_bits() raises:
    assert_equal(decode("Zh"), bytes_of([102]))
    assert_equal(decode("Zh=="), bytes_of([102]))
    assert_equal(decode("Zm9"), bytes_of([102, 111]))
    assert_equal(decode("Zm9="), bytes_of([102, 111]))
    var encoded = bytes_of([90, 104])
    assert_equal(decode(Span(encoded)), bytes_of([102]))

def test_decode_rejects_standard_alphabet() raises:
    expect_error("+_8", ErrorKind.INVALID_SYMBOL, 0)
    expect_error("-/8", ErrorKind.INVALID_SYMBOL, 1)

def test_decode_rejects_whitespace() raises:
    expect_error(" Zg", ErrorKind.INVALID_SYMBOL, 0)
    expect_error("Z g", ErrorKind.INVALID_SYMBOL, 1)
    expect_error("Zg\t", ErrorKind.INVALID_SYMBOL, 2)
    expect_error("Zg\n", ErrorKind.INVALID_SYMBOL, 2)
    expect_error("Zg\r", ErrorKind.INVALID_SYMBOL, 2)

def test_decode_rejects_invalid_symbols() raises:
    expect_error("Zm!v", ErrorKind.INVALID_SYMBOL, 2)
    expect_error("Zg\x00", ErrorKind.INVALID_SYMBOL, 2)
    expect_error("Zg?", ErrorKind.INVALID_SYMBOL, 2)

def test_decode_rejects_impossible_remainder() raises:
    expect_error("Z", ErrorKind.INVALID_LENGTH, 0)
    expect_error("Zm9vZ", ErrorKind.INVALID_LENGTH, 4)

def test_decode_rejects_bad_padding() raises:
    expect_error("Zg=", ErrorKind.INVALID_PADDING, 0)
    expect_error("Zg===", ErrorKind.INVALID_PADDING, 0)
    expect_error("Z=g=", ErrorKind.INVALID_PADDING, 0)
    expect_error("Zg==Zg", ErrorKind.INVALID_PADDING, 0)
    expect_error("Zm9vZg=", ErrorKind.INVALID_PADDING, 4)

def test_decode_failure_has_no_result() raises:
    var returned = False
    var caught = False
    try:
        var result = decode("Zm9v!")
        returned = True
        _ = result
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 4)
    assert_true(caught)
    assert_true(not returned)
    assert_equal(decode("Zg"), bytes_of([102]))

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
