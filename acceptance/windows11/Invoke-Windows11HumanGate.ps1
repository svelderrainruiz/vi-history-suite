[CmdletBinding()]
param(
  [ValidateSet("status", "prepare", "complete")]
  [string]$Action = "status",
  [string]$WorkRoot = "",
  [string]$AcceptanceRecordPath = "",
  [ValidateSet("passed-human-review", "failed-human-review", "needs-more-review")]
  [string]$Outcome = "",
  [string[]]$Note = @(),
  [string[]]$ScreenshotPath = @(),
  [switch]$SkipOpen
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

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Value
  )

  $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding ASCII
}

function Set-ObjectProperty {
  param(
    [object]$Object,
    [string]$Name,
    $Value
  )

  if ($Object.PSObject.Properties.Name -contains $Name) {
    $Object.$Name = $Value
  } else {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  }
}

function Resolve-WorkRootPath {
  param(
    [string]$RequestedPath,
    [string]$RequestedAcceptanceRecordPath
  )

  if ($RequestedPath) {
    return [IO.Path]::GetFullPath($RequestedPath)
  }

  if ($RequestedAcceptanceRecordPath) {
    return Split-Path -Parent ([IO.Path]::GetFullPath($RequestedAcceptanceRecordPath))
  }

  if (-not $env:LocalAppData) {
    throw "LocalAppData is required to resolve the default host-machine acceptance root."
  }

  return Join-Path $env:LocalAppData "VI History Suite\acceptance\host-machine"
}

function Resolve-AcceptanceRecordPath {
  param(
    [string]$RequestedPath,
    [string]$ResolvedWorkRoot
  )

  if ($RequestedPath) {
    return [IO.Path]::GetFullPath($RequestedPath)
  }

  return Join-Path $ResolvedWorkRoot "acceptance-record.json"
}

function Copy-ChecklistResults {
  param([object[]]$ChecklistResults)

  $copied = @()
  foreach ($item in @($ChecklistResults)) {
    $copied += [pscustomobject]@{
      id = $item.id
      label = $item.label
      status = $item.status
      notes = @($item.notes)
    }
  }

  return $copied
}

function Normalize-HumanGateRecord {
  param(
    [object]$Record,
    [object]$Template
  )

  if (-not ($Record.PSObject.Properties.Name -contains "humanGate")) {
    Set-ObjectProperty -Object $Record -Name "humanGate" -Value ([pscustomobject]@{})
  }

  $humanGate = $Record.humanGate
  $templateHumanGate = $Template.humanGate

  foreach ($propertyName in @(
    "checklistPath",
    "reviewScriptPath",
    "reviewer",
    "recordTemplatePath",
    "status",
    "reviewedAtUtc",
    "summaryPath"
  )) {
    $templateValue = if ($templateHumanGate.PSObject.Properties.Name -contains $propertyName) {
      $templateHumanGate.$propertyName
    } else {
      ""
    }

    if (-not ($humanGate.PSObject.Properties.Name -contains $propertyName)) {
      Set-ObjectProperty -Object $humanGate -Name $propertyName -Value $templateValue
    }
  }

  if (-not ($humanGate.PSObject.Properties.Name -contains "notes")) {
    Set-ObjectProperty -Object $humanGate -Name "notes" -Value @()
  } else {
    $humanGate.notes = @($humanGate.notes)
  }

  if (-not ($humanGate.PSObject.Properties.Name -contains "screenshots")) {
    Set-ObjectProperty -Object $humanGate -Name "screenshots" -Value @()
  } else {
    $humanGate.screenshots = @($humanGate.screenshots)
  }

  if (-not ($humanGate.PSObject.Properties.Name -contains "checklistResults") -or @($humanGate.checklistResults).Count -eq 0) {
    Set-ObjectProperty -Object $humanGate -Name "checklistResults" -Value (Copy-ChecklistResults -ChecklistResults @($templateHumanGate.checklistResults))
  } else {
    $existingById = @{}
    foreach ($item in @($humanGate.checklistResults)) {
      $existingById[$item.id] = $item
    }

    $normalized = @()
    foreach ($templateItem in @($templateHumanGate.checklistResults)) {
      if ($existingById.ContainsKey($templateItem.id)) {
        $currentItem = $existingById[$templateItem.id]
        if (-not ($currentItem.PSObject.Properties.Name -contains "label")) {
          Set-ObjectProperty -Object $currentItem -Name "label" -Value $templateItem.label
        }
        if (-not ($currentItem.PSObject.Properties.Name -contains "status")) {
          Set-ObjectProperty -Object $currentItem -Name "status" -Value "pending"
        }
        if (-not ($currentItem.PSObject.Properties.Name -contains "notes")) {
          Set-ObjectProperty -Object $currentItem -Name "notes" -Value @()
        } else {
          $currentItem.notes = @($currentItem.notes)
        }
        $normalized += $currentItem
      } else {
        $normalized += [pscustomobject]@{
          id = $templateItem.id
          label = $templateItem.label
          status = $templateItem.status
          notes = @($templateItem.notes)
        }
      }
    }

    $humanGate.checklistResults = $normalized
  }

  return $Record
}

