# codec_base64url — design record

## Purpose

Provide a small, byte-oriented Base64url convenience API using the existing sibling codec. Encoding uses the RFC 4648 URL alphabet without padding. Decoding accepts padded or unpadded URL-alphabet input with the sibling's tolerant trailing-bit policy.

## Status legend

`planned` means designed; `scaffolded` means a compile-ready stub; `tested` means a failing behavioral suite exists; `implemented` means that suite passes; `benchmarked` means measured performance evidence exists.

## Dependencies

`codec_base64url -> codec_base64`: reuse its public encoding and decoding functions, alphabet constants, padding policies and typed error. MojoAkku uses this sibling because the reviewed C/Python specialization pattern avoids duplicating the radix engine (c.md §10–12, python.md §10–12). Both libraries remain flat siblings. No private sibling module, Python runtime or native dependency is needed. Dependency acceptance: the sibling is in this repository under the same Apache-2.0 LICENSE, depends only on the Mojo standard library, and introduces no additional external package or native code. Reference libraries informed the design; no reference implementation code is copied or vendored. Reusing the established public engine avoids a second validation/security surface and keeps future fixes in one owner.

## Overview

Two function names, each overloaded for borrowed `StringSpan` and `Span[UInt8, _]`. `encode` returns an owned String; `decode` returns an owned List[UInt8] or raises the original sibling Base64Error. No configuration, stream state or resource lifecycle is exposed.

## Goals

- Make URL-alphabet, unpadded encoding a direct call.
- Accept both correctly padded and unpadded whole-input decoding.
- Reject standard-alphabet `+`/`/`, whitespace and other non-alphabet bytes.
- Preserve byte data, borrowed inputs, owned outputs and typed error fields.

## Non-Goals

No URI escaping, Unicode normalization, encryption, text decoding, hidden global state or native/Python interop. MojoAkku rejects Node's dual-alphabet acceptance because this namespace promises the distinct URL alphabet (js_ts.md §11). MojoAkku rejects Python's silent invalid-character discarding because malformed input must remain visible (python.md §11). No partial-parse success or C-style caller capacity/NUL contract (c.md §11).

Caller-buffer, streaming, size prediction, validity checks, padded encoding and strict canonical decoding are concrete deferred candidates in TODO.md. The initial decoder does not establish textual canonicality: its tolerant policy accepts non-zero unused trailing bits. No new strictness algorithm is added to this facade.

## Reference APIs

- libsodium's variant-specialized helpers: c.md §3, §10.
- cppcodec base64_url_unpadded accepts padded or unpadded decode: cpp.md §10.
- Go RawURLEncoding and separate Strict setting: go.md §3, §10.
- Rust URL_SAFE_NO_PAD and trailing-bit configuration: rust.md §3, §10.
- Python URL-safe helper reuse: python.md §10.
- Node unpadded URL-safe output: js_ts.md §3, §10.
- Mojo syntax: local mojov1 `keywords/import.md`, `functions/parameters-and-generics.md`, `memory/ownership-and-lifetimes.md`, `errors/raising-and-propagation.md`.
- Delegated public contracts: codec_base64 encode.mojo, decode.mojo, alphabet.mojo, padding.mojo, padding_mode.mojo, whitespace.mojo and base64_error.mojo.

## Public API

1. `encode(input: StringSpan) -> String` and `encode(input: Span[UInt8, _]) -> String` — borrowed bytes to owned unpadded Base64url.
2. `decode(input: StringSpan) raises Base64Error -> List[UInt8]` and `decode(input: Span[UInt8, _]) raises Base64Error -> List[UInt8]` — whole-input URL-safe decode with optional padding.

Base64Error is the existing `akku.codec_base64.Base64Error` type, not a new facade type or public facade re-export. Callers can inspect the inferred caught error or explicitly import Base64Error and ErrorKind from the sibling. Only encode and decode are public facade entries.

## Error Surface

