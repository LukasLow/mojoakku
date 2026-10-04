# Concern: `Alphabet` — the two compile-time symbol tables and the per-alphabet
# case policy (docs block in `../alphabet.mojo`).
#
# Covers: B32_STANDARD, B32_HEX. The alphabet fixes the symbols and the
# 5-bits-per-symbol geometry (5 bytes <-> 8 symbols). On decode both alphabets
# accept only their uppercase spellings and reject lowercase and the other
# alphabet's exclusive symbols.

from std.testing import assert_equal, assert_true, TestSuite
from akku.codec_base32 import (
    Alphabet,
    ErrorKind,
    encode,
    decode,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_b32_standard_vectors() raises:
    # RFC 4648 §10 test vectors, standard alphabet.
    assert_equal(encode[Alphabet.B32_STANDARD](""), "")
    assert_equal(encode[Alphabet.B32_STANDARD]("f"), "MY======")
    assert_equal(encode[Alphabet.B32_STANDARD]("fo"), "MZXQ====")
    assert_equal(encode[Alphabet.B32_STANDARD]("foo"), "MZXW6===")
    assert_equal(encode[Alphabet.B32_STANDARD]("foob"), "MZXW6YQ=")
    assert_equal(encode[Alphabet.B32_STANDARD]("fooba"), "MZXW6YTB")
    assert_equal(encode[Alphabet.B32_STANDARD]("foobar"), "MZXW6YTBOI======")
    assert_equal(
        decode[Alphabet.B32_STANDARD]("MZXW6YTBOI======"), bytes_of("foobar")
    )

def test_b32_hex_vectors() raises:
    # RFC 4648 §10 test vectors, extended-hex alphabet.
    assert_equal(encode[Alphabet.B32_HEX]("f"), "CO======")
    assert_equal(encode[Alphabet.B32_HEX]("fo"), "CPNG====")
    assert_equal(encode[Alphabet.B32_HEX]("foo"), "CPNMU===")
    assert_equal(encode[Alphabet.B32_HEX]("foob"), "CPNMUOG=")
    assert_equal(encode[Alphabet.B32_HEX]("fooba"), "CPNMUOJ1")
    assert_equal(encode[Alphabet.B32_HEX]("foobar"), "CPNMUOJ1E8======")
    assert_equal(
        decode[Alphabet.B32_HEX]("CPNMUOJ1E8======"), bytes_of("foobar")
    )

def test_b32_standard_rejects_lowercase() raises:
    # base32 is uppercase-only; lowercase is an invalid symbol at its position.
    var caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD]("mzxw6===")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 0)
    assert_true(caught)

def test_b32_hex_rejects_lowercase() raises:
    var caught = False
    try:
        _ = decode[Alphabet.B32_HEX]("cpnmu===")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 0)
    assert_true(caught)

def test_b32_standard_rejects_hex_only_symbols() raises:
    # '8' and '9' exist only in the extended-hex alphabet; the remainder is
    # structurally valid (2 data symbols + 6 '='), so the failure is the symbol.
    var eight_caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD]("C8======")
    except e:
        eight_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 1)
    assert_true(eight_caught)

    var nine_caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD]("C9======")
    except e:
        nine_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 1)
    assert_true(nine_caught)

def test_b32_hex_rejects_standard_only_symbols() raises:
    # 'W', 'X', 'Y', 'Z' exist only in the standard alphabet.
    var w_caught = False
    try:
        _ = decode[Alphabet.B32_HEX]("CW======")
    except e:
        w_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 1)
    assert_true(w_caught)

    var z_caught = False
    try:
        _ = decode[Alphabet.B32_HEX]("CZ======")
    except e:
        z_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
        assert_equal(e.position, 1)
    assert_true(z_caught)

def test_both_alphabets_share_the_five_to_eight_geometry() raises:
    # The alphabet changes the symbols, not the length: 1..4 bytes always
    # encode to 8 characters with required padding.
    for text in ["f", "fo", "foo", "foob"]:
        assert_equal(encode[Alphabet.B32_STANDARD](text).byte_length(), 8)
        assert_equal(encode[Alphabet.B32_HEX](text).byte_length(), 8)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
