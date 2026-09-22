# API-DOCS-START
# Alphabet — compile-time value type selecting the symbol table.
# Status: implemented
# Signature: struct Alphabet(Equatable, ImplicitlyCopyable, Deinitable):
#   var _id: UInt8; @doc_hidden def __init__(out self, id: UInt8)
#   comptime B64_STANDARD/B64_URL/B32_STANDARD/B32_HEX/HEX_LOWER/HEX_UPPER
# Semantics: used as a function/struct value parameter (`[alphabet: Alphabet]`).
#   Identifies the symbol table, the symbols-per-quantum ratio and whether
#   padding exists. The six comptime members are the complete public set; the
#   _id field and its @doc_hidden initializer are implementation details. Mojo
#   has no access control, so the constructor is technically reachable inside the
#   package; the library defines behaviour only for ids 0-5. Case policy is a
#   fixed property of the alphabet: B64_* are case-sensitive two-case;
#   B32_STANDARD/B32_HEX are uppercase-only; HEX_LOWER/HEX_UPPER each accept only
#   their own case on decode. Value type, compile-time only; no heap, no I/O.
# Errors: none in practice. The six named constants are the only Alphabet values
#   in the public contract, so code on public names never supplies an invalid
#   alphabet. This is a documented convention boundary, not compiler-enforced.
# Tests: test_base64_alphabet.mojo
# Implementation status: implemented
# Rationale: MojoAkku uses a compile-time Alphabet value parameter because Go's
#   runtime variant integer and Rust's Alphabet::new pay per-call
#   branching/validation, while cppcodec's variant-as-type and Mojo's documented
#   value-parameter specialization remove all runtime alphabet dispatch.
# API-DOCS-END


# Alphabet — compile-time value type selecting the symbol table.
#
# Used as a value parameter `[alphabet: Alphabet = Alphabet.B64_STANDARD]` on
# the codec entries. It identifies the symbol table, the symbols-per-quantum
# ratio and whether padding exists.
# Parameters: none; callers use the six named constants below.
# Return / meaning: an opaque compile-time value; the library defines behaviour
# only for ids 0-5. Values outside that set are outside the public contract.
# Errors: none in practice; the six named constants are the only public values.
# Semantics (one line): the alphabet is chosen at compile time, so table
# lookups and branches resolve while compiling.
struct Alphabet(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8):
        self._id = id

    comptime B64_STANDARD = Alphabet(0)   # RFC 4648 §4,  A-Z a-z 0-9 + /
    comptime B64_URL      = Alphabet(1)   # RFC 4648 §5,  A-Z a-z 0-9 - _
    comptime B32_STANDARD = Alphabet(2)   # RFC 4648 §6,  A-Z 2-7
    comptime B32_HEX      = Alphabet(3)   # RFC 4648 §7,  0-9 A-V
    comptime HEX_LOWER    = Alphabet(4)   # RFC 4648 §8,  0-9 a-f
    comptime HEX_UPPER    = Alphabet(5)   # RFC 4648 §8,  0-9 A-F
