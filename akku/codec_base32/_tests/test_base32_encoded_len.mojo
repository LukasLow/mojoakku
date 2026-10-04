# Concern: `encoded_len` — exact encoded length for n raw input bytes
# (docs block in `../encoded_len.mojo`).
#
# Covers: the exact formulas REQUIRED 8*((n+4)//5) and OMITTED (n*8+4)//5;
# n = 0 returns 0; the function is total and returns 0 for a negative n
# (defined safety net, does not trap); there is no alphabet parameter because
# both base32 alphabets share the 5<->8 geometry.

from std.testing import assert_equal, TestSuite
from akku.codec_base32 import (
    Padding,
    encoded_len,
)

def test_required_formula() raises:
    # 8 * ((n + 4) // 5)
    assert_equal(encoded_len[Padding.REQUIRED](0), 0)
    assert_equal(encoded_len[Padding.REQUIRED](1), 8)
    assert_equal(encoded_len[Padding.REQUIRED](2), 8)
    assert_equal(encoded_len[Padding.REQUIRED](3), 8)
    assert_equal(encoded_len[Padding.REQUIRED](4), 8)
    assert_equal(encoded_len[Padding.REQUIRED](5), 8)
    assert_equal(encoded_len[Padding.REQUIRED](6), 16)
    assert_equal(encoded_len[Padding.REQUIRED](10), 16)
    assert_equal(encoded_len[Padding.REQUIRED](11), 24)

def test_omitted_formula() raises:
    # (n * 8 + 4) // 5
    assert_equal(encoded_len[Padding.OMITTED](0), 0)
    assert_equal(encoded_len[Padding.OMITTED](1), 2)
    assert_equal(encoded_len[Padding.OMITTED](2), 4)
    assert_equal(encoded_len[Padding.OMITTED](3), 5)
    assert_equal(encoded_len[Padding.OMITTED](4), 7)
    assert_equal(encoded_len[Padding.OMITTED](5), 8)
    assert_equal(encoded_len[Padding.OMITTED](6), 10)
    assert_equal(encoded_len[Padding.OMITTED](10), 16)

def test_default_padding_is_required() raises:
    # The documented default of `encoded_len` is Padding.REQUIRED.
    assert_equal(encoded_len(1), encoded_len[Padding.REQUIRED](1))
    assert_equal(encoded_len(6), encoded_len[Padding.REQUIRED](6))

def test_omitted_is_required_minus_padding_count() raises:
    # REQUIRED - OMITTED equals the RFC 4648 §6 '=' count for n % 5.
    for n in range(0, 21):
        var pad = encoded_len[Padding.REQUIRED](n) - encoded_len[Padding.OMITTED](n)
        var expected = 0
        var rem = n % 5
        if rem == 1:
            expected = 6
        elif rem == 2:
            expected = 4
        elif rem == 3:
            expected = 3
        elif rem == 4:
            expected = 1
        assert_equal(pad, expected)

def test_zero_returns_zero_in_both_cases() raises:
    assert_equal(encoded_len[Padding.REQUIRED](0), 0)
    assert_equal(encoded_len[Padding.OMITTED](0), 0)

def test_negative_n_is_defined_to_return_zero() raises:
    # Total function: a caller programming error is defined to return 0.
    assert_equal(encoded_len[Padding.REQUIRED](-1), 0)
    assert_equal(encoded_len[Padding.OMITTED](-5), 0)
    assert_equal(encoded_len[Padding.REQUIRED](-100), 0)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
