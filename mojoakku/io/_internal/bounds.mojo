# Private shared bounds for mojoakku/io.
#
# Every stored stream type parameter must be movable and deinitable so the
# adapter can own it in a struct field. `Reader`/`ByteWriter` come from the
# public per-entry traits; these aliases name the full bound once.

from io.reader import Reader
from io.byte_writer import ByteWriter


# Stream — the bound a stored, owned reader must satisfy.
comptime Stream = Reader & Movable & Deinitable

# Sink — the bound a stored, owned writer must satisfy.
comptime Sink = ByteWriter & Movable & Deinitable
