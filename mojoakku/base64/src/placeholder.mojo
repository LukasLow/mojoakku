# MojoAkku base64 — private implementation area marker.
#
# The real private logic lives in `engine.mojo` in this directory: the shared
# encode/decode state machine, alphabet tables and length functions. The public
# stubs delegate from `api/`.
#
# This file carries no logic; it only marks the `src/` directory. See
# `engine.mojo` for the implementation.
