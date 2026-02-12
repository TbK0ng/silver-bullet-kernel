param(
  [string]$MetricsPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$docsGeneratedDir = Join-Path $repoRoot "xxx_docs\\generated"
$reportPath = Join-Path $docsGeneratedDir "workflow-metrics-weekly.md"
$jsonPath = Join-Path $docsGeneratedDir "workflow-metrics-latest.json"
$tokenCostPath = Join-Path $repoRoot ".metrics\\token-cost.json"

function Resolve-MetricsPath {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $false)][string]$OverridePath
  )

  if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
    if ([System.IO.Path]::IsPathRooted($OverridePath)) {
      return $OverridePath
    }
    return (Join-Path $RepoRoot $OverridePath)
  }

  if (-not [string]::IsNullOrWhiteSpace($env:WORKFLOW_VERIFY_RUNS_PATH)) {
    if ([System.IO.Path]::IsPathRooted($env:WORKFLOW_VERIFY_RUNS_PATH)) {
      return $env:WORKFLOW_VERIFY_RUNS_PATH
    }
    return (Join-Path $RepoRoot $env:WORKFLOW_VERIFY_RUNS_PATH)
  }

  $defaultMetricsPath = ".metrics/verify-runs.jsonl"
  $policyPath = Join-Path $RepoRoot "workflow-policy.json"
  if (Test-Path $policyPath) {
    try {
      $policy = Get-Content -Path $policyPath -Encoding UTF8 | ConvertFrom-Json
      if ($null -ne $policy.telemetry -and -not [string]::IsNullOrWhiteSpace([string]$policy.telemetry.defaultVerifyRunsPath)) {
        $defaultMetricsPath = [string]$policy.telemetry.defaultVerifyRunsPath
      }
    } catch {
      # Keep fallback default path.
    }
  }

  if ([System.IO.Path]::IsPathRooted($defaultMetricsPath)) {
    return $defaultMetricsPath
  }
  return (Join-Path $RepoRoot $defaultMetricsPath)
}

$metricsPath = Resolve-MetricsPath -RepoRoot $repoRoot -OverridePath $MetricsPath

if (-not (Test-Path $docsGeneratedDir)) {
  New-Item -ItemType Directory -Path $docsGeneratedDir | Out-Null
}

function Get-Quantile {
  param(
    [Parameter(Mandatory = $true)][double[]]$Values,
    [Parameter(Mandatory = $true)][double]$Percent
  )
  if ($Values.Length -eq 0) { return 0 }
  $sorted = $Values | Sort-Object
  $rank = [math]::Ceiling(($Percent / 100) * $sorted.Length) - 1
  if ($rank -lt 0) { $rank = 0 }
  if ($rank -ge $sorted.Length) { $rank = $sorted.Length - 1 }
  return [math]::Round([double]$sorted[$rank], 2)
}

function Get-ArchivedChangeLeadTimes {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $archiveDir = Join-Path $RepoRoot "openspec\\changes\\archive"
  if (-not (Test-Path $archiveDir)) { return @() }

  $leadTimes = @()
  $dirs = Get-ChildItem -Path $archiveDir -Directory
  foreach ($dir in $dirs) {
    $proposalPath = Join-Path $dir.FullName "proposal.md"
    if (-not (Test-Path $proposalPath)) { continue }

    $lastCommit = git -C $RepoRoot log -1 --format=%aI -- "$proposalPath" | Select-Object -First 1
    if (-not $lastCommit) { continue }
    $end = [DateTimeOffset]::Parse($lastCommit.Trim())

    $startCandidates = @()

    $slug = $dir.Name -replace "^\d{4}-\d{2}-\d{2}-", ""
    if ($slug -and $slug -ne $dir.Name) {
      $preArchiveProposalPath = "openspec/changes/$slug/proposal.md"
      $preArchiveFirstCommit = git -C $RepoRoot log --diff-filter=A --format=%aI -- "$preArchiveProposalPath" | Select-Object -First 1
      if ($preArchiveFirstCommit) {
        $startCandidates += [DateTimeOffset]::Parse($preArchiveFirstCommit.Trim())
      }
    }

    $archiveFirstCommit = git -C $RepoRoot log --diff-filter=A --format=%aI -- "$proposalPath" | Select-Object -First 1
    if ($archiveFirstCommit) {
      $startCandidates += [DateTimeOffset]::Parse($archiveFirstCommit.Trim())
    }

    $openSpecMetaPath = Join-Path $dir.FullName ".openspec.yaml"
    if (Test-Path $openSpecMetaPath) {
      $createdLine = Get-Content -Path $openSpecMetaPath -Encoding UTF8 | Where-Object { $_ -match "^created:\s*(\d{4}-\d{2}-\d{2})\s*$" } | Select-Object -First 1
      if ($createdLine) {
        $createdDate = $createdLine -replace "^created:\s*", ""
        $startCandidates += [DateTimeOffset]::Parse("$createdDate" + "T00:00:00+00:00")
      }
    }

    $start = $end
    if ($startCandidates.Count -gt 0) {
      $start = $startCandidates | Sort-Object | Select-Object -First 1
    }

    $hours = ($end - $start).TotalHours
    if ($hours -lt 0) { continue }
    $leadTimes += [math]::Round($hours, 2)
  }

  return @($leadTimes)
}

