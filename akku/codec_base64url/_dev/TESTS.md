# codec_base64url — behavioral test evidence

## Concern map

- encode: `test_codec_base64url_encode.mojo` — 6 cases, both overloads, empty/RFC/binary vectors, all 256 octets against a fixed independent Python stdlib fixture, borrowed input and independent owned output.
- decode: `test_codec_base64url_decode.mojo` — 6 cases, both overloads, empty/padded/unpadded URL vectors, fixed all-octet fixture, borrowed input and independent owned output.
- policy: `test_codec_base64url_policy.mojo` — 7 cases, tolerant unused bits, rejected standard alphabet/whitespace/invalid bytes, all three typed error kinds and original positions, atomic failure/retry.

No EOF, interruption, would-block, timeout, descriptor close or stream finalization: these are pure synchronous in-memory calls.

## Failing baseline

Command: `smd -t task codec_base64url::test` (equivalent container root `task codec_base64url::test`). Raw output: `raw_red.log`. Exit 201 at the first test program, aborting with the exact scaffold message. The test runner stops on first program failure.

Each program was also run independently with `smd -t mojo run -I . akku/codec_base64url/_tests/<filename>`; raw outputs `raw_red_encode.log`, `raw_red_decode.log`, `raw_red_policy.log`. Each compiled and exited 1 at its first stub invocation with `MojoAkku: this API is not yet implemented`.

Authored total: 19 named test cases in 3 programs. Observed baseline: 3/3 independently run programs abort, 0 programs pass. An abort terminates its suite before later assertions; this is not a claim that all 19 cases were individually executed or failed.

The fixed binary oracle was generated once using Python stdlib `base64.urlsafe_b64encode(bytes(range(256))).decode().rstrip("=")`; tests embed that literal and never derive expectations using the sibling codec. Byte conversion helpers construct input/expected containers only.
