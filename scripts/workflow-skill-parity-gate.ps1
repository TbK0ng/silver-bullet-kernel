param(
  [switch]$NoReport,
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$metricsOutputDir = Join-Path $repoRoot ".metrics"
$reportMd = Join-Path $metricsOutputDir "workflow-skill-parity-gate.md"
$reportJson = Join-Path $metricsOutputDir "workflow-skill-parity-gate.json"

function Get-DirectoryNames {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path $Path)) {
    return @()
  }

  return @(
    Get-ChildItem -Path $Path -Directory |
      Select-Object -ExpandProperty Name |
      Sort-Object -Unique
  )
}

function Get-CommandNames {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path $Path)) {
    return @()
  }

  return @(
    Get-ChildItem -Path $Path -File -Filter "*.md" |
      Select-Object -ExpandProperty BaseName |
      Sort-Object -Unique
  )
}

function Get-MissingItems {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Required,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Actual
  )

  $missing = @()
  foreach ($item in $Required) {
    if ($Actual -notcontains $item) {
      $missing += $item
    }
  }
  return @($missing)
}

$codexSkills = @(Get-DirectoryNames -Path (Join-Path $repoRoot ".codex\\skills"))
$agentsSkills = @(Get-DirectoryNames -Path (Join-Path $repoRoot ".agents\\skills"))
$claudeSkills = @(Get-DirectoryNames -Path (Join-Path $repoRoot ".claude\\skills"))
$claudeTrellisCommands = @(Get-CommandNames -Path (Join-Path $repoRoot ".claude\\commands\\trellis"))
$claudeOpsxCommands = @(Get-CommandNames -Path (Join-Path $repoRoot ".claude\\commands\\opsx"))

$missingInAgents = @(Get-MissingItems -Required $codexSkills -Actual $agentsSkills)
$missingInClaudeSkills = @(Get-MissingItems -Required $codexSkills -Actual $claudeSkills)

$openspecSkillToOpsx = @{
  "openspec-apply-change" = "apply"
  "openspec-archive-change" = "archive"
  "openspec-bulk-archive-change" = "bulk-archive"
  "openspec-continue-change" = "continue"
  "openspec-explore" = "explore"
  "openspec-ff-change" = "ff"
  "openspec-new-change" = "new"
  "openspec-onboard" = "onboard"
  "openspec-sync-specs" = "sync"
  "openspec-verify-change" = "verify"
}

$openspecSkills = @($codexSkills | Where-Object { $_.StartsWith("openspec-", [System.StringComparison]::OrdinalIgnoreCase) })
$missingOpsxCommands = @()
foreach ($skill in $openspecSkills) {
  if (-not $openspecSkillToOpsx.ContainsKey($skill)) {
    $missingOpsxCommands += "mapping:$skill"
    continue
  }

  $requiredCommand = [string]$openspecSkillToOpsx[$skill]
  if ($claudeOpsxCommands -notcontains $requiredCommand) {
    $missingOpsxCommands += $requiredCommand
  }
}
$missingOpsxCommands = @($missingOpsxCommands | Sort-Object -Unique)

$trellisSkillNames = @($codexSkills | Where-Object { -not $_.StartsWith("openspec-", [System.StringComparison]::OrdinalIgnoreCase) })
$missingTrellisCommands = @(Get-MissingItems -Required $trellisSkillNames -Actual $claudeTrellisCommands)

$summary = [ordered]@{
  generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
  passed = $true
  checks = [ordered]@{
    codexSkillsMirroredToAgents = [ordered]@{
      passed = ($missingInAgents.Count -eq 0)
      missing = $missingInAgents
    }
    codexSkillsMirroredToClaude = [ordered]@{
      passed = ($missingInClaudeSkills.Count -eq 0)
      missing = $missingInClaudeSkills
    }
    claudeTrellisCommandsCoverCodexTrellisSkills = [ordered]@{
      passed = ($missingTrellisCommands.Count -eq 0)
      missing = $missingTrellisCommands
    }
    claudeOpsxCommandsCoverOpenSpecSkills = [ordered]@{
      passed = ($missingOpsxCommands.Count -eq 0)
      missing = $missingOpsxCommands
    }
  }
  inventories = [ordered]@{
    codexSkills = $codexSkills
    agentsSkills = $agentsSkills
    claudeSkills = $claudeSkills
    claudeTrellisCommands = $claudeTrellisCommands
    claudeOpsxCommands = $claudeOpsxCommands
  }
}

foreach ($checkEntry in $summary.checks.GetEnumerator()) {
  $check = $checkEntry.Value
  if (-not [bool]$check["passed"]) {
    $summary.passed = $false
    break
  }
}

if (-not $NoReport) {
  if (-not (Test-Path $metricsOutputDir)) {
    New-Item -ItemType Directory -Path $metricsOutputDir | Out-Null
  }

  $lines = @()
  $lines += "# Workflow Skill Parity Gate"
  $lines += ""
  $lines += "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))"
  $lines += "- passed: $($summary.passed)"
  $lines += ""
  $lines += "## Checks"
  $lines += ""
  $lines += "| Check | Status | Missing |"
  $lines += "| --- | --- | --- |"

  foreach ($item in $summary.checks.GetEnumerator()) {
    $checkName = [string]$item.Key
    $check = $item.Value
    $status = if ([bool]$check["passed"]) { "PASS" } else { "FAIL" }
    $missingValues = @($check["missing"])
    $missingText = if ($missingValues.Count -eq 0) { "none" } else { ($missingValues -join ", ") }
    $lines += "| $checkName | $status | $missingText |"
  }

  Set-Content -Path $reportMd -Encoding UTF8 -Value $lines
  Set-Content -Path $reportJson -Encoding UTF8 -Value ($summary | ConvertTo-Json -Depth 12)
}

if (-not $Quiet) {
  Write-Host "[workflow-skill-parity-gate] passed=$($summary.passed)"
}

if (-not [bool]$summary.passed) {
  throw "workflow skill parity gate failed"
}
