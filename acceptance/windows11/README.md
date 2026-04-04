# Windows 11 Acceptance

This directory defines the installed-user acceptance lane for `vi-history-suite`.

## Intended Split

- automation: PowerShell + public release kit setup + Visual Studio Code CLI
- human gate: manual right-click review flow on the canonical VI

The current human gate is maintainer-operated by Sergio Velderrain on the host
Windows 11 machine. Public GitHub issues are supplemental feedback, not a
replacement for that gate.

## Current Acceptance Inputs

- primary public setup manifest:
  [releases/v0.2.0/public-setup-manifest.json](../../releases/v0.2.0/public-setup-manifest.json)
- public release-provenance ledger:
  [releases/v0.2.0/release-ingestion.json](../../releases/v0.2.0/release-ingestion.json)
- canonical fixture manifest:
  [fixtures/labview-icon-editor.manifest.json](../../fixtures/labview-icon-editor.manifest.json)
- primary public setup adapter:
  [setup/windows/Setup-VIHistorySuite.ps1](../../setup/windows/Setup-VIHistorySuite.ps1)

The automation script currently supports one execution target:

- `host-machine`: default and current iteration surface on this Windows 11 machine

If the local repo checkout or public setup files are not available, the script
downloads the public setup manifest and setup script into
`%LocalAppData%\VI History Suite\acceptance\<target>\downloads`.

## Current Automated Proof Surface

- invoke the public setup adapter on the selected Windows 11 proof machine
- confirm the setup adapter installs or reuses Visual Studio Code and Git
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
- Sergio Velderrain is the named maintainer reviewer for the current host-machine pass

See [manual-right-click-checklist.md](./manual-right-click-checklist.md).

Example primary acceptance command on this Windows 11 host machine:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File acceptance/windows11/Invoke-Windows11Acceptance.ps1 -ExecutionTarget host-machine
```
