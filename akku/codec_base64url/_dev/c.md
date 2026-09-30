# codec_base64url research: C

## 1. Standard library support
The C11 library roster contains no Base64 codec; this is an absence check against N1570 §7, not a claim about vendor extensions. [C11]

## 2. Relevant community libraries
libsodium is a portable, released cryptographic library with documented Base64 helpers; Frank Denis and contributors maintain it under ISC. This establishes an existing implementation, not an independent audit of its maturity. [Intro] [License]

## 3. Exposed APIs
`sodium_bin2base64`, `sodium_base642bin`, `sodium_base64_encoded_len` and `sodium_base64_ENCODED_LEN` support original/URL-safe alphabets, each padded or unpadded. [Helpers]

## 4. Error representation
Decode returns 0 or -1. An optional end pointer permits partial parsing; output capacity is explicit. [Helpers]

## 5. Ownership semantics
Signatures take caller-provided input/output buffers and lengths. Encoding's capacity calculation includes its terminating NUL. [Helpers]

## 6. Blocking / non-blocking
Inference: these buffer-to-buffer signatures expose synchronous computation, with no async handle. [Helpers]

## 7. IPv4 / IPv6
Not applicable: Base64url maps arbitrary octets, not address families. [RFC §4–5]

## 8. Timeouts
No timeout or cancellation parameter appears in the documented helpers. [Helpers]

## 9. TLS
The helpers encode data; Base64 provides no encryption and no TLS connection API. [Helpers]

## 10. Interesting design decisions
Bindings are encouraged to expose specialized codec functions instead of variant macros. Optional ignored-character sets make permissiveness explicit. [Helpers]
RFC 4648 distinguishes alphabet selection from padding omission and requires rejection of non-alphabet symbols unless a referring specification says otherwise. [RFC §3.2–3.3, §5]

## 11. Decisions NOT to copy
Research recommendation: avoid optional partial-parse success in the small convenience API; whole-input validation is easier to reason about. [Helpers] [RFC §3.3]
Research recommendation: do not expose C buffer capacities/NUL termination when returning an owned Mojo collection. [Helpers] [Buch ownership]

## 12. Ideas fitting Mojo
Candidate only: specialize the existing sibling codec's URL alphabet, borrow input and return owned output, preserve its typed decode errors. The sibling already documents those capabilities; Mojo's typed propagation and lifetime checking support this shape. [Sibling] [Buch errors] [Buch ownership]

## Sources
- [C11] https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf §7.
- [Intro] https://doc.libsodium.org/ (accessed 2026-10-01).
- [License] https://github.com/jedisct1/libsodium/blob/master/LICENSE.
- [Helpers] https://doc.libsodium.org/helpers (accessed 2026-10-01).
- [RFC] https://datatracker.ietf.org/doc/html/rfc4648.
- [Sibling] akku/codec_base64/__init__.mojo:26–84.
- [Buch errors] /Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/errors/raising-and-propagation.md#catching-typed-errors.
- [Buch ownership] /Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/memory/ownership-and-lifetimes.md (sections Argument conventions and Transfer).
