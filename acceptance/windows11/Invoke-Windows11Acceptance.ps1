[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$ReleaseDir = "",
  [string]$InstallerPath = "",
  [string]$WorkRoot = "",
  [string]$CodeCommand = "",
  [switch]$SkipInstaller,
  [switch]$SkipClone
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

function Resolve-CodeCommand {
  param([string]$Candidate)

  $candidates = @()
  if ($Candidate) {
    $candidates += $Candidate
  }

  $candidates += @(
    "code.cmd",
    "code"
  )

  if ($env:LocalAppData) {
    $candidates += (Join-Path $env:LocalAppData "Programs\Microsoft VS Code\bin\code.cmd")
  }

  if ($env:ProgramFiles) {
    $candidates += (Join-Path $env:ProgramFiles "Microsoft VS Code\bin\code.cmd")
  }

  foreach ($item in $candidates | Where-Object { $_ }) {
    if (Test-Path -LiteralPath $item) {
      return (Resolve-Path -LiteralPath $item).Path
    }

    $command = Get-Command $item -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }

  throw "Visual Studio Code CLI was not found after installer execution. The Windows acceptance lane expects the fresh-machine bootstrap path to provide code.cmd."
}

function Resolve-GitCommand {
  $candidates = @(
    "git.exe",
    "git"
  )

  if ($env:LocalAppData) {
    $candidates += (Join-Path $env:LocalAppData "Programs\Git\cmd\git.exe")
    $candidates += (Join-Path $env:LocalAppData "Programs\Git\bin\git.exe")
  }

  if ($env:ProgramFiles) {
    $candidates += (Join-Path $env:ProgramFiles "Git\cmd\git.exe")
    $candidates += (Join-Path $env:ProgramFiles "Git\bin\git.exe")
  }

  if (${env:ProgramFiles(x86)}) {
    $candidates += (Join-Path ${env:ProgramFiles(x86)} "Git\cmd\git.exe")
    $candidates += (Join-Path ${env:ProgramFiles(x86)} "Git\bin\git.exe")
  }

  foreach ($item in $candidates | Where-Object { $_ }) {
    if (Test-Path -LiteralPath $item) {
      return (Resolve-Path -LiteralPath $item).Path
    }

    $command = Get-Command $item -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }

  throw "Git executable was not found after installer execution. The Windows acceptance lane requires a real Git-backed workspace."
}

function Invoke-Git {
  param(
    [string]$GitCommand,
    [string[]]$Args
  )

  & $GitCommand @Args
  if ($LASTEXITCODE -ne 0) {
    throw "$GitCommand $($Args -join ' ') failed with exit code $LASTEXITCODE."
  }
}

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$releaseDirPath = if ($ReleaseDir) { (Resolve-Path -LiteralPath $ReleaseDir).Path } else { Join-Path $repoRootPath "releases/v0.2.0" }
$releaseContractPath = Join-Path $releaseDirPath "release-ingestion.json"
$fixtureManifestPath = Join-Path $repoRootPath "fixtures/labview-icon-editor.manifest.json"
$releaseContract = Read-JsonFile -Path $releaseContractPath
$fixtureManifest = Read-JsonFile -Path $fixtureManifestPath

$workRootPath = if ($WorkRoot) { [IO.Path]::GetFullPath($WorkRoot) } else { Join-Path $repoRootPath "artifacts/windows11-acceptance" }
Ensure-Directory -Path $workRootPath

$resolvedInstallerPath = if ($InstallerPath) {
  [IO.Path]::GetFullPath($InstallerPath)
} else {
  Join-Path $repoRootPath $releaseContract.builderContract.installerBuild.defaultOutputRelativePath
}
$automationLogPath = Join-Path $workRootPath "cli-extensions.txt"
$codeVersionLogPath = Join-Path $workRootPath "cli-code-version.txt"
$gitVersionLogPath = Join-Path $workRootPath "cli-git-version.txt"
$workspaceLogPath = Join-Path $workRootPath "workspace-launch.txt"
$selectionLogPath = Join-Path $workRootPath "selection-launch.txt"
$acceptanceRecordPath = Join-Path $workRootPath "acceptance-record.json"
$fixtureRoot = Join-Path $workRootPath "fixture\labview-icon-editor"

if (-not $SkipInstaller.IsPresent) {
  Assert-PathPresent -Path $resolvedInstallerPath -Message "Installer not found at $resolvedInstallerPath."
  & $resolvedInstallerPath "/S"
  if ($LASTEXITCODE -ne 0) {
    throw "Installer execution failed with exit code $LASTEXITCODE."
  }
}

$codeCommandPath = Resolve-CodeCommand -Candidate $CodeCommand
$gitCommandPath = Resolve-GitCommand

& $codeCommandPath --version 2>&1 | Set-Content -LiteralPath $codeVersionLogPath -Encoding ASCII
if ($LASTEXITCODE -ne 0) {
  throw "VS Code CLI version check failed with exit code $LASTEXITCODE."
}

& $gitCommandPath --version 2>&1 | Set-Content -LiteralPath $gitVersionLogPath -Encoding ASCII
if ($LASTEXITCODE -ne 0) {
  throw "Git version check failed with exit code $LASTEXITCODE."
}

$extensionsOutput = & $codeCommandPath --list-extensions --show-versions 2>&1
$extensionsOutput | Set-Content -LiteralPath $automationLogPath -Encoding ASCII
$expectedToken = "{0}@{1}" -f $releaseContract.builderContract.extensionIdentifier, $releaseContract.sourceTruth.releaseManifest.packageVersion
if ($extensionsOutput -notcontains $expectedToken) {
  if (-not (($extensionsOutput -join "`n") -match [regex]::Escape($expectedToken))) {
    throw "Expected installed extension token '$expectedToken' was not found in VS Code CLI output."
  }
}

if (-not $SkipClone.IsPresent) {
  if (-not (Test-Path -LiteralPath $fixtureRoot)) {
    Ensure-Directory -Path (Split-Path -Parent $fixtureRoot)
    Invoke-Git -GitCommand $gitCommandPath -Args @("clone", $fixtureManifest.repositoryUrl, $fixtureRoot)
  }

  Invoke-Git -GitCommand $gitCommandPath -Args @("-C", $fixtureRoot, "fetch", "--all", "--tags", "--force")
  Invoke-Git -GitCommand $gitCommandPath -Args @("-C", $fixtureRoot, "checkout", "--detach", $fixtureManifest.reference.commitSha)
}

$selectionPath = Join-Path $fixtureRoot ($fixtureManifest.selectionPath -replace '/', '\')
Assert-PathPresent -Path $selectionPath -Message "Pinned canonical VI was not found at $selectionPath."

& $codeCommandPath --new-window $fixtureRoot 2>&1 | Set-Content -LiteralPath $workspaceLogPath -Encoding ASCII
$workspaceExitCode = $LASTEXITCODE
& $codeCommandPath --goto $selectionPath 2>&1 | Set-Content -LiteralPath $selectionLogPath -Encoding ASCII
$selectionExitCode = $LASTEXITCODE

$record = [ordered]@{
  releaseContractId = $releaseContract.builderContract.releaseContractId
  expectedExtension = [ordered]@{
    identifier = $releaseContract.builderContract.extensionIdentifier
    version = $releaseContract.sourceTruth.releaseManifest.packageVersion
  }
  installer = [ordered]@{
    path = $resolvedInstallerPath
    sha256 = if (Test-Path -LiteralPath $resolvedInstallerPath) { (Get-Sha256 -Path $resolvedInstallerPath) } else { "" }
    executed = (-not $SkipInstaller.IsPresent)
  }
  fixture = [ordered]@{
    fixtureId = $fixtureManifest.fixtureId
    repositoryUrl = $fixtureManifest.repositoryUrl
    commitSha = $fixtureManifest.reference.commitSha
    selectionPath = $fixtureManifest.selectionPath
  }
  automation = [ordered]@{
    codeCommand = $codeCommandPath
    gitCommand = $gitCommandPath
    codeVersionLogPath = $codeVersionLogPath
    gitVersionLogPath = $gitVersionLogPath
    installedExtensionToken = $expectedToken
    extensionsLogPath = $automationLogPath
    workspaceLaunchExitCode = $workspaceExitCode
    workspaceLaunchLogPath = $workspaceLogPath
    selectionLaunchExitCode = $selectionExitCode
    selectionLaunchLogPath = $selectionLogPath
  }
  humanGate = [ordered]@{
    checklistPath = "acceptance/windows11/manual-right-click-checklist.md"
    recordTemplatePath = "acceptance/windows11/acceptance-record.template.json"
    status = "pending-human-review"
  }
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}

$record | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $acceptanceRecordPath -Encoding ASCII
Write-Host "Windows 11 acceptance scaffold completed. Record: $acceptanceRecordPath"
