# codec_base64url research: C++

## 1. Standard library support
The current C++ library roster supplies no Base64 codec; checked against the library overview, excluding third-party extensions. [Standard]

## 2. Relevant community libraries
cppcodec is a header-only C++11 codec project in the tplgy repository. Its license credits Topology Inc., Jakob Petsovits and contributors; MIT. Its checked-in tests establish a test corpus, not an independent maturity certification. [Project] [License]

## 3. Exposed APIs
`base64_url` and `base64_url_unpadded` expose encode/decode, caller-container/buffer overloads, `encoded_size` and `decoded_max_size`. [Project]

## 4. Error representation
Malformed input throws `cppcodec::parse_error`; insufficient raw output capacity aborts. Container allocation can also throw. [Project]

## 5. Ownership semantics
Convenient calls return owned string/vector results. Other overloads reuse caller containers or raw storage; input is read through const references/pointers. [Project]

## 6. Blocking / non-blocking
Inference: the documented value-returning buffer APIs are synchronous, without async handles. [Project]

## 7. IPv4 / IPv6
Not applicable: the codec operates on octets, independent of address family. [RFC §4–5]

## 8. Timeouts
No timeout/cancellation argument is exposed in the documented codec API. [Project]

## 9. TLS
Not applicable: Base64url is a text representation, not a secure transport protocol. [RFC §5, §12]

## 10. Interesting design decisions
Padded URL mode requires padding; unpadded mode omits it on encode but accepts both forms on decode. [Project]
Research observation: RFC 4648 §5 makes the alphabet distinction explicit, while §3.2 permits padding omission only under a referring specification. A convenience API therefore needs an explicit policy. [RFC]

## 11. Decisions NOT to copy
Research recommendation: avoid abort-on-capacity-error overloads for a minimal owned-result API; their safety burden is unnecessary here. [Project]
Research recommendation: don't silently conflate URL-safe encoding with arbitrary URI escaping; the pad character may require percent encoding in a URI. [RFC §5]

## 12. Ideas fitting Mojo
Candidate only: a variant-focused namespace can delegate to the sibling codec, preserving typed errors rather than copying C++ exception semantics. Borrowed input and owned output already match the sibling contract. [Sibling] [Buch errors] [Buch ownership]

## Sources
- [Standard] https://eel.is/c++draft/library.
- [Project] https://github.com/tplgy/cppcodec (accessed 2026-10-01).
- [License] https://github.com/tplgy/cppcodec/blob/master/LICENSE.
- [RFC] https://datatracker.ietf.org/doc/html/rfc4648.
- [Sibling] akku/codec_base64/__init__.mojo:26–84.
- [Buch errors] /Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/errors/raising-and-propagation.md#catching-typed-errors.
- [Buch ownership] /Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/memory/ownership-and-lifetimes.md (sections Argument conventions and Transfer).
