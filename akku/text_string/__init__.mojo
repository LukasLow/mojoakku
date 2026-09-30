# MojoAkku string — package entry point.
#
# Re-exports the public API from the flat per-entry modules so
# `from string import ...` works. Nothing else lives here: the public surface is
# defined by the per-entry files and this file only forwards names.

from .string_error_kind import StringErrorKind
from .string_error import StringError
from .string_builder import StringBuilder
from .find import find
from .rfind import rfind
from .split_once import split_once
from .rsplit_once import rsplit_once
from .trim import trim
from .capitalize import capitalize
from .to_ascii_lower import to_ascii_lower
from .to_ascii_upper import to_ascii_upper
from .replace_n import replace_n
from .is_char_boundary import is_char_boundary
from .slice import slice
from .try_slice import try_slice
from .is_valid_utf8 import is_valid_utf8

# API-DOCS-START
# Purpose   — akku/text_string is the text primitives library for MojoAkku: the
#   one predictable string layer every parser and protocol library above it
#   (url, mime, json, parser, regex, path, html, csv, toml, yaml, ...) can rely
#   on. The Mojo standard library already ships a rich string family (String,
#   StringSpan, StaticString, three length measurements, grapheme iteration,
#   find/split/strip/lower/upper/replace/startswith/endswith and the byte-input
#   constructors), so this library does NOT rebuild it: it fills the four gaps
#   std leaves — a builder, typed-absence search/split, boundary-safe slicing,
#   and a typed error plus an allocation-free validity predicate. It is a leaf
#   library (no sibling dependencies) and performs no I/O.
# Overview  — the substrate is the stdlib's String/StringSpan/StaticString
#   triple. The library adds five small groups:
#     1. Error surface     — StringErrorKind + StringError (one closed
#        discriminant, one typed error carrying a byte position).
#     2. Builder layer     — StringBuilder: an owning incremental buffer with
#        append/reserve/clear, a byte length and capacity, and two ways to
#        materialise (to_string borrows a copy; finish consumes).
#     3. Search and split  — find/rfind returning Optional[Int] (no -1 sentinel)
#        and split_once/rsplit_once returning Optional views of the two halves.
#     4. Trim, case and replace — trim (Unicode whitespace or an explicit char
#        set), capitalize, the ASCII-only to_ascii_lower/to_ascii_upper fast
#        paths, and the counted replace_n.
#     5. Boundary and byte bridge — is_char_boundary, the checked slice (raises)
#        and its total twin try_slice (Optional), and the allocation-free
#        is_valid_utf8.
#   Positions are byte offsets; ranges are half-open [start, end); absence is
#   Optional, never a sentinel; a bad input is a typed error, never a panic.
# Dependencies — none. string is a leaf: it depends only on the Mojo standard
#   library (String, StringSpan, StaticString, Span[UInt8, _], Codepoint, List,
#   Optional, Tuple, Int, Bool, UInt8, Some[Writer]). No signature mentions a
#   stream, socket, file, buffer, URL or other sibling concept, so no dependency
#   edge can be technically justified. The 36 libraries above it depend on
#   string, never the reverse.
# Public API — the ordered index (each entry is specified in its own file):
#    1. StringErrorKind — closed failure discriminant: INDEX_OUT_OF_BOUNDS,
#                         BAD_RANGE, NOT_A_BOUNDARY, INVALID_UTF8.
#    2. StringError     — the one typed error: kind: StringErrorKind,
#                         position: Int.
#    3. StringBuilder   — an owning incremental text buffer with append,
#                         reserve, clear, byte_length, capacity, to_string,
#                         finish, and Writer conformance.
#    4. find            — first needle occurrence as Optional[Int] (byte offset).
#    5. rfind           — last needle occurrence at or after start as
#                         Optional[Int].
#    6. split_once      — split at the first separator into Optional[(before,
#                         after)].
#    7. rsplit_once     — split at the last separator into Optional[(before,
#                         after)].
#    8. trim            — remove leading/trailing Unicode whitespace, or an
#                         explicit char set.
#    9. capitalize      — uppercase the first codepoint, lowercase the rest.
#   10. to_ascii_lower  — deterministic ASCII-only lowercase fast path.
#   11. to_ascii_upper  — deterministic ASCII-only uppercase fast path.
#   12. replace_n       — replace the first count occurrences (or all) of a
#                         needle.
#   13. is_char_boundary — is a byte index a valid codepoint start (or the end)?
#   14. slice           — checked byte-range extraction raising StringError.
#   15. try_slice       — checked byte-range extraction returning Optional.
#   16. is_valid_utf8   — allocation-free validity predicate over raw bytes.
# Error Surface — exactly one error type, StringError, carrying
#   kind: StringErrorKind and position: Int (a byte offset into the original
#   input). Every kind is a recoverable data error. Which API raises what:
#     StringBuilder.append_bytes — INVALID_UTF8
#     replace_n                  — BAD_RANGE (empty `old` needle)
#     slice                      — INDEX_OUT_OF_BOUNDS, BAD_RANGE, NOT_A_BOUNDARY
#     find, rfind, split_once, rsplit_once, trim, capitalize, to_ascii_lower,
#       to_ascii_upper, is_char_boundary, try_slice, is_valid_utf8
#                                — none (absence is Optional; predicates return
#                                  Bool)
#   There are no I/O or allocation errors: the library owns no descriptor.
#   `print(err)` gives a readable kind + position message, and a caught error is
#   re-raised by transfer with `raise e^`.
# Conventions — positions are byte offsets into the UTF-8 buffer, zero-based;
#   codepoint/grapheme indexing stays the stdlib's s[codepoint=...] and
#   s[grapheme=...] view. Ranges are half-open [start, end) in bytes, so
#   start == end is the empty slice and start > end is BAD_RANGE. Queries borrow
#   a StringSpan and return a view or a plain value; allocating transforms
#   return an owned String. Names are snake_case for functions and types are
#   CamelCase. trim is Unicode-whitespace aware, unlike std's ASCII-only strip.
#   There is no hidden global state, no ambient locale and no default encoding.
# API-DOCS-END
