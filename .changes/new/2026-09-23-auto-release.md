NEW: main-push workflow — auto-release: on a push to main with a pending .changes/new file, task ci runs, then the changelog is updated and a 0.x.y tag is created.
INTERNAL: release:prepare task — computes the next 0.x.y, folds .changes/new into CHANGELOG.md and moves the released files to .changes/archive/<tag>/.
NEW: pull-request-check workflow — enforces exactly one .changes/new file per PR and validates its category lines.
