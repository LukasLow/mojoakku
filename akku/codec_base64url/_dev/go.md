# codec_base64url research: Go

## 1. Standard library support
`encoding/base64` supplies padded `URLEncoding` and unpadded `RawURLEncoding`. [G1]

## 2. Relevant community libraries
Segment's `segmentio/asm/base64` offers CPU-optimized implementations; repository owner Segment, MIT license. Its published module has tests and tagged releases; this demonstrates maintained artifacts, not a maintenance guarantee. [G2][G3]

## 3. Exposed APIs
`Encoding` has encode/decode, string, append and length methods; `WithPadding`, `Strict`, `NewEncoder` and `NewDecoder` provide configuration and streaming. [G1]
The Segment package exports corresponding encoding constants and buffer operations. [G2]

## 4. Error representation
Decoding returns an error and may return partial output; invalid input uses `CorruptInputError`. [G1]

## 5. Ownership semantics
Buffer APIs write caller-provided slices; `EncodeToString` allocates output. The stream encoder retains its writer and requires `Close` to flush its final block. [G4]

## 6. Blocking / non-blocking
In-memory calls are synchronous loops. Stream calls invoke the supplied reader/writer; there is no independent asynchronous codec scheduler. [G4]

## 7. IPv4 / IPv6
Not applicable: byte encoding is independent of address families; RFC 4648 defines alphabets, not IP transport. [R]

## 8. Timeouts
No codec timeout argument; streaming delegates I/O to reader/writer. [G4]

## 9. TLS
No integrated TLS; this package encodes bytes, whereas TLS belongs to a separate transport layer. [G4][R]

## 10. Interesting design decisions
Padding and alphabet are separate choices. Strict decoding verifies unused bits, but still ignores CR/LF. Unpadded syntax does not itself establish zero unused bits: raw Go decoding needs the separate `Strict` setting. [G1][G4]

## 11. Decisions NOT to copy
Research recommendation: do not equate Go's `Strict` with complete textual canonicality: newline acceptance remains. Avoid mandatory stream finalization for a small in-memory facade. Evidence: [G1][G4].

## 12. Ideas fitting Mojo
Research candidate, not a design decision: expose simple owned-result encode/decode operations and an explicit padding choice; caller-buffer and stream variants could be deferred. Evidence: [G1][G4]. Mojo syntax, ownership and error feasibility must be checked by the Manager in the local mojov1 buch.

## Sources
[G1]: https://pkg.go.dev/encoding/base64
[G2]: https://pkg.go.dev/github.com/segmentio/asm/base64
[G3]: https://github.com/segmentio/asm
[G4]: https://raw.githubusercontent.com/golang/go/master/src/encoding/base64/base64.go
[R]: https://www.rfc-editor.org/rfc/rfc4648.html
