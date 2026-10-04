# Concern: `PaddingMode` — the compile-time decode padding/canonicality policy
# STRICT vs TOLERANT (docs block in `../padding_mode.mojo`).
#
# Covers: STRICT requires canonical RFC 4648 input (exact '=' on a partial final
# quantum, none on a full one, zero trailing bits); TOLERANT accepts a padded or
# unpadded final quantum with exact padding if present, and accepts non-zero
# trailing bits. A structurally impossible data-symbol remainder (base32: 1, 3
# or 6) raises INVALID_LENGTH under both modes; a wrong padding count raises
# INVALID_PADDING.

from std.testing import assert_equal, assert_true, TestSuite
from akku.codec_base32 import (
    Alphabet,
    PaddingMode,
    ErrorKind,
    decode,
)

def bytes_of(text: String) -> List[UInt8]:
    var out = List[UInt8]()
    for b in text.bytes():
        out.append(b)
    return out^

def test_strict_accepts_every_canonical_padding_run() raises:
    # RFC 4648 §10 vectors, one per valid '=' count: 6, 4, 3, 1 and 0.
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.STRICT]("MY======"), bytes_of("f")
    )
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.STRICT]("MZXQ===="), bytes_of("fo")
    )
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.STRICT]("MZXW6==="), bytes_of("foo")
    )
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.STRICT]("MZXW6YQ="), bytes_of("foob")
    )
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.STRICT]("MZXW6YTBOI======"),
        bytes_of("foobar"),
    )

def test_strict_rejects_missing_padding() raises:
    var caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD, PaddingMode.STRICT]("MY")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
        assert_equal(e.position, 0)
    assert_true(caught)

def test_strict_rejects_padding_on_full_quantum() raises:
    # A full 8-symbol quantum must carry no '='.
    var caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD, PaddingMode.STRICT]("MZXW6YTB=")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
    assert_true(caught)

def test_strict_rejects_non_zero_trailing_bits() raises:
    # "MZ======" carries 10 value bits for one byte; the unused low 2 bits are
    # 01 (non-zero), so it is non-canonical. Both symbols are in the alphabet,
    # so STRICT reports INVALID_SYMBOL.
    var caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD, PaddingMode.STRICT]("MZ======")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(caught)

def test_tolerant_accepts_unpadded_partial_quantum() raises:
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT]("MY"), bytes_of("f")
    )
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT]("MZXQ"), bytes_of("fo")
    )

def test_tolerant_accepts_padded_partial_quantum() raises:
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT]("MY======"), bytes_of("f")
    )
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT]("MZXQ===="), bytes_of("fo")
    )

def test_tolerant_accepts_non_zero_trailing_bits() raises:
    assert_equal(
        decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT]("MZ======"), bytes_of("f")
    )

def test_tolerant_requires_exact_count_when_padding_is_present() raises:
    # 5 data symbols need 3 '='; 2 is wrong even under TOLERANT.
    var caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT]("MZXW6==")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
    assert_true(caught)

def test_tolerant_rejects_symbol_after_padding() raises:
    var caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT]("MY======AAAA")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
    assert_true(caught)

def test_both_modes_reject_impossible_remainder() raises:
    # One data symbol (remainder 1) is structurally impossible.
    var strict_caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD, PaddingMode.STRICT]("A")
    except e:
        strict_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
        assert_equal(e.position, 0)
    assert_true(strict_caught)

    var tolerant_caught = False
    try:
        _ = decode[Alphabet.B32_STANDARD, PaddingMode.TOLERANT]("A")
    except e:
        tolerant_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
        assert_equal(e.position, 0)
    assert_true(tolerant_caught)

def test_impossible_padding_lengths_2_5_7_are_invalid_length() raises:
    # The impossible '=' counts 2, 5 and 7 correspond to the impossible data
    # remainders 6, 3 and 1; padding cannot rescue them.
    for input in ["MZXW6Y==", "MZX=====", "M======="]:
        var caught = False
        try:
            _ = decode[Alphabet.B32_STANDARD, PaddingMode.STRICT](input)
        except e:
            caught = True
            assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
        assert_true(caught)

def test_hex_modes_are_equivalent_for_base32_alphabet_geometry() raises:
    # Both modes share the same valid data-symbol counts on the hex alphabet.
    assert_equal(
        decode[Alphabet.B32_HEX, PaddingMode.STRICT]("CO======"), bytes_of("f")
    )
    assert_equal(
        decode[Alphabet.B32_HEX, PaddingMode.TOLERANT]("CO======"), bytes_of("f")
    )
    var caught = False
    try:
        _ = decode[Alphabet.B32_HEX, PaddingMode.STRICT]("CO")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
    assert_true(caught)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
