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
- current public state: the release kit is the active publication surface and the exact VSIX remains the authoritative payload identity

Machine-readable public release/setup surfaces:

- [releases/v0.2.0/public-setup-manifest.json](releases/v0.2.0/public-setup-manifest.json)
- [releases/v0.2.0/release-ingestion.json](releases/v0.2.0/release-ingestion.json)
- [releases/v0.2.0/README.md](releases/v0.2.0/README.md)

Scaffold status:

- immutable release contract is retained here for `v0.2.0`
- direct-release setup manifest and Windows/Linux setup adapters are now scaffolded as the primary public setup surface
- a pinned `ni/labview-icon-editor` fixture bundle with commit history is generated for the release kit
- Docker is no longer part of the default public setup path
- legacy installer assets are retired from the active public toolchain
- pinned Visual Studio Code and Git prerequisite identities remain in the public setup contracts
- Windows 11 acceptance harness and manual checklist are scaffolded
- public binary publication is complete through the GitHub workflow
- automated Windows 11 host-machine proof is the active acceptance lane
- future reproducible automation is intended to move to a published container image

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
- [Windows 11 Acceptance Scaffold](acceptance/windows11/README.md)
- [Scaffold Validation Script](scripts/Validate-PublicFacadeScaffold.ps1)
- [Publish Public Release Kit Workflow](.github/workflows/publish-public-release-kit.yml)
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
- `release-ingestion.json` is retained as a bounded public release-provenance ledger
- the GitHub workflow now publishes the release kit only and deletes retired legacy installer assets when present
- the current Windows 11 host machine is the active installed-user proof surface
- a future published container image is the preferred reproducible automation follow-on
- public GitHub issues are supplemental field feedback, not the proof gate

Current scaffold entrypoints:

- build validation: `pwsh -File scripts/Validate-PublicFacadeScaffold.ps1`
- build public setup assets: `pwsh -File scripts/Build-PublicSetupAssets.ps1`
- Windows setup adapter: `pwsh -File setup/windows/Setup-VIHistorySuite.ps1`
- Linux setup adapter: `bash setup/linux/setup-vi-history-suite.sh`
- sync pinned fixture bundle: `pwsh -File scripts/Sync-PinnedFixtureBundle.ps1`
- Windows 11 acceptance: `pwsh -File acceptance/windows11/Invoke-Windows11Acceptance.ps1 -ExecutionTarget host-machine`
- Windows 11 human gate: `pwsh -File acceptance/windows11/Invoke-Windows11HumanGate.ps1 -Action prepare|complete`
- publish workflow: `.github/workflows/publish-public-release-kit.yml`
