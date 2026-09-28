# Concern: `StringBuilder` — the owning incremental text buffer with an explicit
# flush (docs block in `../string_builder.mojo`).
#
# Covers: `__init__()` starts empty; `__init__(capacity_bytes=...)` is a growth
# hint only (still empty); `append` adds UTF-8 bytes of a borrowed view;
# `append_codepoint` adds one Codepoint; `append_bytes` adds raw bytes and
# raises INVALID_UTF8 (appending nothing) on non-UTF-8 input; `reserve` grows
# capacity without changing content length; `clear` resets content while keeping
# capacity; `byte_length` tracks content; `capacity` is the addressable byte
# count; `to_string` returns a copy and leaves the builder usable; `finish`
# transfers the buffer out and consumes the builder (called as `b^.finish()`);
# `Writer` conformance via `write(...)`; `Writable` via `print(builder)`.
#
# Edge-case checklist (honest coverage): EOF / EINTR / EAGAIN / timeouts /
# close / errno are N/A — the builder is an in-memory buffer with no descriptor
# and no blocking point. The applicable edge is invalid input (non-UTF-8 bytes),
# covered below.

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from string import StringBuilder


def test_string_builder_starts_empty() raises:
    var b = StringBuilder()
    assert_equal(b.byte_length(), 0)
    assert_true(String(b) == "")


def test_string_builder_capacity_ctor_is_a_hint_only() raises:
    # A capacity hint reserves room up front but is not a logical length.
    var b = StringBuilder(capacity_bytes=64)
    assert_equal(b.byte_length(), 0)
    assert_true(b.capacity() >= 64)
    assert_true(String(b) == "")


def test_string_builder_append() raises:
    var b = StringBuilder()
    b.append("Hello")
    b.append(" world")
    assert_equal(b.byte_length(), 11)
    assert_true(String(b) == "Hello world")


def test_string_builder_append_codepoint() raises:
    var b = StringBuilder()
    b.append("a")
    b.append_codepoint(Codepoint(98))   # 'b'
    assert_equal(b.byte_length(), 2)
    assert_true(String(b) == "ab")


def test_string_builder_append_non_ascii_codepoint() raises:
    var b = StringBuilder()
    b.append_codepoint(Codepoint(0x00E9))   # 'é', two UTF-8 bytes
    assert_equal(b.byte_length(), 2)
    assert_true(String(b) == "é")


def test_string_builder_append_bytes_valid() raises:
    var b = StringBuilder()
    var hi: List[UInt8] = [104, 105]   # "hi"
    b.append_bytes(Span(hi))
    assert_equal(b.byte_length(), 2)
    assert_true(String(b) == "hi")


def test_string_builder_append_bytes_invalid_raises() raises:
    # Invalid UTF-8 raises INVALID_UTF8 and appends nothing (atomic).
    var b = StringBuilder()
    b.append("keep")
    var bad: List[UInt8] = [255]
    var caught = False
    try:
        b.append_bytes(Span(bad))
    except e:
        caught = True
    assert_true(caught)
    # The prior content is unchanged; nothing partial was appended.
    assert_equal(b.byte_length(), 4)
    assert_true(String(b) == "keep")


def test_string_builder_reserve_capacity() raises:
    var b = StringBuilder()
    b.append("hi")
    var before = b.byte_length()
    b.reserve(256)
    assert_true(b.capacity() >= 256)
    # reserve is a growth hint, not a content change.
    assert_equal(b.byte_length(), before)


def test_string_builder_clear_keeps_capacity() raises:
    var b = StringBuilder()
    b.append("hello")
    b.reserve(128)
    var cap = b.capacity()
    b.clear()
    assert_equal(b.byte_length(), 0)
    assert_true(String(b) == "")
    # clear resets content, not capacity.
    assert_true(b.capacity() >= cap)


def test_string_builder_to_string_borrows() raises:
    # to_string returns a copy and leaves the builder usable.
    var b = StringBuilder()
    b.append("abc")
    var s = b.to_string()
    assert_true(s == "abc")
    # The builder still has its content and can keep growing.
    assert_equal(b.byte_length(), 3)
    b.append("d")
    assert_true(String(b) == "abcd")
    # The returned copy is independent of the builder.
    assert_true(s == "abc")


def test_string_builder_finish_consumes() raises:
    # finish transfers the buffer out and consumes the builder.
    var b = StringBuilder()
    b.append("done")
    var out = b^.finish()
    assert_true(out == "done")


def test_string_builder_writer_conformance() raises:
    # Writer conformance lets builder.write(a, b, c) accept formatted output.
    var b = StringBuilder()
    b.write("Count: ", 42)
    assert_true(String(b) == "Count: 42")


def test_string_builder_writable() raises:
    # Writable conformance: print(builder) uses write_to.
    var b = StringBuilder()
    b.append("shown")
    assert_true("shown" in String(b))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
