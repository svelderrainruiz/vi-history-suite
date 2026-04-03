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
- GitHub Releases with a Windows installer built from an immutable released `.vsix`

## Planned VS Code CLI Verification

The VS Code CLI is expected to be part of the public install and support workflow.

Examples:

```bash
code --install-extension vi-history-suite-<version>.vsix
code --install-extension vi-history-suite-<version>.vsix --force
code --list-extensions --show-versions
```

## Planned Windows Installer Direction

The first public Windows installer lane is planned to:
- consume only immutable released VSIX artifacts
- be built through a Windows Docker + NSIS build lane
- assume Visual Studio Code is already installed on the acceptance VM unless later requirements say otherwise

The installer build lane is not the installed-user proof lane. Installed-user proof is planned for a separate fresh Windows 11 VM flow.

## Planned Trust Model

The extension is designed for use inside trusted Git repositories containing eligible LabVIEW VI files.

## Planned Product Surfaces

- `VI History` context-menu entry on eligible `.vi` files
- retained comparison report generation and refresh
- multi-report dashboard review
- bundled in-product documentation
- separate decision-record retention
