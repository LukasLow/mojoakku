# Concern: `decoded_len` — maximum decoded byte count for n encoded symbols
# (docs block in `../decoded_len.mojo`).
#
# Covers: the upper-bound formula (n // 8) * 5 plus the partial-quantum map
# 2->1, 4->2, 5->3, 7->4 and 1/3/6->0; n = 0 returns 0; the function is total and
# returns 0 for a negative n; there is no parameter; it is a conservative upper
# bound (>= the actual decoded length) and counts padding symbols as input
# symbols.

from std.testing import assert_equal, assert_true, TestSuite
from akku.codec_base32 import (
    Alphabet,
    PaddingMode,
    Whitespace,
    decode,
    decoded_len,
)

def test_formula_every_remainder() raises:
    assert_equal(decoded_len(0), 0)
    assert_equal(decoded_len(1), 0)
    assert_equal(decoded_len(2), 1)
    assert_equal(decoded_len(3), 0)
    assert_equal(decoded_len(4), 2)
    assert_equal(decoded_len(5), 3)
    assert_equal(decoded_len(6), 0)
    assert_equal(decoded_len(7), 4)
    assert_equal(decoded_len(8), 5)
    assert_equal(decoded_len(10), 6)
    assert_equal(decoded_len(13), 8)

def test_full_quanta_are_five_bytes_each() raises:
    assert_equal(decoded_len(8), 5)
    assert_equal(decoded_len(16), 10)
    assert_equal(decoded_len(24), 15)

def test_zero_returns_zero() raises:
    assert_equal(decoded_len(0), 0)

def test_negative_n_is_defined_to_return_zero() raises:
    assert_equal(decoded_len(-1), 0)
    assert_equal(decoded_len(-9), 0)
    assert_equal(decoded_len(-100), 0)

def test_is_a_conservative_upper_bound() raises:
    # The actual decoded length is at most decoded_len(symbol count).
    var raw = "MZXW6YTBOI======"
    var actual = decode(raw)
    assert_equal(len(actual), 6)
    assert_true(len(actual) <= decoded_len(raw.byte_length()))
    # With padding present, decoded_len counts the '=' symbols and is a strict
    # upper bound.
    assert_equal(decoded_len(raw.byte_length()), 10)
    assert_true(len(actual) < decoded_len(raw.byte_length()))

    var unpadded = "MZXW6YTBOI"
    assert_equal(
        len(
            decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT](
                unpadded
            )
        ),
        6,
    )
    assert_true(
        len(
            decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT](
                unpadded
            )
        )
        <= decoded_len(unpadded.byte_length())
    )

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
