# v0.2.0 Public Release Kit

This directory retains the machine-readable public release/setup surfaces for
the first public `vi-history-suite` release.

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
- current workflow publication run for the legacy installer asset:
  `https://github.com/svelderrainruiz/vi-history-suite/actions/runs/23972941672`
- published legacy Windows installer SHA-256:
  `fd66fa6dd3ef7d3e8f840f63dae172bff812c958224313531dcd051970961e72`

Primary public machine-readable setup surface:

- [public-setup-manifest.json](./public-setup-manifest.json)

Legacy secondary machine-readable surface retained only for builder or wrapper
scaffolding:

- [release-ingestion.json](./release-ingestion.json)

Public release-kit surfaces tied to this release:

- [setup/README.md](../../setup/README.md)
- [setup/windows/Setup-VIHistorySuite.ps1](../../setup/windows/Setup-VIHistorySuite.ps1)
- [setup/linux/setup-vi-history-suite.sh](../../setup/linux/setup-vi-history-suite.sh)
- [fixtures/labview-icon-editor.manifest.json](../../fixtures/labview-icon-editor.manifest.json)
- [acceptance/windows11/Invoke-Windows11Acceptance.ps1](../../acceptance/windows11/Invoke-Windows11Acceptance.ps1)

Legacy builder and wrapper scaffolds retained for secondary use:

- [release-evidence/README.md](./release-evidence/README.md)
- [docker/windows-installer-builder/Invoke-InstallerBuild.ps1](../../docker/windows-installer-builder/Invoke-InstallerBuild.ps1)
- [docker/windows-installer-builder/Stage-NsisBootstrap.ps1](../../docker/windows-installer-builder/Stage-NsisBootstrap.ps1)
- [docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1](../../docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1)
- [docker/windows-installer-builder/Stage-GitBootstrap.ps1](../../docker/windows-installer-builder/Stage-GitBootstrap.ps1)
- [installer/nsis/vi-history-suite-installer.nsi](../../installer/nsis/vi-history-suite-installer.nsi)
