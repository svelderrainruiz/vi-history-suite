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
- [Invoke-HarnessBootstrap.ps1](./Invoke-HarnessBootstrap.ps1):
  materializes the bundled proof workspace, prepares Docker Desktop, and
  verifies the pinned Windows container image
- [docker/windows-installer-builder/Invoke-InstallerBuild.ps1](../../docker/windows-installer-builder/Invoke-InstallerBuild.ps1):
  stages immutable inputs and calls `makensis`

## Current Installer Contract

The scaffolded installer:

- stages the exact released VSIX into the install root
- stages pinned Visual Studio Code, Git, and Docker Desktop bootstrap
  installers into the install root
- stages the pinned `ni/labview-icon-editor` fixture manifest and Git bundle
  with develop-branch commit history
- stages public-facing `README.md`, `INSTALL.md`, `SUPPORT.md`, `LICENSE`, and
  the immutable `release-ingestion.json`
- bootstraps Visual Studio Code on a fresh Windows 11 VM when needed
- bootstraps Git for Windows on a fresh Windows 11 VM when needed
- bootstraps Docker Desktop on a fresh Windows 11 VM when needed
- switches Docker Desktop to the Windows containers engine and verifies the
  pinned LabVIEW Windows image digest
- materializes the pinned proof workspace from the bundled Git fixture so a
  real Git repo with commit history is available locally
- installs the extension through the Visual Studio Code CLI after bootstrap
- removes the installed extension through the Visual Studio Code CLI on
  uninstall
- leaves shared Visual Studio Code, Git, and Docker Desktop installations in
  place on uninstall

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

## Current Limitation

The exact-contract installer is now published through the GitHub workflow, but
fresh Windows 11 VM proof still remains open. Acceptance must still confirm the
installer bootstraps Visual Studio Code, Git, and Docker Desktop on a truly
fresh VM, prepares the pinned Windows container image, materializes the pinned
Git fixture workspace with commit history, and supports the right-click review
flow on that proof fixture.
