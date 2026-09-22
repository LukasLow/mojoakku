# Concern: `decoded_len` — maximum decoded byte count for n encoded symbols
# (BASE64_DOCS.md `### decoded_len`).
#
# Covers: the base64, base32 and base16 upper-bound formulas including the
# partial-quantum contribution; n = 0 returns 0; the function is total and
# returns 0 for a negative n; it is a conservative upper bound (>= the actual
# decoded length) and counts padding symbols as input symbols.

from std.testing import assert_equal, assert_true, TestSuite
from base64 import (
    Alphabet,
    decode,
    decoded_len,
)

def test_base64_formula() raises:
    # (n // 4) * 3 plus partial contribution (n%4 == 2 -> 1, 3 -> 2, 1 -> 0).
    assert_equal(decoded_len[Alphabet.B64_STANDARD](0), 0)
    assert_equal(decoded_len[Alphabet.B64_STANDARD](1), 0)
    assert_equal(decoded_len[Alphabet.B64_STANDARD](2), 1)
    assert_equal(decoded_len[Alphabet.B64_STANDARD](3), 2)
    assert_equal(decoded_len[Alphabet.B64_STANDARD](4), 3)
    assert_equal(decoded_len[Alphabet.B64_STANDARD](5), 3)
    assert_equal(decoded_len[Alphabet.B64_STANDARD](6), 4)
    assert_equal(decoded_len[Alphabet.B64_STANDARD](7), 5)
    assert_equal(decoded_len[Alphabet.B64_STANDARD](8), 6)

def test_base32_formula_partial_map() raises:
    # (n // 8) * 5 plus partial: 2->1, 4->2, 5->3, 7->4; 1,3,6 -> 0.
    assert_equal(decoded_len[Alphabet.B32_STANDARD](0), 0)
    assert_equal(decoded_len[Alphabet.B32_STANDARD](2), 1)
    assert_equal(decoded_len[Alphabet.B32_STANDARD](4), 2)
    assert_equal(decoded_len[Alphabet.B32_STANDARD](5), 3)
    assert_equal(decoded_len[Alphabet.B32_STANDARD](7), 4)
    assert_equal(decoded_len[Alphabet.B32_STANDARD](1), 0)
    assert_equal(decoded_len[Alphabet.B32_STANDARD](3), 0)
    assert_equal(decoded_len[Alphabet.B32_STANDARD](6), 0)
    assert_equal(decoded_len[Alphabet.B32_STANDARD](8), 5)
    assert_equal(decoded_len[Alphabet.B32_STANDARD](10), 6)

def test_base32_hex_uses_same_lengths_as_base32() raises:
    for n in range(0, 17):
        assert_equal(
            decoded_len[Alphabet.B32_HEX](n),
            decoded_len[Alphabet.B32_STANDARD](n),
        )

def test_base16_formula_is_half_n() raises:
    assert_equal(decoded_len[Alphabet.HEX_LOWER](0), 0)
    assert_equal(decoded_len[Alphabet.HEX_LOWER](1), 0)
    assert_equal(decoded_len[Alphabet.HEX_LOWER](2), 1)
    assert_equal(decoded_len[Alphabet.HEX_UPPER](7), 3)
    assert_equal(decoded_len[Alphabet.HEX_UPPER](8), 4)

def test_zero_returns_zero_in_every_alphabet() raises:
    assert_equal(decoded_len[Alphabet.B64_STANDARD](0), 0)
    assert_equal(decoded_len[Alphabet.B64_URL](0), 0)
    assert_equal(decoded_len[Alphabet.B32_STANDARD](0), 0)
    assert_equal(decoded_len[Alphabet.B32_HEX](0), 0)
    assert_equal(decoded_len[Alphabet.HEX_LOWER](0), 0)
    assert_equal(decoded_len[Alphabet.HEX_UPPER](0), 0)

def test_negative_n_is_defined_to_return_zero() raises:
    assert_equal(decoded_len[Alphabet.B64_STANDARD](-1), 0)
    assert_equal(decoded_len[Alphabet.B32_STANDARD](-9), 0)
    assert_equal(decoded_len[Alphabet.HEX_UPPER](-4), 0)

def test_is_a_conservative_upper_bound() raises:
    # For any valid encoded text the actual decoded length is at most
    # decoded_len(symbol count); with padding present it is a strict bound.
    var encoded = "Zm9vYmFy"
    var actual = decode(encoded)
    assert_true(len(actual) <= decoded_len[Alphabet.B64_STANDARD](8))
    assert_equal(len(actual), 6)

    var padded = decode("Zm8=")
    assert_equal(len(padded), 2)
    assert_true(len(padded) <= decoded_len[Alphabet.B64_STANDARD](4))

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
