param(
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$CommandArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\sbk-runtime.ps1")

function Show-Usage {
  Write-Host "sbk fleet <operation> [args]"
  Write-Host ""
  Write-Host "Operations:"
  Write-Host "  collect --roots <path1,path2,...>"
  Write-Host "  report [--format md|json]"
  Write-Host "  doctor"
}

function Ensure-MetricsDir {
  $metricsDir = Join-Path $repoRoot ".metrics"
  if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
  }
  return $metricsDir
}

function Parse-Roots {
  param(
    [Parameter(Mandatory = $true)][string[]]$Args
  )

  $roots = @()
  for ($i = 0; $i -lt $Args.Count; $i++) {
    $token = [string]$Args[$i]
    if ($token -eq "--roots" -and ($i + 1) -lt $Args.Count) {
      $raw = [string]$Args[$i + 1]
      $segments = @($raw -split "[,;]" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
      $roots += $segments
      $i++
      continue
    }
    if ($token -eq "--root" -and ($i + 1) -lt $Args.Count) {
      $roots += [string]$Args[$i + 1]
      $i++
      continue
    }
  }

  if ($roots.Count -eq 0) {
    $roots += "."
  }

  return @($roots | Select-Object -Unique)
}

function Resolve-RootPaths {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Roots
  )

  $resolved = @()
  foreach ($root in $Roots) {
    $path = Resolve-SbkPath -BasePath $repoRoot -Path $root
    if (-not (Test-Path $path -PathType Container)) {
      throw "fleet collect root path is invalid: $path"
    }
    $resolved += (Resolve-Path -LiteralPath $path).Path
  }
  return @($resolved | Select-Object -Unique)
}

function Read-RepoWorkflowMetrics {
  param(
    [Parameter(Mandatory = $true)][string]$RepoPath
  )

  $metricsPath = Join-Path $RepoPath ".metrics\\workflow-metrics-latest.json"
  $policyPath = Join-Path $RepoPath "workflow-policy.json"
  $metrics = Read-SbkJsonFile -Path $metricsPath
  $policy = Read-SbkJsonFile -Path $policyPath

  $thresholds = Get-SbkPropertyValue -Object $policy -Name "indicatorGate"
  if ($null -eq $thresholds) {
    $thresholds = [PSCustomObject]@{
      maxFailureRateLast7Days = 5
      maxLeadTimeHoursP90 = 72
      maxReworkCountLast7Days = 2
      maxSpecDriftEventsLast30Days = 1
      requireTokenCostAvailable = $false
    }
  }

  $breaches = @()
  if ($null -ne $metrics) {
    $failureRate = [double](Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $metrics -Name "totals") -Name "last7DaysFailureRate")
    $leadTimeP90 = [double](Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $metrics -Name "indicators") -Name "leadTimeHoursP90")
    $rework = [double](Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $metrics -Name "indicators") -Name "reworkCountLast7Days")
    $drift = [double](Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $metrics -Name "indicators") -Name "specDriftEventsLast30Days")
    $tokenStatus = [string](Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $metrics -Name "indicators") -Name "tokenCost") -Name "status")

    if ($failureRate -gt [double](Get-SbkPropertyValue -Object $thresholds -Name "maxFailureRateLast7Days")) {
      $breaches += "failureRate:$failureRate"
    }
    if ($leadTimeP90 -gt [double](Get-SbkPropertyValue -Object $thresholds -Name "maxLeadTimeHoursP90")) {
      $breaches += "leadTimeP90:$leadTimeP90"
    }
    if ($rework -gt [double](Get-SbkPropertyValue -Object $thresholds -Name "maxReworkCountLast7Days")) {
      $breaches += "rework:$rework"
    }
    if ($drift -gt [double](Get-SbkPropertyValue -Object $thresholds -Name "maxSpecDriftEventsLast30Days")) {
      $breaches += "specDrift:$drift"
    }
    if ([bool](Get-SbkPropertyValue -Object $thresholds -Name "requireTokenCostAvailable") -and -not $tokenStatus.Equals("available", [System.StringComparison]::OrdinalIgnoreCase)) {
      $breaches += "tokenCost:$tokenStatus"
    }
  }

  $remote = ""
  try {
    $remoteCandidate = [string](git -C $RepoPath remote get-url origin 2>$null | Select-Object -First 1)
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -eq 0) {
      $remote = $remoteCandidate.Trim()
    }
  } catch {
    $remote = ""
  }

  return [ordered]@{
    repository = [ordered]@{
      id = Split-Path $RepoPath -Leaf
      path = $RepoPath
      remote = $remote
      collectedAt = [DateTimeOffset]::UtcNow.ToString("o")
    }
    metricsAvailable = ($null -ne $metrics)
    policyAvailable = ($null -ne $policy)
    metrics = $metrics
    thresholds = $thresholds
    thresholdBreaches = $breaches
  }
}

