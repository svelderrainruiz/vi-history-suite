# Install

## Current Public Release State

No public `vi-history-suite` release has been published from this repository yet.

When public releases begin, this page will document:
- the current released version
- the release source
- the supported installation path
- upgrade guidance

## Planned Install Surfaces

- VS Code Marketplace
- GitHub Releases with versioned `.vsix` artifacts

## Planned VS Code CLI Verification

The VS Code CLI is expected to be part of the public install and support workflow.

Examples:

```bash
code --install-extension vi-history-suite-<version>.vsix
code --install-extension vi-history-suite-<version>.vsix --force
code --list-extensions --show-versions
```

## Planned Trust Model

The extension is designed for use inside trusted Git repositories containing eligible LabVIEW VI files.

## Planned Product Surfaces

- `VI History` context-menu entry on eligible `.vi` files
- retained comparison report generation and refresh
- multi-report dashboard review
- bundled in-product documentation
- separate decision-record retention
