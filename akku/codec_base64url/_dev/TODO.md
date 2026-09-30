# codec_base64url — TODO

- encode_into/decode_into — reuse caller-owned buffers — go.md §3, rust.md §3.
- Encoder/Decoder — incremental chunks with explicit finish — go.md §3, rust.md §3.
- encoded_len/decoded_len — predict output buffer sizes — c.md §3, go.md §3.
- is_valid — validate URL-safe input without allocating — python.md §3.
- encode_padded — emit URL-safe text with explicit padding — go.md §3, js_ts.md §12.
- decode_strict — reject non-zero unused trailing bits under an explicit canonical policy — go.md §10, rust.md §10.
