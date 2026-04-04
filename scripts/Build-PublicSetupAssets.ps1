[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$OutputRoot = ""
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

function Get-Sha256 {
  param([string]$Path)

  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
      $hashBytes = $sha.ComputeHash($stream)
    } finally {
      $sha.Dispose()
    }
  } finally {
    $stream.Dispose()
  }

  return ([System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLowerInvariant())
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Value
  )

  $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding ASCII
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$outputRootPath = if ($OutputRoot) {
  [IO.Path]::GetFullPath($OutputRoot)
} else {
  Join-Path $repoRootPath "artifacts/public-setup"
}

$manifestPath = Join-Path $repoRootPath "releases/v0.2.0/public-setup-manifest.json"
$fixtureManifestPath = Join-Path $repoRootPath "fixtures/labview-icon-editor.manifest.json"
$bundlePath = Join-Path $repoRootPath "artifacts/fixtures/labview-icon-editor-develop-e8945de7.bundle"
$bundleMetadataPath = Join-Path $repoRootPath "artifacts/fixtures/labview-icon-editor-develop-e8945de7.json"
$windowsSetupPath = Join-Path $repoRootPath "setup/windows/Setup-VIHistorySuite.ps1"
$linuxSetupPath = Join-Path $repoRootPath "setup/linux/setup-vi-history-suite.sh"
$setupReadmePath = Join-Path $repoRootPath "setup/README.md"
$acceptanceAutomationPath = Join-Path $repoRootPath "acceptance/windows11/Invoke-Windows11Acceptance.ps1"
$acceptanceHumanGatePath = Join-Path $repoRootPath "acceptance/windows11/Invoke-Windows11HumanGate.ps1"
$acceptanceChecklistPath = Join-Path $repoRootPath "acceptance/windows11/manual-right-click-checklist.md"
$acceptanceRecordTemplatePath = Join-Path $repoRootPath "acceptance/windows11/acceptance-record.template.json"

foreach ($path in @(
  $manifestPath,
  $fixtureManifestPath,
  $bundlePath,
  $bundleMetadataPath,
  $windowsSetupPath,
  $linuxSetupPath,
  $setupReadmePath,
  $acceptanceAutomationPath,
  $acceptanceHumanGatePath,
  $acceptanceChecklistPath,
  $acceptanceRecordTemplatePath
)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required public setup surface was not found at $path."
  }
}

Ensure-Directory -Path $outputRootPath
Ensure-Directory -Path (Join-Path $outputRootPath "setup/windows")
Ensure-Directory -Path (Join-Path $outputRootPath "setup/linux")
Ensure-Directory -Path (Join-Path $outputRootPath "acceptance/windows11")

Copy-Item -LiteralPath $fixtureManifestPath -Destination (Join-Path $outputRootPath "labview-icon-editor.manifest.json") -Force
Copy-Item -LiteralPath $bundlePath -Destination (Join-Path $outputRootPath "labview-icon-editor-develop-e8945de7.bundle") -Force
Copy-Item -LiteralPath $bundleMetadataPath -Destination (Join-Path $outputRootPath "labview-icon-editor-develop-e8945de7.json") -Force
Copy-Item -LiteralPath $windowsSetupPath -Destination (Join-Path $outputRootPath "setup/windows/Setup-VIHistorySuite.ps1") -Force
Copy-Item -LiteralPath $linuxSetupPath -Destination (Join-Path $outputRootPath "setup/linux/setup-vi-history-suite.sh") -Force
Copy-Item -LiteralPath $setupReadmePath -Destination (Join-Path $outputRootPath "setup/README.md") -Force
Copy-Item -LiteralPath $acceptanceAutomationPath -Destination (Join-Path $outputRootPath "acceptance/windows11/Invoke-Windows11Acceptance.ps1") -Force
Copy-Item -LiteralPath $acceptanceHumanGatePath -Destination (Join-Path $outputRootPath "acceptance/windows11/Invoke-Windows11HumanGate.ps1") -Force
Copy-Item -LiteralPath $acceptanceChecklistPath -Destination (Join-Path $outputRootPath "acceptance/windows11/manual-right-click-checklist.md") -Force
Copy-Item -LiteralPath $acceptanceRecordTemplatePath -Destination (Join-Path $outputRootPath "acceptance/windows11/acceptance-record.template.json") -Force

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.assets.vsix.sha256 = Get-Sha256 -Path (Join-Path $repoRootPath ("releases/{0}/release-evidence/{1}" -f $manifest.release.tag, $manifest.assets.vsix.fileName))
$manifest.assets.windowsSetupScript.sha256 = Get-Sha256 -Path $windowsSetupPath
$manifest.assets.linuxSetupScript.sha256 = Get-Sha256 -Path $linuxSetupPath
$manifest.fixture.manifest.sha256 = Get-Sha256 -Path $fixtureManifestPath
$manifest.fixture.bundle.sha256 = Get-Sha256 -Path $bundlePath
$manifest.fixture.metadata.sha256 = Get-Sha256 -Path $bundleMetadataPath
$manifest.acceptance.windows11.automationScript.sha256 = Get-Sha256 -Path $acceptanceAutomationPath
$manifest.acceptance.windows11.humanGateScript.sha256 = Get-Sha256 -Path $acceptanceHumanGatePath
$manifest.acceptance.windows11.manualChecklist.sha256 = Get-Sha256 -Path $acceptanceChecklistPath
$manifest.acceptance.windows11.acceptanceRecordTemplate.sha256 = Get-Sha256 -Path $acceptanceRecordTemplatePath
Write-JsonFile -Path (Join-Path $outputRootPath "public-setup-manifest.json") -Value $manifest

$checksumLines = foreach ($relativePath in @(
  "public-setup-manifest.json",
  "labview-icon-editor.manifest.json",
  "labview-icon-editor-develop-e8945de7.bundle",
  "labview-icon-editor-develop-e8945de7.json",
  "setup/windows/Setup-VIHistorySuite.ps1",
  "setup/linux/setup-vi-history-suite.sh",
  "acceptance/windows11/Invoke-Windows11Acceptance.ps1",
  "acceptance/windows11/Invoke-Windows11HumanGate.ps1",
  "acceptance/windows11/manual-right-click-checklist.md",
  "acceptance/windows11/acceptance-record.template.json"
)) {
  $path = Join-Path $outputRootPath $relativePath
  "{0} *{1}" -f (Get-Sha256 -Path $path), ($relativePath -replace '\\', '/')
}

$checksumsPath = Join-Path $outputRootPath "SHA256SUMS-public-setup.txt"
$checksumLines | Set-Content -LiteralPath $checksumsPath -Encoding ASCII

Write-Host "Public setup assets staged at $outputRootPath"
Write-Host "Checksums written to $checksumsPath"
