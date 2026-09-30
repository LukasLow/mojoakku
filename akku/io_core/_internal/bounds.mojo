# Private shared bounds for akku/io_core.
#
# Every stored stream type parameter must be movable and deinitable so the
# adapter can own it in a struct field. `Reader`/`ByteWriter` come from the
# public per-entry traits; these aliases name the full bound once.

from ..reader import Reader
from ..byte_writer import ByteWriter


# Stream — the bound a stored, owned reader must satisfy.
comptime Stream = Reader & Movable & Deinitable

# Sink — the bound a stored, owned writer must satisfy.
comptime Sink = ByteWriter & Movable & Deinitable