function Write-FleetSnapshot {
  param(
    [Parameter(Mandatory = $true)]$Snapshot
  )

  $metricsDir = Ensure-MetricsDir
  $jsonPath = Join-Path $metricsDir "fleet-snapshot.json"
  $mdPath = Join-Path $metricsDir "fleet-snapshot.md"

  Set-Content -Path $jsonPath -Value ($Snapshot | ConvertTo-Json -Depth 30) -Encoding UTF8

  $lines = @()
  $lines += "# Fleet Snapshot"
  $lines += ""
  $lines += "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))"
  $lines += "- repositories: $(@($Snapshot.repositories).Count)"
  $lines += ""
  $lines += "| Repository | Metrics | Breaches | Collected At |"
  $lines += "| --- | --- | --- | --- |"
  foreach ($repo in @($Snapshot.repositories)) {
    $breaches = @($repo.thresholdBreaches)
    $lines += "| $($repo.repository.id) | $($repo.metricsAvailable) | $(if ($breaches.Count -eq 0) { "none" } else { $breaches -join ", " }) | $($repo.repository.collectedAt) |"
  }

  Set-Content -Path $mdPath -Value $lines -Encoding UTF8
}

function Read-FleetSnapshot {
  $path = Join-Path $repoRoot ".metrics\\fleet-snapshot.json"
  $snapshot = Read-SbkJsonFile -Path $path
  if ($null -eq $snapshot) {
    throw "fleet snapshot not found. run `sbk fleet collect` first."
  }
  return $snapshot
}

function Build-FleetReport {
  param(
    [Parameter(Mandatory = $true)]$Snapshot
  )

  $repos = @($Snapshot.repositories)
  $available = @($repos | Where-Object { [bool]$_.metricsAvailable })
  $metrics = @($available | ForEach-Object { $_.metrics })

  $failureRates = @($metrics | ForEach-Object { [double](Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $_ -Name "totals") -Name "last7DaysFailureRate") })
  $leadP90 = @($metrics | ForEach-Object { [double](Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $_ -Name "indicators") -Name "leadTimeHoursP90") })
  $rework = @($metrics | ForEach-Object { [double](Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $_ -Name "indicators") -Name "reworkCountLast7Days") })
  $drift = @($metrics | ForEach-Object { [double](Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $_ -Name "indicators") -Name "specDriftEventsLast30Days") })
  $tokenAvailable = @($metrics | Where-Object {
      [string](Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $_ -Name "indicators") -Name "tokenCost") -Name "status") -eq "available"
    }).Count

  $avgFailure = if ($failureRates.Count -eq 0) { 0 } else { [math]::Round((($failureRates | Measure-Object -Average).Average), 2) }
  $avgLeadP90 = if ($leadP90.Count -eq 0) { 0 } else { [math]::Round((($leadP90 | Measure-Object -Average).Average), 2) }
  $avgRework = if ($rework.Count -eq 0) { 0 } else { [math]::Round((($rework | Measure-Object -Average).Average), 2) }
  $avgDrift = if ($drift.Count -eq 0) { 0 } else { [math]::Round((($drift | Measure-Object -Average).Average), 2) }

  $breachRepos = @($repos | Where-Object { @($_.thresholdBreaches).Count -gt 0 } | ForEach-Object {
      [ordered]@{
        id = [string]$_.repository.id
        path = [string]$_.repository.path
        breaches = @($_.thresholdBreaches)
      }
    })

  return [ordered]@{
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    repositories = $repos.Count
    repositoriesWithMetrics = $available.Count
    consolidatedIndicators = [ordered]@{
      failureRateLast7DaysAvg = $avgFailure
      leadTimeHoursP90Avg = $avgLeadP90
      reworkCountLast7DaysAvg = $avgRework
      specDriftEventsLast30DaysAvg = $avgDrift
      tokenCostAvailabilityRate = if ($available.Count -eq 0) { 0 } else { [math]::Round(($tokenAvailable / $available.Count) * 100, 2) }
    }
    repositoriesExceedingThresholds = $breachRepos
  }
}

