# Concern: `is_valid` — allocation-free validity predicate returning Bool, never
# raising (BASE64_DOCS.md `### is_valid`).
#
# Covers: both overloads; empty input is valid under every policy; True iff
# `decode` with the same parameters would succeed (symbol membership with the
# alphabet case policy, quantum structure, padding count/placement, and under
# STRICT the final symbol's zero trailing bits); every malformed condition is
# False, never a Base64Error.

from std.testing import assert_equal, assert_false, assert_true, TestSuite
from base64 import (
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
    assert_true(is_valid[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.REJECT](""))
    assert_true(
        is_valid[Alphabet.B64_STANDARD, PaddingMode.TOLERANT, Whitespace.IGNORE]("")
    )
    var raw = List[UInt8]()
    assert_true(is_valid(Span(raw)))

def test_valid_base64_inputs() raises:
    assert_true(is_valid("Zg=="))
    assert_true(is_valid("Zm8="))
    assert_true(is_valid("Zm9v"))
    assert_true(is_valid("Zm9vYmFy"))

def test_invalid_symbol_is_false() raises:
    assert_false(is_valid("Zm!v"))
    assert_false(is_valid("Zg=!"))

def test_impossible_length_is_false() raises:
    assert_false(is_valid("Z"))
    assert_false(is_valid("Zg==="))

def test_padded_impossible_remainder_is_false() raises:
    # Regression: padding cannot complete a structurally impossible remainder.
    assert_false(is_valid("A==="))
    assert_false(is_valid[Alphabet.B32_STANDARD]("A======="))

def test_missing_padding_is_false_under_strict() raises:
    assert_false(
        is_valid[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.REJECT]("Zg")
    )
    assert_true(
        is_valid[Alphabet.B64_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]("Zg")
    )

def test_non_zero_trailing_bits_under_strict() raises:
    assert_false(
        is_valid[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.REJECT]("Zh==")
    )
    assert_true(
        is_valid[Alphabet.B64_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]("Zh==")
    )

def test_whitespace_policy_is_respected() raises:
    assert_false(
        is_valid[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.REJECT]("Zm 9v")
    )
    assert_true(
        is_valid[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.IGNORE]("Zm 9v")
    )

def test_case_policy_per_alphabet() raises:
    assert_true(is_valid[Alphabet.HEX_UPPER]("666F"))
    assert_false(is_valid[Alphabet.HEX_UPPER]("666f"))
    assert_true(is_valid[Alphabet.HEX_LOWER]("666f"))
    assert_false(is_valid[Alphabet.HEX_LOWER]("666F"))
    assert_true(is_valid[Alphabet.B32_STANDARD]("MZXW6==="))
    assert_false(is_valid[Alphabet.B32_STANDARD]("mzxw6==="))

def test_byte_overload_matches_string_overload() raises:
    var good = bytes_of("Zm9vYmFy")
    assert_true(is_valid(Span(good)))
    var bad = bytes_of("Zm!v")
    assert_false(is_valid(Span(bad)))

def test_is_valid_agrees_with_decode_for_each_policy() raises:
    # Valid inputs: both agree True / decode succeeds.
    assert_true(is_valid("Zm9v"))
    assert_equal(decode("Zm9v"), bytes_of("foo"))

    # Invalid symbol: is_valid False and decode raises.
    assert_false(is_valid("Zm!v"))
    var caught = False
    try:
        _ = decode("Zm!v")
    except e:
        caught = True
    assert_true(caught)

    # Strict vs tolerant on an unpadded partial quantum.
    assert_false(
        is_valid[Alphabet.B64_STANDARD, PaddingMode.STRICT, Whitespace.REJECT]("Zg")
    )
    assert_true(
        is_valid[Alphabet.B64_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]("Zg")
    )
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT, Whitespace.REJECT]("Zg"),
        bytes_of("f"),
    )

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
