[CmdletBinding()]
param(
  [string]$InstallRoot = "",
  [string]$ReleaseContractPath = "",
  [string]$FixtureManifestPath = "",
  [string]$GitCommand = "",
  [string]$LogRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
    [string[]]$Args,
    [string]$LogPath,
    [int[]]$AllowedExitCodes = @(0)
  )

  $output = & $FilePath @Args 2>&1
  if ($LogPath) {
    $output | Set-Content -LiteralPath $LogPath -Encoding ASCII
  }

  $exitCode = $LASTEXITCODE
  if ($AllowedExitCodes -notcontains $exitCode) {
    throw "$FilePath $($Args -join ' ') failed with exit code $exitCode."
  }

  return [ordered]@{
    Output = $output
    ExitCode = $exitCode
  }
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
  $cloneResult = Invoke-ExternalCommand -FilePath $GitCommand -Args @("clone", $bundlePath, $workspacePath) -LogPath ""
  foreach ($line in $cloneResult.Output) {
    $logLines.Add([string]$line)
  }

  $checkoutResult = Invoke-ExternalCommand -FilePath $GitCommand -Args @("-C", $workspacePath, "checkout", "--detach", $FixtureManifest.reference.commitSha) -LogPath ""
  foreach ($line in $checkoutResult.Output) {
    $logLines.Add([string]$line)
  }

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

  return [ordered]@{
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
  if (-not (Test-Path -LiteralPath $dockerInstallerPath)) {
    throw "Docker Desktop bootstrap installer was not found at $dockerInstallerPath."
  }

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
    $process = Start-Process -FilePath $dockerInstallerPath -ArgumentList $dockerContract.installArguments -Wait -PassThru -NoNewWindow
    $installExitCode = $process.ExitCode
    @(
      "Installer: $dockerInstallerPath",
      "Arguments: $($dockerContract.installArguments -join ' ')",
      "ExitCode: $installExitCode"
    ) | Set-Content -LiteralPath $dockerInstallLogPath -Encoding ASCII

    if ($installExitCode -eq 3010 -or $installExitCode -eq 1641) {
      return [ordered]@{
        RebootRequired = $true
        InstallExitCode = $installExitCode
      }
    }

    if ($installExitCode -ne 0) {
      throw "Docker Desktop bootstrap failed with exit code $installExitCode."
    }

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

  $startResult = Invoke-ExternalCommand -FilePath $dockerCommandPath -Args @("desktop", "start") -LogPath $dockerDesktopStartLogPath -AllowedExitCodes @(0)
  if ($startResult.ExitCode -ne 0) {
    throw "Docker Desktop failed to start."
  }

  $serverVersion = Wait-ForDockerServer -DockerCommand $dockerCommandPath
  @("Docker server version: $serverVersion") | Set-Content -LiteralPath $dockerVersionLogPath -Encoding ASCII

  Invoke-ExternalCommand -FilePath $dockerCommandPath -Args @("desktop", "engine", "use", "windows") -LogPath $dockerEngineLogPath -AllowedExitCodes @(0) | Out-Null
  Wait-ForWindowsEngine -DockerCommand $dockerCommandPath

  $repoDigestOutput = & $dockerCommandPath image inspect --format '{{join .RepoDigests "\n"}}' $imageContract.imageReference 2>&1
  $repoDigestExitCode = $LASTEXITCODE
  $repoDigestText = ($repoDigestOutput | Out-String).Trim()
  $imagePresent = $repoDigestExitCode -eq 0 -and ($repoDigestText -match [regex]::Escape($imageContract.repositoryDigestReference))

  if (-not $imagePresent) {
    Invoke-ExternalCommand -FilePath $dockerCommandPath -Args @("pull", $imageContract.imageReference) -LogPath $dockerImagePullLogPath -AllowedExitCodes @(0) | Out-Null
  } else {
    @(
      "Pinned image already present: $($imageContract.imageReference)",
      "Expected repo digest: $($imageContract.repositoryDigestReference)"
    ) | Set-Content -LiteralPath $dockerImagePullLogPath -Encoding ASCII
  }

  $inspectResult = Invoke-ExternalCommand -FilePath $dockerCommandPath -Args @("image", "inspect", $imageContract.imageReference) -LogPath $dockerImageInspectLogPath -AllowedExitCodes @(0)
  $repoDigests = & $dockerCommandPath image inspect --format '{{join .RepoDigests "\n"}}' $imageContract.imageReference 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to inspect the pinned LabVIEW Windows container image."
  }

  $repoDigestsText = ($repoDigests | Out-String).Trim()
  if ($repoDigestsText -notmatch [regex]::Escape($imageContract.repositoryDigestReference)) {
    throw "Pinned LabVIEW Windows container image digest mismatch. Expected $($imageContract.repositoryDigestReference)."
  }

  return [ordered]@{
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

$releaseContract = Read-JsonFile -Path $releaseContractResolvedPath
$fixtureManifest = Read-JsonFile -Path $fixtureManifestResolvedPath
$gitCommandPath = Resolve-GitCommand -Candidate $GitCommand

$fixtureResult = Ensure-FixtureWorkspace -GitCommand $gitCommandPath -FixtureManifest $fixtureManifest -InstallRoot $installRootPath -LogPath (Join-Path $logRootPath "fixture-workspace.txt")
$dockerResult = Ensure-DockerDesktopAndImage -ReleaseContract $releaseContract -InstallRoot $installRootPath -LogRoot $logRootPath

$summaryPath = Join-Path $logRootPath "harness-bootstrap-summary.json"
$summary = [ordered]@{
  fixture = [ordered]@{
    repositoryUrl = $fixtureManifest.repositoryUrl
    branch = $fixtureManifest.reference.branch
    commitSha = $fixtureResult.HeadCommit
    workspacePath = $fixtureResult.WorkspacePath
    selectionPath = $fixtureResult.SelectionPath
  }
  docker = [ordered]@{
    rebootRequired = $dockerResult.RebootRequired
    installExitCode = $dockerResult.InstallExitCode
    dockerCommand = if ($dockerResult.Contains("DockerCommand")) { $dockerResult.DockerCommand } else { "" }
    dockerDesktopPath = if ($dockerResult.Contains("DockerDesktopPath")) { $dockerResult.DockerDesktopPath } else { "" }
    serverVersion = if ($dockerResult.Contains("ServerVersion")) { $dockerResult.ServerVersion } else { "" }
    imageReference = if ($dockerResult.Contains("ImageReference")) { $dockerResult.ImageReference } else { "" }
    repositoryDigest = if ($dockerResult.Contains("RepositoryDigest")) { $dockerResult.RepositoryDigest } else { "" }
  }
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding ASCII

if ($dockerResult.RebootRequired) {
  Write-Host "Docker Desktop requested a Windows restart before the harness can finish preparing the Windows container engine."
  exit $dockerResult.InstallExitCode
}

Write-Host "Harness bootstrap completed. Summary: $summaryPath"
