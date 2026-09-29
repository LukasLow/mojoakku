# std_probe.mojo — auditable probe of the installed Mojo standard-library
# string surface. This is a DEVELOPMENT artifact under `_dev/`; it is never
# shipped and is not library code.
#
# Run (inside the smd container, from the repo root):
#
#     smd mojo run mojoakku/text_string/_dev/std_probe.mojo
#
# The captured output is checked in as `std_probe.log`. Together the two files
# are the audit trail for the "Empirical std surface" table in `DESIGN.md`:
# every `✓` row below is one `print` line, and every `✗` row is a one-line
# snippet in the NEGATIVE CHECKS block at the bottom, whose exact compiler error
# is recorded in `std_probe.log`.
#
# Toolchain: Mojo 1.1.0 (8189361e). `mojo run <file>` type-checks and executes.

# NEGATIVE CHECKS — each line was run as `mojo run` on its own and does NOT
# compile in Mojo 1.1.0 (the exact error is in std_probe.log). Keep these as
# comments so this file itself always compiles.
#
#   print(String("a").trim())                 # no attribute 'trim'
#   print(String("a").is_empty())             # no attribute 'is_empty'
#   print(String("a").capitalize())           # no attribute 'capitalize'
#   print(String("a").title())                # no attribute 'title'
#   print(String("a").casefold())             # no attribute 'casefold'
#   print(String("a").to_lower())             # no attribute 'to_lower' (use lower())
#   print(String("a").to_ascii_lower())       # no attribute 'to_ascii_lower'
#   print(String("a").reverse())              # no attribute 'reverse'
#   print(String("a").clear())                # no attribute 'clear'
#   print(String("a").shrink_to_fit())        # no attribute 'shrink_to_fit'
#   print(String("a").push_back(UInt8(98)))   # no attribute 'push_back'
#   print(String("a").pop())                  # no attribute 'pop'
#   print(String("a").replace("a","b",1))     # replace takes no count argument
#   print(String("a").split(",").rsplit(",")) # no attribute 'rsplit'
#   print(String("a").rsplit(","))            # no attribute 'rsplit'
#   print(String("a").split_once("="))        # no attribute 'split_once'
#   print(String("a").partition("="))         # no attribute 'partition'
#   print(String("a").find("a", 1, 2))        # find takes no end argument
#   print(String("a").is_char_boundary(0))    # no attribute 'is_char_boundary'
#   print(String("a").byte_at(0))             # no attribute 'byte_at'
#   print(String("a").codepoint_at(0))        # no attribute 'codepoint_at'
#   print(String("a").strip_prefix("a"))      # no attribute 'strip_prefix'
#   print(String("a").as_bytes_slice())       # no attribute 'as_bytes_slice'
#   print(String("a").is_valid_utf8())        # no attribute 'is_valid_utf8'
#   from std.collections import StringBuilder   # package 'collections' has no 'StringBuilder'
#   for c in reversed(String("ab")): pass      # reversed(String) does not compile
#
# Note: `String(some_list)` DOES compile, but it stringifies the list through
# the variadic Writable constructor (e.g. String([104,105]) prints "[104, 105]"),
# it is NOT a byte -> text bridge. Byte input must go through a Span:
#   String(from_utf8=Span(list)), String(from_utf8_lossy=Span(list)),
#   String(unsafe_from_utf8=Span(list)).


from std.collections import Optional


