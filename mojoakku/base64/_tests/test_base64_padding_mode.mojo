# Concern: `PaddingMode` — the compile-time decode padding policy STRICT vs
# TOLERANT (BASE64_DOCS.md `### PaddingMode`).
#
# Covers: STRICT requires canonical RFC 4648 input (exact padding on a partial
# final quantum, none on a full one, zero trailing bits); TOLERANT accepts a
# padded or unpadded final quantum with exact padding if present, and accepts
# non-zero trailing bits in the final symbol. A structurally impossible
# remainder raises INVALID_LENGTH under both modes. For base16 there is no
# padding symbol, so both modes reject '=' as INVALID_SYMBOL.

from std.testing import assert_equal, assert_true, TestSuite
from base64 import (
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

def test_strict_accepts_canonical_padding() raises:
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.STRICT]("Zg=="), bytes_of("f")
    )
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.STRICT]("Zm8="), bytes_of("fo")
    )
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.STRICT]("Zm9v"), bytes_of("foo")
    )

def test_strict_rejects_missing_padding() raises:
    var caught = False
    try:
        _ = decode[Alphabet.B64_STANDARD, PaddingMode.STRICT]("Zg")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
        assert_equal(e.position, 0)
    assert_true(caught)

def test_strict_rejects_padding_on_full_quantum() raises:
    var caught = False
    try:
        _ = decode[Alphabet.B64_STANDARD, PaddingMode.STRICT]("Zm9v====")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
    assert_true(caught)

def test_strict_rejects_non_zero_trailing_bits() raises:
    # "Zh==" has value bits that do not round-trip to zero trailing bits.
    var caught = False
    try:
        _ = decode[Alphabet.B64_STANDARD, PaddingMode.STRICT]("Zh==")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(caught)

def test_tolerant_accepts_unpadded_partial_quantum() raises:
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT]("Zg"), bytes_of("f")
    )
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT]("Zm8"), bytes_of("fo")
    )

def test_tolerant_accepts_padded_partial_quantum() raises:
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT]("Zg=="), bytes_of("f")
    )
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT]("Zm8="), bytes_of("fo")
    )

def test_tolerant_accepts_non_zero_trailing_bits() raises:
    # TOLERANT does not enforce canonical trailing bits.
    assert_equal(
        decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT]("Zh=="), bytes_of("f")
    )

def test_tolerant_requiring_exact_count_when_padding_present() raises:
    # Padding present but the count is wrong: still invalid under TOLERANT.
    var caught = False
    try:
        _ = decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT]("Zg=")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
    assert_true(caught)

def test_tolerant_rejects_symbol_after_padding() raises:
    var caught = False
    try:
        _ = decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT]("Zg==AAAA")
    except e:
        caught = True
        assert_equal(e.kind, ErrorKind.INVALID_PADDING)
    assert_true(caught)

def test_both_modes_reject_impossible_remainder() raises:
    # A single base64 symbol is structurally impossible: INVALID_LENGTH.
    var strict_caught = False
    try:
        _ = decode[Alphabet.B64_STANDARD, PaddingMode.STRICT]("A")
    except e:
        strict_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
        assert_equal(e.position, 0)
    assert_true(strict_caught)

    var tolerant_caught = False
    try:
        _ = decode[Alphabet.B64_STANDARD, PaddingMode.TOLERANT]("A")
    except e:
        tolerant_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_LENGTH)
        assert_equal(e.position, 0)
    assert_true(tolerant_caught)

def test_base16_modes_are_equivalent_and_reject_equals() raises:
    # base16 has no padding symbol; '=' is INVALID_SYMBOL under both modes.
    assert_equal(
        decode[Alphabet.HEX_UPPER, PaddingMode.STRICT]("666F"), bytes_of("fo")
    )
    assert_equal(
        decode[Alphabet.HEX_UPPER, PaddingMode.TOLERANT]("666F"), bytes_of("fo")
    )
    var strict_caught = False
    try:
        _ = decode[Alphabet.HEX_UPPER, PaddingMode.STRICT]("66==")
    except e:
        strict_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(strict_caught)

    var tolerant_caught = False
    try:
        _ = decode[Alphabet.HEX_UPPER, PaddingMode.TOLERANT]("66==")
    except e:
        tolerant_caught = True
        assert_equal(e.kind, ErrorKind.INVALID_SYMBOL)
    assert_true(tolerant_caught)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
