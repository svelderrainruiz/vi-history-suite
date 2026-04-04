[CmdletBinding()]
param(
  [string]$RepoRoot = ""
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

function Assert-PathPresent {
  param(
    [string]$Path,
    [string]$Message
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw $Message
  }
}

function Ensure-Directory {
  param([string]$Path)

  New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Read-JsonFile {
  param([string]$Path)

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
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

function Stage-LocalFileForWindowsInvocation {
  param(
    [string]$SourcePath,
    [string]$DestinationDirectory
  )

  Assert-PathPresent -Path $SourcePath -Message "Staging source file was not found at $SourcePath."
  Ensure-Directory -Path $DestinationDirectory
  $destinationPath = Join-Path $DestinationDirectory (Split-Path -Leaf $SourcePath)
  Copy-Item -LiteralPath $SourcePath -Destination $destinationPath -Force
  return $destinationPath
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$manifestPath = Join-Path $repoRootPath "artifacts/public-setup/public-setup-manifest.json"
$fallbackManifestPath = Join-Path $repoRootPath "releases/v0.2.0/public-setup-manifest.json"
$setupScriptPath = Join-Path $repoRootPath "setup/windows/Setup-VIHistorySuite.ps1"
$vsixPath = Join-Path $repoRootPath "releases/v0.2.0/release-evidence/vi-history-suite-0.2.0.vsix"
$bundlePath = Join-Path $repoRootPath "artifacts/fixtures/labview-icon-editor-develop-e8945de7.bundle"

if (-not (Test-Path -LiteralPath $manifestPath)) {
  $manifestPath = $fallbackManifestPath
}

Assert-PathPresent -Path $manifestPath -Message "Public setup manifest was not found at $manifestPath."
Assert-PathPresent -Path $setupScriptPath -Message "Windows setup script was not found at $setupScriptPath."
Assert-PathPresent -Path $vsixPath -Message "Exact VSIX was not found at $vsixPath."
Assert-PathPresent -Path $bundlePath -Message "Pinned fixture bundle was not found at $bundlePath."

$windowsPowerShell = Get-Command powershell.exe -ErrorAction SilentlyContinue
if (-not $windowsPowerShell) {
  throw "powershell.exe was not found, so the public setup smoke test cannot exercise the Windows adapter."
}

$tempId = "VI History Suite Public Setup " + [guid]::NewGuid().ToString("N")

if ($IsWindows) {
  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) $tempId
  $workRoot = Join-Path $tempRoot "work-root"
  $installRoot = Join-Path $tempRoot "install-root"
  $setupScriptInvocationPath = $setupScriptPath
  $manifestPathForInvocation = $manifestPath
  $vsixPathForInvocation = $vsixPath
  $bundlePathForInvocation = $bundlePath
  $workRootForInvocation = $workRoot
  $installRootForInvocation = $installRoot
} else {
  $windowsTempRoot = (& $windowsPowerShell.Source -NoProfile -Command '$env:TEMP' | Select-Object -First 1).Trim()
  if (-not $windowsTempRoot) {
    throw "Failed to resolve the Windows TEMP directory."
  }

  $tempRootWindows = "{0}\\{1}" -f $windowsTempRoot.TrimEnd('\'), $tempId
  $tempRoot = Convert-WindowsPathToWsl -Path $tempRootWindows
  $workRoot = Join-Path $tempRoot "work-root"
  $installRoot = Join-Path $tempRoot "install-root"
  $stagingRoot = Join-Path $tempRoot "staging"
  $stagedSetupScriptPath = Stage-LocalFileForWindowsInvocation -SourcePath $setupScriptPath -DestinationDirectory $stagingRoot
  $stagedManifestPath = Stage-LocalFileForWindowsInvocation -SourcePath $manifestPath -DestinationDirectory $stagingRoot
  $stagedVsixPath = Stage-LocalFileForWindowsInvocation -SourcePath $vsixPath -DestinationDirectory $stagingRoot
  $stagedBundlePath = Stage-LocalFileForWindowsInvocation -SourcePath $bundlePath -DestinationDirectory $stagingRoot
  $setupScriptInvocationPath = (wslpath -w $stagedSetupScriptPath)
  $manifestPathForInvocation = (wslpath -w $stagedManifestPath)
  $vsixPathForInvocation = (wslpath -w $stagedVsixPath)
  $bundlePathForInvocation = (wslpath -w $stagedBundlePath)
  $workRootForInvocation = "$tempRootWindows\work-root"
  $installRootForInvocation = "$tempRootWindows\install-root"
}

try {
  & $windowsPowerShell.Source `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $setupScriptInvocationPath `
    -ManifestPath $manifestPathForInvocation `
    -ExecutionTarget host-machine `
    -WorkRoot $workRootForInvocation `
    -InstallRoot $installRootForInvocation `
    -VsixPath $vsixPathForInvocation `
    -FixtureBundlePath $bundlePathForInvocation

  if ($LASTEXITCODE -ne 0) {
    throw "Windows public setup adapter smoke test failed with exit code $LASTEXITCODE."
  }

  $recordPath = Join-Path $workRoot "setup-record.json"
  Assert-PathPresent -Path $recordPath -Message "Setup record was not created at $recordPath."
  $record = Read-JsonFile -Path $recordPath
  if ($record.release.tag -ne "v0.2.0") {
    throw "Setup record did not retain the expected release tag."
  }

  $selectionPath = $record.fixture.selectionPath
  if ((-not $IsWindows) -and ($selectionPath -match '^[A-Za-z]:\\')) {
    $selectionPath = Convert-WindowsPathToWsl -Path $selectionPath
  }

  Assert-PathPresent -Path $selectionPath -Message "Pinned fixture selection was not materialized at $selectionPath."
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "Public setup fixture smoke test passed."
