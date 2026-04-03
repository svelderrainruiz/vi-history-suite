# NSIS Installer Scaffold

This directory is reserved for the public Windows installer project for `vi-history-suite`.

## Intended Source Truth

The installer must consume only an immutable released VSIX artifact.

It must not consume:
- a working tree
- a floating preview artifact
- an unpublished package version

## Version 1 Assumptions

- the target Windows 11 VM already has Visual Studio Code installed
- the canonical proof repo is provisioned separately from the installer
- the installer packages the exact released extension payload and public-facing support materials

## Planned Deliverables

- NSIS script(s)
- version metadata
- installer asset layout
- release ingestion contract from the immutable VSIX