function Write-FleetReport {
  param(
    [Parameter(Mandatory = $true)]$Report
  )

  $metricsDir = Ensure-MetricsDir
  $jsonPath = Join-Path $metricsDir "fleet-report.json"
  $mdPath = Join-Path $metricsDir "fleet-report.md"
  Set-Content -Path $jsonPath -Value ($Report | ConvertTo-Json -Depth 20) -Encoding UTF8

  $lines = @()
  $lines += "# Fleet Report"
  $lines += ""
  $lines += "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))"
  $lines += "- repositories: $($Report.repositories)"
  $lines += "- repositories_with_metrics: $($Report.repositoriesWithMetrics)"
  $lines += ""
  $lines += "## Consolidated Indicators"
  $lines += ""
  $lines += "- failure_rate_last_7_days_avg: $($Report.consolidatedIndicators.failureRateLast7DaysAvg)"
  $lines += "- lead_time_hours_p90_avg: $($Report.consolidatedIndicators.leadTimeHoursP90Avg)"
  $lines += "- rework_count_last_7_days_avg: $($Report.consolidatedIndicators.reworkCountLast7DaysAvg)"
  $lines += "- spec_drift_events_last_30_days_avg: $($Report.consolidatedIndicators.specDriftEventsLast30DaysAvg)"
  $lines += "- token_cost_availability_rate: $($Report.consolidatedIndicators.tokenCostAvailabilityRate)%"
  $lines += ""
  $lines += "## Repositories Exceeding Thresholds"
  $lines += ""
  if (@($Report.repositoriesExceedingThresholds).Count -eq 0) {
    $lines += "- none"
  } else {
    foreach ($repo in @($Report.repositoriesExceedingThresholds)) {
      $lines += "- $($repo.id): $(@($repo.breaches) -join ", ")"
    }
  }
  Set-Content -Path $mdPath -Value $lines -Encoding UTF8
}

if ($null -eq $CommandArgs -or $CommandArgs.Count -eq 0) {
  Show-Usage
  exit 0
}

$operation = [string]$CommandArgs[0]
$rest = @()
if ($CommandArgs.Count -gt 1) {
  $rest = @($CommandArgs[1..($CommandArgs.Count - 1)])
}

switch ($operation.ToLowerInvariant()) {
  "collect" {
    $roots = Parse-Roots -Args $rest
    $resolvedRoots = Resolve-RootPaths -Roots $roots
    $repos = @()
    foreach ($root in $resolvedRoots) {
      $repos += Read-RepoWorkflowMetrics -RepoPath $root
    }

    $snapshot = [ordered]@{
      generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
      collectorRepoRoot = $repoRoot
      repositories = $repos
    }
    Write-FleetSnapshot -Snapshot $snapshot
    Write-Host ("[fleet] collect repositories={0}" -f $repos.Count)
    break
  }
  "report" {
    $format = "md"
    for ($i = 0; $i -lt $rest.Count; $i++) {
      if ([string]$rest[$i] -eq "--format" -and ($i + 1) -lt $rest.Count) {
        $format = [string]$rest[$i + 1]
        $i++
      }
    }

    $snapshot = Read-FleetSnapshot
    $report = Build-FleetReport -Snapshot $snapshot
    Write-FleetReport -Report $report
    if ($format -eq "json") {
      Write-Host ($report | ConvertTo-Json -Depth 20)
    } else {
      $reportPath = Join-Path $repoRoot ".metrics\\fleet-report.md"
      Get-Content -Path $reportPath -Encoding UTF8 | ForEach-Object { Write-Host $_ }
    }
    break
  }
  "doctor" {
    $snapshot = Read-FleetSnapshot
    $generatedAt = [DateTimeOffset]::Parse([string](Get-SbkPropertyValue -Object $snapshot -Name "generatedAt"))
    $ageHours = [math]::Round(([DateTimeOffset]::UtcNow - $generatedAt).TotalHours, 2)
    $repos = @($snapshot.repositories)
    $missingMetrics = @($repos | Where-Object { -not [bool]$_.metricsAvailable } | ForEach-Object { [string]$_.repository.id })
    $issues = @()
    if ($ageHours -gt 24) {
      $issues += "snapshot stale ($ageHours hours old)"
    }
    if ($missingMetrics.Count -gt 0) {
      $issues += "repos_missing_metrics: " + ($missingMetrics -join ", ")
    }

    $doctor = [ordered]@{
      generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
      passed = ($issues.Count -eq 0)
      snapshotAgeHours = $ageHours
      repositories = $repos.Count
      issues = $issues
      remediation = if ($issues.Count -eq 0) {
        @("none")
      } else {
        @(
          "Run `sbk fleet collect --roots <paths>` to refresh snapshot.",
          "Run `npm run metrics:collect` inside repositories missing workflow metrics.",
          "Re-run `sbk fleet doctor` and confirm no stale data."
        )
      }
    }

    $metricsDir = Ensure-MetricsDir
    Set-Content -Path (Join-Path $metricsDir "fleet-doctor.json") -Value ($doctor | ConvertTo-Json -Depth 20) -Encoding UTF8
    Set-Content -Path (Join-Path $metricsDir "fleet-doctor.md") -Value @(
      "# Fleet Doctor",
      "",
      "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))",
      "- passed: $($doctor.passed)",
      "- snapshot_age_hours: $ageHours",
      "- repositories: $($repos.Count)",
      "- issues: $(if ($issues.Count -eq 0) { "none" } else { $issues -join ", " })"
    ) -Encoding UTF8
    Write-Host ("[fleet] doctor passed={0} issues={1}" -f $doctor.passed, $issues.Count)
    if (-not [bool]$doctor.passed) {
      throw "fleet doctor failed"
    }
    break
  }
  default {
    throw "unknown fleet operation: $operation"
  }
}
