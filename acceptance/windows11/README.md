# Windows 11 Acceptance

This directory defines the installed-user acceptance lane for `vi-history-suite`.

## Intended Split

- automation: PowerShell + Visual Studio Code CLI
- human gate: manual right-click review flow on the canonical VI

## Current Acceptance Inputs

- immutable release contract:
  [releases/v0.2.0/release-ingestion.json](../../releases/v0.2.0/release-ingestion.json)
- canonical fixture manifest:
  [fixtures/labview-icon-editor.manifest.json](../../fixtures/labview-icon-editor.manifest.json)

## Planned Automated Proof

- invoke the public installer
- verify the installed extension version
- launch the pinned proof workspace
- retain CLI outputs and acceptance artifacts

## Planned Human Gate

- right-click the canonical VI
- evaluate wording clarity and trust prompts
- confirm the expected review surfaces open
- retain the result as a bounded acceptance record

See [manual-right-click-checklist.md](./manual-right-click-checklist.md).
