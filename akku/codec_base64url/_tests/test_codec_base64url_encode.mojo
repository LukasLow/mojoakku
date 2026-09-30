from std.testing import assert_equal, assert_true, TestSuite
from akku.codec_base64url import encode, decode

def bytes_of(values: List[Int]) -> List[UInt8]:
    var result = List[UInt8]()
    for value in values:
        result.append(UInt8(value))
    return result^

def test_encode_empty() raises:
    assert_equal(encode(""), "")
    var data = List[UInt8]()
    assert_equal(encode(Span(data)), "")

def test_encode_rfc_vectors() raises:
    assert_equal(encode("f"), "Zg")
    assert_equal(encode("fo"), "Zm8")
    assert_equal(encode("foo"), "Zm9v")
    assert_equal(encode("foob"), "Zm9vYg")
    assert_equal(encode("fooba"), "Zm9vYmE")
    assert_equal(encode("foobar"), "Zm9vYmFy")
    # Python stdlib oracle: UTF-8 bytes are distinct; no normalization.
    assert_equal(encode("é"), "w6k")
    assert_equal(encode("é"), "ZcyB")

def test_encode_url_symbols() raises:
    var data = bytes_of([251, 255])
    assert_equal(encode(Span(data)), "-_8")

def test_encode_binary_all_values() raises:
    var data = List[UInt8]()
    for i in range(256):
        data.append(UInt8(i))
    # Independent oracle: Python stdlib urlsafe_b64encode(bytes(range(256)))
    # with only the final '=' omitted, generated at test-authoring time.
    assert_equal(encode(Span(data)), "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0-P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn-AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq-wsbKztLW2t7i5uru8vb6_wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t_g4eLj5OXm5-jp6uvs7e7v8PHy8_T19vf4-fr7_P3-_w")

def test_encode_borrows_inputs() raises:
    var text = String("foobar")
    _ = encode(text)
    assert_equal(text, "foobar")
    var data = bytes_of([0, 251, 255])
    _ = encode(Span(data))
    assert_equal(data, bytes_of([0, 251, 255]))

def test_encode_result_is_independent() raises:
    var data = bytes_of([102])
    var result = encode(Span(data))
    data[0] = 120
    assert_equal(result, "Zg")
    var text = String("f")
    var from_text = encode(text)
    text = "x"
    assert_equal(from_text, "Zg")

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
