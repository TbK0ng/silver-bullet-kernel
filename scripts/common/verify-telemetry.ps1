Set-StrictMode -Version Latest

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

  $metricsDir = Join-Path $RepoRoot ".metrics"
  $metricsPath = Join-Path $metricsDir "verify-runs.jsonl"
  if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir | Out-Null
  }

  $line = ($Run | ConvertTo-Json -Depth 8 -Compress)
  Add-Content -Path $metricsPath -Value $line
}
