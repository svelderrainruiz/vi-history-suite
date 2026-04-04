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

foreach ($path in @(
  $manifestPath,
  $fixtureManifestPath,
  $bundlePath,
  $bundleMetadataPath,
  $windowsSetupPath,
  $linuxSetupPath,
  $setupReadmePath
)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Required public setup surface was not found at $path."
  }
}

Ensure-Directory -Path $outputRootPath
Ensure-Directory -Path (Join-Path $outputRootPath "setup/windows")
Ensure-Directory -Path (Join-Path $outputRootPath "setup/linux")

Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $outputRootPath "public-setup-manifest.json") -Force
Copy-Item -LiteralPath $fixtureManifestPath -Destination (Join-Path $outputRootPath "labview-icon-editor.manifest.json") -Force
Copy-Item -LiteralPath $bundlePath -Destination (Join-Path $outputRootPath "labview-icon-editor-develop-e8945de7.bundle") -Force
Copy-Item -LiteralPath $bundleMetadataPath -Destination (Join-Path $outputRootPath "labview-icon-editor-develop-e8945de7.json") -Force
Copy-Item -LiteralPath $windowsSetupPath -Destination (Join-Path $outputRootPath "setup/windows/Setup-VIHistorySuite.ps1") -Force
Copy-Item -LiteralPath $linuxSetupPath -Destination (Join-Path $outputRootPath "setup/linux/setup-vi-history-suite.sh") -Force
Copy-Item -LiteralPath $setupReadmePath -Destination (Join-Path $outputRootPath "setup/README.md") -Force

$checksumLines = foreach ($relativePath in @(
  "public-setup-manifest.json",
  "labview-icon-editor.manifest.json",
  "labview-icon-editor-develop-e8945de7.bundle",
  "labview-icon-editor-develop-e8945de7.json",
  "setup/README.md",
  "setup/windows/Setup-VIHistorySuite.ps1",
  "setup/linux/setup-vi-history-suite.sh"
)) {
  $path = Join-Path $outputRootPath $relativePath
  "{0} *{1}" -f (Get-Sha256 -Path $path), ($relativePath -replace '\\', '/')
}

$checksumsPath = Join-Path $outputRootPath "SHA256SUMS-public-setup.txt"
$checksumLines | Set-Content -LiteralPath $checksumsPath -Encoding ASCII

Write-Host "Public setup assets staged at $outputRootPath"
Write-Host "Checksums written to $checksumsPath"
