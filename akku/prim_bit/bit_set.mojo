from .bit_error import BitError
from .bit_error_kind import BitErrorKind
from .bit_set_iter import BitSetIter
from akku.prim_bit._internal.field_mask import field_mask

from std.bit import pop_count, bit_width, count_trailing_zeros


# BitSet — a growable, word-packed set of bits with LSB-first indexing.
struct BitSet(Equatable, Copyable, Deinitable, Writable, Sized):
    var _words: List[UInt64]
    var _len: Int            # logical length in bits = highest set index + 1

    def __init__(out self):
        self._words = List[UInt64]()
        self._len = 0

    def __init__(out self, *, capacity: Int):
        self._words = List[UInt64]()
        self._len = 0
        self.reserve(capacity)

    def __len__(self) -> Int:
        return self._len

    def __eq__(self, other: Self) -> Bool:
        # Equality is about the set bits only: capacity and the derived _len do
        # not participate. Because trailing words are zero and _len is exactly
        # the highest set index + 1, comparing zero-padded words is sufficient.
        var n = len(self._words)
        if len(other._words) > n:
            n = len(other._words)
        for i in range(n):
            if self._word_or_zero(i) != other._word_or_zero(i):
                return False
        return True

    def capacity(self) -> Int:
        # Addressable bits currently allocated: word count * 64. This is a
        # multiple of 64 by construction.
        return len(self._words) * 64

    def count(self) -> Int:
        # Cardinality: how many bits are set.
        var total = 0
        for w in self._words:
            total += Int(pop_count(w))
        return total

    def is_empty(self) -> Bool:
        return self._len == 0

    def all(self) -> Bool:
        # Every logical bit 0.._len-1 is set. The empty set is vacuously all-set.
        return self.count() == self._len

    def any(self) -> Bool:
        return self._len != 0

    def none(self) -> Bool:
        return self._len == 0

    def test(self, index: Int) raises BitError -> Bool:
        if index < 0:
            raise BitError(BitErrorKind.RANGE, "test", "index is negative")
        if index >= self._len:
            return False
        return (self._words[index // 64] & (UInt64(1) << UInt64(index % 64))) != UInt64(0)

    def set(mut self, index: Int) raises BitError:
        if index < 0:
            raise BitError(BitErrorKind.RANGE, "set", "index is negative")
        self._set_bit(index)

    def clear(mut self, index: Int) raises BitError:
        if index < 0:
            raise BitError(BitErrorKind.RANGE, "clear", "index is negative")
        self._clear_bit(index)

    def toggle(mut self, index: Int) raises BitError:
        if index < 0:
            raise BitError(BitErrorKind.RANGE, "toggle", "index is negative")
        if index < self._len and self.test(index):
            self._clear_bit(index)
        else:
            self._set_bit(index)

    def set_to(mut self, index: Int, value: Bool) raises BitError:
        if index < 0:
            raise BitError(BitErrorKind.RANGE, "set_to", "index is negative")
        if value:
            self._set_bit(index)
        else:
            self._clear_bit(index)

    def set_range(mut self, lo: Int, hi: Int) raises BitError:
        if lo < 0:
            raise BitError(BitErrorKind.RANGE, "set_range", "lo is negative")
        if hi < lo:
            raise BitError(BitErrorKind.BAD_RANGE, "set_range", "hi is less than lo")
        self._ensure_words(hi // 64 + 1)
        self._apply_range(lo, hi, 0)
        if hi + 1 > self._len:
            self._len = hi + 1

    def clear_range(mut self, lo: Int, hi: Int) raises BitError:
        if lo < 0:
            raise BitError(BitErrorKind.RANGE, "clear_range", "lo is negative")
        if hi < lo:
            raise BitError(BitErrorKind.BAD_RANGE, "clear_range", "hi is less than lo")
        if self._len == 0:
            return
        # A clear past the end is a no-op; clamp to the last logical bit.
        var last = hi
        if last > self._len - 1:
            last = self._len - 1
        if lo > last:
            return
        self._apply_range(lo, last, 1)
        self._recompute_len()

    def toggle_range(mut self, lo: Int, hi: Int) raises BitError:
        if lo < 0:
            raise BitError(BitErrorKind.RANGE, "toggle_range", "lo is negative")
        if hi < lo:
            raise BitError(BitErrorKind.BAD_RANGE, "toggle_range", "hi is less than lo")
        # Flipping a zero above _len to one grows the set, so allocate through hi.
        self._ensure_words(hi // 64 + 1)
        self._apply_range(lo, hi, 2)
        self._recompute_len()

    def clear_all(mut self):
        for ref w in self._words:
            w = 0
        self._len = 0

    def reserve(mut self, bits: Int):
        if bits <= 0:
            return
        self._ensure_words((bits + 63) // 64)

    def shrink(mut self):
        # Release trailing all-zero words down to what _len needs. _len is the
        # highest set index + 1, so every word above it is zero by invariant.
        var needed = 0
        if self._len > 0:
            needed = (self._len - 1) // 64 + 1
        if len(self._words) > needed:
            self._words.shrink(needed)

    def find_next(self, from_index: Int) -> Optional[Int]:
        # Total query: a negative from_index behaves as 0; absence is Optional.
        var i = from_index
        if i < 0:
            i = 0
        if i >= self._len:
            return None
        var word = i // 64
        var bit = i % 64
        # Mask off the bits below i in the first word.
        var current = self._words[word] & (~UInt64(0) << UInt64(bit))
        while True:
            if current != UInt64(0):
                var index = word * 64 + Int(count_trailing_zeros(current))
                if index < self._len:
                    return index
                return None
            word += 1
            if word >= len(self._words):
                return None
            current = self._words[word]

    def to_list(self) -> List[Int]:
        var out = List[Int]()
        var cursor = -1
        while True:
            var found = self.find_next(cursor)
            if not found:
                break
            var index = found.value()
            out.append(index)
            cursor = index + 1
        return out^

    def union(self, other: BitSet) -> BitSet:
        var result = self.copy()
        result.union_with(other)
        return result^

    def intersection(self, other: BitSet) -> BitSet:
        var result = self.copy()
        result.intersection_with(other)
        return result^

    def difference(self, other: BitSet) -> BitSet:
        var result = self.copy()
        result.difference_with(other)
        return result^

    def symmetric_difference(self, other: BitSet) -> BitSet:
        var result = self.copy()
        result.symmetric_difference_with(other)
        return result^

    def union_with(mut self, other: BitSet):
        if other._len > 0:
            self._ensure_words(other._len // 64 + 1)
        # Iterate self's allocation, not other's: other may be over-allocated
        # beyond its logical length (via `reserve` or `capacity=...`), and its
        # trailing words hold no set bit. `_word_or_zero` pads beyond other's
        # words, so this cannot index out of bounds.
        var n = len(self._words)
        for i in range(n):
            self._words[i] |= other._word_or_zero(i)
        # The union's highest set bit is the max of the two.
        if other._len > self._len:
            self._len = other._len

    def intersection_with(mut self, other: BitSet):
        var n = len(self._words)
        for i in range(n):
            self._words[i] &= other._word_or_zero(i)
        # Capacity is never reduced; only _len collapses to the highest
        # surviving set bit.
        self._recompute_len()

    def difference_with(mut self, other: BitSet):
        var n = len(self._words)
        for i in range(n):
            self._words[i] &= ~other._word_or_zero(i)
        self._recompute_len()

    def symmetric_difference_with(mut self, other: BitSet):
        if other._len > 0:
            self._ensure_words(other._len // 64 + 1)
        var n = len(self._words)
        for i in range(n):
            self._words[i] ^= other._word_or_zero(i)
        self._recompute_len()

    def is_subset_of(self, other: BitSet) -> Bool:
        for i in range(len(self._words)):
            if (self._words[i] & ~other._word_or_zero(i)) != UInt64(0):
                return False
        return True

    def is_superset_of(self, other: BitSet) -> Bool:
        return other.is_subset_of(self)

    def is_disjoint(self, other: BitSet) -> Bool:
        for i in range(len(self._words)):
            if (self._words[i] & other._word_or_zero(i)) != UInt64(0):
                return False
        return True

    def complement(self, width: Int) raises BitError -> BitSet:
        var result = self.copy()
        result.complement_with(width)
        return result^

    def complement_with(mut self, width: Int) raises BitError:
        if width < 0:
            raise BitError(
                BitErrorKind.RANGE, "complement_with", "width is negative"
            )
        if width == 0:
            self.clear_all()
            self._words.shrink(0)
            self._len = 0
            return
        # The complement universe is bits 0..width-1: every bit inside it is
        # flipped relative to the receiver; anything at or above `width` is
        # outside the universe and becomes 0.
        var new_words = List[UInt64]()
        var word_count = (width - 1) // 64 + 1
        for i in range(word_count):
            var inverted = ~self._word_or_zero(i)
            # Keep only the in-universe bits. The last word holds the partial
            # tail; a mask of the bits `(width-1) % 64` down to 0 trims it.
            if i == word_count - 1:
                var tail = (width - 1) % 64
                inverted &= field_mask[DType.uint64](i * 64, i * 64 + tail)
            new_words.append(inverted)
        self._words = new_words^
        self._recompute_len()

    def to_bytes(self) -> List[UInt8]:
        # Little-endian, LSB-first, minimal length: byte i bit j is index
        # i * 8 + j; the length is ceil(len / 8), so the empty set is 0 bytes.
        var out = List[UInt8]()
        if self._len == 0:
            return out^
        var byte_count = (self._len - 1) // 8 + 1
        for i in range(byte_count):
            var value = UInt8(0)
            for j in range(8):
                var index = i * 8 + j
                if index < len(self._words) * 64:
                    var bit = (self._words[index // 64] >> UInt64(index % 64)) & UInt64(1)
                    if bit == UInt64(1):
                        value |= UInt8(1) << UInt8(j)
            out.append(value)
        return out^

    @staticmethod
    def from_bytes(bytes: Span[UInt8, _]) -> BitSet:
        # Exact inverse of `to_bytes`: byte i bit j is index i * 8 + j. Trailing
        # zero bytes carry no set bit, so the result's logical length is the
        # highest set index + 1.
        var result = BitSet()
        for i in range(len(bytes)):
            var value = bytes[i]
            if value == UInt8(0):
                continue
            for j in range(8):
                if (value >> UInt8(j)) & UInt8(1) == UInt8(1):
                    result._set_bit(i * 8 + j)
        return result^

    def __iter__(self) -> BitSetIter:
        # A snapshot: the iterator copies the words, so mutating the set during
        # iteration is safe and does not change what the iterator yields.
        return BitSetIter(self._words.copy())

    def write_to(self, mut writer: Some[Writer]):
        # Compact set notation: `{0, 3, 5}`; the empty set prints `{}`.
        writer.write("{")
        var first = True
        var cursor = -1
        while True:
            var found = self.find_next(cursor)
            if not found:
                break
            var index = found.value()
            if not first:
                writer.write(", ")
            writer.write(index)
            first = False
            cursor = index + 1
        writer.write("}")

    # ----------------------------------------------------------------------
    # Private helpers (not part of the public surface).
    # ----------------------------------------------------------------------

    def _word_or_zero(self, i: Int) -> UInt64:
        # A word beyond the allocation reads as zero, for equal/relation queries.
        if i < len(self._words):
            return self._words[i]
        return UInt64(0)

    def _ensure_words(mut self, word_count: Int):
        # Grow the word list to at least `word_count` words, doubling for
        # amortized repeated growth.
        if word_count <= len(self._words):
            return
        var doubled = len(self._words) * 2
        var target = word_count if word_count > doubled else doubled
        if target < 1:
            target = 1
        self._words.resize(target, 0)

    def _set_bit(mut self, index: Int):
        # Assumes index >= 0. Grows and sets; _len becomes highest set + 1.
        self._ensure_words(index // 64 + 1)
        self._words[index // 64] |= UInt64(1) << UInt64(index % 64)
        if index + 1 > self._len:
            self._len = index + 1

    def _clear_bit(mut self, index: Int):
        # Assumes index >= 0. A clear at or beyond _len is a no-op.
        if index >= self._len:
            return
        self._words[index // 64] &= ~(UInt64(1) << UInt64(index % 64))
        if index + 1 == self._len:
            self._recompute_len()

    def _apply_range(mut self, lo: Int, hi: Int, op: Int):
        # Apply a word-wise mask over the inclusive range [lo, hi].
        # op: 0 = set (OR), 1 = clear (AND NOT), 2 = toggle (XOR).
        var lo_w = lo // 64
        var hi_w = hi // 64
        if lo_w == hi_w:
            var mask = field_mask[DType.uint64](lo % 64, hi % 64)
            self._apply_mask(lo_w, mask, op)
            return
        self._apply_mask(lo_w, field_mask[DType.uint64](lo % 64, 63), op)
        for w in range(lo_w + 1, hi_w):
            self._apply_mask(w, ~UInt64(0), op)
        self._apply_mask(hi_w, field_mask[DType.uint64](0, hi % 64), op)

    def _apply_mask(mut self, w: Int, mask: UInt64, op: Int):
        if op == 0:
            self._words[w] |= mask
        elif op == 1:
            self._words[w] &= ~mask
        else:
            self._words[w] ^= mask

    def _recompute_len(mut self):
        # Set _len to the highest set index + 1 (0 when the set is empty).
        for i in range(len(self._words) - 1, -1, -1):
            if self._words[i] != UInt64(0):
                self._len = i * 64 + Int(bit_width(self._words[i]))
                return
        self._len = 0

# API-DOCS-START
# BitSet — a growable, word-packed set of bits with LSB-first indexing.
# Signature:
#   struct BitSet(Equatable, Copyable, Deinitable, Writable, Sized):
#       var _words: List[UInt64]
#       var _len: Int
#       def __init__(out self)
#       def __init__(out self, *, capacity: Int)
#       def __len__(self) -> Int
#       def __eq__(self, other: Self) -> Bool
#       def capacity(self) -> Int
#       def count(self) -> Int
#       def is_empty(self) -> Bool
#       def all(self) -> Bool
#       def any(self) -> Bool
#       def none(self) -> Bool
#       def test(self, index: Int) raises BitError -> Bool
#       def set(mut self, index: Int) raises BitError
#       def clear(mut self, index: Int) raises BitError
#       def toggle(mut self, index: Int) raises BitError
#       def set_to(mut self, index: Int, value: Bool) raises BitError
#       def set_range(mut self, lo: Int, hi: Int) raises BitError
#       def clear_range(mut self, lo: Int, hi: Int) raises BitError
#       def toggle_range(mut self, lo: Int, hi: Int) raises BitError
#       def clear_all(mut self)
#       def reserve(mut self, bits: Int)
#       def shrink(mut self)
#       def find_next(self, from_index: Int) -> Optional[Int]
#       def to_list(self) -> List[Int]
#       def union(self, other: BitSet) -> BitSet
#       def intersection(self, other: BitSet) -> BitSet
#       def difference(self, other: BitSet) -> BitSet
#       def symmetric_difference(self, other: BitSet) -> BitSet
#       def union_with(mut self, other: BitSet)
#       def intersection_with(mut self, other: BitSet)
#       def difference_with(mut self, other: BitSet)
#       def symmetric_difference_with(mut self, other: BitSet)
#       def is_subset_of(self, other: BitSet) -> Bool
#       def is_superset_of(self, other: BitSet) -> Bool
#       def is_disjoint(self, other: BitSet) -> Bool
#       def complement(self, width: Int) raises BitError -> BitSet
#       def complement_with(mut self, width: Int) raises BitError
#       def to_bytes(self) -> List[UInt8]
#       @staticmethod
#       def from_bytes(bytes: Span[UInt8, _]) -> BitSet
#       def __iter__(self) -> BitSetIter
#       def write_to(self, mut writer: Some[Writer])
# What it does:
#   A growable set of bits stored as 64-bit words. Bit `i` is bit `i % 64` of
#   word `i / 64` (LSB-first, zero-based); index 0 is the least significant bit
#   of word 0. It is an owning value type: it owns its word list, so after a
#   move or an explicit `.copy()` it is independent of every other set.
#   Three deliberately distinct quantities:
#     len(bs)      — logical length in bits: highest set index + 1, or 0.
#     capacity()   — addressable bits currently allocated (word count * 64).
#     count()      — cardinality: how many bits are set.
#   `__init__(capacity=...)` is keyword-only and reserves room up front; it is a
#   growth hint, not a logical length, so `len` and `count` stay 0.
#   Queries are total: `test(index)` returns False for a not-yet-set index at or
#   beyond `len`, and `find_next(from_index)` returns the lowest set index
#   >= from_index or None (a negative from_index behaves as 0; never -1). Mutating
#   operations grow the word list to cover the highest touched index and never
#   shrink implicitly — only `shrink()` releases trailing all-zero words.
#   Ranges are inclusive `[lo, hi]`. The four materialising setters (`union`,
#   `intersection`, `difference`, `symmetric_difference`) return a new BitSet and
#   leave the receiver unchanged; the four `*_with` methods mutate in place and
#   return nothing. `complement(width)` returns a new set of the bits `0..width-1`
#   that are NOT set in the receiver (bits at or above `width` are outside the
#   universe and are 0); `complement_with(width)` does the same in place; a
#   negative `width` raises RANGE and `width == 0` yields the empty set.
#   `to_bytes()` serialises little-endian, LSB-first, minimal length (byte 0 bit 0
#   is index 0; length is ceil(len/8), 0 bytes for the empty set); the static
#   `from_bytes(span)` is its exact inverse. `for i in bits:` iterates the set
#   indices in ascending order through the public `BitSetIter`, which snapshots
#   the words at `__iter__` time. `write_to` prints a compact set notation, e.g.
#   `{0, 3, 5}`.
# Returns:
#   A BitSet owns its words; the materialising operators (`union`, …,
#   `complement`) return a new BitSet, `to_bytes` returns an owned List[UInt8],
#   `to_list` returns an owned List[Int] in ascending order, `find_next` returns
#   Optional[Int], and `__iter__` returns a `BitSetIter`.
# Errors:
#   raises BitError — RANGE on a negative index/lo or a negative complement width;
#   BAD_RANGE when lo > hi in a range method. All other operations cannot fail.
# Example:
#   var flags = BitSet()
#   flags.set(0)
#   flags.set(3)
#   print(len(flags))              # -> 4  (highest set index + 1)
#   print(flags.count())           # -> 2  (cardinality)
#   print(flags.find_next(0))      # -> 0
#   print(flags)                   # -> {0, 3}
#   var other = BitSet()
#   other.set(5)
#   var both = flags.union(other)  # -> {0, 3, 5}; flags unchanged
#   print(flags.complement(4))     # -> {1, 2}  (universe 0..3, {0, 3} set)
#   for i in flags:                # ascending set indices
#       print(i)                   # -> 0, 3
# API-DOCS-END
