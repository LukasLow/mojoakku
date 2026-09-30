# codec_base64url research: Rust

## 1. Standard library support
The documented Rust standard-library module index contains no Base64 codec module; ecosystem codecs provide it. This is an inventory observation, not a promise about future Rust versions. [S]

## 2. Relevant community libraries
`base64`, maintained in Marshall Pierce's `rust-base64` repository, is MIT/Apache-2.0 licensed. The primary repository provides tests, fuzzing and benchmarks; its maturity claim is widely used and thoroughly tested, without an independent adoption audit here. [B2]

## 3. Exposed APIs
The `Engine` abstraction provides encoding and decoding; standard and URL-safe presets have padded and unpadded variants. Input/output choices include allocated results, existing buffers and stream adapters. [B1][B3]

## 4. Error representation
`DecodeError` distinguishes invalid byte (with position), invalid length, invalid final symbol and invalid padding. Operations use Rust `Result`. [B4]

## 5. Ownership semantics
Allocated encode/decode produce owned `String`/`Vec<u8>`; slice operations borrow output storage and avoid that allocation. Input is accepted by reference. [B1]

## 6. Blocking / non-blocking
The documented codec interface consists of synchronous operations and standard I/O adapters; it exposes no async codec runtime. This is an interface inventory observation. [B1]

## 7. IPv4 / IPv6
Not applicable: RFC 4648 transforms octets; address families are outside its scope. [R]

## 8. Timeouts
No timeout parameter appears in the documented codec interfaces; cancellation belongs to the surrounding operation. This is an interface inventory observation. [B1]

## 9. TLS
No TLS integration is documented; the encoding is independent of transport encryption. [B1][R]

## 10. Interesting design decisions
`URL_SAFE` and `URL_SAFE_NO_PAD` make padding policy visible; configuration also controls padding acceptance and nonzero trailing bits. Optional padding and canonical unused-bit validation are distinct policies, so accepting raw input is insufficient evidence of canonicality. [B3][B2][R]

## 11. Decisions NOT to copy
Research recommendation: avoid exposing a general-purpose engine hierarchy merely to fix one alphabet. Keep invalid padding distinguishable; do not silently strip arbitrary input characters. Evidence: [B2][B3][B4].

## 12. Ideas fitting Mojo
Research candidates: a fixed-alphabet facade, explicit padding behavior, owned byte results and strict errors. Buffer-oriented variants remain a separate candidate. Evidence: [B1][B3][B4]. The Manager must verify Mojo feasibility in the local mojov1 buch; these are not claims about Mojo syntax.

## Sources
[S]: https://doc.rust-lang.org/std/index.html
[B1]: https://docs.rs/base64/latest/base64/
[B2]: https://github.com/marshallpierce/rust-base64
[B3]: https://docs.rs/base64/latest/base64/engine/general_purpose/index.html
[B4]: https://docs.rs/base64/0.22.1/base64/enum.DecodeError.html
[R]: https://www.rfc-editor.org/rfc/rfc4648.html
