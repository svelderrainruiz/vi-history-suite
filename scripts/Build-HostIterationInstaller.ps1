[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$ReleaseDir = "",
  [string]$OutputDir = "",
  [string]$MakensisPath = "",
  [switch]$KeepStaging
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-PublicRepoRoot {
  param([string]$Path)

  if ($Path) {
    return (Resolve-Path -LiteralPath $Path).Path
  }

  return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

function Ensure-Directory {
  param([string]$Path)

  New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Convert-WindowsPathToWsl {
  param([string]$Path)

  if ($Path -match '^([A-Za-z]):\\(.*)$') {
    $drive = $Matches[1].ToLowerInvariant()
    $rest = $Matches[2] -replace '\\', '/'
    return "/mnt/$drive/$rest"
  }

  throw "Unable to convert Windows path '$Path' to a WSL path."
}

function Convert-WslPathToWindows {
  param([string]$Path)

  $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
  $windowsPath = (& wslpath -w $resolvedPath | Select-Object -First 1).Trim()
  if (-not $windowsPath) {
    throw "Unable to convert WSL path '$resolvedPath' to a Windows path."
  }

  return $windowsPath
}

function Invoke-BuilderDirectly {
  param(
    [string]$RepoRootPath,
    [string]$ReleaseDir,
    [string]$OutputDir,
    [string]$MakensisPath,
    [switch]$KeepStaging
  )

  $builderScriptPath = Join-Path $RepoRootPath "docker/windows-installer-builder/Invoke-InstallerBuild.ps1"
  if (-not (Test-Path -LiteralPath $builderScriptPath)) {
    throw "Installer builder entrypoint was not found at $builderScriptPath."
  }

  $invokeArgs = @{
    RepoRoot = $RepoRootPath
    BuildProfile = "host-iteration"
  }

  if ($ReleaseDir) {
    $invokeArgs.ReleaseDir = $ReleaseDir
  }

  if ($OutputDir) {
    $invokeArgs.OutputDir = $OutputDir
  }

  if ($MakensisPath) {
    $invokeArgs.MakensisPath = $MakensisPath
  }

  if ($KeepStaging.IsPresent) {
    $invokeArgs.KeepStaging = $true
  }

  & $builderScriptPath @invokeArgs
}

function Invoke-HostIterationBuildFromWsl {
  param(
    [string]$RepoRootPath,
    [string]$ReleaseDir,
    [string]$OutputDir,
    [string]$MakensisPath,
    [switch]$KeepStaging
  )

  $windowsPowerShellPath = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
  if (-not (Test-Path -LiteralPath $windowsPowerShellPath)) {
    throw "powershell.exe was not found at $windowsPowerShellPath."
  }

  $windowsTempRoot = (& $windowsPowerShellPath -NoProfile -Command '$env:TEMP' | Select-Object -First 1).Trim()
  if (-not $windowsTempRoot) {
    throw "Failed to resolve the Windows TEMP directory."
  }

  $tempRepoWindowsPath = "{0}\\vi-history-suite-host-iteration-repo.{1}" -f $windowsTempRoot.TrimEnd('\'), ([guid]::NewGuid().ToString("N"))
  $tempRepoPath = Convert-WindowsPathToWsl -Path $tempRepoWindowsPath
  Ensure-Directory -Path $tempRepoPath

  $rsyncArgs = @(
    "-a",
    "--exclude", ".git/",
    "--exclude", "docker/windows-installer-builder/vendor/",
    "--exclude", "artifacts/windows-installer/",
    "--exclude", "artifacts/windows-installer-host-iteration/",
    "--exclude", "artifacts/fixtures/",
    ($RepoRootPath.TrimEnd('/') + "/"),
    ($tempRepoPath.TrimEnd('/') + "/")
  )

  & rsync @rsyncArgs
  if ($LASTEXITCODE -ne 0) {
    throw "rsync failed while staging the Windows-side temp repo. Exit code: $LASTEXITCODE."
  }

  $windowsBuilderScriptPath = "$tempRepoWindowsPath\scripts\Build-HostIterationInstaller.ps1"
  $windowsInvokeArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $windowsBuilderScriptPath,
    "-RepoRoot", $tempRepoWindowsPath
  )

  if ($ReleaseDir) {
    $windowsInvokeArgs += @("-ReleaseDir", (Convert-WslPathToWindows -Path $ReleaseDir))
  }

  if ($MakensisPath) {
    $windowsInvokeArgs += @("-MakensisPath", $MakensisPath)
  }

  if ($KeepStaging.IsPresent) {
    $windowsInvokeArgs += "-KeepStaging"
  }

  & $windowsPowerShellPath @windowsInvokeArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Windows host-iteration build failed with exit code $LASTEXITCODE."
  }

  $tempOutputPath = Join-Path $tempRepoPath "artifacts/windows-installer-host-iteration"
  $finalOutputPath = if ($OutputDir) { [IO.Path]::GetFullPath($OutputDir) } else { Join-Path $RepoRootPath "artifacts/windows-installer-host-iteration" }
  Ensure-Directory -Path $finalOutputPath

  & rsync -a ($tempOutputPath.TrimEnd('/') + "/") ($finalOutputPath.TrimEnd('/') + "/")
  if ($LASTEXITCODE -ne 0) {
    throw "rsync failed while copying the host-iteration artifacts back from the Windows temp repo. Exit code: $LASTEXITCODE."
  }

  if (-not $KeepStaging.IsPresent -and (Test-Path -LiteralPath $tempRepoPath)) {
    Remove-Item -LiteralPath $tempRepoPath -Recurse -Force -ErrorAction SilentlyContinue
  }

  Write-Host "Host-iteration installer staged at $finalOutputPath"
  return $finalOutputPath
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$runningOnWindows = $env:OS -eq "Windows_NT"

if ($runningOnWindows) {
  Invoke-BuilderDirectly -RepoRootPath $repoRootPath -ReleaseDir $ReleaseDir -OutputDir $OutputDir -MakensisPath $MakensisPath -KeepStaging:$KeepStaging
} else {
  Invoke-HostIterationBuildFromWsl -RepoRootPath $repoRootPath -ReleaseDir $ReleaseDir -OutputDir $OutputDir -MakensisPath $MakensisPath -KeepStaging:$KeepStaging | Out-Null
}