def main() raises:
    # ---- Toolchain banner -------------------------------------------------
    print("PROBE toolchain=Mojo 1.1.0(8189361e)")

    # ---- Length / measurement --------------------------------------------
    var s = String("café")
    print("byte_length", s.byte_length())            # 5
    print("count_codepoints", s.count_codepoints())  # 4
    print("count_graphemes", s.count_graphemes())    # 4
    # len(s) is a compile error by design:
    #   `len(String)` is not supported because UTF-8 length is ambiguous.

    # ---- Search -----------------------------------------------------------
    print("find_hit", String("hello world").find("world"))    # 6
    print("find_miss", String("hello").find("zz"))            # -1 (sentinel)
    print("find_start", String("abab").find("a", 1))          # 2
    print("rfind", String("abab").rfind("a"))                 # 2
    print("rfind_miss", String("abab").rfind("z"))            # -1 (sentinel)
    print("rfind_start", String("abab").rfind("a", 1))        # 2
    print("count_substr", String("abab").count("a"))          # 2
    print("startswith", String("hello").startswith("he"))     # True
    print("endswith", String("hello").endswith("lo"))         # True
    print("startswith_start", String("abc").startswith("b", 1))  # True
    print("in_operator", "ell" in String("hello"))            # True

    # ---- Split ------------------------------------------------------------
    print("split_sep", String("a,b,c").split(","))            # [a, b, c]
    print("split_maxsplit", String("a,b,c").split(",", 1))    # [a, b,c]
    print("split_none_ws", String(" a  b ").split())          # [a, b]
    print("splitlines", String("a\nb").splitlines())          # [a, b]
    print("split_empty_sep", String("abc").split(""))         # [, a, b, c, ]

    # ---- Trim -------------------------------------------------------------
    print("strip", "[" + String("  x  ").strip() + "]")       # [x]
    print("strip_chars", "[" + String("xxaxx").strip("x") + "]")  # [a]
    print("lstrip", "[" + String("  x  ").lstrip() + "]")     # [x  ]
    print("rstrip", "[" + String("  x  ").rstrip() + "]")     # [  x]
    # ASCII-only: NBSP (U+00A0) and U+3000 survive `strip()`.
    print("strip_nbsp_survives", "[" + String("\u00A0x\u00A0").strip() + "]")
    print("strip_u3000_survives", "[" + String("\u3000x\u3000").strip() + "]")

    # ---- Case -------------------------------------------------------------
    print("lower", String("AbC").lower())                     # abc
    print("upper", String("AbC").upper())                     # ABC
    print("lower_unicode", String("Ä").lower())               # ä
    print("upper_unicode", String("ä").upper())               # Ä

    # ---- Replace ----------------------------------------------------------
    print("replace", String("aaa").replace("a", "b"))         # bbb

    # ---- Affix ------------------------------------------------------------
    print("removeprefix", String("foobar").removeprefix("foo"))  # bar
    print("removesuffix", String("foobar").removesuffix("bar"))  # foo
    print("removeprefix_miss", String("abc").removeprefix("x"))  # abc

    # ---- Indexing / slicing ----------------------------------------------
    # The annotated forms are the only ones; bare s[i] / s[a:b] are compile
    # errors by design. The std forms abort on a bad index / mid-codepoint.
    print("index_byte", String("hello")[byte=1])              # e
    print("index_codepoint", String("hé")[codepoint=1])       # é
    print("slice_byte", String("hello")[byte=1:3])            # el
    print("slice_codepoint", String("hello")[codepoint=1:3])  # el
    var v: StringSpan = "hello"
    print("slice_grapheme_span", v[grapheme=1:3])             # el

    # ---- Views / iteration ------------------------------------------------
    var nbytes = 0
    for b in s.bytes():
        _ = b
        nbytes += 1
    print("bytes_iter_len", nbytes)                           # 5
    var ncps = 0
    for c in s.codepoints():
        _ = c
        ncps += 1
    print("codepoints_iter_len", ncps)                        # 4
    var nslices = 0
    for cs in s.codepoint_slices():
        _ = cs
        nslices += 1
    print("codepoint_slices_iter_len", nslices)               # 4
    var ngraphemes = 0
    for g in s:
        _ = g
        ngraphemes += 1
    print("grapheme_iter_len", ngraphemes)                    # 4

    # ---- Construct / bridge ----------------------------------------------
    var raw: List[UInt8] = [104, 105]                         # "hi"
    var sp = Span(raw)
    print("String_from_utf8", String(from_utf8=sp))           # hi
    var bad: List[UInt8] = [255, 105]
    print("String_from_utf8_lossy", String(from_utf8_lossy=Span(bad)))  # replacement + i
    print("String_unsafe_from_utf8", String(unsafe_from_utf8=Span(raw)))  # hi
    print("String_capacity_bytes", String(capacity_bytes=8).byte_length())  # 0
    print("String_ptr_len", String("hi").unsafe_ptr(), 2)     # byte pointer + explicit length
    print("String_variadic", String("a", 5))                  # a5
    print("TString", t"v={5}")                                # v=5
    print("format_method", "{} {}".format(1, "x"))            # 1 x

    # ---- Builder-ish (mutating String, not a builder type) ----------------
    var b = String("a")
    b += "b"
    b.append(Codepoint(99))                                   # append one codepoint
    b.reserve_bytes(64)
    print("String_mutation", b)                               # abc
    print("String_capacity_bytes_gt0", b.capacity_bytes() > 0)  # True
    var r = String("a")
    r.resize(3, UInt8(98))
    print("String_resize", r)                                 # abb
    var parts: List[String] = ["x", "y"]
    print("String_join", String(",").join(parts))             # x,y
    var nums: List[Int] = [1, 2]
    print("String_join_writable", String(",").join(nums))     # 1,2

    # ---- Boundary behaviour (aborts, not reports) ------------------------
    # These are demonstrated by their exact error text in std_probe.log:
    #   String("hi")[byte=5]        -> Assert Error: index 5 is out of bounds
    #   String("hi")[byte=-1]       -> compile-time instantiation failure
    #   String("hé")[byte=1:2]      -> Assert Error: ... not a codepoint boundary
    print("PROBE done")
