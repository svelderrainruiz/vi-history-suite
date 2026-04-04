# Legacy NSIS Wrapper Surface

This directory retains the legacy Windows NSIS wrapper scaffold for
`vi-history-suite`.

It is no longer the primary public setup surface. The primary public setup
surface is the release kit:

- [releases/v0.2.0/public-setup-manifest.json](../../releases/v0.2.0/public-setup-manifest.json)
- [setup/windows/Setup-VIHistorySuite.ps1](../../setup/windows/Setup-VIHistorySuite.ps1)
- [setup/linux/setup-vi-history-suite.sh](../../setup/linux/setup-vi-history-suite.sh)

## Source Truth

The legacy wrapper consumes only the immutable released VSIX contract retained
in:

- [releases/v0.2.0/release-ingestion.json](../../releases/v0.2.0/release-ingestion.json)
- [releases/v0.2.0/release-evidence/README.md](../../releases/v0.2.0/release-evidence/README.md)

It must not consume:

- a working tree
- a floating preview artifact
- an unpublished package version

## Scaffold Files

- [vi-history-suite-installer.nsi](./vi-history-suite-installer.nsi):
  legacy wrapper entrypoint
- [Invoke-HarnessBootstrap.ps1](./Invoke-HarnessBootstrap.ps1):
  legacy prerequisite/bootstrap harness retained for wrapper work
- [docker/windows-installer-builder/Invoke-InstallerBuild.ps1](../../docker/windows-installer-builder/Invoke-InstallerBuild.ps1):
  stages immutable inputs and calls `makensis` for the legacy wrapper build

## Current Legacy Contract

The retained wrapper scaffold:

- stages the exact released VSIX into the install root
- stages pinned Visual Studio Code, Git, and Docker Desktop bootstrap
  installers into the install root
- stages the pinned `ni/labview-icon-editor` fixture manifest and Git bundle
  with develop-branch commit history
- stages public-facing `README.md`, `INSTALL.md`, `SUPPORT.md`, `LICENSE`, and
  the immutable `release-ingestion.json`
- bootstraps Visual Studio Code on a Windows 11 proof machine when needed
- bootstraps Git for Windows on a Windows 11 proof machine when needed
- bootstraps Docker Desktop on a Windows 11 proof machine when needed
- switches Docker Desktop to the Windows containers engine and verifies the
  pinned LabVIEW Windows image digest
- materializes the pinned proof workspace from the bundled Git fixture so a
  real Git repo with commit history is available locally
- installs the extension through the Visual Studio Code CLI after bootstrap
- removes the installed extension through the Visual Studio Code CLI on
  uninstall
- leaves shared Visual Studio Code, Git, and Docker Desktop installations in
  place on uninstall

The builder also supports a local `host-iteration` profile for this machine:

- writes to `$LocalAppData\Programs\VI History Suite Host Iteration`
- omits the pinned Visual Studio Code, Git, and Docker Desktop bootstrap
  installers from the payload
- expects those shared tools to already be installed on the host
- still installs the exact released VSIX, materializes the pinned proof
  workspace, and verifies Docker Desktop plus the pinned Windows container
  image

Default staged install layout:

- `$LocalAppData\Programs\VI History Suite\payload\vi-history-suite-<version>.vsix`
- `$LocalAppData\Programs\VI History Suite\bootstrap\vscode\VSCodeSetup-x64-1.109.3.exe`
- `$LocalAppData\Programs\VI History Suite\bootstrap\git\Git-2.53.0-64-bit.exe`
- `$LocalAppData\Programs\VI History Suite\bootstrap\docker\Docker Desktop Installer.exe`
- `$LocalAppData\Programs\VI History Suite\scripts\Invoke-HarnessBootstrap.ps1`
- `$LocalAppData\Programs\VI History Suite\docs\README.md`
- `$LocalAppData\Programs\VI History Suite\docs\INSTALL.md`
- `$LocalAppData\Programs\VI History Suite\docs\SUPPORT.md`
- `$LocalAppData\Programs\VI History Suite\docs\LICENSE`
- `$LocalAppData\Programs\VI History Suite\contracts\release-ingestion.json`
- `$LocalAppData\Programs\VI History Suite\fixtures\labview-icon-editor.manifest.json`
- `$LocalAppData\Programs\VI History Suite\fixtures\labview-icon-editor-develop-e8945de7.bundle`
- `$LocalAppData\Programs\VI History Suite\fixtures-workspace\labview-icon-editor`

Local host-iteration build command:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Build-HostIterationInstaller.ps1
```

## Current Status

The exact-contract wrapper is retained as a secondary or future signed-wrapper
option. It is not the critical path for public setup anymore. The active public
direction is direct setup from the public release kit, with Docker removed from
the default setup lane and NSIS treated as optional legacy scaffolding.
