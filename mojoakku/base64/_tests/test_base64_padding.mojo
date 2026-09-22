# Concern: `Padding` — the compile-time encode padding policy REQUIRED vs OMITTED
# (BASE64_DOCS.md `### Padding`).
#
# Covers: REQUIRED emits '=' to complete the final quantum; OMITTED never emits
# '='; the choice is visible in the signature and affects base64/base32 output
# only (base16 has no padding). Decode is governed separately by `PaddingMode`.

from std.testing import assert_equal, TestSuite
from base64 import (
    Alphabet,
    Padding,
    PaddingMode,
    encode,
    decode,
)

def test_b64_required_pads_partial_quantum() raises:
    assert_equal(encode[Alphabet.B64_STANDARD, Padding.REQUIRED]("f"), "Zg==")
    assert_equal(encode[Alphabet.B64_STANDARD, Padding.REQUIRED]("fo"), "Zm8=")
    assert_equal(encode[Alphabet.B64_STANDARD, Padding.REQUIRED]("foo"), "Zm9v")

def test_b64_omitted_never_emits_padding() raises:
    assert_equal(encode[Alphabet.B64_STANDARD, Padding.OMITTED]("f"), "Zg")
    assert_equal(encode[Alphabet.B64_STANDARD, Padding.OMITTED]("fo"), "Zm8")
    assert_equal(encode[Alphabet.B64_STANDARD, Padding.OMITTED]("foo"), "Zm9v")
    assert_equal(encode[Alphabet.B64_STANDARD, Padding.OMITTED]("foobar"), "Zm9vYmFy")

def test_b64_default_is_required() raises:
    # The documented default of `encode` is standard base64 with required padding.
    assert_equal(encode("fo"), "Zm8=")
    assert_equal(encode[Alphabet.B64_STANDARD]("fo"), "Zm8=")

def test_b32_required_pads_partial_quantum() raises:
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("f"), "MY======")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("fo"), "MZXQ====")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.REQUIRED]("foob"), "MZXW6YQ=")

def test_b32_omitted_never_emits_padding() raises:
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.OMITTED]("f"), "MY")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.OMITTED]("fo"), "MZXQ")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.OMITTED]("foob"), "MZXW6YQ")
    assert_equal(
        encode[Alphabet.B32_STANDARD, Padding.OMITTED]("foobar"), "MZXW6YTBOI"
    )

def test_empty_input_yields_empty_string_for_both_policies() raises:
    assert_equal(encode[Alphabet.B64_STANDARD, Padding.REQUIRED](""), "")
    assert_equal(encode[Alphabet.B64_STANDARD, Padding.OMITTED](""), "")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.REQUIRED](""), "")
    assert_equal(encode[Alphabet.B32_STANDARD, Padding.OMITTED](""), "")

def test_required_output_decodes_back_strict() raises:
    # Padding.REQUIRED output is canonical under the default PaddingMode.STRICT.
    var encoded = encode[Alphabet.B64_STANDARD, Padding.REQUIRED]("fo")
    var decoded = decode[Alphabet.B64_STANDARD, PaddingMode.STRICT](encoded)
    assert_equal(decoded, decode("fo"))

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
