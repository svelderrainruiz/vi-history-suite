[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$ReleaseDir = "",
  [string]$GitLabToken = ""
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

function ConvertTo-ProjectPathId {
  param([string]$ProjectPath)

  return [System.Uri]::EscapeDataString($ProjectPath)
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$releaseDirPath = if ($ReleaseDir) { (Resolve-Path -LiteralPath $ReleaseDir).Path } else { Join-Path $repoRootPath "releases/v0.2.0" }
$releaseContractPath = Join-Path $releaseDirPath "release-ingestion.json"
$releaseContract = Read-JsonFile -Path $releaseContractPath

$token = if ($GitLabToken) { $GitLabToken } elseif ($env:VI_HISTORY_SUITE_GITLAB_API_TOKEN) { $env:VI_HISTORY_SUITE_GITLAB_API_TOKEN } else { "" }
if (-not $token) {
  throw "GitLab API token was not provided. Supply -GitLabToken or set VI_HISTORY_SUITE_GITLAB_API_TOKEN."
}

$projectId = ConvertTo-ProjectPathId -ProjectPath $releaseContract.sourceTruth.projectPath
$jobId = $releaseContract.sourceTruth.releaseJobId
$artifactZipPath = Join-Path ([System.IO.Path]::GetTempPath()) "vi-history-suite-release-artifacts-$jobId.zip"
$artifactUri = "https://gitlab.com/api/v4/projects/$projectId/jobs/$jobId/artifacts"

Invoke-WebRequest -Headers @{ "PRIVATE-TOKEN" = $token } -Uri $artifactUri -OutFile $artifactZipPath

$releaseEvidenceRoot = Join-Path $releaseDirPath "release-evidence"
Ensure-Directory -Path $releaseEvidenceRoot

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($artifactZipPath)
try {
  foreach ($entry in $archive.Entries) {
    if (-not $entry.FullName.StartsWith("release-evidence/")) {
      continue
    }

    $relativePath = $entry.FullName.Substring("release-evidence/".Length)
    if (-not $relativePath) {
      continue
    }

    $destinationPath = Join-Path $releaseEvidenceRoot $relativePath
    if ($entry.FullName.EndsWith("/")) {
      Ensure-Directory -Path $destinationPath
      continue
    }

    Ensure-Directory -Path (Split-Path -Parent $destinationPath)
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destinationPath, $true)
  }
} finally {
  $archive.Dispose()
}

$vsixPath = Join-Path $releaseDirPath $releaseContract.sourceTruth.releaseManifest.vsixArtifact.path
$actualHash = Get-Sha256 -Path $vsixPath
$expectedHash = $releaseContract.sourceTruth.releaseManifest.vsixArtifact.sha256
if ($actualHash -ne $expectedHash) {
  throw "Exact VSIX hash mismatch after GitLab artifact sync. Expected $expectedHash but found $actualHash."
}

Write-Host "Synced immutable release evidence from GitLab job $jobId."
Write-Host "Exact VSIX verified at $vsixPath"
