# Vendor Bootstrap Inputs

This directory is the local-only staging surface for Windows installer-builder
bootstrap inputs that should not be committed to the public repo.

Current expected bootstrap installers:

- file: `nsis-3.11-setup.exe`
- SHA-256:
  `38d49f8fe09b1c332b01d0940e57b7258f4447733643273a01c59959ad9d3b0a`
- file: `VSCodeSetup-x64-1.109.3.exe`
- SHA-256:
  `ef2ffa7f7589209a6ce452955b0dacd842be4f960b3a92c0d275180b0e74874d`
- file: `Git-2.53.0-64-bit.exe`
- SHA-256:
  `3b4e1b127dbebea2931f2ae9dfafa0c2343a488a1222009debfe78d5d335e6a9`

Stage the local bootstrap installers into this directory with:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-NsisBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-GitBootstrap.ps1
```

On this machine, the known local reference installers are:

- `C:\Users\sveld\Downloads\nsis-3.11-setup.exe`
- `C:\Users\sveld\Downloads\VSCodeSetup-x64-1.109.3.exe`
- `C:\Users\sveld\Downloads\Git-2.53.0-64-bit.exe`

The staged `.exe` and generated metadata `.json` are intentionally ignored by
Git.
