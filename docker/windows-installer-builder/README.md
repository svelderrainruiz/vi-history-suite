# Legacy Windows Wrapper Builder Surface

This directory retains the Windows builder scaffold for the legacy NSIS wrapper
lane for `vi-history-suite`.

The intended primary public release path is the GitHub workflow at
[publish-windows-installer.yml](../../.github/workflows/publish-windows-installer.yml),
which now stages the public release kit first and only invokes this builder
when the optional legacy wrapper path is enabled.

## Trust Boundary

- the GitHub workflow publishes the public release kit as the primary surface
- this builder entrypoint is invoked only for the optional legacy wrapper path
- the retained Dockerfile is legacy hardening scaffolding, not the primary
  publication path
- the current Windows 11 host machine is the active human proof surface

This builder lane is not the default setup path and is not the final proof
surface.

## Planned Responsibilities

- download or stage the immutable released VSIX payload
- stage pinned Visual Studio Code, Git, and Docker Desktop bootstrap installers
  for the final installer payload
- materialize the pinned `ni/labview-icon-editor` Git fixture bundle with
  commit history for the final installer payload
- stage the NSIS project inputs
- build the versioned Windows wrapper artifact
- retain bounded build metadata

Current authoritative release input:

- [releases/v0.2.0/public-setup-manifest.json](../../releases/v0.2.0/public-setup-manifest.json)
- [releases/v0.2.0/release-ingestion.json](../../releases/v0.2.0/release-ingestion.json)
- [releases/v0.2.0/release-evidence/README.md](../../releases/v0.2.0/release-evidence/README.md)

Current scaffold files:

- [Dockerfile](./Dockerfile)
- [Invoke-InstallerBuild.ps1](./Invoke-InstallerBuild.ps1)
- [Stage-NsisBootstrap.ps1](./Stage-NsisBootstrap.ps1)
- [Stage-VsCodeBootstrap.ps1](./Stage-VsCodeBootstrap.ps1)
- [Stage-GitBootstrap.ps1](./Stage-GitBootstrap.ps1)
- [Stage-DockerDesktopBootstrap.ps1](./Stage-DockerDesktopBootstrap.ps1)
- [../../scripts/Sync-PinnedFixtureBundle.ps1](../../scripts/Sync-PinnedFixtureBundle.ps1)
- [vendor/README.md](./vendor/README.md)

## Legacy Bootstrap References

The builder scaffold can bootstrap `makensis.exe` from the NSIS 3.11 setup
installer and package pinned runtime prerequisite installers for Visual Studio
Code, Git for Windows, and Docker Desktop into the final NSIS payload so the
legacy wrapper lane can run on the current host machine or a fresh VM when that
secondary path is exercised. It also generates a pinned Git fixture bundle for
`ni/labview-icon-editor` so the wrapper can materialize a local proof workspace
with commit history.

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
- file: `Docker Desktop Installer.exe`
- SHA-256:
  `9e334622293ddf15eb7ecb935b829370899a93c92a53385a2e4c7749e5d57c77`

Stage the local installers into the vendor path with:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-NsisBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-GitBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-DockerDesktopBootstrap.ps1
```

On this machine, the known local reference installers are:

- `C:\Users\sveld\Downloads\nsis-3.11-setup.exe`
- `C:\Users\sveld\Downloads\VSCodeSetup-x64-1.109.3.exe`
- `C:\Users\sveld\Downloads\Git-2.53.0-64-bit.exe`
- `C:\Users\sveld\Downloads\Docker Desktop Installer.exe`

Current optional legacy-wrapper outputs:

- `artifacts/windows-installer/vi-history-suite-setup-0.2.0.exe`
- `artifacts/windows-installer/vi-history-suite-setup-0.2.0-build.json`
- `artifacts/windows-installer/SHA256SUMS.txt`

Local host-iteration outputs:

- `artifacts/windows-installer-host-iteration/vi-history-suite-host-iteration-setup-0.2.0.exe`
- `artifacts/windows-installer-host-iteration/vi-history-suite-host-iteration-setup-0.2.0-build.json`
- `artifacts/windows-installer-host-iteration/SHA256SUMS.txt`

Example scaffold commands on a Windows host:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-GitBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Stage-DockerDesktopBootstrap.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Sync-PinnedFixtureBundle.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File docker/windows-installer-builder/Invoke-InstallerBuild.ps1
```

Host-machine iteration build on this machine:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/Build-HostIterationInstaller.ps1
```

The `host-iteration` profile keeps the immutable VSIX and pinned fixture
bundle, but omits the large runtime bootstrap installers and expects Visual
Studio Code, Git, and Docker Desktop to already exist on the local machine.

## Current Status

This scaffold is retained for optional wrapper work and future signed-wrapper
hardening. The primary public direction is the direct release kit with setup
adapters, no default Docker prerequisite, and no reliance on NSIS as the main
distribution surface.
