[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$ReleaseDir = "",
  [string]$OutputDir = "",
  [string]$MakensisPath = "",
  [string]$NsisBootstrapInstaller = "",
  [switch]$KeepStaging
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-PublicRepoRoot {
  param([string]$Path)

  if ($Path) {
    return (Resolve-Path -LiteralPath $Path).Path
  }

  return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\\..")).Path
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

function Resolve-NsisBootstrapInstaller {
  param(
    [string]$RepoRoot,
    [pscustomobject]$Contract,
    [string]$Candidate
  )

  $candidates = @()
  if ($Candidate) {
    $candidates += $Candidate
  }

  $candidates += @(
    (Join-Path $RepoRoot "docker/windows-installer-builder/vendor/$($Contract.builderContract.toolchainReferences.nsis.bootstrapInstaller.fileName)"),
    "C:\Users\sveld\Downloads\$($Contract.builderContract.toolchainReferences.nsis.bootstrapInstaller.fileName)"
  )

  foreach ($path in $candidates | Where-Object { $_ }) {
    if (Test-Path -LiteralPath $path) {
      return (Resolve-Path -LiteralPath $path).Path
    }
  }

  return ""
}

function Resolve-StagedBootstrapInstaller {
  param(
    [string]$RepoRoot,
    [pscustomobject]$BootstrapInstaller,
    [string]$Label
  )

  $path = Join-Path $RepoRoot $BootstrapInstaller.vendorRelativePath
  Assert-PathPresent -Path $path -Message "Missing ${Label} bootstrap installer at $path. Stage it with $($BootstrapInstaller.stageEntrypoint)."

  $resolvedPath = (Resolve-Path -LiteralPath $path).Path
  $actualHash = Get-Sha256 -Path $resolvedPath
  if ($actualHash -ne $BootstrapInstaller.sha256) {
    throw "${Label} bootstrap installer hash mismatch. Expected $($BootstrapInstaller.sha256) but found $actualHash at $resolvedPath."
  }

  return $resolvedPath
}

function Install-NsisBootstrap {
  param(
    [pscustomobject]$Contract,
    [string]$BootstrapInstallerPath
  )

  if (-not $BootstrapInstallerPath) {
    throw "NSIS bootstrap installer path was empty."
  }

  $expectedHash = $Contract.builderContract.toolchainReferences.nsis.bootstrapInstaller.sha256
  $actualHash = Get-Sha256 -Path $BootstrapInstallerPath
  if ($actualHash -ne $expectedHash) {
    throw "NSIS bootstrap installer hash mismatch. Expected $expectedHash but found $actualHash."
  }

  Write-Host "Installing NSIS bootstrap reference from $BootstrapInstallerPath"
  $process = Start-Process -FilePath $BootstrapInstallerPath -ArgumentList '/S' -Wait -PassThru -NoNewWindow
  if ($process.ExitCode -ne 0) {
    throw "NSIS bootstrap installer failed with exit code $($process.ExitCode)."
  }
}

function Resolve-MakensisPath {
  param(
    [pscustomobject]$Contract,
    [string]$RepoRoot,
    [string]$Candidate,
    [string]$BootstrapInstallerPath
  )

  $candidates = @()
  if ($Candidate) {
    $candidates += $Candidate
  }

  if ($env:MAKENSIS_PATH) {
    $candidates += $env:MAKENSIS_PATH
  }

  if ($env:ProgramFiles) {
    $candidates += (Join-Path $env:ProgramFiles "NSIS\makensis.exe")
  }

  if (${env:ProgramFiles(x86)}) {
    $candidates += (Join-Path ${env:ProgramFiles(x86)} "NSIS\makensis.exe")
  }

  foreach ($path in $candidates | Where-Object { $_ }) {
    if (Test-Path -LiteralPath $path) {
      return (Resolve-Path -LiteralPath $path).Path
    }
  }

  $command = Get-Command makensis.exe -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  if ($BootstrapInstallerPath) {
    Install-NsisBootstrap -Contract $Contract -BootstrapInstallerPath $BootstrapInstallerPath

    $installedCandidates = @()
    if ($env:ProgramFiles) {
      $installedCandidates += (Join-Path $env:ProgramFiles "NSIS\makensis.exe")
    }
    if (${env:ProgramFiles(x86)}) {
      $installedCandidates += (Join-Path ${env:ProgramFiles(x86)} "NSIS\makensis.exe")
    }

    foreach ($path in $installedCandidates) {
      if (Test-Path -LiteralPath $path) {
        return (Resolve-Path -LiteralPath $path).Path
      }
    }

    $command = Get-Command makensis.exe -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }

  throw "makensis.exe was not found. Supply -MakensisPath, stage the NSIS bootstrap installer, or bake NSIS into the Windows builder image."
}

function Assert-ExactVsix {
  param(
    [pscustomobject]$Contract,
    [string]$ReleaseRoot
  )

  $relativeVsixPath = $Contract.sourceTruth.releaseManifest.vsixArtifact.path
  $vsixPath = Join-Path $ReleaseRoot $relativeVsixPath
  Assert-PathPresent -Path $vsixPath -Message "Missing immutable VSIX staging artifact at $vsixPath."

  $actualHash = Get-Sha256 -Path $vsixPath
  $expectedHash = $Contract.sourceTruth.releaseManifest.vsixArtifact.sha256
  if ($actualHash -ne $expectedHash) {
    throw "Exact VSIX hash mismatch. Expected $expectedHash but found $actualHash at $vsixPath."
  }

  return $vsixPath
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$releaseDirPath = if ($ReleaseDir) { (Resolve-Path -LiteralPath $ReleaseDir).Path } else { Join-Path $repoRootPath "releases/v0.2.0" }
$releaseContractPath = Join-Path $releaseDirPath "release-ingestion.json"
$releaseContract = Read-JsonFile -Path $releaseContractPath

foreach ($required in $releaseContract.builderContract.stagingRequirements.requiredBeforeInstallerBuild) {
  Assert-PathPresent -Path (Join-Path $repoRootPath $required.relativePath) -Message "Missing required release-evidence path: $($required.relativePath)"
}

$vsixPath = Assert-ExactVsix -Contract $releaseContract -ReleaseRoot $releaseDirPath
$nsisBootstrapInstallerPath = Resolve-NsisBootstrapInstaller -RepoRoot $repoRootPath -Contract $releaseContract -Candidate $NsisBootstrapInstaller
$vsCodeBootstrapInstallerPath = Resolve-StagedBootstrapInstaller -RepoRoot $repoRootPath -BootstrapInstaller $releaseContract.builderContract.runtimeBootstrapInstallers.vscode -Label "Visual Studio Code"
$gitBootstrapInstallerPath = Resolve-StagedBootstrapInstaller -RepoRoot $repoRootPath -BootstrapInstaller $releaseContract.builderContract.runtimeBootstrapInstallers.git -Label "Git"
$makensis = Resolve-MakensisPath -Contract $releaseContract -RepoRoot $repoRootPath -Candidate $MakensisPath -BootstrapInstallerPath $nsisBootstrapInstallerPath
$outputDirPath = if ($OutputDir) { [IO.Path]::GetFullPath($OutputDir) } else { Join-Path $repoRootPath "artifacts/windows-installer" }
Ensure-Directory -Path $outputDirPath

$packageVersion = $releaseContract.sourceTruth.releaseManifest.packageVersion
$stageRoot = Join-Path $outputDirPath ("staging-{0}" -f ([guid]::NewGuid().ToString("N")))
$payloadRoot = Join-Path $stageRoot "payload"
$bootstrapRoot = Join-Path $stageRoot "bootstrap"
$vsCodeBootstrapRoot = Join-Path $bootstrapRoot "vscode"
$gitBootstrapRoot = Join-Path $bootstrapRoot "git"
$docsRoot = Join-Path $stageRoot "docs"
$contractsRoot = Join-Path $stageRoot "contracts"
$installerRelativePath = $releaseContract.builderContract.installerBuild.defaultOutputRelativePath
$installerFileName = Split-Path -Leaf $installerRelativePath
$installerPath = Join-Path $outputDirPath $installerFileName
$buildMetadataPath = Join-Path $outputDirPath (Split-Path -Leaf $releaseContract.builderContract.installerBuild.defaultBuildMetadataRelativePath)
$checksumPath = Join-Path $outputDirPath "SHA256SUMS.txt"
$nsisScriptPath = Join-Path $repoRootPath $releaseContract.builderContract.installerBuild.nsisProject

Ensure-Directory -Path $payloadRoot
Ensure-Directory -Path $vsCodeBootstrapRoot
Ensure-Directory -Path $gitBootstrapRoot
Ensure-Directory -Path $docsRoot
Ensure-Directory -Path $contractsRoot

Copy-Item -LiteralPath $vsixPath -Destination (Join-Path $payloadRoot (Split-Path -Leaf $vsixPath)) -Force
Copy-Item -LiteralPath $vsCodeBootstrapInstallerPath -Destination (Join-Path $vsCodeBootstrapRoot (Split-Path -Leaf $vsCodeBootstrapInstallerPath)) -Force
Copy-Item -LiteralPath $gitBootstrapInstallerPath -Destination (Join-Path $gitBootstrapRoot (Split-Path -Leaf $gitBootstrapInstallerPath)) -Force
foreach ($doc in @("README.md", "INSTALL.md", "SUPPORT.md", "LICENSE")) {
  Copy-Item -LiteralPath (Join-Path $repoRootPath $doc) -Destination (Join-Path $docsRoot $doc) -Force
}
Copy-Item -LiteralPath $releaseContractPath -Destination (Join-Path $contractsRoot "release-ingestion.json") -Force

$makensisArgs = @(
  "/DPRODUCT_NAME=VI History Suite",
  "/DPRODUCT_VERSION=$packageVersion",
  "/DEXTENSION_IDENTIFIER=$($releaseContract.builderContract.extensionIdentifier)",
  "/DVSCODE_BOOTSTRAP_FILE=$($releaseContract.builderContract.runtimeBootstrapInstallers.vscode.fileName)",
  "/DGIT_BOOTSTRAP_FILE=$($releaseContract.builderContract.runtimeBootstrapInstallers.git.fileName)",
  "/DSTAGING_ROOT=$stageRoot",
  "/DOUTPUT_FILE=$installerPath",
  $nsisScriptPath
)

Write-Host "Building public installer from immutable release contract $($releaseContract.builderContract.releaseContractId)."
& $makensis @makensisArgs
if ($LASTEXITCODE -ne 0) {
  throw "makensis.exe failed with exit code $LASTEXITCODE."
}

$installerHash = Get-Sha256 -Path $installerPath
@("$installerHash *$installerFileName") | Set-Content -LiteralPath $checksumPath -Encoding ASCII

$metadata = [ordered]@{
  releaseContractId = $releaseContract.builderContract.releaseContractId
  packageVersion = $packageVersion
  extensionIdentifier = $releaseContract.builderContract.extensionIdentifier
  installer = [ordered]@{
    fileName = $installerFileName
    path = $installerPath
    sha256 = $installerHash
  }
  immutableVsix = [ordered]@{
    fileName = Split-Path -Leaf $vsixPath
    path = $vsixPath
    sha256 = $releaseContract.sourceTruth.releaseManifest.vsixArtifact.sha256
  }
  sourceTruth = [ordered]@{
    provider = $releaseContract.sourceTruth.provider
    releaseTag = $releaseContract.sourceTruth.releaseTag
    tagPipelineId = $releaseContract.sourceTruth.tagPipelineId
    releaseJobId = $releaseContract.sourceTruth.releaseJobId
    commitSha = $releaseContract.sourceTruth.releaseManifest.commitSha
  }
  toolchain = [ordered]@{
    makensisPath = $makensis
    nsisBootstrapInstaller = $nsisBootstrapInstallerPath
    nsisBootstrapInstallerSha256 = if ($nsisBootstrapInstallerPath) { (Get-Sha256 -Path $nsisBootstrapInstallerPath) } else { "" }
  }
  runtimeBootstrapInstallers = [ordered]@{
    vscode = [ordered]@{
      path = $vsCodeBootstrapInstallerPath
      sha256 = $releaseContract.builderContract.runtimeBootstrapInstallers.vscode.sha256
    }
    git = [ordered]@{
      path = $gitBootstrapInstallerPath
      sha256 = $releaseContract.builderContract.runtimeBootstrapInstallers.git.sha256
    }
  }
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}
$metadata | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $buildMetadataPath -Encoding ASCII

if (-not $KeepStaging.IsPresent -and (Test-Path -LiteralPath $stageRoot)) {
  Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Installer created: $installerPath"
Write-Host "Build metadata: $buildMetadataPath"
Write-Host "Checksums: $checksumPath"
