# escape=`
ARG WINDOWS_BASE_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2022
FROM ${WINDOWS_BASE_IMAGE}

SHELL ["powershell.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

WORKDIR C:\\workspace
COPY . C:\\workspace

RUN $bootstrap = 'C:\\workspace\\docker\\windows-installer-builder\\vendor\\nsis-3.11-setup.exe'; `
    if (Test-Path -LiteralPath $bootstrap) { `
      Start-Process -FilePath $bootstrap -ArgumentList '/S' -Wait -NoNewWindow; `
      if (-not (Test-Path -LiteralPath 'C:\\Program Files (x86)\\NSIS\\makensis.exe') -and -not (Test-Path -LiteralPath 'C:\\Program Files\\NSIS\\makensis.exe')) { `
        throw 'NSIS bootstrap installer completed but makensis.exe was not installed.' `
      } `
    } else { `
      Write-Host 'NSIS bootstrap installer not staged in docker/windows-installer-builder/vendor; image remains scaffold-only.' `
    }

ENV PUBLIC_FACADE_REPO=C:\\workspace
ENV PUBLIC_FACADE_RELEASE_DIR=C:\\workspace\\releases\\v0.2.0

ENTRYPOINT ["powershell.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\workspace\\docker\\windows-installer-builder\\Invoke-InstallerBuild.ps1"]
