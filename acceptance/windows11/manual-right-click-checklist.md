# Manual Right-Click Checklist

Use this checklist on the fresh Windows 11 acceptance VM after the automated installer and Visual Studio Code CLI setup steps succeed.

## Canonical Target

- repository: `ni/labview-icon-editor`
- commit: `e8945de7e07feba4b87daf7b41d546f10e9d714c`
- VI: `Tooling/deployment/VIP_Pre-Install Custom Action.vi`

## Checklist

- confirm Visual Studio Code opens the pinned proof workspace
- confirm the workspace is trusted before review actions are exercised
- locate the canonical VI in the Explorer tree
- right-click the VI and confirm `VI History` is present
- invoke `VI History`
- confirm the history panel opens without misleading warnings
- evaluate wording clarity on first-use actions
- confirm the expected compare/dashboard/docs actions are visible for the installed build
- note any trust, wording, or discoverability friction

## Retain

- installed extension version
- Visual Studio Code version
- pinned proof-repo identity
- release contract id
- pass/fail notes for each checklist item
- screenshots for any UX defect or ambiguity
