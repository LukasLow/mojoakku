# Changelog

All notable changes to MojoAkku are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions stay on `0.x.y`; major is never bumped.

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
