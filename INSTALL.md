# Install

## Current Public Release State

The first immutable release has been ingested into this public facade repo:

- release tag: `v0.2.0`
- package version: `0.2.0`
- commit: `3fcd02c398fe162480e9fdb0bfc432277302fd5f`
- exact VSIX: `vi-history-suite-0.2.0.vsix`
- SHA-256: `dd9585dbd684939ce71eeed01ca435685bb8da305b601e4d2bde15dfb54c4cf3`
- GitHub release: `https://github.com/svelderrainruiz/vi-history-suite/releases/tag/v0.2.0`
- Windows installer: `vi-history-suite-setup-0.2.0.exe`
- installer SHA-256: `b1d057b5fd4ca4ba5076e49217ebc28168d4984a28e0b6ecb08ec738044c06e0`

Current state:

- the authoritative release still lives on the private GitLab control plane
- the public GitHub release now publishes the exact VSIX and the workflow-built Windows installer
- the public installer lane continues consuming the immutable contract in `releases/v0.2.0/`
- fresh Windows 11 VM acceptance is still a separate proof gate

## Planned Install Surfaces

- VS Code Marketplace
- GitHub Releases with versioned `.vsix` artifacts
- GitHub Releases with a Windows installer built from an immutable released `.vsix`

Current public download commands:

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

## Windows Installer Direction

The first public Windows installer lane:
- consume only immutable released VSIX artifacts
- is built and published through the GitHub repo workflow on a Windows runner, using the NSIS build lane contract and the retained Windows builder scaffold
- treat the Windows 11 proof VM as a fresh install with no preinstalled Visual Studio Code, Git, or Docker Desktop
- bootstrap pinned Visual Studio Code, Git, and Docker Desktop installers before using the VS Code CLI to install the exact released extension
- switch Docker Desktop to the Windows containers engine and verify the pinned LabVIEW Windows container image digest
- materialize a local `ni/labview-icon-editor` Git fixture workspace from a bundled fixture bundle so commit history is available without remote clone credentials

The installer build lane is not the installed-user proof lane. Installed-user proof remains a separate fresh Windows 11 VM flow.

Authoritative installer input for the current release:

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
- [fixtures/labview-icon-editor.manifest.json](fixtures/labview-icon-editor.manifest.json)

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

Pinned Windows container fixture identities:

- image reference: `nationalinstruments/labview:2026q1-windows`
- image digest:
  `sha256:57c453dabd2ff0185ce718d88704921bb82eb83189f4049205ed9b4da7df7bcd`
- bundled fixture bundle:
  `labview-icon-editor-develop-e8945de7.bundle`

Reference local build commands on a Windows host with NSIS available:

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
