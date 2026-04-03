# Windows 11 Acceptance Scaffold

This directory is reserved for the installed-user acceptance lane for `vi-history-suite`.

## Intended Split

- automation: PowerShell + Visual Studio Code CLI
- human gate: manual right-click review flow on the canonical VI

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
