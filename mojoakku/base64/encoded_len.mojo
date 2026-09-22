# API-DOCS-START
# encoded_len — exact encoded length for n raw input bytes.
# Status: implemented
# Signature: def encoded_len[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding: Padding = Padding.REQUIRED,
# ](n: Int) -> Int
# Semantics: `n` is the number of raw input bytes and must be >= 0; a negative
#   argument is a caller programming error. Compile-time-callable: pure,
#   non-raising def with no FFI, usable inside comptime(...) and in buffer sizing.
#   Returns the exact encoded length: base64 REQUIRED 4*((n+2)//3), base64
#   OMITTED ceil(n/3)*4 - ((3-n%3)%3); base32 REQUIRED 8*((n+4)//5), OMITTED
#   (n*8+4)//5; base16 2*n for both padding values. n=0 returns 0 in every case.
#   Pure function; no allocation, no state, no I/O.
# Errors: none. The function is total: n<0 is defined to return 0 (the
#   empty-input length) rather than trap, keeping it non-raising and
#   compile-time-callable.
# Tests: test_base64_encoded_len.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses a pure exact encoded_len because Perl's
#   encoded_base64_length, Go's EncodedLen, Commons Codec's getEncodedLength and
#   cppcodec's encoded_size all exist to pre-size a buffer, and a total function
#   is strictly better than C's two-call size query.
# API-DOCS-END

from .alphabet import Alphabet
from .padding import Padding

from base64._internal.engine import encoded_len_core


# encoded_len — exact encoded length for n raw input bytes.
#
# Parameters: `n` is the number of raw input bytes (>= 0). `alphabet` and
# `padding` are compile-time. Pure and compile-time-callable.
# Return / meaning: the exact encoded length under the alphabet and padding
# policy; `n = 0` returns 0. A negative `n` is a caller programming error and is
# defined to return 0 (the empty-input length).
# Errors: none; the function is total.
# Semantics (one line): pre-size an encode buffer without guessing.
def encoded_len[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](n: Int) -> Int:
    return encoded_len_core[alphabet, padding](n)
