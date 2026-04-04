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
$publicSetupManifestPath = Join-Path $releaseDir "public-setup-manifest.json"
$fixtureManifestPath = Join-Path $repoRootPath "fixtures/labview-icon-editor.manifest.json"
$releaseContract = Read-JsonFile -Path $releaseContractPath
$publicSetupManifest = Read-JsonFile -Path $publicSetupManifestPath
$fixtureManifest = Read-JsonFile -Path $fixtureManifestPath

Assert-PathPresent -Path $releaseContractPath -Message "Missing immutable release contract at $releaseContractPath."
Assert-PathPresent -Path $publicSetupManifestPath -Message "Missing public setup manifest at $publicSetupManifestPath."
Assert-PathPresent -Path $fixtureManifestPath -Message "Missing pinned fixture manifest at $fixtureManifestPath."

if ($releaseContract.schemaVersion -lt 4) {
  throw "Release contract schemaVersion must be at least 4."
}

if ($releaseContract.sourceTruth.releaseTag -ne "v0.2.0") {
  throw "Expected releaseTag v0.2.0 in the immutable release contract."
}

if ($releaseContract.builderContract.releaseContractId -ne "v0.2.0") {
  throw "builderContract.releaseContractId must remain aligned with v0.2.0."
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

Assert-Matches -Value $releaseContract.sourceTruth.releaseManifest.vsixArtifact.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "VSIX SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $releaseContract.builderContract.toolchainReferences.nsis.bootstrapInstaller.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Pinned NSIS bootstrap installer SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $releaseContract.builderContract.runtimeBootstrapInstallers.vscode.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Pinned Visual Studio Code bootstrap installer SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $releaseContract.builderContract.runtimeBootstrapInstallers.git.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Pinned Git bootstrap installer SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $releaseContract.builderContract.runtimeBootstrapInstallers.dockerDesktop.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Pinned Docker Desktop bootstrap installer SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $releaseContract.builderContract.toolchainReferences.nsis.bootstrapInstaller.downloadUrl.ToString() -Pattern '^https://.+' -Message "Pinned NSIS bootstrap installer downloadUrl must be an https URL."
Assert-Matches -Value $releaseContract.builderContract.runtimeBootstrapInstallers.vscode.downloadUrl.ToString() -Pattern '^https://.+' -Message "Pinned Visual Studio Code bootstrap installer downloadUrl must be an https URL."
Assert-Matches -Value $releaseContract.builderContract.runtimeBootstrapInstallers.git.downloadUrl.ToString() -Pattern '^https://.+' -Message "Pinned Git bootstrap installer downloadUrl must be an https URL."
Assert-Matches -Value $releaseContract.builderContract.runtimeBootstrapInstallers.dockerDesktop.downloadUrl.ToString() -Pattern '^https://.+' -Message "Pinned Docker Desktop bootstrap installer downloadUrl must be an https URL."
Assert-Matches -Value $releaseContract.builderContract.runtimeBootstrapInstallers.dockerDesktop.checksumUrl.ToString() -Pattern '^https://.+' -Message "Pinned Docker Desktop bootstrap installer checksumUrl must be an https URL."
Assert-Matches -Value $releaseContract.builderContract.runtimeContainerImages.labview2026q1Windows.expectedDigest.ToString() -Pattern '^sha256:[0-9a-f]{64}$' -Message "Pinned LabVIEW Windows container digest must be a sha256 reference."
Assert-Matches -Value $publicSetupManifest.assets.vsix.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Public setup manifest VSIX SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.assets.windowsSetupScript.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Windows setup script SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.assets.linuxSetupScript.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Linux setup script SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.fixture.bundle.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Fixture bundle SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.fixture.metadata.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Fixture metadata SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.assets.vsix.downloadUrl.ToString() -Pattern '^https://.+' -Message "Public setup manifest VSIX downloadUrl must be an https URL."
Assert-Matches -Value $publicSetupManifest.assets.windowsSetupScript.downloadUrl.ToString() -Pattern '^https://.+' -Message "Windows setup script downloadUrl must be an https URL."
Assert-Matches -Value $publicSetupManifest.assets.linuxSetupScript.downloadUrl.ToString() -Pattern '^https://.+' -Message "Linux setup script downloadUrl must be an https URL."
Assert-Matches -Value $publicSetupManifest.fixture.manifest.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Fixture manifest SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.fixture.manifest.downloadUrl.ToString() -Pattern '^https://.+' -Message "Fixture manifest downloadUrl must be an https URL."
Assert-Matches -Value $publicSetupManifest.fixture.bundle.downloadUrl.ToString() -Pattern '^https://.+' -Message "Fixture bundle downloadUrl must be an https URL."
Assert-Matches -Value $publicSetupManifest.fixture.metadata.downloadUrl.ToString() -Pattern '^https://.+' -Message "Fixture metadata downloadUrl must be an https URL."
Assert-Matches -Value $publicSetupManifest.setup.windows.prerequisites.vscode.downloadUrl.ToString() -Pattern '^https://.+' -Message "Windows VS Code bootstrap downloadUrl must be an https URL."
Assert-Matches -Value $publicSetupManifest.setup.windows.prerequisites.git.downloadUrl.ToString() -Pattern '^https://.+' -Message "Windows Git bootstrap downloadUrl must be an https URL."
Assert-Matches -Value $publicSetupManifest.setup.windows.prerequisites.vscode.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Windows VS Code bootstrap SHA256 must be a lowercase 64-character hex string."
Assert-Matches -Value $publicSetupManifest.setup.windows.prerequisites.git.sha256.ToString() -Pattern '^[0-9a-f]{64}$' -Message "Windows Git bootstrap SHA256 must be a lowercase 64-character hex string."

foreach ($required in $releaseContract.builderContract.stagingRequirements.requiredBeforeInstallerBuild) {
  $path = Join-Path $repoRootPath $required.relativePath
  Assert-PathPresent -Path $path -Message "Missing staged release-evidence path required by the contract: $($required.relativePath)"
}

Assert-PathPresent -Path (Join-Path $repoRootPath $fixtureManifest.bundle.builderEntrypoint) -Message "Missing pinned fixture bundle sync entrypoint."

$requiredPaths = @(
  "README.md",
  "INSTALL.md",
  "SUPPORT.md",
  ".github/workflows/publish-windows-installer.yml",
  "setup/README.md",
  "setup/windows/Setup-VIHistorySuite.ps1",
  "setup/linux/setup-vi-history-suite.sh",
  "installer/nsis/README.md",
  "installer/nsis/Invoke-HarnessBootstrap.ps1",
  "installer/nsis/vi-history-suite-installer.nsi",
  "docker/windows-installer-builder/README.md",
  "docker/windows-installer-builder/Dockerfile",
  "docker/windows-installer-builder/Fetch-WorkflowBootstrapInputs.ps1",
  "docker/windows-installer-builder/Invoke-InstallerBuild.ps1",
  "docker/windows-installer-builder/Stage-NsisBootstrap.ps1",
  "docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1",
  "docker/windows-installer-builder/Stage-GitBootstrap.ps1",
  "docker/windows-installer-builder/Stage-DockerDesktopBootstrap.ps1",
  "docker/windows-installer-builder/vendor/README.md",
  "scripts/Build-HostIterationInstaller.ps1",
  "acceptance/windows11/README.md",
  "acceptance/windows11/Invoke-Windows11Acceptance.ps1",
  "acceptance/windows11/manual-right-click-checklist.md",
  "acceptance/windows11/acceptance-record.template.json",
  "scripts/Sync-ImmutableReleaseEvidence.ps1",
  "scripts/Build-PublicSetupAssets.ps1",
  "scripts/Test-PublicSetupFixture.ps1",
  "scripts/Sync-PinnedFixtureBundle.ps1",
  "scripts/Validate-PublicFacadeScaffold.ps1"
)

foreach ($relativePath in $requiredPaths) {
  Assert-PathPresent -Path (Join-Path $repoRootPath $relativePath) -Message "Missing scaffold surface: $relativePath"
}

foreach ($ps1RelativePath in @(
  "scripts/Validate-PublicFacadeScaffold.ps1",
  "scripts/Build-PublicSetupAssets.ps1",
  "scripts/Test-PublicSetupFixture.ps1",
  "scripts/Sync-ImmutableReleaseEvidence.ps1",
  "scripts/Sync-PinnedFixtureBundle.ps1",
  "docker/windows-installer-builder/Fetch-WorkflowBootstrapInputs.ps1",
  "docker/windows-installer-builder/Invoke-InstallerBuild.ps1",
  "docker/windows-installer-builder/Stage-NsisBootstrap.ps1",
  "docker/windows-installer-builder/Stage-VsCodeBootstrap.ps1",
  "docker/windows-installer-builder/Stage-GitBootstrap.ps1",
  "docker/windows-installer-builder/Stage-DockerDesktopBootstrap.ps1",
  "scripts/Build-HostIterationInstaller.ps1",
  "installer/nsis/Invoke-HarnessBootstrap.ps1",
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

$nsisPath = Join-Path $repoRootPath "installer/nsis/vi-history-suite-installer.nsi"
$nsisContent = Get-Content -LiteralPath $nsisPath -Raw
foreach ($token in @(
  '--install-extension',
  '--uninstall-extension',
  'release-ingestion.json',
  'Visual Studio Code',
  'Git',
  'Docker Desktop',
  'INSTALLER_PROFILE',
  'bootstrap\vscode',
  'bootstrap\git',
  'DOCKER_DESKTOP_BOOTSTRAP_FILE',
  'Invoke-HarnessBootstrap.ps1',
  'svelderrainruiz.vi-history-suite'
)) {
  if ($nsisContent -notmatch [regex]::Escape($token)) {
    throw "NSIS scaffold must retain token '$token'."
  }
}

$harnessScriptPath = Join-Path $repoRootPath "installer/nsis/Invoke-HarnessBootstrap.ps1"
$harnessScriptContent = Get-Content -LiteralPath $harnessScriptPath -Raw
foreach ($token in @(
  'Docker Desktop',
  'host-iteration',
  '"desktop", "engine", "use", "windows"',
  '"image", "inspect"',
  'labview-icon-editor',
  '.bundle',
  'fixtures-workspace'
)) {
  if ($harnessScriptContent -notmatch [regex]::Escape($token)) {
    throw "Harness bootstrap script must retain token '$token'."
  }
}

$builderScriptPath = Join-Path $repoRootPath "docker/windows-installer-builder/Invoke-InstallerBuild.ps1"
$builderScriptContent = Get-Content -LiteralPath $builderScriptPath -Raw
foreach ($token in @(
  'host-iteration',
  'IncludeRuntimeBootstrapInstallers',
  'vi-history-suite-host-iteration-setup-',
  'HOST_ITERATION_PROFILE'
)) {
  if ($builderScriptContent -notmatch [regex]::Escape($token)) {
    throw "Builder script must retain token '$token'."
  }
}

Write-Host "Public facade scaffold validated successfully."
