# Windows 11 Acceptance

This directory defines the installed-user acceptance lane for `vi-history-suite`.

## Intended Split

- automation: PowerShell + fresh-machine prerequisite bootstrap + Visual Studio Code CLI
- human gate: manual right-click review flow on the canonical VI

## Current Acceptance Inputs

- immutable release contract:
  [releases/v0.2.0/release-ingestion.json](../../releases/v0.2.0/release-ingestion.json)
- canonical fixture manifest:
  [fixtures/labview-icon-editor.manifest.json](../../fixtures/labview-icon-editor.manifest.json)
- installer build output:
  `artifacts/windows-installer/vi-history-suite-setup-0.2.0.exe`

## Planned Automated Proof

- invoke the public installer
- confirm the installer bootstraps Visual Studio Code, Git, and Docker Desktop on a fresh VM
- confirm Docker Desktop is running the Windows containers engine and that the pinned LabVIEW image digest is present
- verify the installed extension version
- launch the pinned proof workspace materialized from the bundled Git fixture
- retain CLI outputs and acceptance artifacts

Current scaffold files:

- [Invoke-Windows11Acceptance.ps1](./Invoke-Windows11Acceptance.ps1)
- [acceptance-record.template.json](./acceptance-record.template.json)

## Planned Human Gate

- right-click the canonical VI
- evaluate wording clarity and trust prompts
- confirm the expected review surfaces open
- retain the result as a bounded acceptance record

See [manual-right-click-checklist.md](./manual-right-click-checklist.md).

Example scaffold command on a Windows 11 VM after building the installer:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File acceptance/windows11/Invoke-Windows11Acceptance.ps1
```
