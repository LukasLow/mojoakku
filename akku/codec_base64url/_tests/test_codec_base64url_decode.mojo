from std.testing import assert_equal, assert_true, TestSuite
from akku.codec_base64url import encode, decode

def bytes_of(values: List[Int]) -> List[UInt8]:
    var result = List[UInt8]()
    for value in values:
        result.append(UInt8(value))
    return result^

def test_decode_empty() raises:
    assert_equal(len(decode("")), 0)
    var encoded = List[UInt8]()
    assert_equal(len(decode(Span(encoded))), 0)

def test_decode_padded_and_unpadded() raises:
    assert_equal(decode("Zg"), bytes_of([102]))
    assert_equal(decode("Zg=="), bytes_of([102]))
    assert_equal(decode("Zm8"), bytes_of([102, 111]))
    assert_equal(decode("Zm8="), bytes_of([102, 111]))
    assert_equal(decode("Zm9v"), bytes_of([102, 111, 111]))
    assert_equal(decode("Zm9vYmFy"), bytes_of([102, 111, 111, 98, 97, 114]))
    var padded = bytes_of([90, 103, 61, 61])
    var raw = bytes_of([90, 103])
    assert_equal(decode(Span(padded)), bytes_of([102]))
    assert_equal(decode(Span(raw)), bytes_of([102]))

def test_decode_url_symbols() raises:
    assert_equal(decode("-_8"), bytes_of([251, 255]))
    assert_equal(decode("-_8="), bytes_of([251, 255]))
    var raw = bytes_of([45, 95, 56])
    assert_equal(decode(Span(raw)), bytes_of([251, 255]))

def test_decode_binary_all_values() raises:
    # Independent fixed Python stdlib Base64url fixture, not sibling output.
    var encoded = String("AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0-P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn-AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq-wsbKztLW2t7i5uru8vb6_wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t_g4eLj5OXm5-jp6uvs7e7v8PHy8_T19vf4-fr7_P3-_w")
    var expected = List[UInt8]()
    for i in range(256):
        expected.append(UInt8(i))
    assert_equal(decode(encoded), expected)
    assert_equal(decode(encoded.as_bytes()), expected)

def test_decode_borrows_inputs() raises:
    var text = String("Zg")
    _ = decode(text)
    assert_equal(text, "Zg")
    var data = bytes_of([90, 103])
    _ = decode(Span(data))
    assert_equal(data, bytes_of([90, 103]))

def test_decode_result_is_independent() raises:
    var text = String("Zg")
    var decoded = decode(text)
    text = "eA"
    assert_equal(decoded, bytes_of([102]))
    var input = bytes_of([90, 103])
    var from_bytes = decode(Span(input))
    input[0] = 101
    assert_equal(from_bytes, bytes_of([102]))
    decoded[0] = 120
    assert_equal(from_bytes, bytes_of([102]))

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
