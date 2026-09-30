# codec_base64url research: Python

Reference snapshot: Python 3.14 documentation; researched 2026-10-01.

## 1. Standard library support

`base64` supplies `urlsafe_b64encode` and `urlsafe_b64decode`; its modern interface operates on byte buffers rather than files. [P1]

## 2. Relevant community libraries

`pybase64`, maintained in mayeut's repository, wraps libbase64 and follows the stdlib modern interface. Its repository reports BSD-2-Clause licensing and publishes releases, tests and benchmarks; this is evidence of established implementation activity, not an independent correctness audit. [P3]

## 3. Exposed APIs

`urlsafe_b64encode(s)` returns bytes; its output may contain padding. `urlsafe_b64decode(s)` accepts byte-like input or ASCII text. General `b64encode(s, altchars)` and `b64decode(s, altchars, validate=False)` permit alphabet configuration and explicit validation. [P1]

## 4. Error representation

Malformed padding causes `binascii.Error`. General decoding with `validate=True` rejects non-alphabet characters; the default discards them. Bad alternative alphabet arguments can cause `ValueError` or `TypeError`. [P1]
The URL-safe helper translates `-`/`_` and delegates to general decoding without exposing `validate`; it is not an independent strict validator. [P2]

## 5. Ownership semantics

The helper returns a resulting bytes object instead of mutating a destination supplied by the caller; its implementation computes/translates results and returns them. The input is not consumed. [P2]

## 6. Blocking / non-blocking

These helpers are ordinary direct function calls, with no awaitable, callback or scheduler parameter. They compute over the supplied buffer; concurrency belongs to callers. [P2]

## 7. IPv4 / IPv6

Not applicable to this codec: its inputs are binary data/ASCII encoding, with no address-family parameter. It can encode bytes representing either family without understanding them. [P1; inference from the input contract]

## 8. Timeouts

No timeout or cancellation argument exists on these helper signatures; unlike the separate legacy file API they do not read a file handle. [P1]

## 9. TLS

TLS is outside this byte transformation. Encoding alone supplies neither confidentiality nor encryption. [R1 §12]

## 10. Interesting design decisions

The URL-safe helpers reuse the general codec by translating only the alphabet, making the distinction small and explicit. [P2]
RFC 4648 distinguishes URL-safe alphabet selection from padding policy: padding normally remains required unless the referring specification permits omission. [R1 §§3.2,5]

## 11. Decisions NOT to copy

Research recommendation: do not silently discard invalid characters merely because Python's general decoder defaults to doing so; RFC 4648 requires rejection unless a referring specification permits another policy. [P1; R1 §3.3]
Do not interpret URL-safe as encrypted or necessarily unpadded. [R1 §§3.2,5,12]

## 12. Ideas fitting Mojo

Candidate, not a design commitment: a fixed-alphabet convenience wrapper with owned return values and borrowed input. Mojo supports read-only borrowing and ownership transfer; explicit `raises ErrorType` preserves the typed error interface of a delegated decoder. [M1; M2]
Potential later candidate: destination-buffer decoding, inspired by separating byte data from text without demanding a Python-specific exception hierarchy. [P1; research proposal]

## Sources

- [P1] https://docs.python.org/3.14/library/base64.html
- [P2] https://github.com/python/cpython/blob/3.14/Lib/base64.py (`urlsafe_b64encode`, `urlsafe_b64decode`)
- [P3] https://github.com/mayeut/pybase64
- [R1] https://www.rfc-editor.org/rfc/rfc4648.html
- [M1] Local mojov1 buch: `/Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/memory/ownership-and-lifetimes.md`, Borrowing / Transfer sections.
- [M2] Local mojov1 buch: `/Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/errors/raising-and-propagation.md`, Catching typed errors / Propagation rules.
