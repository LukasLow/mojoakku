# Concern: `Padding` — the compile-time encode padding policy REQUIRED vs
# OMITTED (docs block in `../padding.mojo`).
#
# Covers: REQUIRED emits the RFC 4648 §6 '=' count completing the final partial
# quantum; OMITTED never emits '='; the choice is visible in the signature;
# empty input yields an empty String under both policies; decode is governed
# separately by `PaddingMode`.

from std.testing import assert_equal, TestSuite
from akku.codec_base32 import (
    Alphabet,
    Padding,
    PaddingMode,
    encode,
    decode,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_required_pads_partial_quantum() raises:
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("f"), "MY======")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("fo"), "MZXQ====")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("foo"), "MZXW6===")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("foob"), "MZXW6YQ=")

def test_omitted_never_emits_padding() raises:
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.OMITTED]("f"), "MY")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.OMITTED]("fo"), "MZXQ")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.OMITTED]("foo"), "MZXW6")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.OMITTED]("foob"), "MZXW6YQ")
    assert_equal(
        encode[Alphabet.B32_STANDARD, Padding.OMITTED]("fooba"), "MZXW6YTB"
    )
    assert_equal(
        encode[Alphabet.B32_STANDARD, Padding.OMITTED]("foobar"), "MZXW6YTBOI"
    )

def test_default_is_required() raises:
    # The documented default of `encode` is standard base32 with required padding.
    assert_equal(encode("fo"), "MZXQ====")
    assert_equal(encode[Alphabet.B32_STANDARD]("fo"), "MZXQ====")

def test_full_quantum_has_no_padding_under_either_policy() raises:
    # 5 bytes make one whole quantum: 8 symbols, no '=' either way.
    assert_equal(
        encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("fooba"), "MZXW6YTB"
    )
    assert_equal(
        encode[Alphabet.B32_STANDARD, Padding.OMITTED]("fooba"), "MZXW6YTB"
    )

def test_hex_required_and_omitted() raises:
    assert_equal(encode[Alphabet.B32_HEX, Padding.REQUIRED]("f"), "CO======")
    assert_equal(encode[Alphabet.B32_HEX, Padding.OMITTED]("f"), "CO")
    assert_equal(encode[Alphabet.B32_HEX, Padding.REQUIRED]("fo"), "CPNG====")
    assert_equal(encode[Alphabet.B32_HEX, Padding.OMITTED]("fo"), "CPNG")

def test_empty_input_yields_empty_string_for_both_policies() raises:
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.REQUIRED](""), "")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.OMITTED](""), "")
    assert_equal(encode[Alphabet.B32_HEX, Padding.REQUIRED](""), "")
    assert_equal(encode[Alphabet.B32_HEX, Padding.OMITTED](""), "")

def test_required_output_decodes_back_strict() raises:
    # Padding.REQUIRED output is canonical under the default PaddingMode.STRICT.
    var encoded = encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("fo")
    assert_equal(encoded, "MZXQ====")
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.STRICT](encoded), bytes_of("fo")
    )

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
