[CmdletBinding()]
param(
  [string]$RepoRoot = "",
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

function Save-BootstrapInstaller {
  param(
    [string]$DestinationPath,
    [pscustomobject]$Contract
  )

  Ensure-Directory -Path (Split-Path -Parent $DestinationPath)

  if ((-not $Force.IsPresent) -and (Test-Path -LiteralPath $DestinationPath)) {
    $existingHash = Get-Sha256 -Path $DestinationPath
    if ($existingHash -eq $Contract.sha256) {
      Write-Host "Bootstrap installer already staged: $DestinationPath"
      return
    }
  }

  Invoke-WebRequest -Uri $Contract.downloadUrl -OutFile $DestinationPath
  $actualHash = Get-Sha256 -Path $DestinationPath
  if ($actualHash -ne $Contract.sha256) {
    throw "Hash mismatch for $($Contract.fileName). Expected $($Contract.sha256) but found $actualHash."
  }

  $metadataPath = [IO.Path]::ChangeExtension($DestinationPath, ".json")
  $metadata = [ordered]@{
    fileName = $Contract.fileName
    sha256 = $Contract.sha256
    sourceUrl = $Contract.downloadUrl
    destinationPath = $DestinationPath
    stagedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  }
  $metadata | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $metadataPath -Encoding ASCII
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$releaseContractPath = Join-Path $repoRootPath "releases/v0.2.0/release-ingestion.json"
$releaseContract = Read-JsonFile -Path $releaseContractPath

$vsCodeContract = $releaseContract.builderContract.runtimeBootstrapInstallers.vscode
$gitContract = $releaseContract.builderContract.runtimeBootstrapInstallers.git
$dockerDesktopContract = $releaseContract.builderContract.runtimeBootstrapInstallers.dockerDesktop

Save-BootstrapInstaller -DestinationPath (Join-Path $repoRootPath $vsCodeContract.vendorRelativePath) -Contract $vsCodeContract
Save-BootstrapInstaller -DestinationPath (Join-Path $repoRootPath $gitContract.vendorRelativePath) -Contract $gitContract
Save-BootstrapInstaller -DestinationPath (Join-Path $repoRootPath $dockerDesktopContract.vendorRelativePath) -Contract $dockerDesktopContract

Write-Host "Pinned workflow runtime bootstrap inputs are staged and verified."
