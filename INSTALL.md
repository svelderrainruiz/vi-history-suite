# Install

## Current Public Release State

The first immutable release has been ingested into this public facade repo:

- release tag: `v0.2.0`
- package version: `0.2.0`
- commit: `3fcd02c398fe162480e9fdb0bfc432277302fd5f`
- exact VSIX: `vi-history-suite-0.2.0.vsix`
- SHA-256: `dd9585dbd684939ce71eeed01ca435685bb8da305b601e4d2bde15dfb54c4cf3`
- GitHub release: `https://github.com/svelderrainruiz/vi-history-suite/releases/tag/v0.2.0`
- legacy Windows installer: `vi-history-suite-setup-0.2.0.exe`
- legacy installer SHA-256: `fd66fa6dd3ef7d3e8f840f63dae172bff812c958224313531dcd051970961e72`

Current state:

- the authoritative release still lives on the private GitLab release surface
- private requirements and design-gate artifacts are not published in this repo
- the public GitHub release currently publishes the exact VSIX and the legacy workflow-built Windows installer
- the public release-kit setup lane is now scaffolded in this repo and is intended to become the primary publication surface
- Windows 11 host-machine acceptance is still a separate proof gate; a fresh VM remains optional replay evidence

## Planned Install Surfaces

- VS Code Marketplace
- GitHub Releases with versioned `.vsix` artifacts
- GitHub Releases with a public release kit: setup manifest, setup scripts, fixture bundle, and checksums
- optional legacy Windows installer assets built from an immutable released `.vsix`

Current direct public setup direction:

- Windows: `Setup-VIHistorySuite.ps1`
- Linux: `setup-vi-history-suite.sh`
- both adapters consume `public-setup-manifest.json`
- Docker is not part of the default public setup path

Current legacy installer download commands:

```powershell
$tag = 'v0.2.0'
$asset = 'vi-history-suite-setup-0.2.0.exe'
$uri = "https://github.com/svelderrainruiz/vi-history-suite/releases/download/$tag/$asset"
$dest = Join-Path $env:TEMP $asset

Invoke-WebRequest -Uri $uri -OutFile $dest
Get-FileHash $dest -Algorithm SHA256
```

## VS Code CLI Verification

The VS Code CLI remains the authoritative extension install, verification, and
workspace-launch surface for the public Windows flow.

Examples:

```bash
code --install-extension vi-history-suite-0.2.0.vsix
code --install-extension vi-history-suite-0.2.0.vsix --force
code --list-extensions --show-versions
```

## Public Setup Direction

The primary public setup lane now aims to:
- consume only immutable released VSIX artifacts
- publish a public setup manifest plus Windows and Linux setup adapters
- support the default review flow with Visual Studio Code, Git, the exact released extension, and a pinned Git fixture bundle
- avoid Docker in the default setup path
- treat heavier runtime providers such as Docker as optional future capability providers

The public setup lane is not the installed-user proof lane. Installed-user proof remains a separate Windows 11 acceptance flow that now defaults to the current host machine and can replay on a fresh VM when needed.

Primary public setup inputs for the current release:

- [releases/v0.2.0/public-setup-manifest.json](releases/v0.2.0/public-setup-manifest.json)
- [setup/windows/Setup-VIHistorySuite.ps1](setup/windows/Setup-VIHistorySuite.ps1)
- [setup/linux/setup-vi-history-suite.sh](setup/linux/setup-vi-history-suite.sh)
- [scripts/Build-PublicSetupAssets.ps1](scripts/Build-PublicSetupAssets.ps1)
- [fixtures/labview-icon-editor.manifest.json](fixtures/labview-icon-editor.manifest.json)

Legacy builder/installer inputs retained for compatibility:

- [releases/v0.2.0/release-ingestion.json](releases/v0.2.0/release-ingestion.json)
- [releases/v0.2.0/release-evidence/README.md](releases/v0.2.0/release-evidence/README.md)
- [.github/workflows/publish-windows-installer.yml](.github/workflows/publish-windows-installer.yml)
- [docker/windows-installer-builder/Stage-NsisBootstrap.ps1](docker/windows-installer-builder/Stage-NsisBootstrap.ps1)
- [docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1](docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1)
- [docker/windows-installer-builder/Stage-GitBootstrap.ps1](docker/windows-installer-builder/Stage-GitBootstrap.ps1)
- [docker/windows-installer-builder/Stage-DockerDesktopBootstrap.ps1](docker/windows-installer-builder/Stage-DockerDesktopBootstrap.ps1)
- [scripts/Sync-PinnedFixtureBundle.ps1](scripts/Sync-PinnedFixtureBundle.ps1)
- [docker/windows-installer-builder/Invoke-InstallerBuild.ps1](docker/windows-installer-builder/Invoke-InstallerBuild.ps1)
- [installer/nsis/vi-history-suite-installer.nsi](installer/nsis/vi-history-suite-installer.nsi)
- [installer/nsis/Invoke-HarnessBootstrap.ps1](installer/nsis/Invoke-HarnessBootstrap.ps1)
- [acceptance/windows11/Invoke-Windows11Acceptance.ps1](acceptance/windows11/Invoke-Windows11Acceptance.ps1)

Pinned bootstrap references for the Windows builder scaffold:

- file: `nsis-3.11-setup.exe`
- SHA-256:
  `38d49f8fe09b1c332b01d0940e57b7258f4447733643273a01c59959ad9d3b0a`
- file: `VSCodeSetup-x64-1.109.3.exe`
- SHA-256:
  `ef2ffa7f7589209a6ce452955b0dacd842be4f960b3a92c0d275180b0e74874d`
- file: `Git-2.53.0-64-bit.exe`
- SHA-256:
  `3b4e1b127dbebea2931f2ae9dfafa0c2343a488a1222009debfe78d5d335e6a9`
- file: `Docker Desktop Installer.exe`
- SHA-256:
  `9e334622293ddf15eb7ecb935b829370899a93c92a53385a2e4c7749e5d57c77`

Pinned review fixture identities:

- image reference: `nationalinstruments/labview:2026q1-windows`
- image digest:
  `sha256:57c453dabd2ff0185ce718d88704921bb82eb83189f4049205ed9b4da7df7bcd`
- bundled fixture bundle:
  `labview-icon-editor-develop-e8945de7.bundle`

Reference local release-kit commands:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Sync-PinnedFixtureBundle.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Build-PublicSetupAssets.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File setup/windows/Setup-VIHistorySuite.ps1
```

Legacy builder commands on a Windows host with NSIS available:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-NsisBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-GitBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-DockerDesktopBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Sync-PinnedFixtureBundle.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Invoke-InstallerBuild.ps1
```

## Planned Trust Model

The extension is designed for use inside trusted Git repositories containing eligible LabVIEW VI files.

## Planned Product Surfaces

- `VI History` context-menu entry on eligible `.vi` files
- retained comparison report generation and refresh
- multi-report dashboard review
- bundled in-product documentation
- separate decision-record retention
