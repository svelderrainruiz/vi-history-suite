# VI History Suite

Public support and release surface for the `vi-history-suite` Visual Studio Code extension.

This repository is intended for:
- public issue intake
- public install and support guidance
- public release notes and VSIX distribution links
- public installer and Windows acceptance scaffolding

This repository is not the private engineering source of truth. Internal source, governed requirements, design gates, and retained engineering evidence stay on the private GitLab control plane.

## Current Status

An immutable `vi-history-suite` release now exists:

- release tag: `v0.2.0`
- package version: `0.2.0`
- authoritative VSIX: `vi-history-suite-0.2.0.vsix`
- SHA-256: `dd9585dbd684939ce71eeed01ca435685bb8da305b601e4d2bde15dfb54c4cf3`
- public GitHub release: `https://github.com/svelderrainruiz/vi-history-suite/releases/tag/v0.2.0`
- Windows installer asset: `vi-history-suite-setup-0.2.0.exe`
- installer SHA-256: `b1d057b5fd4ca4ba5076e49217ebc28168d4984a28e0b6ecb08ec738044c06e0`
- current public state: the exact VSIX and Windows installer are published through the GitHub workflow on `2026-04-04`

Machine-readable public ingestion contract:

- [releases/v0.2.0/release-ingestion.json](releases/v0.2.0/release-ingestion.json)
- [releases/v0.2.0/README.md](releases/v0.2.0/README.md)

Scaffold status:

- immutable release contract is retained here for `v0.2.0`
- pinned NSIS 3.11 bootstrap reference is retained in the release/build contract
- pinned Visual Studio Code, Git, and Docker Desktop bootstrap references are
  retained for fresh Windows 11 VM proof
- pinned Docker Desktop bootstrap and LabVIEW Windows container image identities
  are retained for the Windows container proof lane
- a pinned `ni/labview-icon-editor` Git fixture bundle with commit history is
  generated for the installer harness
- Windows Docker builder entrypoint is scaffolded
- NSIS installer entrypoint is scaffolded
- Windows 11 acceptance harness and manual checklist are scaffolded
- public binary publication is complete through the GitHub workflow
- executed Windows 11 proof remains open

## Planned User Flows

- Install a released `.vsix` from GitHub Releases or the VS Code Marketplace.
- Open a trusted Git repository in VS Code.
- Right-click an eligible LabVIEW VI and use `VI History`.
- Generate or open retained comparison reports.
- Open the review dashboard for multi-commit VI review.
- Open bundled documentation from inside the extension.

## Documentation

- [Install](INSTALL.md)
- [Support](SUPPORT.md)
- [Release Ingestion](releases/v0.2.0/README.md)
- [Windows Installer Build Scaffold](docker/windows-installer-builder/README.md)
- [NSIS Installer Scaffold](installer/nsis/README.md)
- [Windows 11 Acceptance Scaffold](acceptance/windows11/README.md)
- [Scaffold Validation Script](scripts/Validate-PublicFacadeScaffold.ps1)
- [Publish Windows Installer Workflow](.github/workflows/publish-windows-installer.yml)
- [Stage NSIS Bootstrap](docker/windows-installer-builder/Stage-NsisBootstrap.ps1)
- [Stage Visual Studio Code Bootstrap](docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1)
- [Stage Git Bootstrap](docker/windows-installer-builder/Stage-GitBootstrap.ps1)
- [Stage Docker Desktop Bootstrap](docker/windows-installer-builder/Stage-DockerDesktopBootstrap.ps1)
- [Sync Pinned Fixture Bundle](scripts/Sync-PinnedFixtureBundle.ps1)

## Public Support Scope

Use this repository for:
- bugs in the installed extension experience
- product feedback
- documentation feedback
- release-facing requests

Do not use this repository to request private engineering artifacts, internal gate evidence, or private GitLab access.

## Public Installer Direction

This facade repo is the intended public surface for:
- Windows installer artifacts built from immutable released VSIX packages
- pinned prerequisite bootstrap installers for fresh-machine proof
- a pinned Git fixture bundle and materialized proof workspace for
  `ni/labview-icon-editor`
- release-facing documentation
- installed-user acceptance guidance

Trust boundary:
- private GitLab release remains the engineering source of truth for the exact released VSIX
- this public repo is the consumer-facing distribution and support facade
- the GitHub workflow is the active installer build and publication surface
- the Windows builder Docker scaffold is retained for future builder-image hardening
- a fresh Windows 11 VM is the installed-user proof surface

Current scaffold entrypoints:

- build validation: `pwsh -File scripts/Validate-PublicFacadeScaffold.ps1`
- publish workflow: `.github/workflows/publish-windows-installer.yml`
- stage NSIS bootstrap: `pwsh -File docker/windows-installer-builder/Stage-NsisBootstrap.ps1`
- stage Visual Studio Code bootstrap: `pwsh -File docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1`
- stage Git bootstrap: `pwsh -File docker/windows-installer-builder/Stage-GitBootstrap.ps1`
- stage Docker Desktop bootstrap: `pwsh -File docker/windows-installer-builder/Stage-DockerDesktopBootstrap.ps1`
- sync pinned fixture bundle: `pwsh -File scripts/Sync-PinnedFixtureBundle.ps1`
- Windows installer build: `pwsh -File docker/windows-installer-builder/Invoke-InstallerBuild.ps1`
- Windows 11 acceptance: `pwsh -File acceptance/windows11/Invoke-Windows11Acceptance.ps1`
