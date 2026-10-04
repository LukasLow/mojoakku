# Concern: `is_valid` — allocation-free validity predicate returning Bool, never
# raising (docs block in `../is_valid.mojo`).
#
# Covers: both overloads; empty input is valid under every policy; True iff
# `decode` with the same parameters would succeed (symbol membership under the
# uppercase-only case policy, quantum structure, padding count/placement, and
# under STRICT the final symbol's zero trailing bits); every malformed condition
# is False, never a Base32Error.

from std.testing import assert_equal, assert_false, assert_true, TestSuite
from akku.codec_base32 import (
    Alphabet,
    PaddingMode,
    Whitespace,
    is_valid,
    decode,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_empty_input_is_valid_under_every_policy() raises:
    assert_true(is_valid(""))
    assert_true(is_valid[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.REJECT](""))
    assert_true(
        is_valid[Alphabet.B32_STANDARD, PaddingMode.TOLERANT, Whitespace.IGNORE]("")
    )
    var raw = List[UInt8]()
    assert_true(is_valid(Span(raw)))

def test_valid_base32_inputs() raises:
    assert_true(is_valid("MY======"))
    assert_true(is_valid("MZXQ===="))
    assert_true(is_valid("MZXW6==="))
    assert_true(is_valid("MZXW6YQ="))
    assert_true(is_valid("MZXW6YTB"))
    assert_true(is_valid("MZXW6YTBOI======"))

def test_valid_hex_inputs() raises:
    assert_true(is_valid[Alphabet.B32_HEX]("CO======"))
    assert_true(is_valid[Alphabet.B32_HEX]("CPNMUOJ1E8======"))

def test_invalid_symbol_is_false() raises:
    assert_false(is_valid("MZ!W6==="))
    assert_false(is_valid("MY======!"))

def test_impossible_length_is_false() raises:
    assert_false(is_valid("A"))
    assert_false(is_valid("A======="))
    assert_false(is_valid("AAA====="))
    assert_false(is_valid("AAAAAA=="))

def test_missing_padding_is_false_under_strict() raises:
    assert_false(
        is_valid[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.REJECT]("MY")
    )
    assert_true(
        is_valid[Alphabet.B32_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]("MY")
    )

def test_non_zero_trailing_bits_under_strict() raises:
    assert_false(
        is_valid[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.REJECT](
            "MZ======"
        )
    )
    assert_true(
        is_valid[Alphabet.B32_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT](
            "MZ======"
        )
    )

def test_whitespace_policy_is_respected() raises:
    assert_false(
        is_valid[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.REJECT](
            "MZ XW6==="
        )
    )
    assert_true(
        is_valid[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE](
            "MZ XW6==="
        )
    )

def test_case_policy_is_uppercase_only() raises:
    assert_true(is_valid[Alphabet.B32_STANDARD]("MZXW6==="))
    assert_false(is_valid[Alphabet.B32_STANDARD]("mzxw6==="))
    assert_true(is_valid[Alphabet.B32_HEX]("CPNMU==="))
    assert_false(is_valid[Alphabet.B32_HEX]("cpnmu==="))

def test_byte_overload_matches_string_overload() raises:
    var good = bytes_of("MZXW6YTBOI======")
    assert_true(is_valid(Span(good)))
    var bad = bytes_of("MZ!W6===")
    assert_false(is_valid(Span(bad)))

def test_is_valid_agrees_with_decode_for_each_policy() raises:
    # Valid inputs: both agree True / decode succeeds.
    assert_true(is_valid("MZXW6==="))
    assert_equal(decode("MZXW6==="), bytes_of("foo"))

    # Invalid symbol: is_valid False and decode raises.
    assert_false(is_valid("MZ!W6==="))
    var caught = False
    try:
        _ = decode("MZ!W6===")
    except e:
        caught = True
    assert_true(caught)

    # Strict vs tolerant on an unpadded partial quantum.
    assert_false(
        is_valid[Alphabet.B32_STANDARD, PaddingMode.STRICT, Whitespace.REJECT]("MY")
    )
    assert_true(
        is_valid[Alphabet.B32_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]("MY")
    )
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]("MY"),
        bytes_of("f"),
    )

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