function Get-SpecDriftCountLast30Days {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $commitIds = @(git -C $RepoRoot log --since="30 days ago" --format=%H -- src)
  if ($commitIds.Count -eq 0) { return 0 }

  $drift = 0
  foreach ($id in $commitIds) {
    $changed = @(git -C $RepoRoot show --name-only --pretty=format: $id)
    $touchedSrc = @($changed | Where-Object { $_ -like "src/*" }).Count -gt 0
    $touchedSpecs = @($changed | Where-Object { $_ -like "openspec/specs/*" -or $_ -like "openspec/changes/*" }).Count -gt 0
    if ($touchedSrc -and -not $touchedSpecs) {
      $drift += 1
    }
  }
  return $drift
}

$runs = @()
if (Test-Path $metricsPath) {
  $runs = Get-Content -Path $metricsPath -Encoding UTF8 |
    Where-Object { $_.Trim().Length -gt 0 } |
    ForEach-Object { $_ | ConvertFrom-Json }
}

$now = [DateTimeOffset]::UtcNow
$weekAgo = $now.AddDays(-7)
$lastWeekRuns = @($runs | Where-Object { [DateTimeOffset]::Parse($_.startedAt) -ge $weekAgo })

$totalRuns = @($runs).Count
$lastWeekTotal = @($lastWeekRuns).Count
$lastWeekPassed = @($lastWeekRuns | Where-Object { $_.status -eq "passed" }).Count
$lastWeekFailed = @($lastWeekRuns | Where-Object { $_.status -eq "failed" }).Count
$failureRate = if ($lastWeekTotal -eq 0) { 0 } else { [math]::Round(($lastWeekFailed / $lastWeekTotal) * 100, 2) }
$successRate = if ($lastWeekTotal -eq 0) { 0 } else { [math]::Round(($lastWeekPassed / $lastWeekTotal) * 100, 2) }

$failedSteps = @($lastWeekRuns |
  Where-Object { $_.status -eq "failed" -and $_.failedStep } |
  Group-Object -Property failedStep |
  Sort-Object -Property Count -Descending)