Encoding raises no recoverable data error. Decoding propagates the sibling Base64Error unchanged: INVALID_SYMBOL for non-alphabet bytes, INVALID_LENGTH for an impossible remainder, INVALID_PADDING for excessive, misplaced or inconsistent padding. Its `position` is a zero-based index in the original input. Failure produces no result List. The caller can correct input and retry; the facade holds no state. Recoverable allocation errors are not exposed by these delegated APIs.

## Conventions

Fixed alphabet `B64_URL`; encode fixes `Padding.OMITTED`; decode fixes `PaddingMode.TOLERANT` and `Whitespace.REJECT`. Thus `encode("f") == "Zg"`, both `decode("Zg")` and `decode("Zg==")` yield byte 102, and `decode("Zh")` also yields byte 102 because unused trailing bits are not validated under TOLERANT. `decode("Z")` fails. URL-safe does not mean suitable for every protocol; protocols requiring canonical/padded text must choose the sibling's explicit policies or validate separately.

## Ownership and Lifecycle

Input is borrowed read-only, never consumed or mutated. StringSpan is processed as its existing bytes without normalization; Span accepts arbitrary binary bytes including zero and values above 127. Each successful call returns freshly owned output independent of input lifetime. Empty input gives an empty output. Pure synchronous in-memory transformation: EOF, EINTR, EAGAIN, non-blocking behavior, timeout, descriptor close/shutdown and in-flight operations are not applicable. There are no stream handles to finish or close.

## Open Questions

None. The user explicitly waived the Phase 3 API presentation/approval gate for this session on 2026-10-01; all other workflow phases remain required.

## encode

Status: planned

Signature:
```mojo
def encode(input: StringSpan) -> String
def encode(input: Span[UInt8, _]) -> String
```

Semantics: Borrow all input bytes read-only and encode the complete value with B64_URL and OMITTED padding. No UTF-8 conversion/normalization is performed. Return a newly owned String containing no `=`; empty input returns empty String. No I/O or stream lifecycle.

Errors: none — no recoverable data errors for any input.

Tests: empty input; RFC text vectors; URL-specific binary symbols; both overloads; all byte values; borrowed inputs and independent output.

Implementation status: not implemented

Rationale: MojoAkku uses `encode` because the sibling, cppcodec and Rust share this simple operation name (cpp.md §3, rust.md §3). MojoAkku uses fixed unpadded output because Node and Go expose this explicit raw URL convention (js_ts.md §10, go.md §3). MojoAkku uses owned String output and borrowed input because they match the sibling and avoid C buffer capacity contracts (cpp.md §5, c.md §11).

## decode

Status: planned

Signature:
```mojo
def decode(input: StringSpan) raises Base64Error -> List[UInt8]
def decode(input: Span[UInt8, _]) raises Base64Error -> List[UInt8]
```

Semantics: Borrow complete input read-only, decode B64_URL under TOLERANT/REJECT, return newly owned binary bytes. Empty input returns empty List. Padded/unpadded final quanta are accepted; present padding must have the exact count, appear only at the end, and have no symbol following it. Non-zero unused trailing bits are accepted. Reject `+`, `/`, all whitespace and every other non-alphabet byte. A single-symbol remainder is impossible. Do not interpret result as Unicode. No result is produced on failure; no I/O or stream lifecycle.

Errors: propagate sibling Base64Error unchanged with INVALID_SYMBOL, INVALID_LENGTH or INVALID_PADDING and original zero-based position. All are recoverable input errors; correct input and call again.

Tests: empty input; padded/unpadded vectors; URL-specific binary symbols; both overloads; borrowed inputs and independent result; non-zero trailing bits; standard alphabet rejection; whitespace rejection; all three error kinds and positions; atomic failure.

Implementation status: not implemented

Rationale: MojoAkku uses `decode` because cppcodec, Rust and the sibling use that operation name (cpp.md §3, rust.md §3). MojoAkku uses TOLERANT to support its unpadded encoder and correctly padded external input without a second engine (cpp.md §10). MojoAkku states trailing-bit tolerance explicitly because raw syntax and canonicality are distinct (go.md §10, rust.md §10). MojoAkku uses typed sibling errors because explicit `raises Base64Error` preserves structured fields without a wrapper hierarchy (python.md §12, js_ts.md §12; local buch raising-and-propagation.md).
