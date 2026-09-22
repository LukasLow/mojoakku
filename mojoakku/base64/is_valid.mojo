# API-DOCS-START
# is_valid — allocation-free validity predicate.
# Status: implemented
# Signature: def is_valid[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding_mode: PaddingMode = PaddingMode.STRICT,
#   whitespace: Whitespace = Whitespace.REJECT,
# ](input: StringSpan) -> Bool
# def is_valid[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding_mode: PaddingMode = PaddingMode.STRICT,
#   whitespace: Whitespace = Whitespace.REJECT,
# ](input: Span[UInt8]) -> Bool
# Semantics: `input` is the encoded text (StringSpan) or the same bytes
#   (Span[UInt8]) to check, borrowed and possibly empty (an empty input is valid
#   under every policy). The accepted symbol set and case policy are fixed by
#   alphabet. Returns True iff decode with the same parameters would succeed,
#   without allocating the decoded output: it performs the full decode validation
#   (symbol-table membership, quantum structure, padding count and placement and,
#   under STRICT, the final symbol's zero trailing bits) but builds no output
#   bytes. input borrowed; returns a scalar Bool; allocates and retains nothing.
#   No I/O.
# Errors: never raises. Every malformed condition is reported as False, never as
#   Base64Error.
# Tests: test_base64_is_valid.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses an allocation-free validity predicate because Elixir's
#   valid64?/valid32?/valid16? exist precisely to validate without allocating the
#   decoded output, and the docs justify them as more efficient than
#   decode-then-discard.
# API-DOCS-END

from .alphabet import Alphabet
from .padding_mode import PaddingMode
from .whitespace import Whitespace

from base64._internal.engine import is_valid_core


# is_valid (StringSpan) — allocation-free validity predicate.
#
# Parameters: `input` is the encoded text to check, borrowed and possibly empty
# (an empty input is valid under every policy). `alphabet`, `padding_mode` and
# `whitespace` have the same meaning as in `decode`.
# Return / meaning: True iff `decode` with the same parameters would succeed,
# without allocating the decoded output: symbol membership, quantum structure,
# padding count/placement and (under STRICT) zero trailing bits are all checked.
# Errors: never raises; every malformed condition is reported as False.
# Semantics (one line): decode validation without building output bytes.
def is_valid[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan) -> Bool:
    return is_valid_core[alphabet, padding_mode, whitespace](input.as_bytes())


# is_valid (Span[UInt8]) — allocation-free validity predicate over bytes.
#
# Parameters: `input` is the encoded bytes to check, borrowed and possibly
# empty. The policy parameters have the same meaning as in the StringSpan
# overload.
# Return / meaning: True iff `decode` with the same parameters would succeed,
# allocating nothing.
# Errors: never raises; every malformed condition is reported as False.
# Semantics (one line): the byte overload of the allocation-free validity
# predicate.
def is_valid[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8, _]) -> Bool:
    return is_valid_core[alphabet, padding_mode, whitespace](input)
