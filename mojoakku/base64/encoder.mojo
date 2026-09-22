# API-DOCS-START
# Encoder — stateful encode value type owning the sub-quantum byte carry.
# Status: implemented
# Signature: @explicit_destroy("call finish() or discard() before this encoder
#   leaves scope") struct Encoder[
#   alphabet: Alphabet = Alphabet.B64_STANDARD,
#   padding: Padding = Padding.REQUIRED,
# ](Deinitable where False):
#   def __init__(out self)
#   def feed(mut self, chunk: Span[UInt8], mut out: String) -> Int
#   def feed(mut self, chunk: StringSpan, mut out: String) -> Int
#   def finish(deinit self, mut out: String) -> Int
#   def discard(deinit self)
# Semantics: feed accepts successive borrowed chunks of any length, including
#   empty, as raw bytes or text; the two overloads mirror one-shot encode. `out`
#   is caller-owned and appended to. finish/discard consume the encoder. The carry
#   size is quantum_bytes-1 (base64 0-2, base32 0-4, base16 none) in a small fixed
#   Array[UInt8, 8] plus a count; never exposed. feed returns the encoded
#   characters appended for this chunk, encoding only complete quanta and holding
#   the remainder; finish encodes the final partial quantum (with padding if
#   REQUIRED) and returns the number appended — the only place padding is emitted.
#   The encoder owns its carry; chunks may be freed right after feed returns.
#   EOF is the caller's call to finish, not an I/O event; an abandoned Encoder is
#   a compile-time error, so the final flush cannot be silently skipped.
# Errors: none; encode cannot fail. discard(deinit self) drops the remainder
#   without emitting it — the explicit, non-silent way to abandon a stream.
# Tests: test_base64_encoder.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses a feed/finish value type with a mandatory finish
#   because Rust's EncoderWriter::finish and data-encoding's Encoder::finalize are
#   documented as required for correctness, while Rust's Drop suppresses write
#   errors and is a rejected footgun; @explicit_destroy enforces the same contract
#   with a compile-time diagnostic.
# API-DOCS-END

from .alphabet import Alphabet
from .padding import Padding

from base64._internal.engine import EncodeState


# Encoder — stateful encode value type owning the sub-quantum byte carry.
#
# Parameters / preconditions: the compile-time `alphabet` and `padding` mirror
# one-shot `encode`. `feed` accepts successive borrowed chunks of any length,
# including empty, as raw bytes (Span) or text (StringSpan); `out` is
# caller-owned and appended to.
# Return / meaning: `feed` returns the number of encoded characters appended for
# this chunk, encoding only complete quanta and holding the remainder; `finish`
# encodes the final partial quantum (with padding if REQUIRED) and returns the
# number appended. `finish` is the only place padding is emitted.
# Errors: none; encode cannot fail. `discard` drops the remainder without
# emitting it.
# Semantics (one line): feed complete quanta as they arrive, then finish exactly
# once to emit the remainder.
@explicit_destroy("call finish() or discard() before this encoder leaves scope")
struct Encoder[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](Deinitable where False):
    # The encoder owns only the sub-quantum carry; it is never exposed.
    var _state: EncodeState

    # __init__ — create an encoder with an empty carry.
    #
    # Parameters: none.
    # Return / meaning: an Encoder ready for the first `feed`.
    # Errors: none.
    # Semantics (one line): start a fresh stream with no buffered bytes.
    def __init__(out self):
        self._state = EncodeState()

    # feed (Span[UInt8]) — encode a borrowed chunk of raw bytes.
    #
    # Parameters: `chunk` is borrowed bytes of any length, including empty;
    # `out` is caller-owned and appended to.
    # Return / meaning: the number of encoded characters appended for this
    # chunk; only complete quanta are encoded and the remainder is held back.
    # Errors: none.
    # Semantics (one line): append whole-quantum output and retain the
    # sub-quantum carry.
    def feed(mut self, chunk: Span[UInt8, _], mut out: String) -> Int:
        return self._state.feed[Self.alphabet, Self.padding](chunk, out)

    # feed (StringSpan) — encode a borrowed chunk of text treated as raw bytes.
    #
    # Parameters: `chunk` is borrowed text treated byte by byte; `out` is
    # caller-owned and appended to.
    # Return / meaning: the number of encoded characters appended for this
    # chunk; the sub-quantum remainder is held back.
    # Errors: none.
    # Semantics (one line): the text overload of Encoder.feed.
    def feed(mut self, chunk: StringSpan, mut out: String) -> Int:
        return self._state.feed[Self.alphabet, Self.padding](chunk.as_bytes(), out)

    # finish — encode the final partial quantum and append it (mandatory flush).
    #
    # Parameters: `out` is caller-owned and appended to.
    # Return / meaning: the number of encoded characters appended, including any
    # required padding. This is the only place padding is emitted.
    # Errors: none.
    # Semantics (one line): consume the encoder and flush the remainder exactly
    # once.
    def finish(deinit self, mut out: String) -> Int:
        return self._state.finish[Self.alphabet, Self.padding](out)

    # discard — drop the remainder without emitting it.
    #
    # Parameters: none.
    # Return / meaning: consumes the encoder; the sub-quantum remainder is
    # abandoned and nothing is appended. `out` is not touched.
    # Errors: none.
    # Semantics (one line): the explicit, non-silent way to abandon a stream.
    def discard(deinit self):
        pass
