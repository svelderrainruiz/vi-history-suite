# Windows Installer Builder Surface

This directory is reserved for the Windows container build lane that will produce the public installer for `vi-history-suite`.

## Trust Boundary

- Windows Docker builds the installer
- the Windows 11 VM proves the installed-user experience

The container build lane is not the final user-proof surface.

## Planned Responsibilities

- download or stage the immutable released VSIX payload
- stage the NSIS project inputs
- build the versioned Windows installer artifact
- retain bounded build metadata

Current authoritative release input:

- [releases/v0.2.0/release-ingestion.json](../../releases/v0.2.0/release-ingestion.json)

## Not Yet Implemented

This scaffold does not yet publish a production builder image or build a real installer artifact.
