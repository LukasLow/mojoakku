# API-DOCS-START
# decoded_len — maximum decoded byte count for n encoded symbols.
# Status: implemented
# Signature: def decoded_len[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
# ](n: Int) -> Int
# Semantics: `n` is the total input byte count used as a conservative upper
#   bound (number of encoded symbols, including any padding and, under
#   Whitespace.IGNORE, whitespace bytes; >= 0). Compile-time-callable. Returns
#   the maximum number of decoded bytes: base64 (n//4)*3 plus the partial final
#   quantum contribution (n%4 of 2 -> 1, of 3 -> 2, of 1 -> 0); base32 (n//8)*5
#   plus n%8 of 2/4/5/7 contributing 1/2/3/4 (remainders 1/3/6 contribute 0);
#   base16 n//2. Because n counts '=' symbols this is an upper bound whenever
#   padding is present. n=0 returns 0. Pure function; no allocation, no state.
# Errors: none. Total function: n<0 is defined to return 0, consistent with
#   encoded_len.
# Tests: test_base64_decoded_len.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses a maximum-size decoded_len because Rust's
#   decoded_len_estimate, Boost.Beast's decoded_size and Java's caller-buffer
#   contract all need a conservative output bound before decoding, and Mojo's
#   explicit buffer sizing benefits from a total function.
# API-DOCS-END

from .alphabet import Alphabet

from base64._internal.engine import decoded_len_core


# decoded_len — maximum decoded byte count for n encoded symbols.
#
# Parameters: `n` is the total input byte count used as a conservative upper
# bound (>= 0), counting padding symbols and, under Whitespace.IGNORE,
# whitespace bytes. `alphabet` is compile-time. Pure and compile-time-callable.
# Return / meaning: the maximum number of decoded bytes for `n` symbols; `n = 0`
# returns 0. A negative `n` is a caller programming error and is defined to
# return 0.
# Errors: none; the function is total.
# Semantics (one line): conservative output bound before decoding.
def decoded_len[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
](n: Int) -> Int:
    return decoded_len_core[alphabet](n)
