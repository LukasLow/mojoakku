# net_socket research: Mojo

Read the local canonical buch under
`/Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/`:

- interop/calling-c.md: C aliases, external_call, pointer/out-parameter hazards,
  C struct layout, std.sys.info.platform_map.
- memory/ownership-and-lifetimes.md: ownership transfer and origins.
- types/structs.md: lifecycle methods and move-only owned resources.
- types/pointers-and-references.md: caller-owned buffers and pointer lifetime.
- errors/error-model.md: typed raises and error propagation.
- stdlib/overview.md: no native socket API; thin libc boundary required.

Mojo research is supplied by these pages, not reconstructed from other languages.
ABI contracts must additionally be checked against the target's native headers.
