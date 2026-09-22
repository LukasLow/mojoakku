from .alphabet import Alphabet
from .padding import Padding

from base64._internal.engine import EncodeState


# Encoder — stateful encode value type owning the sub-quantum byte carry.
# finish() is the only place padding is emitted; see API-DOCS below.
@explicit_destroy("call finish() or discard() before this encoder leaves scope")
struct Encoder[
    alphabet: Alphabet = Alphabet.B64_STANDARD,
    padding: Padding = Padding.REQUIRED,
](Deinitable where False):
    # The encoder owns only the sub-quantum carry; it is never exposed.
    var _state: EncodeState

    def __init__(out self):
        self._state = EncodeState()

    def feed(mut self, chunk: Span[UInt8, _], mut out: String) -> Int:
        return self._state.feed[Self.alphabet, Self.padding](chunk, out)

    # StringSpan overload: chunk bytes are encoded as-is (no UTF-8 conversion).
    def feed(mut self, chunk: StringSpan, mut out: String) -> Int:
        return self._state.feed[Self.alphabet, Self.padding](chunk.as_bytes(), out)

    def finish(deinit self, mut out: String) -> Int:
        return self._state.finish[Self.alphabet, Self.padding](out)

    def discard(deinit self):
        pass

# API-DOCS-START
# Encoder — stateful streaming encoder with a mandatory finish.
# Signature:
#   @explicit_destroy("call finish() or discard() before this encoder leaves scope")
#   struct Encoder[
#       alphabet: Alphabet = Alphabet.B64_STANDARD,
#       padding: Padding = Padding.REQUIRED,
#   ](Deinitable where False):
#       def __init__(out self)
#       def feed(mut self, chunk: Span[UInt8], mut out: String) -> Int
#       def feed(mut self, chunk: StringSpan, mut out: String) -> Int
#       def finish(deinit self, mut out: String) -> Int
#       def discard(deinit self)
# What it does:
#   Encodes a stream that arrives in pieces. `feed` accepts successive borrowed
#   chunks of any length, including empty, as raw bytes or text; each call
#   encodes only the complete quanta it can and holds the sub-quantum remainder,
#   so `feed...feed; finish()` produces exactly the same output as one-shot
#   `encode` of the concatenation. `out` is caller-owned and appended to. The
#   compile-time `alphabet` and `padding` match `encode`; padding is emitted only
#   by `finish`. `feed` borrows the encoder; `finish` and `discard` consume it.
#   The end of input is the caller's explicit `finish` call. Because the struct
#   is `@explicit_destroy`, an encoder that reaches end of scope without
#   `finish`/`discard` is a compile-time error, so the final flush cannot be
#   silently skipped.
# Returns:
#   `feed` returns the number of encoded characters appended for that chunk;
#   `finish` returns the number appended while flushing the remainder (including
#   any required padding); `discard` returns nothing. The caller owns `out`.
# Errors:
#   none — encoding cannot fail. `discard` drops the retained remainder without
#   emitting it (the complete quanta already appended by `feed` stay).
# Example:
#   var out = String()
#   var enc = Encoder[Alphabet.B64_STANDARD, Padding.REQUIRED]()
#   _ = enc.feed("fo", out)
#   _ = enc.feed("ob", out)
#   _ = enc.feed("ar", out)
#   _ = enc^.finish(out)          # out -> "Zm9vYmFy"
#   # Streaming a partial quantum:
#   var out2 = String()
#   var enc2 = Encoder[Alphabet.B64_STANDARD, Padding.REQUIRED]()
#   _ = enc2.feed("f", out2)      # appends nothing yet
#   _ = enc2^.finish(out2)        # out2 -> "Zg=="
# API-DOCS-END
