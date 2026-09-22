# Concern: `Alphabet` — the six compile-time symbol tables and the per-alphabet
# case policy (BASE64_DOCS.md `### Alphabet`, "Case policy (decode)").
#
# Covers: B64_STANDARD, B64_URL, B32_STANDARD, B32_HEX, HEX_LOWER, HEX_UPPER.
# The alphabet fixes the symbols, the symbols-per-quantum ratio and, on decode,
# exactly which letter case is accepted. Cross-alphabet input is rejected.

from std.testing import assert_equal, assert_true, TestSuite
from base64 import (
    Alphabet,
    Padding,
    ErrorKind,
    encode,
    decode,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_b64_standard_vectors() raises:
    # RFC 4648 §4 test vectors.
    assert_equal(encode(""), "")
    assert_equal(encode("f"), "Zg==")
    assert_equal(encode("fo"), "Zm8=")
    assert_equal(encode("foo"), "Zm9v")
    assert_equal(encode("foob"), "Zm9vYg==")
    assert_equal(encode("fooba"), "Zm9vYmE=")
    assert_equal(encode("foobar"), "Zm9vYmFy")
    assert_equal(decode("Zm9vYmFy"), bytes_of("foobar"))

def test_b64_url_alphabet_replaces_plus_and_slash() raises:
    var raw = List[UInt8]()
    raw.append(UInt8(0xFB))
    raw.append(UInt8(0xFF))
    # Standard alphabet emits '+' and '/'; the URL alphabet emits '-' and '_'.
    assert_equal(encode[Alphabet.B64_STANDARD](Span(raw)), "+/8=")
    assert_equal(encode[Alphabet.B64_URL](Span(raw)), "-_8=")
    assert_equal(decode[Alphabet.B64_URL]("-_8="), raw)

def test_b64_standard_rejects_url_symbols() raises:
    # '-' and '_' belong only to the URL alphabet. The input is a structurally
    # valid 4-symbol quantum, so the failure is unambiguously INVALID_SYMBOL.
    var dash_caught = False
    try:
        _ = decode("Zm-v")
    except e:
        dash_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 2)
    assert_true(dash_caught)

    var underscore_caught = False
    try:
        _ = decode("Zm_v")
    except e:
        underscore_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 2)
    assert_true(underscore_caught)

def test_b64_case_sensitive_both_cases_are_symbols() raises:
    # base64 is inherently two-case: 'Z' and 'z' are different symbols.
    assert_equal(decode("Zm9v"), bytes_of("foo"))
    # Exact bytes, not mere inequality: 'z' has value 51, 'Z' has value 25.
    # "zm9v" -> 0xCE 0x6F 0x6F ("\xCEoo"); only 'm', '9' and 'v' are shared
    # with "Zm9v". The raw bytes are built as a List because 0xCE makes the
    # value invalid UTF-8 and so cannot be spelled as a String literal.
    var expected = List[UInt8]()
    expected.append(UInt8(0xCE))
    expected.append(UInt8(0x6F))
    expected.append(UInt8(0x6F))
    assert_equal(decode("zm9v"), expected)

def test_b32_standard_vectors() raises:
    # RFC 4648 §6 test vectors.
    assert_equal(encode[Alphabet.B32_STANDARD]("f"), "MY======")
    assert_equal(encode[Alphabet.B32_STANDARD]("fo"), "MZXQ====")
    assert_equal(encode[Alphabet.B32_STANDARD]("foo"), "MZXW6===")
    assert_equal(encode[Alphabet.B32_STANDARD]("foob"), "MZXW6YQ=")
    assert_equal(encode[Alphabet.B32_STANDARD]("fooba"), "MZXW6YTB")
    assert_equal(encode[Alphabet.B32_STANDARD]("foobar"), "MZXW6YTBOI======")
    assert_equal(
        decode[Alphabet.B32_STANDARD]("MZXW6YTBOI======"), bytes_of("foobar")
    )

def test_b32_lowercase_is_invalid_symbol() raises:
    # base32 is uppercase-only; lowercase is not accepted.
    var caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD]("my======")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 0)
    assert_true(caught)

def test_b32_hex_uses_extended_hex_alphabet() raises:
    # RFC 4648 §7 test vectors.
    assert_equal(encode[Alphabet.B32_HEX]("f"), "CO======")
    assert_equal(encode[Alphabet.B32_HEX]("fo"), "CPNG====")
    assert_equal(encode[Alphabet.B32_HEX]("foo"), "CPNMU===")
    assert_equal(encode[Alphabet.B32_HEX]("foob"), "CPNMUOG=")
    assert_equal(encode[Alphabet.B32_HEX]("fooba"), "CPNMUOJ1")
    assert_equal(encode[Alphabet.B32_HEX]("foobar"), "CPNMUOJ1E8======")
    assert_equal(
        decode[Alphabet.B32_HEX]("CPNMUOJ1E8======"), bytes_of("foobar")
    )

def test_hex_lower_vectors() raises:
    assert_equal(encode[Alphabet.HEX_LOWER]("f"), "66")
    assert_equal(encode[Alphabet.HEX_LOWER]("fo"), "666f")
    assert_equal(encode[Alphabet.HEX_LOWER]("foobar"), "666f6f626172")
    assert_equal(decode[Alphabet.HEX_LOWER]("666f6f626172"), bytes_of("foobar"))

def test_hex_upper_vectors() raises:
    assert_equal(encode[Alphabet.HEX_UPPER]("f"), "66")
    assert_equal(encode[Alphabet.HEX_UPPER]("fo"), "666F")
    assert_equal(encode[Alphabet.HEX_UPPER]("foobar"), "666F6F626172")
    assert_equal(decode[Alphabet.HEX_UPPER]("666F6F626172"), bytes_of("foobar"))

def test_hex_case_sensitive_on_decode() raises:
    # Each HEX_* alphabet accepts only its own case on decode.
    var upper_caught = False
    try:
        _ = decode[Alphabet.HEX_UPPER]("666f")
    except e:
        upper_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 3)
    assert_true(upper_caught)

    var lower_caught = False
    try:
        _ = decode[Alphabet.HEX_LOWER]("666F")
    except e:
        lower_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 3)
    assert_true(lower_caught)

def test_hex_padding_values_are_equivalent() raises:
    # base16 has no padding concept, so both Padding values emit the same text.
    assert_equal(
        encode[Alphabet.HEX_UPPER, Padding.OMITTED]("fo"),
        encode[Alphabet.HEX_UPPER, Padding.REQUIRED]("fo"),
    )
    assert_equal(
        encode[Alphabet.HEX_LOWER, Padding.OMITTED]("foobar"),
        encode[Alphabet.HEX_LOWER, Padding.REQUIRED]("foobar"),
    )

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
