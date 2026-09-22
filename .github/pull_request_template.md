# Pull request

## What does this change?

<!-- One or two sentences. Name the affected library, e.g. mojoakku/base64. -->

## Checklist

- [ ] `task ci` passes locally (it auto-discovers and tests every library).
- [ ] A `.changes/new/<yyyy-mm-dd>-<slug>.md` file is added, with one category line
      per change (`NEW:` / `FIX:` / `SECURITY:` / `PERFORMANCE:` / `BREAKING:` /
      `DEPRECATED:` / `INTERNAL:` / `DOCS:` — see `.changes/README.md`).
- [ ] The affected library's inline `# API-DOCS` blocks are current.
- [ ] No version was set by hand; the next tag is derived from `.changes/`
      (`task changes:version`, always `0.x.y`, never major).
