# VI History Suite

Public support and release surface for the `vi-history-suite` Visual Studio Code extension.

This repository is intended for:
- public issue intake
- public install and support guidance
- public release notes and VSIX distribution links
- public setup adapters, fixture assets, and Windows acceptance scaffolding

This repository is not a publication surface for private requirements, design
gates, or retained engineering evidence. It exists only for public release,
setup, and support material, while private engineering control stays on the
private GitLab side.

## Current Status

An immutable `vi-history-suite` release now exists:

- release tag: `v0.2.0`
- package version: `0.2.0`
- authoritative VSIX: `vi-history-suite-0.2.0.vsix`
- SHA-256: `dd9585dbd684939ce71eeed01ca435685bb8da305b601e4d2bde15dfb54c4cf3`
- public GitHub release: `https://github.com/svelderrainruiz/vi-history-suite/releases/tag/v0.2.0`
- legacy Windows installer asset: `vi-history-suite-setup-0.2.0.exe`
- legacy installer SHA-256: `fd66fa6dd3ef7d3e8f840f63dae172bff812c958224313531dcd051970961e72`
- current public state: the exact VSIX and legacy Windows installer are already published; the release-kit setup assets are now staged here as the validated primary setup surface for the next publication run

Machine-readable public release/setup surfaces:

- [releases/v0.2.0/public-setup-manifest.json](releases/v0.2.0/public-setup-manifest.json)
- [releases/v0.2.0/release-ingestion.json](releases/v0.2.0/release-ingestion.json)
- [releases/v0.2.0/README.md](releases/v0.2.0/README.md)

Scaffold status:

- immutable release contract is retained here for `v0.2.0`
- direct-release setup manifest and Windows/Linux setup adapters are now scaffolded as the primary public setup surface
- a pinned `ni/labview-icon-editor` fixture bundle with commit history is generated for the release kit
- Docker is no longer part of the default public setup path
- legacy NSIS scaffolding is retained as an optional secondary wrapper path
- pinned NSIS 3.11 bootstrap reference is retained in the release/build contract
- pinned Visual Studio Code, Git, and Docker Desktop bootstrap references are
  retained only for legacy installer-wrapper work and future optional provider work
- Windows Docker builder entrypoint is retained as legacy scaffolding
- NSIS installer entrypoint is retained as legacy scaffolding
- Windows 11 acceptance harness and manual checklist are scaffolded
- public binary publication is complete through the GitHub workflow
- executed Windows 11 host-machine proof remains open

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
- [Public Setup Surface](setup/README.md)
- [Release Ingestion](releases/v0.2.0/README.md)
- [Windows Installer Build Scaffold](docker/windows-installer-builder/README.md)
- [NSIS Installer Scaffold](installer/nsis/README.md)
- [Windows 11 Acceptance Scaffold](acceptance/windows11/README.md)
- [Scaffold Validation Script](scripts/Validate-PublicFacadeScaffold.ps1)
- [Publish Public Release Kit Workflow](.github/workflows/publish-windows-installer.yml)
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

## Public Setup Direction

This facade repo is the intended public surface for:
- exact released VSIX packages
- public setup manifest plus Windows and Linux setup adapters
- a pinned Git fixture bundle and materialized proof workspace for
  `ni/labview-icon-editor`
- release-facing documentation
- installed-user acceptance guidance

Trust boundary:
- private GitLab release remains the engineering source of truth for the exact released VSIX
- private requirements, design gates, and retained engineering evidence are intentionally not mirrored here
- this public repo is the consumer-facing distribution and support facade
- `public-setup-manifest.json` is the primary public release/setup manifest
- `release-ingestion.json` is retained only for legacy builder/installer scaffolding
- the GitHub workflow now treats the release kit as the primary publication surface and the installer path as optional legacy work
- the Windows builder Docker scaffold is retained only for legacy or future optional hardening work
- the current Windows 11 host machine is the active installed-user proof surface
- a future published container image is the preferred reproducible automation follow-on
- a fresh Windows 11 VM remains only optional replay evidence

Current scaffold entrypoints:

- build validation: `pwsh -File scripts/Validate-PublicFacadeScaffold.ps1`
- build public setup assets: `pwsh -File scripts/Build-PublicSetupAssets.ps1`
- Windows setup adapter: `pwsh -File setup/windows/Setup-VIHistorySuite.ps1`
- Linux setup adapter: `bash setup/linux/setup-vi-history-suite.sh`
- sync pinned fixture bundle: `pwsh -File scripts/Sync-PinnedFixtureBundle.ps1`
- Windows 11 acceptance: `pwsh -File acceptance/windows11/Invoke-Windows11Acceptance.ps1 -ExecutionTarget host-machine -SetupMode direct-release`
- publish workflow: `.github/workflows/publish-windows-installer.yml`
- legacy installer build: `pwsh -File docker/windows-installer-builder/Invoke-InstallerBuild.ps1`
