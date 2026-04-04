# Public Setup Surface

This directory contains the primary public setup adapters for `vi-history-suite`.

Current direction:

- public release kit first
- scriptable setup adapters
- cross-OS setup surface
- no default Docker requirement
- no reliance on NSIS as the primary public path
- optional container automation scaffolded separately from the default setup path

Primary entrypoints:

- [windows/Setup-VIHistorySuite.ps1](./windows/Setup-VIHistorySuite.ps1)
- [linux/setup-vi-history-suite.sh](./linux/setup-vi-history-suite.sh)

These adapters consume the public setup manifest at
[releases/v0.2.0/public-setup-manifest.json](../releases/v0.2.0/public-setup-manifest.json)
plus the public release assets published on GitHub.
