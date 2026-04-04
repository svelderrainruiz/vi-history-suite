# NSIS Installer Surface

This directory contains the public Windows installer scaffold for
`vi-history-suite`.

## Source Truth

The installer consumes only the immutable released VSIX contract retained in:

- [releases/v0.2.0/release-ingestion.json](../../releases/v0.2.0/release-ingestion.json)
- [releases/v0.2.0/release-evidence/README.md](../../releases/v0.2.0/release-evidence/README.md)

It must not consume:

- a working tree
- a floating preview artifact
- an unpublished package version

## Scaffold Files

- [vi-history-suite-installer.nsi](./vi-history-suite-installer.nsi):
  public installer entrypoint
- [docker/windows-installer-builder/Invoke-InstallerBuild.ps1](../../docker/windows-installer-builder/Invoke-InstallerBuild.ps1):
  stages immutable inputs and calls `makensis`

## Current Installer Contract

The scaffolded installer:

- stages the exact released VSIX into the install root
- stages pinned Visual Studio Code and Git bootstrap installers into the
  install root
- stages public-facing `README.md`, `INSTALL.md`, `SUPPORT.md`, `LICENSE`, and
  the immutable `release-ingestion.json`
- bootstraps Visual Studio Code on a fresh Windows 11 VM when needed
- bootstraps Git for Windows on a fresh Windows 11 VM when needed
- installs the extension through the Visual Studio Code CLI after bootstrap
- removes the installed extension through the Visual Studio Code CLI on
  uninstall
- leaves shared Visual Studio Code and Git installations in place on uninstall

Default staged install layout:

- `$LocalAppData\Programs\VI History Suite\payload\vi-history-suite-<version>.vsix`
- `$LocalAppData\Programs\VI History Suite\bootstrap\vscode\VSCodeSetup-x64-1.109.3.exe`
- `$LocalAppData\Programs\VI History Suite\bootstrap\git\Git-2.53.0-64-bit.exe`
- `$LocalAppData\Programs\VI History Suite\docs\README.md`
- `$LocalAppData\Programs\VI History Suite\docs\INSTALL.md`
- `$LocalAppData\Programs\VI History Suite\docs\SUPPORT.md`
- `$LocalAppData\Programs\VI History Suite\docs\LICENSE`
- `$LocalAppData\Programs\VI History Suite\contracts\release-ingestion.json`

## Current Limitation

This scaffold is intentionally fail-closed until the exact VSIX is staged under
`releases/v0.2.0/release-evidence/` and the Windows builder lane is executed on
an actual Windows host or Windows container runner with NSIS available.
