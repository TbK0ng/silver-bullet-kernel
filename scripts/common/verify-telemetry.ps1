Set-StrictMode -Version Latest

function Resolve-VerifyRunsPath {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot
  )

  $override = $env:WORKFLOW_VERIFY_RUNS_PATH
  if (-not [string]::IsNullOrWhiteSpace($override)) {
    if ([System.IO.Path]::IsPathRooted($override)) {
      return $override
    }
    return (Join-Path $RepoRoot $override)
  }

  $defaultPath = ".metrics/verify-runs.jsonl"
  $configPath = Join-Path $RepoRoot "workflow-policy.json"
  if (Test-Path $configPath) {
    try {
      $config = Get-Content -Path $configPath -Encoding UTF8 | ConvertFrom-Json
      if ($null -ne $config.telemetry -and -not [string]::IsNullOrWhiteSpace([string]$config.telemetry.defaultVerifyRunsPath)) {
        $defaultPath = [string]$config.telemetry.defaultVerifyRunsPath
      }
    } catch {
      # Keep fallback defaults when policy config cannot be parsed.
    }
  }

  if ([System.IO.Path]::IsPathRooted($defaultPath)) {
    return $defaultPath
  }
  return (Join-Path $RepoRoot $defaultPath)
}

function New-VerifyRun {
  param(
    [Parameter(Mandatory = $true)][string]$Mode,
    [Parameter(Mandatory = $true)][string]$RepoRoot
  )

  return [ordered]@{
    id = [guid]::NewGuid().ToString()
    mode = $Mode
    startedAt = [DateTimeOffset]::UtcNow.ToString("o")
    status = "running"
    durationMs = 0
    failedStep = $null
    errorMessage = $null
    steps = @()
    repoRoot = $RepoRoot
  }
}

function Add-VerifyStep {
  param(
    [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Run,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][long]$DurationMs,
    [Parameter(Mandatory = $true)][string]$Status
  )

  $Run.steps += [ordered]@{
    name = $Name
    command = $Command
    durationMs = $DurationMs
    status = $Status
  }
}

function Complete-VerifyRun {
  param(
    [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Run,
    [Parameter(Mandatory = $true)][string]$Status,
    [string]$FailedStep = $null,
    [string]$ErrorMessage = $null
  )

  $started = [DateTimeOffset]::Parse($Run.startedAt)
  $duration = [DateTimeOffset]::UtcNow - $started
  $Run.status = $Status
  $Run.durationMs = [math]::Round($duration.TotalMilliseconds)
  $Run.failedStep = $FailedStep
  $Run.errorMessage = $ErrorMessage
}

function Write-VerifyRun {
  param(
    [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Run,
    [Parameter(Mandatory = $true)][string]$RepoRoot
  )

  $metricsPath = Resolve-VerifyRunsPath -RepoRoot $RepoRoot
  $metricsDir = Split-Path -Path $metricsPath -Parent
  if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir | Out-Null
  }

  $line = ($Run | ConvertTo-Json -Depth 8 -Compress)
  Add-Content -Path $metricsPath -Value $line
}
