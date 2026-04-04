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

function Assert-Matches {
  param(
    [string]$Value,
    [string]$Pattern,
    [string]$Message
  )

  if ($Value -notmatch $Pattern) {
    throw $Message
  }
}

function Test-PowerShellSyntax {
  param([string]$Path)

  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) {
    $details = ($errors | ForEach-Object { $_.Message }) -join "; "
    throw "PowerShell parse errors in ${Path}: $details"
  }
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$releaseDir = Join-Path $repoRootPath "releases/v0.2.0"
$releaseContractPath = Join-Path $releaseDir "release-ingestion.json"
$fixtureManifestPath = Join-Path $repoRootPath "fixtures/labview-icon-editor.manifest.json"
$releaseContract = Read-JsonFile -Path $releaseContractPath
$fixtureManifest = Read-JsonFile -Path $fixtureManifestPath

Assert-PathPresent -Path $releaseContractPath -Message "Missing immutable release contract at $releaseContractPath."
Assert-PathPresent -Path $fixtureManifestPath -Message "Missing pinned fixture manifest at $fixtureManifestPath."

if ($releaseContract.schemaVersion -lt 3) {
  throw "Release contract schemaVersion must be at least 3."
}

if ($releaseContract.sourceTruth.releaseTag -ne "v0.2.0") {
  throw "Expected releaseTag v0.2.0 in the immutable release contract."
}

if ($releaseContract.builderContract.releaseContractId -ne "v0.2.0") {
  throw "builderContract.releaseContractId must remain aligned with v0.2.0."
}

Assert-Matches -Value $releaseContract.sourceTruth.releaseManifest.vsixArtifact.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "VSIX SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $releaseContract.builderContract.toolchainReferences.nsis.bootstrapInstaller.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Pinned NSIS bootstrap installer SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $releaseContract.builderContract.runtimeBootstrapInstallers.vscode.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Pinned Visual Studio Code bootstrap installer SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $releaseContract.builderContract.runtimeBootstrapInstallers.git.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Pinned Git bootstrap installer SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $releaseContract.builderContract.toolchainReferences.nsis.bootstrapInstaller.downloadUrl.ToString() -Pattern '^https://.+' -Message "Pinned NSIS bootstrap installer downloadUrl must be an https URL."
Assert-Matches -Value $releaseContract.builderContract.runtimeBootstrapInstallers.vscode.downloadUrl.ToString() -Pattern '^https://.+' -Message "Pinned Visual Studio Code bootstrap installer downloadUrl must be an https URL."
Assert-Matches -Value $releaseContract.builderContract.runtimeBootstrapInstallers.git.downloadUrl.ToString() -Pattern '^https://.+' -Message "Pinned Git bootstrap installer downloadUrl must be an https URL."

foreach ($required in $releaseContract.builderContract.stagingRequirements.requiredBeforeInstallerBuild) {
  $path = Join-Path $repoRootPath $required.relativePath
  Assert-PathPresent -Path $path -Message "Missing staged release-evidence path required by the contract: $($required.relativePath)"
}

$requiredPaths = @(
  "README.md",
  "INSTALL.md",
  "SUPPORT.md",
  ".github/workflows/publish-windows-installer.yml",
  "installer/nsis/README.md",
  "installer/nsis/vi-history-suite-installer.nsi",
  "docker/windows-installer-builder/README.md",
  "docker/windows-installer-builder/Dockerfile",
  "docker/windows-installer-builder/Fetch-WorkflowBootstrapInputs.ps1",
  "docker/windows-installer-builder/Invoke-InstallerBuild.ps1",
  "docker/windows-installer-builder/Stage-NsisBootstrap.ps1",
  "docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1",
  "docker/windows-installer-builder/Stage-GitBootstrap.ps1",
  "docker/windows-installer-builder/vendor/README.md",
  "acceptance/windows11/README.md",
  "acceptance/windows11/Invoke-Windows11Acceptance.ps1",
  "acceptance/windows11/manual-right-click-checklist.md",
  "acceptance/windows11/acceptance-record.template.json",
  "scripts/Sync-ImmutableReleaseEvidence.ps1",
  "scripts/Validate-PublicFacadeScaffold.ps1"
)

foreach ($relativePath in $requiredPaths) {
  Assert-PathPresent -Path (Join-Path $repoRootPath $relativePath) -Message "Missing scaffold surface: $relativePath"
}

foreach ($ps1RelativePath in @(
  "scripts/Validate-PublicFacadeScaffold.ps1",
  "scripts/Sync-ImmutableReleaseEvidence.ps1",
  "docker/windows-installer-builder/Fetch-WorkflowBootstrapInputs.ps1",
  "docker/windows-installer-builder/Invoke-InstallerBuild.ps1",
  "docker/windows-installer-builder/Stage-NsisBootstrap.ps1",
  "docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1",
  "docker/windows-installer-builder/Stage-GitBootstrap.ps1",
  "acceptance/windows11/Invoke-Windows11Acceptance.ps1"
)) {
  Test-PowerShellSyntax -Path (Join-Path $repoRootPath $ps1RelativePath)
}

if ($fixtureManifest.status -ne "pinned") {
  throw "Fixture manifest must remain pinned."
}

if (-not $fixtureManifest.selectionCommitVerified) {
  throw "Fixture manifest must retain selectionCommitVerified=true."
}

$nsisPath = Join-Path $repoRootPath "installer/nsis/vi-history-suite-installer.nsi"
$nsisContent = Get-Content -LiteralPath $nsisPath -Raw
foreach ($token in @(
  '--install-extension',
  '--uninstall-extension',
  'release-ingestion.json',
  'Visual Studio Code',
  'Git',
  'bootstrap\vscode',
  'bootstrap\git',
  'svelderrainruiz.vi-history-suite'
)) {
  if ($nsisContent -notmatch [regex]::Escape($token)) {
    throw "NSIS scaffold must retain token '$token'."
  }
}

Write-Host "Public facade scaffold validated successfully."
