# codec_base64url research: JS/TS

Reference snapshot: Node.js Buffer documentation and js-base64 repository; researched 2026-10-01.

## 1. Standard library support

Node.js provides `Buffer` with `base64url`. Browser HTML provides ordinary-Base64 `btoa`/`atob`. TypeScript describes these Node/browser runtime APIs. [J1; J3; inference about the documented implementations]

## 2. Relevant community libraries

`js-base64`, maintained in dankogai's repository, is written in TypeScript with generated JavaScript distributions. Its repository shows release history, tests and BSD-3-Clause licensing; these are maturity signals rather than a correctness guarantee. [J2]

## 3. Exposed APIs

Node: `buffer.toString('base64url')` encodes without padding; `Buffer.from(text, 'base64url')` decodes and also accepts regular Base64. [J1]
js-base64: `encodeURI`, `encode(text, true)`, `fromUint8Array(bytes, true)`, `toUint8Array(text)`, `decode`, plus optional prototype-extension conveniences. Its `decode` produces UTF-8 text; `toUint8Array` is the binary alternative. [J2]

## 4. Error representation

Browser `btoa` rejects characters outside its byte-string range; `atob` throws `InvalidCharacterError` when forgiving Base64 decoding fails. [J3]
Node accepts both alphabets; no strict URL-only validation contract is documented. [J1]

## 5. Ownership semantics

`Buffer.from(string, encoding)` creates a new Buffer, potentially pooled. `toString` returns text; neither accepts a destination. [J1]
js-base64 also offers conversions to/from Uint8Array and distinguishes binary output from UTF-8 decoding. [J2]

## 6. Blocking / non-blocking

Conversions return directly, with no callback/Promise. [J1; inference from signatures]

## 7. IPv4 / IPv6

No address-family parameter exists; either family's bytes remain opaque. [J1; inference from contract]

## 8. Timeouts

The documented conversion signatures contain no timeout/cancellation parameter. [J1]

## 9. TLS

No TLS operation belongs to Base64url; it is a representation of bytes, not secrecy protection. [R1 §12]

## 10. Interesting design decisions

Node fixes the raw URL-safe output convention; Python's padded output therefore cannot be assumed universal. [J1; comparison with python.md §3]
js-base64 distinguishes text decoding from binary decoding explicitly; this avoids treating arbitrary bytes as valid UTF-8. [J2]

## 11. Decisions NOT to copy

Research recommendation: avoid accepting the standard alphabet through a URL-only API by accident. Node deliberately permits both, whereas RFC 4648 names Base64url as a distinct alphabet. [J1; R1 §5]
Avoid optional global/prototype extension as an import side effect: js-base64 exposes it separately; a small library can retain ordinary explicit entry points. [J2; research recommendation]

## 12. Ideas fitting Mojo

Candidate, not a design commitment: byte-oriented input and output, fixed URL-safe alphabet, and an explicit padding policy. RFC 4648 requires distinguishing alphabet from allowed padding omission. [R1 §§3.2,5]
Candidate: propagate the sibling decoder's typed error rather than erase it in a convenience wrapper. Mojo's typed `raises` and borrowed inputs support that boundary. [M1; M2]

## Sources

- [J1] https://nodejs.org/api/buffer.html (Buffers and character encodings; Buffer.from(string); buf.toString)
- [J2] https://github.com/dankogai/js-base64 (API synopsis, decoding warning, history, license)
- [J3] https://html.spec.whatwg.org/multipage/webappapis.html#base64-utility-methods
- [R1] https://www.rfc-editor.org/rfc/rfc4648.html
- [M1] Local mojov1 buch: `/Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/memory/ownership-and-lifetimes.md`, Borrowing.
- [M2] Local mojov1 buch: `/Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/errors/raising-and-propagation.md`, Propagation rules.