function Resolve-CodeCommand {
  param([string]$Candidate)

  foreach ($item in @(
    $Candidate,
    "code.cmd",
    "code"
  ) | Where-Object { $_ }) {
    if (Test-Path -LiteralPath $item) {
      return (Resolve-Path -LiteralPath $item).Path
    }

    $command = Get-Command $item -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }

  throw "Visual Studio Code CLI was not found for the host-machine human gate."
}

function Resolve-SelectionPath {
  param([object]$Record)

  $selectionPath = $Record.fixture.selectionPath
  if ([IO.Path]::IsPathRooted($selectionPath)) {
    return $selectionPath
  }

  return Join-Path $Record.fixture.bundledWorkspacePath $selectionPath
}

function Get-InteractiveOutcome {
  param([object[]]$ChecklistResults)

  $hasFailure = $false
  $hasPending = $false

  foreach ($item in $ChecklistResults) {
    if ($item.status -eq "fail") {
      $hasFailure = $true
    }

    if ($item.status -eq "pending") {
      $hasPending = $true
    }
  }

  if ($hasFailure) {
    return "needs-more-review"
  }

  if ($hasPending) {
    return "needs-more-review"
  }

  return "passed-human-review"
}

function Prompt-ChecklistResults {
  param([object[]]$ChecklistResults)

  foreach ($item in $ChecklistResults) {
    $rawStatus = Read-Host ("Checklist [{0}] {1} [pass/fail/na/pending] (Enter=pass)" -f $item.id, $item.label)
    $normalizedStatus = switch (($rawStatus ?? "").Trim().ToLowerInvariant()) {
      "" { "pass" }
      "pass" { "pass" }
      "fail" { "fail" }
      "na" { "not-applicable" }
      "n/a" { "not-applicable" }
      "not-applicable" { "not-applicable" }
      "pending" { "pending" }
      default { throw "Unsupported checklist status '$rawStatus' for item $($item.id)." }
    }

    $item.status = $normalizedStatus
    $note = Read-Host ("Optional note for {0}" -f $item.id)
    $item.notes = if ($note) { @($note) } else { @() }
  }

  return $ChecklistResults
}

function Resolve-ScreenshotPaths {
  param([string[]]$Paths)

  $resolved = @()
  foreach ($item in @($Paths)) {
    if (-not $item) {
      continue
    }

    $resolvedPath = [IO.Path]::GetFullPath($item)
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
      throw "Screenshot path was not found at $resolvedPath."
    }

    $resolved += $resolvedPath
  }

  return $resolved
}

