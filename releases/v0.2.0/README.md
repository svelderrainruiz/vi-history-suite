# v0.2.0 Release Ingestion

This directory retains the immutable public-facade ingestion contract for the
first governed `vi-history-suite` release.

Current truth:

- tag: `v0.2.0`
- package version: `0.2.0`
- commit: `3fcd02c398fe162480e9fdb0bfc432277302fd5f`
- authoritative VSIX: `vi-history-suite-0.2.0.vsix`
- authoritative SHA-256:
  `dd9585dbd684939ce71eeed01ca435685bb8da305b601e4d2bde15dfb54c4cf3`
- retained source truth: private GitLab release `v0.2.0`
- public GitHub release:
  `https://github.com/svelderrainruiz/vi-history-suite/releases/tag/v0.2.0`
- workflow publication run:
  `https://github.com/svelderrainruiz/vi-history-suite/actions/runs/23968715268`
- published Windows installer SHA-256:
  `f4c7b57c0b9ad2377e202f8dc898d1ca8291d5134dda25d7bae86221ec1f7e14`

Use [release-ingestion.json](./release-ingestion.json) as the machine-readable
source for installer and Windows acceptance work in this public facade repo.

Staging and scaffold surfaces tied to this release contract:

- [release-evidence/README.md](./release-evidence/README.md)
- [docker/windows-installer-builder/Invoke-InstallerBuild.ps1](../../docker/windows-installer-builder/Invoke-InstallerBuild.ps1)
- [docker/windows-installer-builder/Stage-NsisBootstrap.ps1](../../docker/windows-installer-builder/Stage-NsisBootstrap.ps1)
- [docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1](../../docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1)
- [docker/windows-installer-builder/Stage-GitBootstrap.ps1](../../docker/windows-installer-builder/Stage-GitBootstrap.ps1)
- [installer/nsis/vi-history-suite-installer.nsi](../../installer/nsis/vi-history-suite-installer.nsi)
- [acceptance/windows11/Invoke-Windows11Acceptance.ps1](../../acceptance/windows11/Invoke-Windows11Acceptance.ps1)
