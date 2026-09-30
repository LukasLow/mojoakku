# codec_base64url research: Mojo

Mojo knowledge is served by the local mojov1 buch, not web research.
Read: keywords/import.md (aliases and public imports), functions/parameters-and-generics.md
(compile-time policy parameters, infer-only Span origins), keyword-conventions/raises.md
and errors/raising-and-propagation.md (typed error propagation), lifecycle/life.md
(borrowing and owned values). Root: /Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/.
The existing sibling public API is inspected at akku/codec_base64/{encode,decode,is_valid,padding_mode}.mojo.
TOLERANT explicitly accepts non-zero trailing bits; it must not be described as canonical validation.
