# API-DOCS-START
# decode — decode borrowed encoded text/bytes to an owned List[UInt8].
# Status: implemented
# Signature: def decode[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding_mode: PaddingMode = PaddingMode.STRICT,
#   whitespace: Whitespace = Whitespace.REJECT,
# ](input: StringSpan) raises Base64Error -> List[UInt8]
# def decode[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding_mode: PaddingMode = PaddingMode.STRICT,
#   whitespace: Whitespace = Whitespace.REJECT,
# ](input: Span[UInt8]) raises Base64Error -> List[UInt8]
# Semantics: `input` is the encoded text (StringSpan) or the same bytes
#   (Span[UInt8]); borrowed and possibly empty (an empty input decodes to an empty
#   List[UInt8]). The accepted symbol set, including case, is fixed by alphabet.
#   The defaults are strict RFC 4648 canonical input with whitespace rejected.
#   Returns a newly allocated List[UInt8]; its length is at most
#   decoded_len(input_length), exact only for a full final quantum with no skipped
#   bytes. input is borrowed; the result is owned by the caller. No I/O.
# Errors: raises Base64Error. INVALID_LENGTH for an impossible remainder;
#   INVALID_PADDING for missing/excess/misplaced '='; INVALID_SYMBOL for a byte
#   outside the alphabet (including whitespace under REJECT) or a non-zero
#   trailing bit under STRICT. All are recoverable data errors. On failure no List
#   is produced — the allocating form is atomic.
# Tests: test_base64_decode.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses a `raises Base64Error` decoder returning an owned
#   List[UInt8] because the Mojo stdlib's b64decode already raises and returns
#   fresh bytes, and Rust's typed DecodeError plus Python's binascii.Error show
#   the failure must carry a reason.
# API-DOCS-END

from .alphabet import Alphabet
from .padding_mode import PaddingMode
from .whitespace import Whitespace
from .base64_error import Base64Error

from base64._internal.engine import decode_into_core


# decode (StringSpan) — decode encoded text to an owned List[UInt8].
#
# Parameters: `input` is the encoded text, borrowed and possibly empty. The
# accepted symbol set including case is fixed by `alphabet`. `padding_mode` and
# `whitespace` default to strict canonical input with whitespace rejected.
# Return / meaning: a newly allocated List[UInt8]; its length is at most
# `decoded_len(input_length)` and exact only for a full final quantum with no
# skipped bytes.
# Errors: raises Base64Error. INVALID_LENGTH for an impossible remainder;
# INVALID_PADDING for missing/excess/misplaced '='; INVALID_SYMBOL for a byte
# outside the alphabet (including whitespace under REJECT) or a non-zero trailing
# bit under STRICT. All are recoverable data errors.
# Semantics (one line): the allocating form is atomic — on failure no List is
# produced.
def decode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: StringSpan) raises Base64Error -> List[UInt8]:
    var result = List[UInt8]()
    _ = decode_into_core[alphabet, padding_mode, whitespace](input.as_bytes(), result)
    return result^


# decode (Span[UInt8]) — decode encoded bytes to an owned List[UInt8].
#
# Parameters: `input` is the encoded bytes, borrowed and possibly empty.
# `alphabet`, `padding_mode` and `whitespace` have the same meaning as in the
# StringSpan overload.
# Return / meaning: a newly allocated List[UInt8], at most
# `decoded_len(input_length)` bytes.
# Errors: raises Base64Error with the same three kinds as the StringSpan
# overload; all recoverable.
# Semantics (one line): the byte overload of the atomic allocating decoder.
def decode[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding_mode: PaddingMode = PaddingMode.STRICT,
    whitespace: Whitespace = Whitespace.REJECT,
](input: Span[UInt8, _]) raises Base64Error -> List[UInt8]:
    var result = List[UInt8]()
    _ = decode_into_core[alphabet, padding_mode, whitespace](input, result)
    return result^
