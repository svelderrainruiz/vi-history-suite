[CmdletBinding()]
param(
  [ValidateSet("host-machine")]
  [string]$ExecutionTarget = "host-machine",
  [string]$ReleaseTag = "v0.2.0",
  [string]$RepoRoot = "",
  [string]$PublicSetupManifestPath = "",
  [string]$SetupScriptPath = "",
  [string]$VsixPath = "",
  [string]$FixtureBundlePath = "",
  [string]$WorkRoot = "",
  [string]$CodeCommand = "",
  [switch]$SkipSetup,
  [switch]$SkipClone
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$isWindowsPlatform = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

function Resolve-OptionalPublicRepoRoot {
  param([string]$Path)

  if ($Path) {
    return (Resolve-Path -LiteralPath $Path).Path
  }

  $defaultPath = Join-Path $PSScriptRoot "..\.."
  if (Test-Path -LiteralPath $defaultPath) {
    return (Resolve-Path -LiteralPath $defaultPath).Path
  }

  return ""
}

function Read-JsonFile {
  param([string]$Path)

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Ensure-Directory {
  param([string]$Path)

  New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Convert-WindowsPathToWsl {
  param([string]$Path)

  if ($Path -match '^([A-Za-z]):\\(.*)$') {
    $drive = $Matches[1].ToLowerInvariant()
    $rest = $Matches[2] -replace '\\', '/'
    return "/mnt/$drive/$rest"
  }

  throw "Unable to convert Windows path '$Path' to a WSL path."
}

function Stage-LocalFileForWindowsInvocation {
  param(
    [string]$SourcePath,
    [string]$DestinationDirectory
  )

  if (-not $SourcePath) {
    return ""
  }

  if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "Staging source file was not found at $SourcePath."
  }

  Ensure-Directory -Path $DestinationDirectory
  $destinationPath = Join-Path $DestinationDirectory (Split-Path -Leaf $SourcePath)
  Copy-Item -LiteralPath $SourcePath -Destination $destinationPath -Force
  return $destinationPath
}

function Resolve-WindowsInvocationPath {
  param([string]$Path)

  if (-not $Path) {
    return ""
  }

  if ($Path -match '^[A-Za-z]:\\') {
    return $Path
  }

  if (Test-Path -LiteralPath $Path) {
    return (wslpath -w (Resolve-Path -LiteralPath $Path).Path)
  }

  if ($Path.StartsWith('/')) {
    return (wslpath -w $Path)
  }

  return $Path
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

function Ensure-DownloadedFile {
  param(
    [string]$Url,
    [string]$DestinationPath,
    [string]$ExpectedSha256 = ""
  )

  Ensure-Directory -Path (Split-Path -Parent $DestinationPath)

  $needsDownload = $true
  if (Test-Path -LiteralPath $DestinationPath) {
    if ($ExpectedSha256) {
      if ((Get-Sha256 -Path $DestinationPath) -eq $ExpectedSha256) {
        $needsDownload = $false
      } else {
        Remove-Item -LiteralPath $DestinationPath -Force
      }
    } else {
      $needsDownload = $false
    }
  }

  if ($needsDownload) {
    Invoke-WebRequest -Uri $Url -OutFile $DestinationPath
  }

  if ($ExpectedSha256) {
    $actualSha256 = Get-Sha256 -Path $DestinationPath
    if ($actualSha256 -ne $ExpectedSha256) {
      throw "Downloaded file hash mismatch for $DestinationPath. Expected $ExpectedSha256 but found $actualSha256."
    }
  }

  return (Resolve-Path -LiteralPath $DestinationPath).Path
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

  throw "Visual Studio Code CLI was not found after setup."
}

function Resolve-GitCommand {
  $candidates = @(
    "git",
    "git.exe"
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

  throw "Git executable was not found after setup."
}

function Resolve-WorkRootPath {
  param(
    [string]$RequestedPath,
    [string]$ExecutionTargetName
  )

  if ($RequestedPath) {
    return [IO.Path]::GetFullPath($RequestedPath)
  }

  if (-not $env:LocalAppData) {
    throw "LocalAppData is required to resolve the default Windows acceptance work root."
  }

  return Join-Path $env:LocalAppData ("VI History Suite\acceptance\{0}" -f $ExecutionTargetName)
}

function Resolve-LocalOrDownloadedSetupManifest {
  param(
    [string]$CandidatePath,
    [string]$RepoRootPath,
    [string]$Tag,
    [string]$DownloadsRoot
  )

  if ($CandidatePath) {
    return (Resolve-Path -LiteralPath $CandidatePath).Path
  }

  if ($RepoRootPath) {
    $localPath = Join-Path $RepoRootPath ("releases\{0}\public-setup-manifest.json" -f $Tag)
    if (Test-Path -LiteralPath $localPath) {
      return (Resolve-Path -LiteralPath $localPath).Path
    }
  }

  $url = "https://github.com/svelderrainruiz/vi-history-suite/releases/download/{0}/public-setup-manifest.json" -f $Tag
  return Ensure-DownloadedFile -Url $url -DestinationPath (Join-Path $DownloadsRoot "public-setup-manifest.json")
}

function Resolve-LocalOrDownloadedSetupScript {
  param(
    [string]$CandidatePath,
    [string]$RepoRootPath,
    [pscustomobject]$Manifest,
    [string]$DownloadsRoot
  )

  if ($CandidatePath) {
    return (Resolve-Path -LiteralPath $CandidatePath).Path
  }

  if ($RepoRootPath) {
    $localPath = Join-Path $RepoRootPath "setup/windows/Setup-VIHistorySuite.ps1"
    if (Test-Path -LiteralPath $localPath) {
      return (Resolve-Path -LiteralPath $localPath).Path
    }
  }

  return Ensure-DownloadedFile `
    -Url $Manifest.assets.windowsSetupScript.downloadUrl `
    -DestinationPath (Join-Path $DownloadsRoot $Manifest.assets.windowsSetupScript.fileName) `
    -ExpectedSha256 $Manifest.assets.windowsSetupScript.sha256
}

if (-not $isWindowsPlatform) {
  $windowsPowerShell = Get-Command powershell.exe -ErrorAction SilentlyContinue
  if (-not $windowsPowerShell) {
    throw "powershell.exe was not found, so the Windows acceptance harness cannot be exercised from this environment."
  }

  $windowsTempRoot = (& $windowsPowerShell.Source -NoProfile -Command '$env:TEMP' | Select-Object -First 1).Trim()
  if (-not $windowsTempRoot) {
    throw "Failed to resolve the Windows TEMP directory."
  }

  $stagingId = "VI History Suite Acceptance " + [guid]::NewGuid().ToString("N")
  $stagingRootWindows = "{0}\\{1}" -f $windowsTempRoot.TrimEnd('\'), $stagingId
  $stagingRoot = Convert-WindowsPathToWsl -Path $stagingRootWindows
  $stagingAssetsRoot = Join-Path $stagingRoot "staged-assets"
  Ensure-Directory -Path $stagingAssetsRoot

  $scriptSelfPath = (Resolve-Path -LiteralPath $PSCommandPath).Path
  $stagedScriptPath = Stage-LocalFileForWindowsInvocation -SourcePath $scriptSelfPath -DestinationDirectory $stagingAssetsRoot
  $stagedManifestPath = Stage-LocalFileForWindowsInvocation -SourcePath $PublicSetupManifestPath -DestinationDirectory $stagingAssetsRoot
  $stagedSetupScriptPath = Stage-LocalFileForWindowsInvocation -SourcePath $SetupScriptPath -DestinationDirectory $stagingAssetsRoot
  $stagedVsixPath = Stage-LocalFileForWindowsInvocation -SourcePath $VsixPath -DestinationDirectory $stagingAssetsRoot
  $stagedFixtureBundlePath = Stage-LocalFileForWindowsInvocation -SourcePath $FixtureBundlePath -DestinationDirectory $stagingAssetsRoot

  $arguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', (wslpath -w $stagedScriptPath),
    '-ExecutionTarget', $ExecutionTarget,
    '-ReleaseTag', $ReleaseTag,
    '-WorkRoot', $(if ($WorkRoot) { Resolve-WindowsInvocationPath -Path $WorkRoot } else { "$stagingRootWindows\\acceptance-work-root" })
  )

  if ($stagedManifestPath) {
    $arguments += @('-PublicSetupManifestPath', (wslpath -w $stagedManifestPath))
  }

  if ($stagedSetupScriptPath) {
    $arguments += @('-SetupScriptPath', (wslpath -w $stagedSetupScriptPath))
  }

  if ($stagedVsixPath) {
    $arguments += @('-VsixPath', (wslpath -w $stagedVsixPath))
  }

  if ($stagedFixtureBundlePath) {
    $arguments += @('-FixtureBundlePath', (wslpath -w $stagedFixtureBundlePath))
  }

  if ($CodeCommand) {
    $arguments += @('-CodeCommand', $CodeCommand)
  }

  if ($SkipSetup.IsPresent) {
    $arguments += '-SkipSetup'
  }

  if ($SkipClone.IsPresent) {
    $arguments += '-SkipClone'
  }

  & $windowsPowerShell.Source @arguments
  exit $LASTEXITCODE
}

$repoRootPath = Resolve-OptionalPublicRepoRoot -Path $RepoRoot
$workRootPath = Resolve-WorkRootPath -RequestedPath $WorkRoot -ExecutionTargetName $ExecutionTarget
Ensure-Directory -Path $workRootPath
$downloadsRootPath = Join-Path $workRootPath "downloads"
$setupWorkRoot = Join-Path $workRootPath "setup"
$setupInstallRoot = Join-Path $setupWorkRoot "install-root"
Ensure-Directory -Path $downloadsRootPath
Ensure-Directory -Path $setupWorkRoot
Ensure-Directory -Path $setupInstallRoot

$setupManifestResolvedPath = Resolve-LocalOrDownloadedSetupManifest -CandidatePath $PublicSetupManifestPath -RepoRootPath $repoRootPath -Tag $ReleaseTag -DownloadsRoot $downloadsRootPath
$setupManifest = Read-JsonFile -Path $setupManifestResolvedPath

$codeVersionLogPath = Join-Path $workRootPath "cli-code-version.txt"
$gitVersionLogPath = Join-Path $workRootPath "cli-git-version.txt"
$extensionsLogPath = Join-Path $workRootPath "cli-extensions.txt"
$workspaceLogPath = Join-Path $workRootPath "workspace-launch.txt"
$selectionLogPath = Join-Path $workRootPath "selection-launch.txt"
$acceptanceRecordPath = Join-Path $workRootPath "acceptance-record.json"

$setupRecord = $null
$setupScriptResolvedPath = ""
$setupScriptResolvedPath = Resolve-LocalOrDownloadedSetupScript -CandidatePath $SetupScriptPath -RepoRootPath $repoRootPath -Manifest $setupManifest -DownloadsRoot $downloadsRootPath
$localVsixPath = if ($VsixPath) { (Resolve-Path -LiteralPath $VsixPath).Path } else { "" }
$localFixtureBundlePath = if ($FixtureBundlePath) { (Resolve-Path -LiteralPath $FixtureBundlePath).Path } else { "" }
if ($repoRootPath) {
  $candidateVsixPath = Join-Path $repoRootPath ("releases\{0}\release-evidence\{1}" -f $setupManifest.release.tag, $setupManifest.assets.vsix.fileName)
  if ((-not $localVsixPath) -and (Test-Path -LiteralPath $candidateVsixPath)) {
    $localVsixPath = (Resolve-Path -LiteralPath $candidateVsixPath).Path
  }

  $candidateFixtureBundlePath = Join-Path $repoRootPath ("artifacts\fixtures\{0}" -f $setupManifest.fixture.bundle.fileName)
  if ((-not $localFixtureBundlePath) -and (Test-Path -LiteralPath $candidateFixtureBundlePath)) {
    $localFixtureBundlePath = (Resolve-Path -LiteralPath $candidateFixtureBundlePath).Path
  }
}

if (-not $SkipSetup.IsPresent) {
  $setupArguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $setupScriptResolvedPath,
    '-ManifestPath', $setupManifestResolvedPath,
    '-ExecutionTarget', $ExecutionTarget,
    '-WorkRoot', $setupWorkRoot,
    '-InstallRoot', $setupInstallRoot,
    '-VsixPath', $localVsixPath,
    '-FixtureBundlePath', $localFixtureBundlePath,
    '-OpenWorkspace'
  )

  if ($CodeCommand) {
    $setupArguments += @('-CodeCommand', $CodeCommand)
  }

  & powershell.exe @setupArguments

  if ($LASTEXITCODE -ne 0) {
    throw "Direct-release setup failed with exit code $LASTEXITCODE."
  }
}

$setupRecordPath = Join-Path $setupWorkRoot "setup-record.json"
Assert-PathPresent -Path $setupRecordPath -Message "Setup record was not found at $setupRecordPath."
$setupRecord = Read-JsonFile -Path $setupRecordPath

$codeCommandPath = Resolve-CodeCommand -Candidate $CodeCommand
$gitCommandPath = Resolve-GitCommand

Push-Location -LiteralPath $workRootPath
try {
  & $codeCommandPath --version 2>&1 | Set-Content -LiteralPath $codeVersionLogPath -Encoding ASCII
  if ($LASTEXITCODE -ne 0) {
    throw "VS Code CLI version check failed with exit code $LASTEXITCODE."
  }

  & $gitCommandPath --version 2>&1 | Set-Content -LiteralPath $gitVersionLogPath -Encoding ASCII
  if ($LASTEXITCODE -ne 0) {
    throw "Git version check failed with exit code $LASTEXITCODE."
  }

  $extensionsOutput = & $codeCommandPath --list-extensions --show-versions 2>&1
  $extensionsOutput | Set-Content -LiteralPath $extensionsLogPath -Encoding ASCII
  $expectedToken = "{0}@{1}" -f $setupManifest.release.extensionIdentifier, $setupManifest.release.version
  if ($extensionsOutput -notcontains $expectedToken) {
    if (-not (($extensionsOutput -join "`n") -match [regex]::Escape($expectedToken))) {
      throw "Expected installed extension token '$expectedToken' was not found in VS Code CLI output."
    }
  }

  $fixtureWorkspacePath = $setupRecord.fixture.workspacePath
  $selectionPath = $setupRecord.fixture.selectionPath
  Assert-PathPresent -Path $fixtureWorkspacePath -Message "Pinned proof workspace was not found at $fixtureWorkspacePath."
  Assert-PathPresent -Path $selectionPath -Message "Pinned canonical VI was not found at $selectionPath."

  & $codeCommandPath --new-window $fixtureWorkspacePath 2>&1 | Set-Content -LiteralPath $workspaceLogPath -Encoding ASCII
  $workspaceExitCode = $LASTEXITCODE
  & $codeCommandPath --goto $selectionPath 2>&1 | Set-Content -LiteralPath $selectionLogPath -Encoding ASCII
  $selectionExitCode = $LASTEXITCODE

  $record = [ordered]@{
    releaseContractId = $setupManifest.release.id
    executionEnvironment = [ordered]@{
      target = $ExecutionTarget
      setupStrategy = $setupManifest.setup.strategy
      workRoot = $workRootPath
      publicSetupManifestPath = $setupManifestResolvedPath
      setupScriptPath = $setupScriptResolvedPath
      computerName = $env:COMPUTERNAME
      userName = $env:USERNAME
    }
    expectedExtension = [ordered]@{
      identifier = $setupManifest.release.extensionIdentifier
      version = $setupManifest.release.version
    }
    setup = [ordered]@{
      manifestPath = $setupManifestResolvedPath
      setupScriptPath = $setupScriptResolvedPath
      setupRecordPath = if ($setupRecord) { (Join-Path $setupWorkRoot "setup-record.json") } else { "" }
      directRelease = $true
    }
    fixture = [ordered]@{
      fixtureId = $setupManifest.fixture.id
      repositoryUrl = $setupManifest.fixture.repositoryUrl
      commitSha = $setupManifest.fixture.commitSha
      bundledWorkspacePath = $fixtureWorkspacePath
      bundledBundlePath = if ($setupRecord) { $setupRecord.assets.fixtureBundlePath } else { "" }
      selectionPath = $setupManifest.fixture.selectionPath
    }
    automation = [ordered]@{
      codeCommand = $codeCommandPath
      gitCommand = $gitCommandPath
      codeVersionLogPath = $codeVersionLogPath
      gitVersionLogPath = $gitVersionLogPath
      installedExtensionToken = $expectedToken
      extensionsLogPath = $extensionsLogPath
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
  Write-Host ("Windows 11 acceptance completed for {0} using direct-release. Record: {1}" -f $ExecutionTarget, $acceptanceRecordPath)
} finally {
  Pop-Location
}
