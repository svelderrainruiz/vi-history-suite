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

$repoRootPath = Resolve-PublicRepoRoot -Path $RepoRoot
$harnessScriptPath = Join-Path $repoRootPath "installer/nsis/Invoke-HarnessBootstrap.ps1"

if (-not (Test-Path -LiteralPath $harnessScriptPath)) {
  throw "Harness bootstrap script was not found at $harnessScriptPath."
}

$content = Get-Content -LiteralPath $harnessScriptPath -Raw

if ($content -match '\[string\[\]\]\$Args\b') {
  throw "Invoke-ExternalCommand must not declare a parameter named 'Args'; PowerShell binds that name unexpectedly."
}

if ($content -notmatch '\[string\[\]\]\$CommandArgs\b') {
  throw "Invoke-ExternalCommand must declare a 'CommandArgs' parameter."
}

if ($content -match 'Invoke-ExternalCommand\s+-FilePath[^\r\n]+-Args\b') {
  throw "Invoke-ExternalCommand call sites must not use -Args."
}

if ($content -notmatch 'Invoke-ExternalCommand\s+-FilePath[^\r\n]+-CommandArgs\b') {
  throw "Invoke-ExternalCommand call sites must pass -CommandArgs explicitly."
}

Write-Host "Harness bootstrap regression checks passed."
