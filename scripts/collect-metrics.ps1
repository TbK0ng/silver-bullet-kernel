Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$metricsPath = Join-Path $repoRoot ".metrics\\verify-runs.jsonl"
$docsGeneratedDir = Join-Path $repoRoot "xxx_docs\\generated"
$reportPath = Join-Path $docsGeneratedDir "workflow-metrics-weekly.md"
$jsonPath = Join-Path $docsGeneratedDir "workflow-metrics-latest.json"

if (-not (Test-Path $docsGeneratedDir)) {
  New-Item -ItemType Directory -Path $docsGeneratedDir | Out-Null
}

$runs = @()
if (Test-Path $metricsPath) {
  $runs = Get-Content -Path $metricsPath -Encoding UTF8 |
    Where-Object { $_.Trim().Length -gt 0 } |
    ForEach-Object { $_ | ConvertFrom-Json }
}

$now = [DateTimeOffset]::UtcNow
$weekAgo = $now.AddDays(-7)
$lastWeekRuns = $runs | Where-Object { [DateTimeOffset]::Parse($_.startedAt) -ge $weekAgo }

$totalRuns = @($runs).Count
$lastWeekTotal = @($lastWeekRuns).Count
$lastWeekPassed = @($lastWeekRuns | Where-Object { $_.status -eq "passed" }).Count
$lastWeekFailed = @($lastWeekRuns | Where-Object { $_.status -eq "failed" }).Count

$successRate = if ($lastWeekTotal -eq 0) { 0 } else { [math]::Round(($lastWeekPassed / $lastWeekTotal) * 100, 2) }

$modes = @("fast", "full", "ci")
$modeRows = @()
foreach ($mode in $modes) {
  $modeRuns = $lastWeekRuns | Where-Object { $_.mode -eq $mode }
  $count = @($modeRuns).Count
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

$failedSteps = $lastWeekRuns |
  Where-Object { $_.status -eq "failed" -and $_.failedStep } |
  Group-Object -Property failedStep |
  Sort-Object -Property Count -Descending
$failedSteps = @($failedSteps)

$activeChanges = @(Get-ChildItem -Path (Join-Path $repoRoot "openspec\\changes") -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "archive" }).Count
$archivedChanges = @(Get-ChildItem -Path (Join-Path $repoRoot "openspec\\changes\\archive") -Directory -ErrorAction SilentlyContinue).Count

$summary = [ordered]@{
  generatedAt = $now.ToString("o")
  totals = [ordered]@{
    allRuns = $totalRuns
    last7DaysRuns = $lastWeekTotal
    last7DaysPassed = $lastWeekPassed
    last7DaysFailed = $lastWeekFailed
    last7DaysSuccessRate = $successRate
  }
  modeStats = $modeRows
  changeStats = [ordered]@{
    activeChanges = $activeChanges
    archivedChanges = $archivedChanges
  }
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
$report += "- total_runs_all_time: $totalRuns"
$report += "- runs_last_7_days: $lastWeekTotal"
$report += "- success_rate_last_7_days: $successRate%"
$report += "- active_changes: $activeChanges"
$report += "- archived_changes: $archivedChanges"
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
if (@($failedSteps).Count -eq 0) {
  $report += "- none"
} else {
  foreach ($item in ($failedSteps | Select-Object -First 5)) {
    $report += "- $($item.Name): $($item.Count)"
  }
}
$report += ""
$report += "## Suggested Actions"
$report += ""
$report += '- Keep `verify:fast` under 120s median for tight local loops.'
$report += '- If `ci` failures increase, inspect `failedStep` trend and add targeted guardrails.'
$report += '- Review change throughput weekly (`active_changes` vs `archived_changes`).'

Set-Content -Path $reportPath -Encoding UTF8 -Value $report
Set-Content -Path $jsonPath -Encoding UTF8 -Value ($summary | ConvertTo-Json -Depth 8)

Write-Host "Wrote report: $reportPath"
Write-Host "Wrote summary: $jsonPath"
