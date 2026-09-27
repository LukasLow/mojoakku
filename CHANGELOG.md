# Changelog

All notable changes to MojoAkku are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions stay on `0.x.y`; major is never bumped.

## v0.3.0 - 2026-09-27

### Added

- io — byte stream library (Phase 13 GO). 15-entry public API: a closed IoErrorKind discriminant; IoError (kind/op/detail); ReadResult {count, eof} as explicit EOF (no -1/0/null sentinel); SeekFrom; the Reader and ByteWriter traits (one required buffer method + provided helpers) and the optional Seeker trait; and the adapters Cursor, SpanCursor, BufferedReader, BufferedWriter (explicit fallible flush/close), LimitReader, TeeReader, MultiReader, plus the free copy pump. Read targets are MutSpan[UInt8, _], write inputs Span[UInt8, _] (borrowed); streams own their state; one typed error; blocking core (no async). Fills the stdlib's missing read side (the stdlib has Writer/Writable but no Reader trait). 75 tests, 0 failing; compile gate green; missingMojo clean.

### Changed

- workflows — align phases 1-8 with the canonical `_dev/` layout (research in `_dev/`, persistent `_dev/DESIGN.md`, no `.research/`, no temporary `<LIB>_DESIGN.md`).
- workflows — PR-only model: one long-lived branch `<lib>-library` per library and exactly one pull request per library; `main` is never written directly. Phase 1 creates the branch, every phase commits to it, CreatePR opens the single PR after Phase 13.
- workflows — fix the Phase 7/8 wording: the inline `# API-DOCS` blocks use the `LibraryLayout.md` end-user field set (summary, Signature, What it does, Returns, Errors, Example), NOT the seven design fields (those stay in `_dev/DESIGN.md`).

## v0.2.0 - 2026-09-26

### Changed

- document the accumulate-into-one-release behaviour for several pending .changes/new files (merge timing, no double tags).
- add the MissingMojo version-stamped workaround ledger — `task missingMojo` scanner (root Taskfile), the `.agents/workflows/MissingMojo.md` convention, and the FFI triage rule; wired into `Release.md`.
- upgrade to Mojo 1.1.0 — pixi pin `mojo = "~=1.1.0"` and the resolved lock now select mojo 1.1.0; the base64 suite passes on 1.1.0 and `task missingMojo -- check` is clean.

### Added

- base64 — first MojoAkku library, 15-entry public API (RFC 4648 base64/base64url/base32/base32hex/base16) with compile-time alphabet/padding/whitespace policies, a typed Base64Error with kind+position, allocation-free is_valid and encoded_len/decoded_len, and streaming Encoder/Decoder with a mandatory finish. 132 tests, 0 failing. Phase 13 final review: GO.

## v0.1.0 - 2026-09-22

### Added

- main-push workflow — auto-release: on a push to main with a pending .changes/new file, task ci runs, then the changelog is updated and a 0.x.y tag is created.
- pull-request-check workflow — enforces exactly one .changes/new file per PR and validates its category lines.
- base64 — 15-entry public API (encode/decode/encode_into/decode_into/encoded_len/decoded_len/is_valid/Encoder/Decoder + Alphabet/Padding/PaddingMode/Whitespace/ErrorKind/Base64Error), covering base64, base64url, base32, base32hex and base16.

### Changed

- release:prepare task — computes the next 0.x.y, folds .changes/new into CHANGELOG.md and moves the released files to .changes/archive/<tag>/.
- new library layout and workflow rework (one file per API entry, inline API docs, _internal/ for shared code, _dev/ for research and design record).
- root task test / task ci auto-discover every library; .changes/ drives the changelog and the 0.x.y tag.
- CI — bump actions/checkout to v5 and prefix-dev/setup-pixi to v0.10.2 (Node 24).

### Fixed

- base64 — streaming decoder now accepts a padding run that crosses a chunk boundary; only end of stream rejects an incomplete run (INVALID_PADDING).
- CI — install task (go-task) via pixi and run exactly `task ci`; the GitHub runner had no task binary.

## [Unreleased]

### Added

- Initial commit: the project map (`AGENTS.md`), the process in
  `.agents/workflows/`, the `_todos/` library catalogue and the `Taskfile.yml`.
- `README.md` describing what MojoAkku is, the workflow entry point and the
  task commands.
- `TODO.md` listing the deferred work (test infrastructure and tests, git tags
  and CI, automatic upload to prefix.dev).
- `LICENSE` containing the full, unmodified Apache License 2.0 text.
