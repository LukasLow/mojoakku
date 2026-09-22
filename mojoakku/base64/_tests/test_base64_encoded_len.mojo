# Concern: `encoded_len` — exact encoded length for n raw input bytes
# (docs block in `../encoded_len.mojo`).
#
# Covers: the exact formulas for base64 (REQUIRED/OMITTED), base32
# (REQUIRED/OMITTED) and base16; n = 0 returns 0; the function is total and
# returns 0 for a negative n (defined safety net, does not trap); it is pure and
# callable with explicit compile-time parameters.

from std.testing import assert_equal, TestSuite
from base64 import (
    Alphabet,
    Padding,
    encoded_len,
)

def test_base64_required_formula() raises:
    # 4 * ((n + 2) // 3)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.REQUIRED](0), 0)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.REQUIRED](1), 4)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.REQUIRED](2), 4)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.REQUIRED](3), 4)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.REQUIRED](4), 8)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.REQUIRED](5), 8)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.REQUIRED](6), 8)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.REQUIRED](7), 12)

def test_base64_omitted_formula() raises:
    # ceil(n/3)*4 - ((3 - n%3) % 3), empty input -> 0
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.OMITTED](0), 0)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.OMITTED](1), 2)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.OMITTED](2), 3)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.OMITTED](3), 4)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.OMITTED](4), 6)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.OMITTED](5), 7)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.OMITTED](6), 8)

def test_base32_required_formula() raises:
    # 8 * ((n + 4) // 5)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.REQUIRED](0), 0)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.REQUIRED](1), 8)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.REQUIRED](5), 8)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.REQUIRED](6), 16)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.REQUIRED](10), 16)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.REQUIRED](11), 24)

def test_base32_omitted_formula() raises:
    # (n * 8 + 4) // 5
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.OMITTED](0), 0)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.OMITTED](1), 2)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.OMITTED](2), 4)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.OMITTED](3), 5)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.OMITTED](4), 7)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.OMITTED](5), 8)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.OMITTED](6), 10)

def test_base32_hex_uses_same_lengths_as_base32() raises:
    # Absolute anchor: B32_HEX OMITTED for 6 bytes is 5 symbols * 2 = 10
    # (the same value B32_STANDARD would give), so the relative comparison
    # below cannot pass on two equally wrong results.
    assert_equal(encoded_len[Alphabet.B32_HEX, Padding.OMITTED](6), 10)
    assert_equal(
        encoded_len[Alphabet.B32_HEX, Padding.REQUIRED](3),
        encoded_len[Alphabet.B32_STANDARD, Padding.REQUIRED](3),
    )
    assert_equal(
        encoded_len[Alphabet.B32_HEX, Padding.OMITTED](3),
        encoded_len[Alphabet.B32_STANDARD, Padding.OMITTED](3),
    )

def test_base16_is_twice_n_for_both_paddings() raises:
    assert_equal(encoded_len[Alphabet.HEX_LOWER, Padding.REQUIRED](0), 0)
    assert_equal(encoded_len[Alphabet.HEX_LOWER, Padding.REQUIRED](5), 10)
    assert_equal(encoded_len[Alphabet.HEX_LOWER, Padding.OMITTED](5), 10)
    assert_equal(encoded_len[Alphabet.HEX_UPPER, Padding.REQUIRED](7), 14)
    assert_equal(encoded_len[Alphabet.HEX_UPPER, Padding.OMITTED](7), 14)

def test_zero_returns_zero_in_every_case() raises:
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.REQUIRED](0), 0)
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.OMITTED](0), 0)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.REQUIRED](0), 0)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.OMITTED](0), 0)
    assert_equal(encoded_len[Alphabet.HEX_LOWER, Padding.REQUIRED](0), 0)
    assert_equal(encoded_len[Alphabet.HEX_UPPER, Padding.OMITTED](0), 0)

def test_negative_n_is_defined_to_return_zero() raises:
    # Total function: a caller programming error is defined to return 0.
    assert_equal(encoded_len[Alphabet.B64_STANDARD, Padding.REQUIRED](-1), 0)
    assert_equal(encoded_len[Alphabet.B32_STANDARD, Padding.REQUIRED](-5), 0)
    assert_equal(encoded_len[Alphabet.HEX_UPPER, Padding.OMITTED](-100), 0)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
