[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$FixtureManifestPath = "",
  [string]$OutputPath = "",
  [switch]$Force
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

function Resolve-GitCommand {
  foreach ($candidate in @("git", "git.exe")) {
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }

  throw "Git command was not found. The pinned fixture bundle sync requires Git on the build host."
}

function Invoke-Git {
  param(
    [string]$GitCommand,
    [string[]]$CommandArgs
  )

  $mergedOutput = & $GitCommand @CommandArgs 2>&1
  $exitCode = $LASTEXITCODE

  foreach ($line in @($mergedOutput)) {
    if ($null -ne $line -and "$line".Length -gt 0) {
      Write-Host $line
    }
  }

  if ($exitCode -ne 0) {
    throw "$GitCommand $($CommandArgs -join ' ') failed with exit code $exitCode."
  }
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$fixtureManifestResolvedPath = if ($FixtureManifestPath) {
  (Resolve-Path -LiteralPath $FixtureManifestPath).Path
} else {
  Join-Path $repoRootPath "fixtures/labview-icon-editor.manifest.json"
}
$fixtureManifest = Read-JsonFile -Path $fixtureManifestResolvedPath
$gitCommand = Resolve-GitCommand

$bundleOutputPath = if ($OutputPath) {
  [IO.Path]::GetFullPath($OutputPath)
} else {
  Join-Path $repoRootPath $fixtureManifest.bundle.defaultGeneratedRelativePath
}
$metadataPath = [IO.Path]::ChangeExtension($bundleOutputPath, ".json")

if ((-not $Force.IsPresent) -and (Test-Path -LiteralPath $bundleOutputPath) -and (Test-Path -LiteralPath $metadataPath)) {
  $metadata = Read-JsonFile -Path $metadataPath
  if (
    $metadata.fixtureId -eq $fixtureManifest.fixtureId -and
    $metadata.commitSha -eq $fixtureManifest.reference.commitSha -and
    $metadata.branch -eq $fixtureManifest.reference.branch -and
    $metadata.repositoryUrl -eq $fixtureManifest.repositoryUrl
  ) {
    Write-Host "Pinned fixture bundle already staged at $bundleOutputPath"
    return
  }
}

Ensure-Directory -Path (Split-Path -Parent $bundleOutputPath)

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("vi-history-suite-fixture-" + [guid]::NewGuid().ToString("N"))
$mirrorPath = Join-Path $tempRoot "labview-icon-editor.git"
Ensure-Directory -Path $tempRoot

try {
  Invoke-Git -GitCommand $gitCommand -CommandArgs @("clone", "--mirror", $fixtureManifest.repositoryUrl, $mirrorPath)
  Invoke-Git -GitCommand $gitCommand -CommandArgs @("-C", $mirrorPath, "fetch", "--all", "--tags", "--force")

  $bundleBranchRef = "refs/heads/$($fixtureManifest.reference.branch)"
  $resolvedCommit = (& $gitCommand -C $mirrorPath rev-parse "$($fixtureManifest.reference.commitSha)^{commit}").Trim()
  if ($LASTEXITCODE -ne 0) {
    throw "Pinned fixture commit $($fixtureManifest.reference.commitSha) was not found in $($fixtureManifest.repositoryUrl)."
  }

  & $gitCommand -C $mirrorPath merge-base --is-ancestor $resolvedCommit $bundleBranchRef
  if ($LASTEXITCODE -ne 0) {
    throw "Pinned fixture commit $resolvedCommit is not reachable from $bundleBranchRef."
  }

  if (Test-Path -LiteralPath $bundleOutputPath) {
    Remove-Item -LiteralPath $bundleOutputPath -Force
  }

  Invoke-Git -GitCommand $gitCommand -CommandArgs @("-C", $mirrorPath, "bundle", "create", $bundleOutputPath, $bundleBranchRef)
  Invoke-Git -GitCommand $gitCommand -CommandArgs @("-C", $mirrorPath, "bundle", "verify", $bundleOutputPath)

  $metadata = [ordered]@{
    fixtureId = $fixtureManifest.fixtureId
    repositoryUrl = $fixtureManifest.repositoryUrl
    branch = $fixtureManifest.reference.branch
    commitSha = $resolvedCommit
    selectionPath = $fixtureManifest.selectionPath
    bundleFileName = Split-Path -Leaf $bundleOutputPath
    bundlePath = $bundleOutputPath
    sha256 = (Get-Sha256 -Path $bundleOutputPath)
    stagedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  }
  $metadata | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $metadataPath -Encoding ASCII
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "Pinned fixture bundle staged at $bundleOutputPath"
Write-Host "Metadata written to $metadataPath"
