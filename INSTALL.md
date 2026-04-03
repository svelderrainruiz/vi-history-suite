# Install

## Current Public Release State

The first immutable release has been ingested into this public facade repo:

- release tag: `v0.2.0`
- package version: `0.2.0`
- commit: `3fcd02c398fe162480e9fdb0bfc432277302fd5f`
- exact VSIX: `vi-history-suite-0.2.0.vsix`
- SHA-256: `dd9585dbd684939ce71eeed01ca435685bb8da305b601e4d2bde15dfb54c4cf3`

Current limitation:

- a public GitHub release artifact has not been published here yet
- the authoritative release still lives on the private GitLab control plane
- the public installer lane must consume the immutable contract in `releases/v0.2.0/`

## Planned Install Surfaces

- VS Code Marketplace
- GitHub Releases with versioned `.vsix` artifacts
- GitHub Releases with a Windows installer built from an immutable released `.vsix`

Until a public GitHub release exists, treat this repo as the public
documentation and support surface, not yet as the public binary download
surface.

## Planned VS Code CLI Verification

The VS Code CLI is expected to be part of the public install and support workflow.

Examples for future public release use:

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

Authoritative installer input for the current release:

- [releases/v0.2.0/release-ingestion.json](releases/v0.2.0/release-ingestion.json)

## Planned Trust Model

The extension is designed for use inside trusted Git repositories containing eligible LabVIEW VI files.

## Planned Product Surfaces

- `VI History` context-menu entry on eligible `.vi` files
- retained comparison report generation and refresh
- multi-report dashboard review
- bundled in-product documentation
- separate decision-record retention
