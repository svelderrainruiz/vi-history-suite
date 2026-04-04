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

function Read-JsonFile {
  param([string]$Path)

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
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

function Convert-WindowsPathToWsl {
  param([string]$Path)

  if ($Path -match '^([A-Za-z]):\\(.*)$') {
    $drive = $Matches[1].ToLowerInvariant()
    $rest = $Matches[2] -replace '\\', '/'
    return "/mnt/$drive/$rest"
  }

  throw "Unable to convert Windows path '$Path' to a WSL path."
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$contractPath = Join-Path $repoRootPath "releases/v0.2.0/release-ingestion.json"
$fixtureManifestPath = Join-Path $repoRootPath "fixtures/labview-icon-editor.manifest.json"
$bundleSyncScriptPath = Join-Path $repoRootPath "scripts/Sync-PinnedFixtureBundle.ps1"
$harnessScriptPath = Join-Path $repoRootPath "installer/nsis/Invoke-HarnessBootstrap.ps1"

Assert-PathPresent -Path $contractPath -Message "Release contract was not found at $contractPath."
Assert-PathPresent -Path $fixtureManifestPath -Message "Fixture manifest was not found at $fixtureManifestPath."
Assert-PathPresent -Path $bundleSyncScriptPath -Message "Bundle sync script was not found at $bundleSyncScriptPath."
Assert-PathPresent -Path $harnessScriptPath -Message "Harness bootstrap script was not found at $harnessScriptPath."

& $bundleSyncScriptPath -RepoRoot $repoRootPath

$fixtureManifest = Read-JsonFile -Path $fixtureManifestPath
$bundlePath = Join-Path $repoRootPath $fixtureManifest.bundle.defaultGeneratedRelativePath
Assert-PathPresent -Path $bundlePath -Message "Pinned fixture bundle was not found at $bundlePath."

$windowsPowerShell = Get-Command powershell.exe -ErrorAction SilentlyContinue
$tempId = "VI History Suite Harness Fixture " + [guid]::NewGuid().ToString("N")

if ($IsWindows) {
  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) $tempId
  $installRoot = Join-Path $tempRoot "install-root"
  $contractRoot = Join-Path $installRoot "contracts"
  $fixturesRoot = Join-Path $installRoot "fixtures"
  $logsRoot = Join-Path $installRoot "logs"
  $scriptsRoot = Join-Path $installRoot "scripts"
  $harnessScriptInvocationPath = Join-Path $scriptsRoot "Invoke-HarnessBootstrap.ps1"
  $installRootForInvocation = $installRoot
  $releaseContractPathForInvocation = Join-Path $contractRoot "release-ingestion.json"
  $fixtureManifestPathForInvocation = Join-Path $fixturesRoot "labview-icon-editor.manifest.json"
  $logsRootForInvocation = $logsRoot
} else {
  if (-not $windowsPowerShell) {
    throw "powershell.exe was not found, so the fixture smoke test cannot exercise the harness under Windows PowerShell."
  }

  $windowsTempRoot = (& $windowsPowerShell.Source -NoProfile -Command '$env:TEMP' | Select-Object -First 1).Trim()
  if (-not $windowsTempRoot) {
    throw "Failed to resolve the Windows TEMP directory."
  }

  $tempRootWindows = "{0}\\{1}" -f $windowsTempRoot.TrimEnd('\'), $tempId
  $tempRoot = Convert-WindowsPathToWsl -Path $tempRootWindows
  $installRoot = Join-Path $tempRoot "install-root"
  $contractRoot = Join-Path $installRoot "contracts"
  $fixturesRoot = Join-Path $installRoot "fixtures"
  $logsRoot = Join-Path $installRoot "logs"
  $scriptsRoot = Join-Path $installRoot "scripts"
  $harnessScriptInvocationPath = "$tempRootWindows\install-root\scripts\Invoke-HarnessBootstrap.ps1"
  $installRootForInvocation = "$tempRootWindows\install-root"
  $releaseContractPathForInvocation = "$tempRootWindows\install-root\contracts\release-ingestion.json"
  $fixtureManifestPathForInvocation = "$tempRootWindows\install-root\fixtures\labview-icon-editor.manifest.json"
  $logsRootForInvocation = "$tempRootWindows\install-root\logs"
}

try {
  New-Item -ItemType Directory -Force -Path $contractRoot | Out-Null
  New-Item -ItemType Directory -Force -Path $fixturesRoot | Out-Null
  New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null
  New-Item -ItemType Directory -Force -Path $scriptsRoot | Out-Null

  Copy-Item -LiteralPath $contractPath -Destination (Join-Path $contractRoot "release-ingestion.json") -Force
  Copy-Item -LiteralPath $fixtureManifestPath -Destination (Join-Path $fixturesRoot "labview-icon-editor.manifest.json") -Force
  Copy-Item -LiteralPath $bundlePath -Destination (Join-Path $fixturesRoot $fixtureManifest.bundle.fileName) -Force
  Copy-Item -LiteralPath $harnessScriptPath -Destination (Join-Path $scriptsRoot "Invoke-HarnessBootstrap.ps1") -Force

  if ($IsWindows) {
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCommand) {
      $gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
    }
    if (-not $gitCommand) {
      throw "Git executable was not found on the workflow runner."
    }

    $gitCommandPathForInvocation = $gitCommand.Source
  } else {
    $gitCommandPathForInvocation = (& $windowsPowerShell.Source -NoProfile -Command '(Get-Command git.exe -ErrorAction SilentlyContinue).Source' | Select-Object -First 1).Trim()
    if (-not $gitCommandPathForInvocation) {
      throw "Windows git.exe was not found for the fixture smoke test."
    }
  }

  & $windowsPowerShell.Source `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $harnessScriptInvocationPath `
    -InstallRoot $installRootForInvocation `
    -ReleaseContractPath $releaseContractPathForInvocation `
    -FixtureManifestPath $fixtureManifestPathForInvocation `
    -GitCommand $gitCommandPathForInvocation `
    -LogRoot $logsRootForInvocation `
    -SkipDockerDesktopPreparation

  if ($LASTEXITCODE -ne 0) {
    throw "Harness bootstrap fixture smoke test failed with exit code $LASTEXITCODE."
  }

  $summaryPath = Join-Path $logsRoot "harness-bootstrap-summary.json"
  Assert-PathPresent -Path $summaryPath -Message "Harness bootstrap summary was not created at $summaryPath."
  $summary = Read-JsonFile -Path $summaryPath
  if ($summary.status -ne "success") {
    throw "Harness bootstrap fixture smoke test did not report success."
  }

  $selectionPath = Join-Path $installRoot ("fixtures-workspace\" + $fixtureManifest.repositoryName + "\" + ($fixtureManifest.selectionPath -replace '/', '\'))
  Assert-PathPresent -Path $selectionPath -Message "Pinned fixture selection was not materialized at $selectionPath."
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "Harness fixture bootstrap smoke test passed."
