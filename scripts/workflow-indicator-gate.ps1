param(
  [switch]$NoReport,
  [switch]$FailOnWarning,
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$configPath = Join-Path $repoRoot "workflow-policy.json"
$metricsOutputDir = Join-Path $repoRoot ".metrics"
$metricsJsonPath = Join-Path $metricsOutputDir "workflow-metrics-latest.json"
$reportMd = Join-Path $metricsOutputDir "workflow-indicator-gate.md"
$reportJson = Join-Path $metricsOutputDir "workflow-indicator-gate.json"

function Add-Check {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Checks,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][ValidateSet("fail", "warn")][string]$Severity,
    [Parameter(Mandatory = $true)][bool]$Passed,
    [Parameter(Mandatory = $true)][string]$Observed,
    [Parameter(Mandatory = $true)][string]$Threshold,
    [Parameter(Mandatory = $true)][string]$Remediation
  )
  $Checks.Add([PSCustomObject]@{
      name = $Name
      severity = $Severity
      passed = $Passed
      observed = $Observed
      threshold = $Threshold
      remediation = $Remediation
    }) | Out-Null
}

if (-not (Test-Path $configPath)) {
  throw "workflow policy config missing: $configPath"
}
if (-not (Test-Path $metricsJsonPath)) {
  throw "metrics snapshot missing: $metricsJsonPath (run npm run metrics:collect first)"
}

$config = Get-Content -Path $configPath -Encoding UTF8 | ConvertFrom-Json
$metrics = Get-Content -Path $metricsJsonPath -Encoding UTF8 | ConvertFrom-Json
$metricsSourcePath = [string]$metrics.metricsSourcePath

$checks = New-Object 'System.Collections.Generic.List[object]'

Add-Check -Checks $checks `
  -Name "Metrics source path resolved" `
  -Severity "warn" `
  -Passed (-not [string]::IsNullOrWhiteSpace($metricsSourcePath)) `
  -Observed $(if ([string]::IsNullOrWhiteSpace($metricsSourcePath)) { "missing" } else { $metricsSourcePath }) `
  -Threshold "recommended: non-empty path" `
  -Remediation "Run metrics collection with deterministic telemetry path configuration."

$failureRate = [double]$metrics.totals.last7DaysFailureRate
$maxFailureRate = [double]$config.indicatorGate.maxFailureRateLast7Days
Add-Check -Checks $checks `
  -Name "Verify failure rate within threshold" `
  -Severity "fail" `
  -Passed ($failureRate -le $maxFailureRate) `
  -Observed "$failureRate%" `
  -Threshold "<= $maxFailureRate%" `
  -Remediation "Investigate top failed steps and stabilize verify gates before adding new scope."

$leadTimeP90 = [double]$metrics.indicators.leadTimeHoursP90
$maxLeadTimeP90 = [double]$config.indicatorGate.maxLeadTimeHoursP90
Add-Check -Checks $checks `
  -Name "Lead time P90 within threshold" `
  -Severity "warn" `
  -Passed ($leadTimeP90 -le $maxLeadTimeP90) `
  -Observed "$leadTimeP90 h" `
  -Threshold "<= $maxLeadTimeP90 h" `
  -Remediation "Split oversized changes and archive in smaller batches."

$reworkCount = [int]$metrics.indicators.reworkCountLast7Days
$maxRework = [int]$config.indicatorGate.maxReworkCountLast7Days
Add-Check -Checks $checks `
  -Name "Rework count within threshold" `
  -Severity "fail" `
  -Passed ($reworkCount -le $maxRework) `
  -Observed "$reworkCount" `
  -Threshold "<= $maxRework" `
  -Remediation "Strengthen proposal/design clarity and pre-implementation acceptance checks."

$activeChanges = [int]$metrics.indicators.parallelThroughput.activeChanges
$maxActiveChanges = [int]$config.indicatorGate.maxActiveChanges
Add-Check -Checks $checks `
  -Name "Active change WIP within threshold" `
  -Severity "fail" `
  -Passed ($activeChanges -le $maxActiveChanges) `
  -Observed "$activeChanges" `
  -Threshold "<= $maxActiveChanges" `
  -Remediation "Pause new starts and close in-flight changes to maintain throughput quality."

$driftEvents = [int]$metrics.indicators.specDriftEventsLast30Days
$maxDriftEvents = [int]$config.indicatorGate.maxSpecDriftEventsLast30Days
Add-Check -Checks $checks `
  -Name "Spec drift events within threshold" `
  -Severity "fail" `
  -Passed ($driftEvents -le $maxDriftEvents) `
  -Observed "$driftEvents" `
  -Threshold "<= $maxDriftEvents" `
  -Remediation "Backfill missing specs/changes for drifted commits and enforce change-first workflow."

$tokenStatus = [string]$metrics.indicators.tokenCost.status
$requireTokenCost = [bool]$config.indicatorGate.requireTokenCostAvailable
$tokenSeverity = if ($requireTokenCost) { "fail" } else { "warn" }
Add-Check -Checks $checks `
  -Name "Token cost status available" `
  -Severity $tokenSeverity `
  -Passed (($tokenStatus -eq "available") -or (-not $requireTokenCost)) `
  -Observed "$tokenStatus" `
  -Threshold $(if ($requireTokenCost) { "must be available" } else { "recommended: available" }) `
  -Remediation "Run npm run metrics:token-cost -- -Source <provider> -TotalCostUsd <amount> to publish token-cost summary."

$failedChecks = @($checks | Where-Object { -not $_.passed -and $_.severity -eq "fail" })
$warningChecks = @($checks | Where-Object { -not $_.passed -and $_.severity -eq "warn" })
$outcome = if ($failedChecks.Count -gt 0) { "FAIL" } elseif ($warningChecks.Count -gt 0) { "WARN" } else { "PASS" }

$summary = [ordered]@{
  generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
  outcome = $outcome
  checks = @($checks | ForEach-Object {
      [ordered]@{
        name = [string]$_.name
        severity = [string]$_.severity
        passed = [bool]$_.passed
        observed = [string]$_.observed
        threshold = [string]$_.threshold
        remediation = [string]$_.remediation
      }
    })
}

if (-not $NoReport) {
  if (-not (Test-Path $metricsOutputDir)) {
    New-Item -ItemType Directory -Path $metricsOutputDir | Out-Null
  }

  $lines = @()
  $lines += "# Workflow Indicator Gate"
  $lines += ""
  $lines += "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))"
  $lines += "- outcome: $outcome"
  $lines += ""
  $lines += "## Checks"
  $lines += ""
  $lines += "| Check | Severity | Status | Observed | Threshold | Remediation |"
  $lines += "| --- | --- | --- | --- | --- | --- |"
  foreach ($check in $checks) {
    $status = if ($check.passed) { "PASS" } else { "FAIL" }
    $lines += "| $($check.name) | $($check.severity) | $status | $($check.observed) | $($check.threshold) | $($check.remediation) |"
  }

  Set-Content -Path $reportMd -Encoding UTF8 -Value $lines
  Set-Content -Path $reportJson -Encoding UTF8 -Value ($summary | ConvertTo-Json -Depth 8)
}

if (-not $Quiet) {
  Write-Host "[workflow-indicator-gate] outcome=$outcome fail=$($failedChecks.Count) warn=$($warningChecks.Count)"
}

if ($failedChecks.Count -gt 0) {
  throw "workflow indicator gate failed"
}
if ($FailOnWarning -and $warningChecks.Count -gt 0) {
  throw "workflow indicator gate warning escalated to failure"
}
