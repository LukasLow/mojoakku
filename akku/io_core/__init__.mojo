# MojoAkku io — package entry point.
#
# Re-exports the public API from the flat per-entry modules so
# `from io import ...` works. Nothing else lives here: the public surface is
# defined by the per-entry files and this file only forwards names.

from .io_error_kind import IoErrorKind
from .io_error import IoError
from .read_result import ReadResult
from .seek_from import SeekFrom
from .reader import Reader
from .byte_writer import ByteWriter
from .seeker import Seeker
from .cursor import Cursor
from .span_cursor import SpanCursor
from .buffered_reader import BufferedReader
from .buffered_writer import BufferedWriter
from .limit_reader import LimitReader
from .tee_reader import TeeReader
from .multi_reader import MultiReader
from .copy import copy

# API-DOCS-START
# Purpose   — akku/io_core is the byte stream layer for MojoAkku: it reads and
#   writes raw bytes through a small, uniform set of traits and adapters. It is
#   pure and in-process — no files, sockets, threads or global state — and it
#   supplies the missing read side of Mojo's I/O (the standard library has
#   Writer/Writable but no Reader trait). Release 1 is bytes only; a text/UTF-8
#   adapter is deliberately deferred.
# Overview  — one uniform shape across the whole layer. Two symmetric traits,
#   Reader and ByteWriter, each have a single required buffer-oriented method
#   plus a few provided helpers, and Seeker is a separate optional capability.
#   A buffer is always borrowed for the call only: a read target is a
#   MutSpan[UInt8, _], a write input a Span[UInt8, _]; the library never retains
#   or allocates it, and the stream owns its own cursor/buffer. A read returns an
#   explicit ReadResult { count, eof } — end of stream is never a magic
#   -1/0/null and never an error. Buffering and limiting are ordinary
#   value-semantics structs over the traits, with a compile-time buffer size, so
#   they compose without virtual dispatch. Failures surface as one typed error,
#   IoError.
# Dependencies — none. io is a leaf: it depends only on the Mojo standard
#   library (Span, MutSpan, Array, List, String, Bool, Int, UInt8). Later
#   libraries (socket, tcp, http) point to io, never the reverse.
# Public API — the ordered index (each entry is specified in its own file):
#    1. IoErrorKind   — closed failure discriminant: INTERRUPTED, WOULD_BLOCK,
#                        CLOSED, TIMED_OUT, INVALID_UTF8, UNEXPECTED_EOF, OTHER.
#    2. IoError       — the one typed error: kind: IoErrorKind, op: String,
#                        detail: String.
#    3. ReadResult    — explicit read outcome: count: Int, eof: Bool.
#    4. SeekFrom      — seek origin: START, CURRENT, END plus a signed offset.
#    5. Reader        — one required read; provided read_exact, read_to_end.
#    6. ByteWriter    — one required write; provided write_all, flush.
#    7. Seeker        — one required seek.
#    8. Cursor        — in-memory reader+writer+seeker over an owned List.
#    9. SpanCursor    — read+seek only over a borrowed Span (read-only).
#   10. BufferedReader — buffered wrapper with an inline, compile-time buffer.
#   11. BufferedWriter — buffered wrapper with an explicit, fallible flush/close.
#   12. LimitReader  — reads at most n bytes.
#   13. TeeReader    — mirrors everything read into a writer.
#   14. MultiReader  — concatenates a homogeneous set of readers.
#   15. copy         — pumps a reader into a writer until EOF.
# Error Surface — exactly one error type, IoError, carrying kind: IoErrorKind,
#   op: String and detail: String. End of stream is not an error; it is
#   ReadResult.eof. Every fallible stream operation declares `raises IoError`:
#     Reader.read, read_exact, read_to_end        — any kind
#     ByteWriter.write, write_all, flush          — any kind
#     Seeker.seek                                 — OTHER (incl. non-seekable), CLOSED
#     Cursor / SpanCursor / BufferedReader /
#       BufferedWriter / LimitReader / TeeReader /
#       MultiReader                               — as the wrapped trait method
#     copy                                        — any kind
#   Most kinds are recoverable: retry (INTERRUPTED / WOULD_BLOCK), reopen
#   (CLOSED), adjust the deadline (TIMED_OUT), re-encode (INVALID_UTF8).
#   UNEXPECTED_EOF is lossy but not fatal. A raising operation does not return
#   its partial count; a caller who needs partial progress uses `read` into a
#   caller-owned buffer. Callers branch on `kind`, never on the opaque `detail`
#   string. `print(err)` gives a readable kind + operation + detail message.
# Conventions — names are stable; read targets are MutSpan[UInt8, _] and write
#   inputs Span[UInt8, _], both borrowed for the call only. End of stream is
#   ReadResult { count, eof: True }; a short read or write is normal and is not
#   EOF and not an error. Buffer capacities are compile-time value parameters
#   (default 4096). flush is explicit and fallible — no destructor performs a
#   silent flush. The blocking, synchronous core has no async/await. Read and
#   write never allocate the caller's buffer; read_to_end returns an owned
#   List[UInt8].
# API-DOCS-END
