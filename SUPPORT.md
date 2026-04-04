# Support

## Public Support Surface

This repository is the public issue and release-facing surface for `vi-history-suite`.

Internal implementation work, governed requirements, and private engineering evidence remain on a private GitLab control plane.

## Before Filing An Issue

Please include:
- release contract id, for example `v0.2.0`
- VS Code version
- Git version
- Docker Desktop version
- operating system
- installed extension version
- whether the workspace was trusted
- whether the target file was an eligible LabVIEW VI
- the command or action you used
- what you expected
- what happened instead

Useful VS Code CLI output:

```bash
code --version
code --list-extensions --show-versions
git --version
docker version
```

## Planned Acceptance Split

The intended acceptance split for the first public installer lane is:
- automation via PowerShell plus pinned prerequisite bootstrap installers and
  VS Code CLI for install, version verification, Docker/image verification, and
  workspace launch from the bundled Git fixture
- a human manual right-click pass on a fresh Windows 11 VM for the final UX gate

That split exists because VS Code CLI can verify installation and launch surfaces, but cannot replace the real right-click interaction proof.

Current scaffold entrypoints:

- [docker/windows-installer-builder/Stage-NsisBootstrap.ps1](docker/windows-installer-builder/Stage-NsisBootstrap.ps1)
- [docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1](docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1)
- [docker/windows-installer-builder/Stage-GitBootstrap.ps1](docker/windows-installer-builder/Stage-GitBootstrap.ps1)
- [docker/windows-installer-builder/Stage-DockerDesktopBootstrap.ps1](docker/windows-installer-builder/Stage-DockerDesktopBootstrap.ps1)
- [scripts/Sync-PinnedFixtureBundle.ps1](scripts/Sync-PinnedFixtureBundle.ps1)
- [docker/windows-installer-builder/Invoke-InstallerBuild.ps1](docker/windows-installer-builder/Invoke-InstallerBuild.ps1)
- [acceptance/windows11/Invoke-Windows11Acceptance.ps1](acceptance/windows11/Invoke-Windows11Acceptance.ps1)
- [acceptance/windows11/manual-right-click-checklist.md](acceptance/windows11/manual-right-click-checklist.md)
- [acceptance/windows11/acceptance-record.template.json](acceptance/windows11/acceptance-record.template.json)

## Good Issue Topics

- extension command behavior
- comparison report generation issues
- dashboard review issues
- documentation problems
- installation and upgrade problems

## Not In Scope For Public Issues

- requests for private engineering artifacts
- requests for private GitLab access
- private repository contents that should not be disclosed publicly

## Future Support Direction

Planned future hardening includes an extension-side support-bundle export so issue reports can include bounded product evidence without requiring private repo access.

Current immutable reference for support and future installer work:

- [releases/v0.2.0/release-ingestion.json](releases/v0.2.0/release-ingestion.json)
- [fixtures/labview-icon-editor.manifest.json](fixtures/labview-icon-editor.manifest.json)
