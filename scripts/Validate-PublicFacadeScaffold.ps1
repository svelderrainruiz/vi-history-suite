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

function Test-BashSyntax {
  param([string]$Path)

  $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
  if (-not $bashCommand) {
    return
  }

  & $bashCommand.Source -n $Path
  if ($LASTEXITCODE -ne 0) {
    throw "Bash parse errors in $Path."
  }
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$releaseDir = Join-Path $repoRootPath "releases/v0.2.0"
$releaseContractPath = Join-Path $releaseDir "release-ingestion.json"
$sourcePublicSetupManifestPath = Join-Path $releaseDir "public-setup-manifest.json"
$builtPublicSetupManifestPath = Join-Path $repoRootPath "artifacts/public-setup/public-setup-manifest.json"
$publicSetupManifestPath = if (Test-Path -LiteralPath $builtPublicSetupManifestPath) { $builtPublicSetupManifestPath } else { $sourcePublicSetupManifestPath }
$fixtureManifestPath = Join-Path $repoRootPath "fixtures/labview-icon-editor.manifest.json"

Assert-PathPresent -Path $releaseContractPath -Message "Missing public release ledger at $releaseContractPath."
Assert-PathPresent -Path $sourcePublicSetupManifestPath -Message "Missing source public setup manifest at $sourcePublicSetupManifestPath."
Assert-PathPresent -Path $publicSetupManifestPath -Message "Missing effective public setup manifest at $publicSetupManifestPath."
Assert-PathPresent -Path $fixtureManifestPath -Message "Missing pinned fixture manifest at $fixtureManifestPath."

$releaseContract = Read-JsonFile -Path $releaseContractPath
$publicSetupManifest = Read-JsonFile -Path $publicSetupManifestPath
$fixtureManifest = Read-JsonFile -Path $fixtureManifestPath

if ($releaseContract.schemaVersion -lt 5) {
  throw "Release contract schemaVersion must be at least 5."
}

if ($releaseContract.sourceTruth.releaseTag -ne "v0.2.0") {
  throw "Expected releaseTag v0.2.0 in the public release ledger."
}

if ($releaseContract.publicSetupContract.releaseContractId -ne "v0.2.0") {
  throw "publicSetupContract.releaseContractId must remain aligned with v0.2.0."
}

if ($releaseContract.publicFacadeState.activePublicationWorkflow.path -ne ".github/workflows/publish-public-release-kit.yml") {
  throw "The active publication workflow must be .github/workflows/publish-public-release-kit.yml."
}

$retiredAssets = @(
  "vi-history-suite-setup-0.2.0.exe",
  "SHA256SUMS.txt",
  "vi-history-suite-setup-0.2.0-build.json"
)

foreach ($asset in $retiredAssets) {
  if ($releaseContract.publicFacadeState.retiredPublicAssets -notcontains $asset) {
    throw "Retired public asset '$asset' must remain listed in release-ingestion.json."
  }
}

if ($publicSetupManifest.schemaVersion -lt 1) {
  throw "Public setup manifest schemaVersion must be at least 1."
}

if ($publicSetupManifest.release.id -ne "v0.2.0") {
  throw "Public setup manifest release.id must remain aligned with v0.2.0."
}

if ($publicSetupManifest.release.tag -ne "v0.2.0") {
  throw "Public setup manifest release.tag must remain aligned with v0.2.0."
}

if ($publicSetupManifest.setup.strategy -ne "direct-release-kit") {
  throw "Public setup manifest must keep direct-release-kit as the primary setup strategy."
}

if ($publicSetupManifest.setup.optionalProviders -contains "legacy-nsis-wrapper") {
  throw "legacy-nsis-wrapper must not remain in the public setup manifest optionalProviders."
}

$vsixPath = Join-Path $releaseDir $releaseContract.sourceTruth.releaseManifest.vsixArtifact.path
$fixtureBundlePath = Join-Path $repoRootPath "artifacts/fixtures/$($publicSetupManifest.fixture.bundle.fileName)"
$fixtureMetadataPath = Join-Path $repoRootPath "artifacts/fixtures/$($publicSetupManifest.fixture.metadata.fileName)"
$windowsSetupPath = Join-Path $repoRootPath "setup/windows/Setup-VIHistorySuite.ps1"
$linuxSetupPath = Join-Path $repoRootPath "setup/linux/setup-vi-history-suite.sh"

foreach ($requiredPath in @(
  $vsixPath,
  $fixtureBundlePath,
  $fixtureMetadataPath,
  $windowsSetupPath,
  $linuxSetupPath
)) {
  Assert-PathPresent -Path $requiredPath -Message "Missing required public setup asset at $requiredPath."
}

$actualVsixHash = Get-Sha256 -Path $vsixPath
if ($actualVsixHash -ne $releaseContract.sourceTruth.releaseManifest.vsixArtifact.sha256) {
  throw "VSIX hash mismatch against release-ingestion.json. Expected $($releaseContract.sourceTruth.releaseManifest.vsixArtifact.sha256) but found $actualVsixHash."
}

if ($actualVsixHash -ne $publicSetupManifest.assets.vsix.sha256) {
  throw "VSIX hash mismatch against public-setup-manifest.json. Expected $($publicSetupManifest.assets.vsix.sha256) but found $actualVsixHash."
}

if ((Get-Sha256 -Path $windowsSetupPath) -ne $publicSetupManifest.assets.windowsSetupScript.sha256) {
  throw "Windows setup script hash does not match public-setup-manifest.json."
}

if ((Get-Sha256 -Path $linuxSetupPath) -ne $publicSetupManifest.assets.linuxSetupScript.sha256) {
  throw "Linux setup script hash does not match public-setup-manifest.json."
}

if ((Get-Sha256 -Path $fixtureManifestPath) -ne $publicSetupManifest.fixture.manifest.sha256) {
  throw "Fixture manifest hash does not match public-setup-manifest.json."
}

if ((Get-Sha256 -Path $fixtureBundlePath) -ne $publicSetupManifest.fixture.bundle.sha256) {
  throw "Fixture bundle hash does not match public-setup-manifest.json."
}

if ((Get-Sha256 -Path $fixtureMetadataPath) -ne $publicSetupManifest.fixture.metadata.sha256) {
  throw "Fixture metadata hash does not match public-setup-manifest.json."
}

Assert-Matches -Value $releaseContract.sourceTruth.releaseManifest.vsixArtifact.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "VSIX SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.assets.windowsSetupScript.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Windows setup script SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.assets.linuxSetupScript.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Linux setup script SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.fixture.manifest.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Fixture manifest SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.fixture.bundle.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Fixture bundle SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.fixture.metadata.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Fixture metadata SHA256 must be a lowercase 64-character hex string."

foreach ($url in @(
  $publicSetupManifest.assets.vsix.downloadUrl,
  $publicSetupManifest.assets.windowsSetupScript.downloadUrl,
  $publicSetupManifest.assets.linuxSetupScript.downloadUrl,
  $publicSetupManifest.fixture.manifest.downloadUrl,
  $publicSetupManifest.fixture.bundle.downloadUrl,
  $publicSetupManifest.fixture.metadata.downloadUrl,
  $publicSetupManifest.setup.windows.prerequisites.vscode.downloadUrl,
  $publicSetupManifest.setup.windows.prerequisites.git.downloadUrl
)) {
  Assert-Matches -Value $url.ToString() -Pattern '^https://.+' -Message "Expected https downloadUrl but found '$url'."
}

foreach ($required in $releaseContract.publicSetupContract.releaseEvidenceStaging.requiredBeforePublication) {
  $path = Join-Path $repoRootPath $required.relativePath
  Assert-PathPresent -Path $path -Message "Missing staged release-evidence path required by the public release ledger: $($required.relativePath)"
}

$requiredPaths = @(
  "README.md",
  "INSTALL.md",
  "SUPPORT.md",
  ".github/workflows/publish-public-release-kit.yml",
  "setup/README.md",
  "setup/windows/Setup-VIHistorySuite.ps1",
  "setup/linux/setup-vi-history-suite.sh",
  "fixtures/labview-icon-editor.manifest.json",
  "acceptance/windows11/README.md",
  "acceptance/windows11/Invoke-Windows11Acceptance.ps1",
  "acceptance/windows11/manual-right-click-checklist.md",
  "acceptance/windows11/acceptance-record.template.json",
  "scripts/Sync-ImmutableReleaseEvidence.ps1",
  "scripts/Build-PublicSetupAssets.ps1",
  "scripts/Test-PublicSetupFixture.ps1",
  "scripts/Sync-PinnedFixtureBundle.ps1",
  "scripts/Validate-PublicFacadeScaffold.ps1",
  "releases/v0.2.0/README.md",
  "releases/v0.2.0/release-evidence/README.md",
  "releases/v0.2.0/release-ingestion.json",
  "releases/v0.2.0/public-setup-manifest.json"
)

foreach ($relativePath in $requiredPaths) {
  Assert-PathPresent -Path (Join-Path $repoRootPath $relativePath) -Message "Missing required public facade surface: $relativePath"
}

foreach ($ps1RelativePath in @(
  "scripts/Validate-PublicFacadeScaffold.ps1",
  "scripts/Build-PublicSetupAssets.ps1",
  "scripts/Test-PublicSetupFixture.ps1",
  "scripts/Sync-ImmutableReleaseEvidence.ps1",
  "scripts/Sync-PinnedFixtureBundle.ps1",
  "setup/windows/Setup-VIHistorySuite.ps1",
  "acceptance/windows11/Invoke-Windows11Acceptance.ps1"
)) {
  Test-PowerShellSyntax -Path (Join-Path $repoRootPath $ps1RelativePath)
}

Test-BashSyntax -Path (Join-Path $repoRootPath "setup/linux/setup-vi-history-suite.sh")

if ($fixtureManifest.status -ne "pinned") {
  throw "Fixture manifest must remain pinned."
}

if (-not $fixtureManifest.selectionCommitVerified) {
  throw "Fixture manifest must retain selectionCommitVerified=true."
}

if (-not $fixtureManifest.bundle.fileName.ToString().EndsWith(".bundle")) {
  throw "Fixture manifest bundle.fileName must end with .bundle."
}

Assert-Matches -Value $fixtureManifest.bundle.defaultGeneratedRelativePath.ToString() -Pattern '^artifacts/.+\.bundle$' -Message "Fixture manifest default bundle path must stay under artifacts/ and end with .bundle."

$workflowPath = Join-Path $repoRootPath ".github/workflows/publish-public-release-kit.yml"
$workflowContent = Get-Content -LiteralPath $workflowPath -Raw
foreach ($token in @(
  "./scripts/Sync-ImmutableReleaseEvidence.ps1",
  "./scripts/Sync-PinnedFixtureBundle.ps1",
  "./scripts/Build-PublicSetupAssets.ps1",
  "./scripts/Test-PublicSetupFixture.ps1",
  "gh release delete-asset",
  "SHA256SUMS-public-setup.txt"
)) {
  if ($workflowContent -notmatch [regex]::Escape($token)) {
    throw "Publish workflow must retain token '$token'."
  }
}

foreach ($forbiddenToken in @(
  "publish_legacy_installer",
  "Invoke-InstallerBuild.ps1",
  "Stage-NsisBootstrap.ps1",
  "Fetch-WorkflowBootstrapInputs.ps1",
  "Test-HarnessBootstrapRegression.ps1",
  "Test-HarnessFixtureBootstrap.ps1",
  "artifacts/windows-installer/"
)) {
  if ($workflowContent -match [regex]::Escape($forbiddenToken)) {
    throw "Publish workflow must not retain legacy toolchain token '$forbiddenToken'."
  }
}

$acceptanceScriptPath = Join-Path $repoRootPath "acceptance/windows11/Invoke-Windows11Acceptance.ps1"
$acceptanceScriptContent = Get-Content -LiteralPath $acceptanceScriptPath -Raw
foreach ($token in @(
  "Setup-VIHistorySuite.ps1",
  "--list-extensions",
  "--new-window",
  "--goto",
  "setupStrategy",
  "direct-release"
)) {
  if ($acceptanceScriptContent -notmatch [regex]::Escape($token)) {
    throw "Acceptance harness must retain token '$token'."
  }
}

foreach ($forbiddenToken in @(
  "legacy-installer",
  "InstallerPath",
  "SkipLegacyInstaller"
)) {
  if ($acceptanceScriptContent -match [regex]::Escape($forbiddenToken)) {
    throw "Acceptance harness must not retain legacy installer token '$forbiddenToken'."
  }
}

Write-Host "Public facade scaffold validated successfully."
