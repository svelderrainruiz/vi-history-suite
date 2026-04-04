[CmdletBinding()]
param(
  [string]$InstallRoot = "",
  [string]$ReleaseContractPath = "",
  [string]$FixtureManifestPath = "",
  [string]$GitCommand = "",
  [string]$LogRoot = "",
  [switch]$SkipDockerDesktopPreparation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:CurrentBootstrapStage = "initialize"

function Resolve-PathOrDefault {
  param(
    [string]$Path,
    [string]$DefaultPath
  )

  $candidate = if ($Path) { $Path } else { $DefaultPath }
  if (-not $candidate) {
    throw "A required path was empty."
  }

  return [IO.Path]::GetFullPath($candidate)
}

function Read-JsonFile {
  param([string]$Path)

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Ensure-Directory {
  param([string]$Path)

  New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Set-BootstrapStage {
  param([string]$Stage)

  $script:CurrentBootstrapStage = $Stage
}

function Resolve-GitCommand {
  param([string]$Candidate)

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

  throw "Git executable was not found. The harness bootstrap cannot materialize the pinned proof workspace."
}

function Resolve-DockerCommand {
  param([switch]$AllowMissing)

  $candidates = @(
    "docker.exe",
    "docker"
  )

  if ($env:ProgramFiles) {
    $candidates += (Join-Path $env:ProgramFiles "Docker\Docker\resources\bin\docker.exe")
  }

  if (${env:ProgramFiles(x86)}) {
    $candidates += (Join-Path ${env:ProgramFiles(x86)} "Docker\Docker\resources\bin\docker.exe")
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

  throw "Docker CLI was not found. Docker Desktop may not be installed correctly."
}

function Resolve-DockerDesktopExecutable {
  param([switch]$AllowMissing)

  $candidates = @()
  if ($env:ProgramFiles) {
    $candidates += (Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe")
  }
  if (${env:ProgramFiles(x86)}) {
    $candidates += (Join-Path ${env:ProgramFiles(x86)} "Docker\Docker\Docker Desktop.exe")
  }

  foreach ($item in $candidates | Where-Object { $_ }) {
    if (Test-Path -LiteralPath $item) {
      return (Resolve-Path -LiteralPath $item).Path
    }
  }

  if ($AllowMissing.IsPresent) {
    return ""
  }

  throw "Docker Desktop executable was not found after bootstrap."
}

function Invoke-ExternalCommand {
  param(
    [string]$FilePath,
    [string[]]$CommandArgs,
    [string]$LogPath,
    [int[]]$AllowedExitCodes = @(0)
  )

  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $rawOutput = & $FilePath @CommandArgs 2>&1
    $output = New-Object System.Collections.Generic.List[string]
    foreach ($item in @($rawOutput)) {
      if ($item -is [System.Management.Automation.ErrorRecord]) {
        $output.Add($item.ToString())
      } elseif ($null -ne $item) {
        $output.Add([string]$item)
      }
    }

    if ($LogPath) {
      $output | Set-Content -LiteralPath $LogPath -Encoding ASCII
    }

    $exitCode = $LASTEXITCODE
    if ($AllowedExitCodes -notcontains $exitCode) {
      $details = ($output | Out-String).Trim()
      if ($details) {
        throw "$FilePath $($CommandArgs -join ' ') failed with exit code $exitCode. Output: $details"
      }

      throw "$FilePath $($CommandArgs -join ' ') failed with exit code $exitCode."
    }

    return [pscustomobject][ordered]@{
      Output = $output
      ExitCode = $exitCode
    }
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
}

function Get-PropertyValueOrDefault {
  param(
    [object]$InputObject,
    [string]$PropertyName,
    [string]$DefaultValue = ""
  )

  $property = $InputObject.PSObject.Properties[$PropertyName]
  if ($property) {
    return [string]$property.Value
  }

  return $DefaultValue
}

function Get-DockerRepoDigestsFromInspectOutput {
  param([string[]]$Output)

  $jsonText = ($Output | Out-String).Trim()
  if (-not $jsonText) {
    return @()
  }

  $parsed = $jsonText | ConvertFrom-Json
  if ($parsed -is [array]) {
    $image = $parsed[0]
  } else {
    $image = $parsed
  }

  if ($null -eq $image -or $null -eq $image.RepoDigests) {
    return @()
  }

  return @($image.RepoDigests | ForEach-Object { [string]$_ })
}

function Wait-ForDockerServer {
  param(
    [string]$DockerCommand,
    [int]$TimeoutSeconds = 600
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $output = & $DockerCommand version --format "{{.Server.Version}}" 2>&1
    if ($LASTEXITCODE -eq 0 -and ($output | Out-String).Trim()) {
      return ($output | Out-String).Trim()
    }

    Start-Sleep -Seconds 5
  }

  throw "Docker server did not become ready within $TimeoutSeconds seconds."
}

function Wait-ForWindowsEngine {
  param(
    [string]$DockerCommand,
    [int]$TimeoutSeconds = 300
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $output = & $DockerCommand info --format "{{.OSType}}" 2>&1
    if ($LASTEXITCODE -eq 0 -and (($output | Out-String).Trim().ToLowerInvariant() -eq "windows")) {
      return
    }

    Start-Sleep -Seconds 5
  }

  throw "Docker Desktop did not switch to the Windows containers engine within $TimeoutSeconds seconds."
}

function Ensure-FixtureWorkspace {
  param(
    [string]$GitCommand,
    [pscustomobject]$FixtureManifest,
    [string]$InstallRoot,
    [string]$LogPath
  )

  $bundlePath = Join-Path $InstallRoot $FixtureManifest.bundle.installerRelativePath
  if (-not (Test-Path -LiteralPath $bundlePath)) {
    throw "Pinned fixture bundle was not found at $bundlePath."
  }

  $workspaceRoot = Join-Path $InstallRoot "fixtures-workspace"
  $workspacePath = Join-Path $workspaceRoot $FixtureManifest.repositoryName
  Ensure-Directory -Path $workspaceRoot

  if (Test-Path -LiteralPath $workspacePath) {
    Remove-Item -LiteralPath $workspacePath -Recurse -Force
  }

  $logLines = New-Object System.Collections.Generic.List[string]
  $logLines.Add("Cloning pinned proof fixture from local bundle: $bundlePath")
  Set-BootstrapStage -Stage "clone-fixture-workspace"
  $cloneResult = Invoke-ExternalCommand -FilePath $GitCommand -CommandArgs @("clone", $bundlePath, $workspacePath) -LogPath ""
  foreach ($line in $cloneResult.Output) {
    $logLines.Add([string]$line)
  }

  Set-BootstrapStage -Stage "checkout-fixture-commit"
  $checkoutResult = Invoke-ExternalCommand -FilePath $GitCommand -CommandArgs @("-C", $workspacePath, "checkout", "--detach", $FixtureManifest.reference.commitSha) -LogPath ""
  foreach ($line in $checkoutResult.Output) {
    $logLines.Add([string]$line)
  }

  Set-BootstrapStage -Stage "verify-fixture-workspace"
  $resolvedHead = ((& $GitCommand -C $workspacePath rev-parse HEAD 2>&1) | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to resolve HEAD for the materialized proof fixture workspace."
  }

  if ($resolvedHead -ne $FixtureManifest.reference.commitSha) {
    throw "Pinned proof fixture workspace resolved HEAD $resolvedHead but expected $($FixtureManifest.reference.commitSha)."
  }

  $selectionPath = Join-Path $workspacePath ($FixtureManifest.selectionPath -replace '/', '\')
  if (-not (Test-Path -LiteralPath $selectionPath)) {
    throw "Pinned proof fixture selection was not found at $selectionPath."
  }

  $logLines.Add("Pinned proof fixture workspace: $workspacePath")
  $logLines.Add("Pinned proof fixture selection: $selectionPath")
  $logLines | Set-Content -LiteralPath $LogPath -Encoding ASCII

  return [pscustomobject][ordered]@{
    WorkspacePath = $workspacePath
    SelectionPath = $selectionPath
    HeadCommit = $resolvedHead
  }
}

function Ensure-DockerDesktopAndImage {
  param(
    [pscustomobject]$ReleaseContract,
    [string]$InstallRoot,
    [string]$LogRoot
  )

  $dockerContract = $ReleaseContract.builderContract.runtimeBootstrapInstallers.dockerDesktop
  $imageContract = $ReleaseContract.builderContract.runtimeContainerImages.labview2026q1Windows
  $dockerInstallerPath = Join-Path $InstallRoot ("bootstrap\docker\" + $dockerContract.fileName)

  $dockerInstallLogPath = Join-Path $LogRoot "docker-desktop-install.txt"
  $dockerDesktopStartLogPath = Join-Path $LogRoot "docker-desktop-start.txt"
  $dockerVersionLogPath = Join-Path $LogRoot "docker-version.txt"
  $dockerEngineLogPath = Join-Path $LogRoot "docker-engine.txt"
  $dockerImagePullLogPath = Join-Path $LogRoot "docker-image-pull.txt"
  $dockerImageInspectLogPath = Join-Path $LogRoot "docker-image-inspect.txt"

  $dockerCommandPath = Resolve-DockerCommand -AllowMissing
  $dockerDesktopPath = Resolve-DockerDesktopExecutable -AllowMissing
  $installExitCode = 0

  if ((-not $dockerCommandPath) -or (-not $dockerDesktopPath)) {
    if (-not (Test-Path -LiteralPath $dockerInstallerPath)) {
      throw "Docker Desktop bootstrap installer was not found at $dockerInstallerPath."
    }

    Set-BootstrapStage -Stage "install-docker-desktop"
    $process = Start-Process -FilePath $dockerInstallerPath -ArgumentList $dockerContract.installArguments -Wait -PassThru -NoNewWindow
    $installExitCode = $process.ExitCode
    @(
      "Installer: $dockerInstallerPath",
      "Arguments: $($dockerContract.installArguments -join ' ')",
      "ExitCode: $installExitCode"
    ) | Set-Content -LiteralPath $dockerInstallLogPath -Encoding ASCII

    if ($installExitCode -eq 3010 -or $installExitCode -eq 1641) {
      return [pscustomobject][ordered]@{
        RebootRequired = $true
        InstallExitCode = $installExitCode
      }
    }

    if ($installExitCode -ne 0) {
      throw "Docker Desktop bootstrap failed with exit code $installExitCode."
    }

    Set-BootstrapStage -Stage "resolve-docker-desktop-after-install"
    $dockerCommandPath = Resolve-DockerCommand
    $dockerDesktopPath = Resolve-DockerDesktopExecutable
  } else {
    @(
      "Docker Desktop already present.",
      "Docker CLI: $dockerCommandPath",
      "Docker Desktop: $dockerDesktopPath",
      "ExitCode: 0"
    ) | Set-Content -LiteralPath $dockerInstallLogPath -Encoding ASCII
  }

  Set-BootstrapStage -Stage "start-docker-desktop"
  $startResult = Invoke-ExternalCommand -FilePath $dockerCommandPath -CommandArgs @("desktop", "start") -LogPath $dockerDesktopStartLogPath -AllowedExitCodes @(0)
  if ($startResult.ExitCode -ne 0) {
    throw "Docker Desktop failed to start."
  }

  Set-BootstrapStage -Stage "wait-for-docker-server"
  $serverVersion = Wait-ForDockerServer -DockerCommand $dockerCommandPath
  @("Docker server version: $serverVersion") | Set-Content -LiteralPath $dockerVersionLogPath -Encoding ASCII

  Set-BootstrapStage -Stage "switch-to-windows-containers"
  Invoke-ExternalCommand -FilePath $dockerCommandPath -CommandArgs @("desktop", "engine", "use", "windows") -LogPath $dockerEngineLogPath -AllowedExitCodes @(0) | Out-Null
  Set-BootstrapStage -Stage "wait-for-windows-containers"
  Wait-ForWindowsEngine -DockerCommand $dockerCommandPath

  Set-BootstrapStage -Stage "inspect-pinned-image"
  $inspectProbe = Invoke-ExternalCommand -FilePath $dockerCommandPath -CommandArgs @("image", "inspect", $imageContract.imageReference) -LogPath "" -AllowedExitCodes @(0, 1, 125)
  $probeRepoDigests = @()
  if ($inspectProbe.ExitCode -eq 0) {
    $probeRepoDigests = Get-DockerRepoDigestsFromInspectOutput -Output $inspectProbe.Output
  }
  $imagePresent = $inspectProbe.ExitCode -eq 0 -and (($probeRepoDigests -join "`n") -match [regex]::Escape($imageContract.repositoryDigestReference))

  if (-not $imagePresent) {
    Set-BootstrapStage -Stage "pull-pinned-image"
    Invoke-ExternalCommand -FilePath $dockerCommandPath -CommandArgs @("pull", $imageContract.imageReference) -LogPath $dockerImagePullLogPath -AllowedExitCodes @(0) | Out-Null
  } else {
    @(
      "Pinned image already present: $($imageContract.imageReference)",
      "Expected repo digest: $($imageContract.repositoryDigestReference)"
    ) | Set-Content -LiteralPath $dockerImagePullLogPath -Encoding ASCII
  }

  Set-BootstrapStage -Stage "verify-pinned-image"
  $inspectResult = Invoke-ExternalCommand -FilePath $dockerCommandPath -CommandArgs @("image", "inspect", $imageContract.imageReference) -LogPath $dockerImageInspectLogPath -AllowedExitCodes @(0)
  $repoDigestsText = (Get-DockerRepoDigestsFromInspectOutput -Output $inspectResult.Output) -join "`n"
  if ($repoDigestsText -notmatch [regex]::Escape($imageContract.repositoryDigestReference)) {
    throw "Pinned LabVIEW Windows container image digest mismatch. Expected $($imageContract.repositoryDigestReference)."
  }

  return [pscustomobject][ordered]@{
    RebootRequired = $false
    InstallExitCode = $installExitCode
    DockerCommand = $dockerCommandPath
    DockerDesktopPath = $dockerDesktopPath
    ServerVersion = $serverVersion
    ImageReference = $imageContract.imageReference
    RepositoryDigest = $imageContract.repositoryDigestReference
    ImageInspectLines = $inspectResult.Output
  }
}

$installRootPath = Resolve-PathOrDefault -Path $InstallRoot -DefaultPath (Join-Path $PSScriptRoot "..")
$releaseContractResolvedPath = Resolve-PathOrDefault -Path $ReleaseContractPath -DefaultPath (Join-Path $installRootPath "contracts\release-ingestion.json")
$fixtureManifestResolvedPath = Resolve-PathOrDefault -Path $FixtureManifestPath -DefaultPath (Join-Path $installRootPath "fixtures\labview-icon-editor.manifest.json")
$logRootPath = Resolve-PathOrDefault -Path $LogRoot -DefaultPath (Join-Path $installRootPath "logs")
Ensure-Directory -Path $logRootPath
$errorLogPath = Join-Path $logRootPath "harness-bootstrap-error.txt"
$summaryPath = Join-Path $logRootPath "harness-bootstrap-summary.json"

try {
  Set-BootstrapStage -Stage "read-release-contract"
  $releaseContract = Read-JsonFile -Path $releaseContractResolvedPath
  Set-BootstrapStage -Stage "read-fixture-manifest"
  $fixtureManifest = Read-JsonFile -Path $fixtureManifestResolvedPath
  Set-BootstrapStage -Stage "resolve-git-command"
  $gitCommandPath = Resolve-GitCommand -Candidate $GitCommand

  Set-BootstrapStage -Stage "prepare-fixture-workspace"
  $fixtureResult = Ensure-FixtureWorkspace -GitCommand $gitCommandPath -FixtureManifest $fixtureManifest -InstallRoot $installRootPath -LogPath (Join-Path $logRootPath "fixture-workspace.txt")
  if ($SkipDockerDesktopPreparation.IsPresent) {
    Set-BootstrapStage -Stage "skip-docker-desktop-preparation"
    $dockerResult = [pscustomobject][ordered]@{
      Skipped = $true
      RebootRequired = $false
      InstallExitCode = 0
    }
  } else {
    Set-BootstrapStage -Stage "prepare-docker-desktop-and-image"
    $dockerResult = Ensure-DockerDesktopAndImage -ReleaseContract $releaseContract -InstallRoot $installRootPath -LogRoot $logRootPath
  }

  Set-BootstrapStage -Stage "write-bootstrap-summary"
  $summary = [ordered]@{
    status = "success"
    stage = $script:CurrentBootstrapStage
    fixture = [ordered]@{
      repositoryUrl = $fixtureManifest.repositoryUrl
      branch = $fixtureManifest.reference.branch
      commitSha = $fixtureResult.HeadCommit
      workspacePath = $fixtureResult.WorkspacePath
      selectionPath = $fixtureResult.SelectionPath
    }
    docker = [ordered]@{
      skipped = [bool](Get-PropertyValueOrDefault -InputObject $dockerResult -PropertyName "Skipped" -DefaultValue "False")
      rebootRequired = $dockerResult.RebootRequired
      installExitCode = $dockerResult.InstallExitCode
      dockerCommand = Get-PropertyValueOrDefault -InputObject $dockerResult -PropertyName "DockerCommand"
      dockerDesktopPath = Get-PropertyValueOrDefault -InputObject $dockerResult -PropertyName "DockerDesktopPath"
      serverVersion = Get-PropertyValueOrDefault -InputObject $dockerResult -PropertyName "ServerVersion"
      imageReference = Get-PropertyValueOrDefault -InputObject $dockerResult -PropertyName "ImageReference"
      repositoryDigest = Get-PropertyValueOrDefault -InputObject $dockerResult -PropertyName "RepositoryDigest"
    }
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  }
  $summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding ASCII

  if ($dockerResult.RebootRequired) {
    Write-Host "Docker Desktop requested a Windows restart before the harness can finish preparing the Windows container engine."
    exit $dockerResult.InstallExitCode
  }

  if ($SkipDockerDesktopPreparation.IsPresent) {
    Write-Host "Harness bootstrap completed with Docker Desktop preparation skipped. Summary: $summaryPath"
    exit 0
  }

  Write-Host "Harness bootstrap completed. Summary: $summaryPath"
} catch {
  $failureMessage = $_.Exception.Message
  @(
    "Stage: $script:CurrentBootstrapStage",
    "Message: $failureMessage",
    "Category: $($_.CategoryInfo.Category)",
    "FullyQualifiedErrorId: $($_.FullyQualifiedErrorId)",
    "ScriptStackTrace:",
    $_.ScriptStackTrace,
    "Position:",
    $_.InvocationInfo.PositionMessage
  ) | Set-Content -LiteralPath $errorLogPath -Encoding ASCII

  $failureSummary = [ordered]@{
    status = "failed"
    stage = $script:CurrentBootstrapStage
    message = $failureMessage
    errorLogPath = $errorLogPath
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  }
  $failureSummary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding ASCII

  Write-Error "Harness bootstrap failed during $($script:CurrentBootstrapStage). See $errorLogPath."
  exit 1
}
