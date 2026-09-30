# codec_base64url — behavioral test evidence

## Concern map

- encode: `test_codec_base64url_encode.mojo` — 6 cases, both overloads, empty/RFC/binary vectors, all 256 octets and distinct precomposed/decomposed UTF-8 text against fixed independent Python stdlib fixtures, borrowed input and independent owned output.
- decode: `test_codec_base64url_decode.mojo` — 6 cases, both overloads, empty/padded/unpadded URL vectors, fixed all-octet fixture, borrowed input and independent owned output.
- policy: `test_codec_base64url_policy.mojo` — 7 cases, tolerant unused bits, rejected standard alphabet/whitespace/invalid bytes, all three typed error kinds and original positions, terminal-padding precedence at offset 4, atomic failure/retry.

No EOF, interruption, would-block, timeout, descriptor close or stream finalization: these are pure synchronous in-memory calls.

## Failing baseline

Command: `smd -t task codec_base64url::test` (equivalent container root `task codec_base64url::test`). Raw output: `raw_red.log`. Exit 201 at the first test program, aborting with the exact scaffold message. The test runner stops on first program failure.

Each program was also run independently with `smd -t mojo run -I . akku/codec_base64url/_tests/<filename>`; raw outputs `raw_red_encode.log`, `raw_red_decode.log`, `raw_red_policy.log`. Each compiled and exited 1 at its first stub invocation with `MojoAkku: this API is not yet implemented`.

Authored total: 19 named test cases in 3 programs. Observed baseline: 3/3 independently run programs abort, 0 programs pass. An abort terminates its suite before later assertions; this is not a claim that all 19 cases were individually executed or failed.

The fixed binary oracle was generated once using Python stdlib `base64.urlsafe_b64encode(bytes(range(256))).decode().rstrip("=")`; tests embed that literal and never derive expectations using the sibling codec. Byte conversion helpers construct input/expected containers only.

## Phase 10 review rework

A public sibling probe established terminal-padding precedence: `Zg===`, `Zg==Zg`, `Zg== ` and `Zg==+` all raise INVALID_PADDING at 4. Refined the inline/design contract and corrected these expectations before tests freeze. Added precomposed/decomposed UTF-8 oracles within an existing named encode case. Repeated the exact aggregate and all three independent commands: unchanged abort stubs, aggregate exit 201, each program exit 1, 19 authored cases, 3/3 aborted programs. Raw logs above contain this repeated baseline.
