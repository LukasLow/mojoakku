from std.bit import count_trailing_zeros


# BitSetIter — the public iterator over the set bits of a BitSet.
#
# It holds a snapshot copy of the words taken at `__iter__` time, so mutating
# the set while iterating is safe and deterministic: the iterator yields the
# state captured when it was created.
struct BitSetIter(Deinitable):
    var _words: List[UInt64]
    var _next: Int

    def __init__(out self, var words: List[UInt64]):
        self._words = words^
        self._next = 0

    def __has_next__(self) -> Bool:
        var word = self._next // 64
        if word >= len(self._words):
            return False
        # Mask off the bits below _next in the first word, then check whether any
        # bit at or above _next survives.
        var masked = self._words[word] & (~UInt64(0) << UInt64(self._next % 64))
        if masked != UInt64(0):
            return True
        for i in range(word + 1, len(self._words)):
            if self._words[i] != UInt64(0):
                return True
        return False

    def __next__(mut self) -> Int:
        var word = self._next // 64
        var masked = self._words[word] & (~UInt64(0) << UInt64(self._next % 64))
        while masked == UInt64(0):
            word += 1
            masked = self._words[word]
        var index = word * 64 + Int(count_trailing_zeros(masked))
        self._next = index + 1
        return index

# API-DOCS-START
# BitSetIter — ascending iterator over the set-bit indices of a BitSet.
# Signature:
#   struct BitSetIter(Deinitable):
#       var _words: List[UInt64]
#       var _next: Int
#       def __init__(out self, var words: List[UInt64])
#       def __has_next__(self) -> Bool
#       def __next__(mut self) -> Int
# What it does:
#   Returned by `BitSet.__iter__`, so `for i in bits:` yields each set index in
#   ascending order — equivalent to `to_list`, but without building the list.
#   It holds a snapshot copy of the set's words taken when `__iter__` ran, so
#   mutating the set during iteration is safe and deterministic: the iterator
#   never sees bits added or removed after it was created. `__has_next__` is the
#   loop guard and `__next__` returns the next index. Constructing one directly
#   is possible but not needed; use the `for` loop.
# Returns:
#   `__next__` returns the next set index as an Int; `__has_next__` a Bool.
# Errors:
#   none — iterating a BitSet cannot fail.
# Example:
#   var bits = BitSet()
#   bits.set(2)
#   bits.set(9)
#   for i in bits:
#       print(i)      # -> 2, then 9
# API-DOCS-END
