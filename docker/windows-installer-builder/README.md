# Windows Installer Builder Surface

This directory contains the Windows container build scaffold for the public
installer lane for `vi-history-suite`.

The intended public release path is the GitHub workflow at
[publish-windows-installer.yml](../../.github/workflows/publish-windows-installer.yml),
which stages exact release evidence, fetches pinned bootstrap installers, and
invokes this builder entrypoint on a Windows runner.

## Trust Boundary

- Windows Docker builds the installer
- the Windows 11 VM proves the installed-user experience

The container build lane is not the final user-proof surface.

## Planned Responsibilities

- download or stage the immutable released VSIX payload
- stage pinned Visual Studio Code and Git bootstrap installers for the final
  installer payload
- stage the NSIS project inputs
- build the versioned Windows installer artifact
- retain bounded build metadata

Current authoritative release input:

- [releases/v0.2.0/release-ingestion.json](../../releases/v0.2.0/release-ingestion.json)
- [releases/v0.2.0/release-evidence/README.md](../../releases/v0.2.0/release-evidence/README.md)

Current scaffold files:

- [Dockerfile](./Dockerfile)
- [Invoke-InstallerBuild.ps1](./Invoke-InstallerBuild.ps1)
- [Stage-NsisBootstrap.ps1](./Stage-NsisBootstrap.ps1)
- [Stage-VsCodeBootstrap.ps1](./Stage-VsCodeBootstrap.ps1)
- [Stage-GitBootstrap.ps1](./Stage-GitBootstrap.ps1)
- [vendor/README.md](./vendor/README.md)

## Bootstrap References

The builder scaffold can bootstrap `makensis.exe` from the NSIS 3.11 setup
installer and package pinned runtime prerequisite installers for Visual Studio
Code and Git for Windows into the final NSIS payload so the Windows 11 proof VM
can start from a fresh install.

Pinned bootstrap references:

- file: `nsis-3.11-setup.exe`
- SHA-256:
  `38d49f8fe09b1c332b01d0940e57b7258f4447733643273a01c59959ad9d3b0a`
- file: `VSCodeSetup-x64-1.109.3.exe`
- SHA-256:
  `ef2ffa7f7589209a6ce452955b0dacd842be4f960b3a92c0d275180b0e74874d`
- file: `Git-2.53.0-64-bit.exe`
- SHA-256:
  `3b4e1b127dbebea2931f2ae9dfafa0c2343a488a1222009debfe78d5d335e6a9`

Stage the local installers into the vendor path with:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-NsisBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-GitBootstrap.ps1
```

On this machine, the known local reference installers are:

- `C:\Users\sveld\Downloads\nsis-3.11-setup.exe`
- `C:\Users\sveld\Downloads\VSCodeSetup-x64-1.109.3.exe`
- `C:\Users\sveld\Downloads\Git-2.53.0-64-bit.exe`

Current default outputs:

- `artifacts/windows-installer/vi-history-suite-setup-0.2.0.exe`
- `artifacts/windows-installer/vi-history-suite-setup-0.2.0-build.json`
- `artifacts/windows-installer/SHA256SUMS.txt`

Example scaffold commands on a Windows host:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-GitBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Invoke-InstallerBuild.ps1
```

## Not Yet Implemented

This scaffold does not yet publish a production builder image or prove the
result on the Windows 11 VM. It intentionally fails closed until the exact
release evidence is staged and the Windows toolchain is present.