$reworkCount = $lastWeekFailed
$activeChanges = @(Get-ChildItem -Path (Join-Path $repoRoot "openspec\\changes") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "archive" }).Count
$archivedChanges = @(Get-ChildItem -Path (Join-Path $repoRoot "openspec\\changes\\archive") -Directory -ErrorAction SilentlyContinue).Count
$last7ArchivedChanges = @(Get-ChildItem -Path (Join-Path $repoRoot "openspec\\changes\\archive") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^(\d{4})-(\d{2})-(\d{2})-" -and ([DateTimeOffset]::ParseExact($_.Name.Substring(0,10), "yyyy-MM-dd", $null) -ge $weekAgo) }).Count

$leadTimes = @(Get-ArchivedChangeLeadTimes -RepoRoot $repoRoot)
$leadTimeP50 = Get-Quantile -Values $leadTimes -Percent 50
$leadTimeP90 = Get-Quantile -Values $leadTimes -Percent 90

$driftEvents = Get-SpecDriftCountLast30Days -RepoRoot $repoRoot

$tokenCostStatus = "unavailable"
$tokenCostTotal = $null
if (Test-Path $tokenCostPath) {
  try {
    $tokenObj = Get-Content -Path $tokenCostPath -Encoding UTF8 | ConvertFrom-Json
    $tokenCostStatus = "available"
    $tokenCostTotal = $tokenObj.totalCostUsd
  } catch {
    $tokenCostStatus = "invalid-format"
    $tokenCostTotal = $null
  }
}

$modes = @("fast", "full", "ci")
$modeRows = @()
foreach ($mode in $modes) {
  $modeRuns = @($lastWeekRuns | Where-Object { $_.mode -eq $mode })
  $count = $modeRuns.Count
  $avgDuration = if ($count -eq 0) { 0 } else { [math]::Round((($modeRuns | Measure-Object -Property durationMs -Average).Average), 2) }
  $passCount = @($modeRuns | Where-Object { $_.status -eq "passed" }).Count
  $passRate = if ($count -eq 0) { 0 } else { [math]::Round(($passCount / $count) * 100, 2) }
  $modeRows += [ordered]@{
    mode = $mode
    count = $count
    averageDurationMs = $avgDuration
    passRate = $passRate
  }
}

$summary = [ordered]@{
  generatedAt = $now.ToString("o")
  metricsSourcePath = $metricsPath
  totals = [ordered]@{
    allRuns = $totalRuns
    last7DaysRuns = $lastWeekTotal
    last7DaysPassed = $lastWeekPassed
    last7DaysFailed = $lastWeekFailed
    last7DaysSuccessRate = $successRate
    last7DaysFailureRate = $failureRate
  }
  indicators = [ordered]@{
    leadTimeHoursP50 = $leadTimeP50
    leadTimeHoursP90 = $leadTimeP90
    reworkCountLast7Days = $reworkCount
    parallelThroughput = [ordered]@{
      activeChanges = $activeChanges
      archivedChangesLast7Days = $last7ArchivedChanges
      archivedChangesTotal = $archivedChanges
    }
    specDriftEventsLast30Days = $driftEvents
    tokenCost = [ordered]@{
      status = $tokenCostStatus
      totalCostUsd = $tokenCostTotal
    }
  }
  modeStats = $modeRows
  topFailureSteps = @($failedSteps | Select-Object -First 5 | ForEach-Object {
      [ordered]@{
        step = $_.Name
        count = $_.Count
      }
    })
}

$report = @()
$report += "# Workflow Metrics (Last 7 Days)"
$report += ""
$report += "- generated_at_utc: $($now.ToString("u"))"
$report += "- metrics_source_path: $metricsPath"
$report += "- total_runs_all_time: $totalRuns"
$report += "- runs_last_7_days: $lastWeekTotal"
$report += "- success_rate_last_7_days: $successRate%"
$report += "- failure_rate_last_7_days: $failureRate%"
$report += ""
$report += "## Plan Indicators"
$report += ""
$report += "- lead_time_p50_hours: $leadTimeP50"
$report += "- lead_time_p90_hours: $leadTimeP90"
$report += "- rework_count_last_7_days: $reworkCount"
$report += "- parallel_throughput_active_changes: $activeChanges"
$report += "- parallel_throughput_archived_changes_last_7_days: $last7ArchivedChanges"
$report += "- spec_drift_events_last_30_days: $driftEvents"
$report += "- token_cost_status: $tokenCostStatus"
if ($null -ne $tokenCostTotal) {
  $report += "- token_cost_total_usd: $tokenCostTotal"
}
$report += ""
$report += "## Verify Mode Summary"
$report += ""
$report += "| Mode | Runs | Pass Rate (%) | Avg Duration (ms) |"
$report += "| --- | ---: | ---: | ---: |"
foreach ($row in $modeRows) {
  $report += "| $($row.mode) | $($row.count) | $($row.passRate) | $($row.averageDurationMs) |"
}
$report += ""
$report += "## Top Failure Steps"
$report += ""
if ($failedSteps.Count -eq 0) {
  $report += "- none"
} else {
  foreach ($item in ($failedSteps | Select-Object -First 5)) {
    $report += "- $($item.Name): $($item.Count)"
  }
}
$report += ""
$report += "## Notes"
$report += ""
$report += "- lead-time uses pre-archive proposal history when available; otherwise falls back to archive metadata + commit timestamps."
$report += "- drift detection counts src commits in last 30 days without openspec spec/change updates."
$report += "- token cost is reported only when `.metrics/token-cost.json` is present."
$report += "- metrics source path can be overridden via `WORKFLOW_VERIFY_RUNS_PATH` or `-MetricsPath`."

Set-Content -Path $reportPath -Encoding UTF8 -Value $report
Set-Content -Path $jsonPath -Encoding UTF8 -Value ($summary | ConvertTo-Json -Depth 10)

Write-Host "Wrote report: $reportPath"
Write-Host "Wrote summary: $jsonPath"