function Write-HumanGateSummary {
  param(
    [string]$Path,
    [object]$Record
  )

  $lines = @(
    "# Windows 11 Host-Machine Human Gate",
    "",
    ("- releaseContractId: {0}" -f $Record.releaseContractId),
    ("- reviewer: {0}" -f $Record.humanGate.reviewer),
    ("- status: {0}" -f $Record.humanGate.status),
    ("- reviewedAtUtc: {0}" -f $Record.humanGate.reviewedAtUtc),
    ("- workRoot: {0}" -f $Record.executionEnvironment.workRoot),
    ("- workspace: {0}" -f $Record.fixture.bundledWorkspacePath),
    ("- selection: {0}" -f $Record.fixture.selectionPath),
    "",
    "## Checklist"
  )

  foreach ($item in @($Record.humanGate.checklistResults)) {
    $lines += ("- [{0}] {1}" -f $item.status, $item.label)
    foreach ($note in @($item.notes)) {
      if ($note) {
        $lines += ("  note: {0}" -f $note)
      }
    }
  }

  if (@($Record.humanGate.notes).Count -gt 0) {
    $lines += ""
    $lines += "## Notes"
    foreach ($note in @($Record.humanGate.notes)) {
      $lines += ("- {0}" -f $note)
    }
  }

  if (@($Record.humanGate.screenshots).Count -gt 0) {
    $lines += ""
    $lines += "## Screenshots"
    foreach ($screenshot in @($Record.humanGate.screenshots)) {
      $lines += ("- {0}" -f $screenshot)
    }
  }

  $lines | Set-Content -LiteralPath $Path -Encoding ASCII
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$templatePath = Join-Path $scriptDirectory "acceptance-record.template.json"
$resolvedWorkRoot = Resolve-WorkRootPath -RequestedPath $WorkRoot -RequestedAcceptanceRecordPath $AcceptanceRecordPath
$resolvedAcceptanceRecordPath = Resolve-AcceptanceRecordPath -RequestedPath $AcceptanceRecordPath -ResolvedWorkRoot $resolvedWorkRoot

if (-not (Test-Path -LiteralPath $templatePath)) {
  throw "Acceptance record template was not found at $templatePath."
}

if (-not (Test-Path -LiteralPath $resolvedAcceptanceRecordPath)) {
  throw "Acceptance record was not found at $resolvedAcceptanceRecordPath. Run Invoke-Windows11Acceptance.ps1 first."
}

$template = Read-JsonFile -Path $templatePath
$record = Normalize-HumanGateRecord -Record (Read-JsonFile -Path $resolvedAcceptanceRecordPath) -Template $template
Ensure-Directory -Path $resolvedWorkRoot

switch ($Action) {
  "status" {
    $record.humanGate | ConvertTo-Json -Depth 20
    break
  }
  "prepare" {
    if (-not $SkipOpen.IsPresent) {
      $codeCommandPath = Resolve-CodeCommand -Candidate $record.automation.codeCommand
      $workspacePath = $record.fixture.bundledWorkspacePath
      $selectionPath = Resolve-SelectionPath -Record $record
      $workspaceLogPath = Join-Path $resolvedWorkRoot "human-gate-workspace-launch.txt"
      $selectionLogPath = Join-Path $resolvedWorkRoot "human-gate-selection-launch.txt"

      & $codeCommandPath --new-window $workspacePath 2>&1 | Set-Content -LiteralPath $workspaceLogPath -Encoding ASCII
      & $codeCommandPath --goto $selectionPath 2>&1 | Set-Content -LiteralPath $selectionLogPath -Encoding ASCII

      Set-ObjectProperty -Object $record.humanGate -Name "prepareWorkspaceLaunchLogPath" -Value $workspaceLogPath
      Set-ObjectProperty -Object $record.humanGate -Name "prepareSelectionLaunchLogPath" -Value $selectionLogPath
    }

    Set-ObjectProperty -Object $record.humanGate -Name "preparedAtUtc" -Value ((Get-Date).ToUniversalTime().ToString("o"))
    Write-JsonFile -Path $resolvedAcceptanceRecordPath -Value $record
    Write-Host ("Prepared host-machine human gate. Record: {0}" -f $resolvedAcceptanceRecordPath)
    break
  }
  "complete" {
    $record.humanGate.checklistResults = Prompt-ChecklistResults -ChecklistResults @($record.humanGate.checklistResults)

    $overallNotes = @($Note)
    $enteredNote = Read-Host "Overall notes (optional)"
    if ($enteredNote) {
      $overallNotes += $enteredNote
    }

    $enteredScreenshots = @($ScreenshotPath)
    $enteredScreenshotLine = Read-Host "Screenshot paths separated by semicolons (optional)"
    if ($enteredScreenshotLine) {
      $enteredScreenshots += ($enteredScreenshotLine -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    $record.humanGate.notes = @($overallNotes | Where-Object { $_ })
    $record.humanGate.screenshots = Resolve-ScreenshotPaths -Paths @($enteredScreenshots)
    $record.humanGate.status = if ($Outcome) { $Outcome } else { Get-InteractiveOutcome -ChecklistResults @($record.humanGate.checklistResults) }
    $record.humanGate.reviewedAtUtc = (Get-Date).ToUniversalTime().ToString("o")

    $summaryPath = Join-Path $resolvedWorkRoot "human-gate-summary.md"
    $record.humanGate.summaryPath = $summaryPath
    Write-HumanGateSummary -Path $summaryPath -Record $record
    Write-JsonFile -Path $resolvedAcceptanceRecordPath -Value $record

    Write-Host ("Completed host-machine human gate with status {0}. Record: {1}" -f $record.humanGate.status, $resolvedAcceptanceRecordPath)
    Write-Host ("Human gate summary: {0}" -f $summaryPath)
    break
  }
}
