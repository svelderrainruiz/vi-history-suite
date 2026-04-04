[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$SourcePath = "C:\Users\sveld\Downloads\Docker Desktop Installer.exe",
  [string]$DestinationPath = "",
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-PublicRepoRoot {
  param([string]$Path)

  if ($Path) {
    return (Resolve-Path -LiteralPath $Path).Path
  }

  return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
}

function Read-JsonFile {
  param([string]$Path)

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
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

function Resolve-PathOrLiteral {
  param([string]$Path)

  if (Test-Path -LiteralPath $Path) {
    return (Resolve-Path -LiteralPath $Path).Path
  }

  return [IO.Path]::GetFullPath($Path)
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$releaseContractPath = Join-Path $repoRootPath "releases/v0.2.0/release-ingestion.json"
$releaseContract = Read-JsonFile -Path $releaseContractPath
$bootstrapContract = $releaseContract.builderContract.runtimeBootstrapInstallers.dockerDesktop
$expectedName = $bootstrapContract.fileName
$expectedHash = $bootstrapContract.sha256

$sourcePathResolved = Resolve-PathOrLiteral -Path $SourcePath
if (-not (Test-Path -LiteralPath $sourcePathResolved)) {
  throw "Docker Desktop bootstrap installer not found at $sourcePathResolved."
}

$destinationPathResolved = if ($DestinationPath) {
  [IO.Path]::GetFullPath($DestinationPath)
} else {
  Join-Path $repoRootPath $bootstrapContract.vendorRelativePath
}

Ensure-Directory -Path (Split-Path -Parent $destinationPathResolved)

if ((-not $Force.IsPresent) -and (Test-Path -LiteralPath $destinationPathResolved)) {
  throw "Destination already exists at $destinationPathResolved. Use -Force to overwrite."
}

$actualName = Split-Path -Leaf $sourcePathResolved
if ($actualName -ne $expectedName) {
  throw "Unexpected Docker Desktop bootstrap installer name '$actualName'. Expected '$expectedName'."
}

$actualHash = Get-Sha256 -Path $sourcePathResolved
if ($actualHash -ne $expectedHash) {
  throw "Unexpected Docker Desktop bootstrap installer hash. Expected $expectedHash but found $actualHash."
}

Copy-Item -LiteralPath $sourcePathResolved -Destination $destinationPathResolved -Force

$metadataPath = [IO.Path]::ChangeExtension($destinationPathResolved, ".json")
$metadata = [ordered]@{
  fileName = $expectedName
  sha256 = $expectedHash
  sourcePath = $sourcePathResolved
  destinationPath = $destinationPathResolved
  stagedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}
$metadata | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $metadataPath -Encoding ASCII

Write-Host "Staged Docker Desktop bootstrap installer at $destinationPathResolved"
Write-Host "Metadata written to $metadataPath"
