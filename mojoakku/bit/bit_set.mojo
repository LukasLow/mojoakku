from std.os import abort

from .bit_error import BitError


# BitSet — a growable, word-packed set of bits with LSB-first indexing.
struct BitSet(Equatable, Copyable, Deinitable, Writable, Sized):
    var _words: List[UInt64]
    var _len: Int            # logical length in bits = highest set index + 1

    def __init__(out self):
        abort("MojoAkku: this API is not yet implemented")

    def __init__(out self, *, capacity: Int):
        abort("MojoAkku: this API is not yet implemented")

    def __len__(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def __eq__(self, other: Self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def capacity(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def count(self) -> Int:
        abort("MojoAkku: this API is not yet implemented")

    def is_empty(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def all(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def any(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def none(self) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def test(self, index: Int) raises BitError -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def set(mut self, index: Int) raises BitError:
        abort("MojoAkku: this API is not yet implemented")

    def clear(mut self, index: Int) raises BitError:
        abort("MojoAkku: this API is not yet implemented")

    def toggle(mut self, index: Int) raises BitError:
        abort("MojoAkku: this API is not yet implemented")

    def set_to(mut self, index: Int, value: Bool) raises BitError:
        abort("MojoAkku: this API is not yet implemented")

    def set_range(mut self, lo: Int, hi: Int) raises BitError:
        abort("MojoAkku: this API is not yet implemented")

    def clear_range(mut self, lo: Int, hi: Int) raises BitError:
        abort("MojoAkku: this API is not yet implemented")

    def toggle_range(mut self, lo: Int, hi: Int) raises BitError:
        abort("MojoAkku: this API is not yet implemented")

    def clear_all(mut self):
        abort("MojoAkku: this API is not yet implemented")

    def reserve(mut self, bits: Int):
        abort("MojoAkku: this API is not yet implemented")

    def shrink(mut self):
        abort("MojoAkku: this API is not yet implemented")

    def find_next(self, from_index: Int) -> Optional[Int]:
        abort("MojoAkku: this API is not yet implemented")

    def to_list(self) -> List[Int]:
        abort("MojoAkku: this API is not yet implemented")

    def union(self, other: BitSet) -> BitSet:
        abort("MojoAkku: this API is not yet implemented")

    def intersection(self, other: BitSet) -> BitSet:
        abort("MojoAkku: this API is not yet implemented")

    def difference(self, other: BitSet) -> BitSet:
        abort("MojoAkku: this API is not yet implemented")

    def symmetric_difference(self, other: BitSet) -> BitSet:
        abort("MojoAkku: this API is not yet implemented")

    def union_with(mut self, other: BitSet):
        abort("MojoAkku: this API is not yet implemented")

    def intersection_with(mut self, other: BitSet):
        abort("MojoAkku: this API is not yet implemented")

    def difference_with(mut self, other: BitSet):
        abort("MojoAkku: this API is not yet implemented")

    def symmetric_difference_with(mut self, other: BitSet):
        abort("MojoAkku: this API is not yet implemented")

    def is_subset_of(self, other: BitSet) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def is_superset_of(self, other: BitSet) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def is_disjoint(self, other: BitSet) -> Bool:
        abort("MojoAkku: this API is not yet implemented")

    def write_to(self, mut writer: Some[Writer]):
        abort("MojoAkku: this API is not yet implemented")

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
#   return nothing. `write_to` prints a compact set notation, e.g. `{0, 3, 5}`.
# Returns:
#   A BitSet owns its words; the materialising operators return a new BitSet,
#   `to_list` returns an owned List[Int] in ascending order, and `find_next`
#   returns Optional[Int].
# Errors:
#   raises BitError — RANGE on a negative index/lo; BAD_RANGE when lo > hi in a
#   range method. All other operations cannot fail.
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
# API-DOCS-END
