# Install

## Current Public Release State

The first immutable release has been ingested into this public facade repo:

- release tag: `v0.2.0`
- package version: `0.2.0`
- commit: `3fcd02c398fe162480e9fdb0bfc432277302fd5f`
- exact VSIX: `vi-history-suite-0.2.0.vsix`
- SHA-256: `dd9585dbd684939ce71eeed01ca435685bb8da305b601e4d2bde15dfb54c4cf3`
- GitHub release: `https://github.com/svelderrainruiz/vi-history-suite/releases/tag/v0.2.0`

Current state:

- the authoritative release still lives on the private GitLab release surface
- private requirements and design-gate artifacts are not published in this repo
- the public GitHub release kit is the active publication surface
- Windows 11 host-machine acceptance is the active proof lane
- a future published container image is the intended reproducible automation follow-on

## Planned Install Surfaces

- VS Code Marketplace
- GitHub Releases with versioned `.vsix` artifacts
- GitHub Releases with a public release kit: setup manifest, setup scripts, fixture bundle, and checksums

Current direct public setup direction:

- Windows: `Setup-VIHistorySuite.ps1`
- Linux: `setup-vi-history-suite.sh`
- both adapters consume `public-setup-manifest.json`
- Docker is not part of the default public setup path

Current direct-release download commands:

```powershell
$tag = 'v0.2.0'
$base = "https://github.com/svelderrainruiz/vi-history-suite/releases/download/$tag"
$dest = Join-Path $env:TEMP 'vi-history-suite-release-kit'

New-Item -ItemType Directory -Force -Path $dest | Out-Null

Invoke-WebRequest -Uri "$base/public-setup-manifest.json" -OutFile (Join-Path $dest 'public-setup-manifest.json')
Invoke-WebRequest -Uri "$base/Setup-VIHistorySuite.ps1" -OutFile (Join-Path $dest 'Setup-VIHistorySuite.ps1')
Invoke-WebRequest -Uri "$base/vi-history-suite-0.2.0.vsix" -OutFile (Join-Path $dest 'vi-history-suite-0.2.0.vsix')
Invoke-WebRequest -Uri "$base/labview-icon-editor-develop-e8945de7.bundle" -OutFile (Join-Path $dest 'labview-icon-editor-develop-e8945de7.bundle')

Get-FileHash (Join-Path $dest 'Setup-VIHistorySuite.ps1') -Algorithm SHA256
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
- treat containerized automation as optional future provider work

The public setup lane is not the installed-user proof lane. Installed-user proof remains a separate Windows 11 host-machine acceptance flow.

Primary public setup inputs for the current release:

- [releases/v0.2.0/public-setup-manifest.json](releases/v0.2.0/public-setup-manifest.json)
- [setup/windows/Setup-VIHistorySuite.ps1](setup/windows/Setup-VIHistorySuite.ps1)
- [setup/linux/setup-vi-history-suite.sh](setup/linux/setup-vi-history-suite.sh)
- [scripts/Build-PublicSetupAssets.ps1](scripts/Build-PublicSetupAssets.ps1)
- [fixtures/labview-icon-editor.manifest.json](fixtures/labview-icon-editor.manifest.json)

Release provenance and acceptance inputs:

- [releases/v0.2.0/release-ingestion.json](releases/v0.2.0/release-ingestion.json)
- [releases/v0.2.0/release-evidence/README.md](releases/v0.2.0/release-evidence/README.md)
- [.github/workflows/publish-public-release-kit.yml](.github/workflows/publish-public-release-kit.yml)
- [scripts/Sync-PinnedFixtureBundle.ps1](scripts/Sync-PinnedFixtureBundle.ps1)
- [acceptance/windows11/Invoke-Windows11Acceptance.ps1](acceptance/windows11/Invoke-Windows11Acceptance.ps1)

Pinned Windows prerequisite identities:

- file: `VSCodeSetup-x64-1.109.3.exe`
- SHA-256:
  `ef2ffa7f7589209a6ce452955b0dacd842be4f960b3a92c0d275180b0e74874d`
- file: `Git-2.53.0-64-bit.exe`
- SHA-256:
  `3b4e1b127dbebea2931f2ae9dfafa0c2343a488a1222009debfe78d5d335e6a9`

Reference local release-kit commands:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Sync-PinnedFixtureBundle.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Build-PublicSetupAssets.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File setup/windows/Setup-VIHistorySuite.ps1
```

## Planned Trust Model

The extension is designed for use inside trusted Git repositories containing eligible LabVIEW VI files.

## Planned Product Surfaces

- `VI History` context-menu entry on eligible `.vi` files
- retained comparison report generation and refresh
- multi-report dashboard review
- bundled in-product documentation
- separate decision-record retention
