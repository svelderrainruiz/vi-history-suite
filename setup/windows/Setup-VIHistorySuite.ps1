[CmdletBinding()]
param(
  [string]$ManifestPath = "",
  [string]$ManifestUrl = "",
  [string]$ReleaseTag = "v0.2.0",
  [ValidateSet("host-machine", "fresh-vm")]
  [string]$ExecutionTarget = "host-machine",
  [string]$WorkRoot = "",
  [string]$InstallRoot = "",
  [string]$VsixPath = "",
  [string]$FixtureBundlePath = "",
  [string]$CodeCommand = "",
  [string]$GitCommand = "",
  [switch]$SkipVsCodeInstall,
  [switch]$SkipGitInstall,
  [switch]$SkipExtensionInstall,
  [switch]$SkipFixtureSetup,
  [switch]$OpenWorkspace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Directory {
  param([string]$Path)

  New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Read-JsonFile {
  param([string]$Path)

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
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

function Resolve-ManifestPath {
  param(
    [string]$LocalPath,
    [string]$RemoteUrl,
    [string]$Tag,
    [string]$DownloadsRoot
  )

  if ($LocalPath) {
    return (Resolve-Path -LiteralPath $LocalPath).Path
  }

  $resolvedUrl = if ($RemoteUrl) {
    $RemoteUrl
  } else {
    "https://github.com/svelderrainruiz/vi-history-suite/releases/download/{0}/public-setup-manifest.json" -f $Tag
  }

  return Ensure-DownloadedFile -Url $resolvedUrl -DestinationPath (Join-Path $DownloadsRoot "public-setup-manifest.json")
}

function Resolve-CodeCommand {
  param(
    [string]$Candidate,
    [switch]$AllowMissing
  )

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

  if ($AllowMissing.IsPresent) {
    return ""
  }

  throw "Visual Studio Code CLI was not found."
}

function Resolve-GitCommand {
  param(
    [string]$Candidate,
    [switch]$AllowMissing
  )

  $candidates = @()
  if ($Candidate) {
    $candidates += $Candidate
  }

  $candidates += @(
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

  if ($AllowMissing.IsPresent) {
    return ""
  }

  throw "Git executable was not found."
}

function Resolve-VerifiedLocalOrDownloadedAsset {
  param(
    [string]$CandidatePath,
    [pscustomobject]$AssetContract,
    [string]$DestinationRoot
  )

  if ($CandidatePath) {
    $resolvedPath = (Resolve-Path -LiteralPath $CandidatePath).Path
    $actualSha256 = Get-Sha256 -Path $resolvedPath
    if ($actualSha256 -ne $AssetContract.sha256) {
      throw "Local asset hash mismatch for $resolvedPath. Expected $($AssetContract.sha256) but found $actualSha256."
    }

    return $resolvedPath
  }

  return Ensure-DownloadedFile `
    -Url $AssetContract.downloadUrl `
    -DestinationPath (Join-Path $DestinationRoot $AssetContract.fileName) `
    -ExpectedSha256 $AssetContract.sha256
}

function Install-Prerequisite {
  param(
    [pscustomobject]$InstallerContract,
    [string]$DownloadsRoot
  )

  $installerPath = Ensure-DownloadedFile `
    -Url $InstallerContract.downloadUrl `
    -DestinationPath (Join-Path $DownloadsRoot $InstallerContract.fileName) `
    -ExpectedSha256 $InstallerContract.sha256

  $process = Start-Process -FilePath $installerPath -ArgumentList @($InstallerContract.silentArguments) -Wait -PassThru -NoNewWindow
  if ($process.ExitCode -ne 0) {
    throw "$($InstallerContract.productName) installer failed with exit code $($process.ExitCode)."
  }

  return $installerPath
}

function Invoke-Git {
  param(
    [string]$GitCommandPath,
    [string[]]$CommandArgs
  )

  $quoteArgument = {
    param([string]$Value)

    if ($null -eq $Value) {
      return '""'
    }

    if ($Value -notmatch '[\s"]') {
      return $Value
    }

    $escapedValue = $Value -replace '(\\*)"', '$1$1\"'
    $escapedValue = $escapedValue -replace '(\\+)$', '$1$1'
    return '"' + $escapedValue + '"'
  }

  $tempRoot = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
  $stdoutPath = Join-Path $tempRoot ("vi-history-suite-git-{0}-stdout.txt" -f [guid]::NewGuid().ToString("N"))
  $stderrPath = Join-Path $tempRoot ("vi-history-suite-git-{0}-stderr.txt" -f [guid]::NewGuid().ToString("N"))
  $argumentLine = ($CommandArgs | ForEach-Object { & $quoteArgument $_ }) -join ' '

  try {
    $process = Start-Process `
      -FilePath $GitCommandPath `
      -ArgumentList $argumentLine `
      -Wait `
      -PassThru `
      -NoNewWindow `
      -RedirectStandardOutput $stdoutPath `
      -RedirectStandardError $stderrPath

    $stdout = if (Test-Path -LiteralPath $stdoutPath) {
      @(Get-Content -LiteralPath $stdoutPath)
    } else {
      @()
    }

    $stderr = if (Test-Path -LiteralPath $stderrPath) {
      @(Get-Content -LiteralPath $stderrPath)
    } else {
      @()
    }

    if ($process.ExitCode -ne 0) {
      $details = @($stdout + $stderr | Where-Object { $_ }) -join [Environment]::NewLine
      if ($details) {
        throw "$GitCommandPath $($CommandArgs -join ' ') failed with exit code $($process.ExitCode). Output: $details"
      }

      throw "$GitCommandPath $($CommandArgs -join ' ') failed with exit code $($process.ExitCode)."
    }

    return @($stdout + $stderr | Where-Object { $_ })
  } finally {
    Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
  }
}

function Materialize-FixtureWorkspace {
  param(
    [string]$GitCommandPath,
    [pscustomobject]$Manifest,
    [string]$BundlePath,
    [string]$DestinationRoot
  )

  $workspaceRoot = Join-Path $DestinationRoot "fixtures-workspace"
  $workspacePath = Join-Path $workspaceRoot $Manifest.fixture.repositoryName
  Ensure-Directory -Path $workspaceRoot

  if (Test-Path -LiteralPath $workspacePath) {
    Remove-Item -LiteralPath $workspacePath -Recurse -Force
  }

  Invoke-Git -GitCommandPath $GitCommandPath -CommandArgs @("clone", $BundlePath, $workspacePath) | Out-Null
  Invoke-Git -GitCommandPath $GitCommandPath -CommandArgs @("-C", $workspacePath, "checkout", "--detach", $Manifest.fixture.commitSha) | Out-Null

  $resolvedHead = ((& $GitCommandPath -C $workspacePath rev-parse HEAD 2>&1) | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to resolve HEAD for the materialized fixture workspace."
  }

  if ($resolvedHead -ne $Manifest.fixture.commitSha) {
    throw "Materialized fixture workspace resolved HEAD $resolvedHead but expected $($Manifest.fixture.commitSha)."
  }

  $selectionPath = Join-Path $workspacePath ($Manifest.fixture.selectionPath -replace '/', '\')
  if (-not (Test-Path -LiteralPath $selectionPath)) {
    throw "Pinned fixture selection was not found at $selectionPath."
  }

  return [pscustomobject][ordered]@{
    WorkspacePath = $workspacePath
    SelectionPath = $selectionPath
    HeadCommit = $resolvedHead
  }
}

if (-not $env:LocalAppData) {
  throw "LocalAppData is required for the Windows setup adapter."
}

$workRootPath = if ($WorkRoot) {
  [IO.Path]::GetFullPath($WorkRoot)
} else {
  Join-Path $env:LocalAppData ("VI History Suite\setup\{0}" -f $ExecutionTarget)
}

$installRootPath = if ($InstallRoot) {
  [IO.Path]::GetFullPath($InstallRoot)
} else {
  Join-Path $env:LocalAppData "Programs\VI History Suite"
}

Ensure-Directory -Path $workRootPath
Ensure-Directory -Path $installRootPath

$downloadsRoot = Join-Path $workRootPath "downloads"
$logsRoot = Join-Path $workRootPath "logs"
$contractsRoot = Join-Path $installRootPath "contracts"
$payloadRoot = Join-Path $installRootPath "payload"
$fixturesRoot = Join-Path $installRootPath "fixtures"
Ensure-Directory -Path $downloadsRoot
Ensure-Directory -Path $logsRoot
Ensure-Directory -Path $contractsRoot
Ensure-Directory -Path $payloadRoot
Ensure-Directory -Path $fixturesRoot

Push-Location -LiteralPath $workRootPath
try {
  $manifestResolvedPath = Resolve-ManifestPath -LocalPath $ManifestPath -RemoteUrl $ManifestUrl -Tag $ReleaseTag -DownloadsRoot $downloadsRoot
  $manifest = Read-JsonFile -Path $manifestResolvedPath

  Copy-Item -LiteralPath $manifestResolvedPath -Destination (Join-Path $contractsRoot "public-setup-manifest.json") -Force

  $vsCodeInstallLogPath = Join-Path $logsRoot "vscode-install.txt"
  $gitInstallLogPath = Join-Path $logsRoot "git-install.txt"
  $codeVersionLogPath = Join-Path $logsRoot "cli-code-version.txt"
  $gitVersionLogPath = Join-Path $logsRoot "cli-git-version.txt"
  $extensionsLogPath = Join-Path $logsRoot "cli-extensions.txt"
  $workspaceLogPath = Join-Path $logsRoot "workspace-launch.txt"
  $selectionLogPath = Join-Path $logsRoot "selection-launch.txt"
  $setupRecordPath = Join-Path $workRootPath "setup-record.json"

  $codeCommandPath = Resolve-CodeCommand -Candidate $CodeCommand -AllowMissing
  if ((-not $codeCommandPath) -and (-not $SkipVsCodeInstall.IsPresent)) {
    $installedVsCodePath = Install-Prerequisite -InstallerContract $manifest.setup.windows.prerequisites.vscode -DownloadsRoot $downloadsRoot
    @(
      "Installer: $installedVsCodePath",
      "Status: installed"
    ) | Set-Content -LiteralPath $vsCodeInstallLogPath -Encoding ASCII
    $codeCommandPath = Resolve-CodeCommand -Candidate $CodeCommand
  } elseif ($codeCommandPath) {
    @(
      "Status: already-present",
      "CodeCommand: $codeCommandPath"
    ) | Set-Content -LiteralPath $vsCodeInstallLogPath -Encoding ASCII
  } else {
    throw "Visual Studio Code CLI was not found and installation was skipped."
  }

  $gitCommandPath = Resolve-GitCommand -Candidate $GitCommand -AllowMissing
  if ((-not $gitCommandPath) -and (-not $SkipGitInstall.IsPresent)) {
    $installedGitPath = Install-Prerequisite -InstallerContract $manifest.setup.windows.prerequisites.git -DownloadsRoot $downloadsRoot
    @(
      "Installer: $installedGitPath",
      "Status: installed"
    ) | Set-Content -LiteralPath $gitInstallLogPath -Encoding ASCII
    $gitCommandPath = Resolve-GitCommand -Candidate $GitCommand
  } elseif ($gitCommandPath) {
    @(
      "Status: already-present",
      "GitCommand: $gitCommandPath"
    ) | Set-Content -LiteralPath $gitInstallLogPath -Encoding ASCII
  } else {
    throw "Git was not found and installation was skipped."
  }

  $vsixPath = Resolve-VerifiedLocalOrDownloadedAsset `
    -CandidatePath $VsixPath `
    -AssetContract $manifest.assets.vsix `
    -DestinationRoot $payloadRoot

  $fixtureBundlePath = Resolve-VerifiedLocalOrDownloadedAsset `
    -CandidatePath $FixtureBundlePath `
    -AssetContract $manifest.fixture.bundle `
    -DestinationRoot $fixturesRoot

  & $codeCommandPath --version 2>&1 | Set-Content -LiteralPath $codeVersionLogPath -Encoding ASCII
  if ($LASTEXITCODE -ne 0) {
    throw "VS Code CLI version check failed with exit code $LASTEXITCODE."
  }

  & $gitCommandPath --version 2>&1 | Set-Content -LiteralPath $gitVersionLogPath -Encoding ASCII
  if ($LASTEXITCODE -ne 0) {
    throw "Git version check failed with exit code $LASTEXITCODE."
  }

  if (-not $SkipExtensionInstall.IsPresent) {
    & $codeCommandPath --install-extension $vsixPath --force 2>&1 | Set-Content -LiteralPath $extensionsLogPath -Encoding ASCII
    if ($LASTEXITCODE -ne 0) {
      throw "VS Code CLI extension installation failed with exit code $LASTEXITCODE."
    }
  } else {
    @("Extension installation skipped.") | Set-Content -LiteralPath $extensionsLogPath -Encoding ASCII
  }

  $extensionsOutput = & $codeCommandPath --list-extensions --show-versions 2>&1
  $extensionsOutput | Add-Content -LiteralPath $extensionsLogPath -Encoding ASCII
  $expectedToken = "{0}@{1}" -f $manifest.release.extensionIdentifier, $manifest.release.version
  if ($extensionsOutput -notcontains $expectedToken) {
    if (-not (($extensionsOutput -join "`n") -match [regex]::Escape($expectedToken))) {
      throw "Expected installed extension token '$expectedToken' was not found in VS Code CLI output."
    }
  }

  $fixtureResult = $null
  if (-not $SkipFixtureSetup.IsPresent) {
    $fixtureResult = Materialize-FixtureWorkspace -GitCommandPath $gitCommandPath -Manifest $manifest -BundlePath $fixtureBundlePath -DestinationRoot $installRootPath
  } else {
    throw "Fixture setup cannot be skipped in the current public setup adapter."
  }

  $workspaceExitCode = 0
  $selectionExitCode = 0
  if ($OpenWorkspace.IsPresent) {
    & $codeCommandPath --new-window $fixtureResult.WorkspacePath 2>&1 | Set-Content -LiteralPath $workspaceLogPath -Encoding ASCII
    $workspaceExitCode = $LASTEXITCODE
    & $codeCommandPath --goto $fixtureResult.SelectionPath 2>&1 | Set-Content -LiteralPath $selectionLogPath -Encoding ASCII
    $selectionExitCode = $LASTEXITCODE
  }

  $record = [ordered]@{
    setupManifestId = $manifest.release.id
    executionEnvironment = [ordered]@{
      target = $ExecutionTarget
      workRoot = $workRootPath
      installRoot = $installRootPath
      manifestPath = $manifestResolvedPath
      computerName = $env:COMPUTERNAME
      userName = $env:USERNAME
    }
    release = [ordered]@{
      tag = $manifest.release.tag
      version = $manifest.release.version
      extensionIdentifier = $manifest.release.extensionIdentifier
    }
    assets = [ordered]@{
      vsixPath = $vsixPath
      vsixSha256 = $manifest.assets.vsix.sha256
      fixtureBundlePath = $fixtureBundlePath
      fixtureBundleSha256 = $manifest.fixture.bundle.sha256
    }
    commands = [ordered]@{
      code = $codeCommandPath
      git = $gitCommandPath
    }
    fixture = [ordered]@{
      fixtureId = $manifest.fixture.id
      repositoryName = $manifest.fixture.repositoryName
      repositoryUrl = $manifest.fixture.repositoryUrl
      branch = $manifest.fixture.branch
      commitSha = $fixtureResult.HeadCommit
      workspacePath = $fixtureResult.WorkspacePath
      selectionPath = $fixtureResult.SelectionPath
    }
    verification = [ordered]@{
      installedExtensionToken = $expectedToken
      codeVersionLogPath = $codeVersionLogPath
      gitVersionLogPath = $gitVersionLogPath
      extensionsLogPath = $extensionsLogPath
      workspaceLaunchExitCode = $workspaceExitCode
      workspaceLaunchLogPath = $workspaceLogPath
      selectionLaunchExitCode = $selectionExitCode
      selectionLaunchLogPath = $selectionLogPath
    }
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  }

  $record | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $setupRecordPath -Encoding ASCII
  Write-Host "Windows setup completed. Record: $setupRecordPath"
} finally {
  Pop-Location
}
