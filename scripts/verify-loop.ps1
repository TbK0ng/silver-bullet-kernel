param(
  [ValidateSet("fast", "full")][string]$Profile = "fast",
  [ValidateRange(1, 10)][int]$MaxAttempts = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$metricsDir = Join-Path $repoRoot ".metrics"
$loopLogPath = Join-Path $metricsDir "verify-fix-loop.jsonl"

if (-not (Test-Path $metricsDir)) {
  New-Item -ItemType Directory -Path $metricsDir | Out-Null
}

function Get-VerifyCommand {
  param([Parameter(Mandatory = $true)][string]$LoopProfile)
  if ($LoopProfile -eq "full") {
    return (Join-Path $PSScriptRoot "verify.ps1")
  }
  return (Join-Path $PSScriptRoot "verify-fast.ps1")
}

function Invoke-Diagnostics {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $diagCommands = @(
    @{
      name = "workflow-doctor"
      action = { & (Join-Path $PSScriptRoot "workflow-doctor.ps1") -NoReport -Quiet }
    },
    @{
      name = "workflow-policy-gate"
      action = { & (Join-Path $PSScriptRoot "workflow-policy-gate.ps1") -Mode local -NoReport -Quiet }
    },
    @{
      name = "workflow-docs-sync-gate"
      action = { & (Join-Path $PSScriptRoot "workflow-docs-sync-gate.ps1") -Mode local -NoReport -Quiet }
    },
    @{
      name = "workflow-skill-parity-gate"
      action = { & (Join-Path $PSScriptRoot "workflow-skill-parity-gate.ps1") -NoReport -Quiet }
    },
    @{
      name = "git-status"
      action = { git -C $RepoRoot status -sb *> $null }
    }
  )

  $results = @()
  foreach ($diagCommand in $diagCommands) {
    $start = [DateTimeOffset]::UtcNow
    $exitCode = 0
    try {
      $global:LASTEXITCODE = 0
      & $diagCommand.action
      if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
        $exitCode = $LASTEXITCODE
      }
    } catch {
      if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
        $exitCode = $LASTEXITCODE
      } else {
        $exitCode = 1
      }
    }
    $durationMs = [math]::Round(([DateTimeOffset]::UtcNow - $start).TotalMilliseconds)
    $results += [ordered]@{
      command = [string]$diagCommand.name
      exitCode = $exitCode
      durationMs = $durationMs
      status = if ($exitCode -eq 0) { "passed" } else { "failed" }
    }
  }
  return @($results)
}

$verifyCommand = Get-VerifyCommand -LoopProfile $Profile
$completed = $false
$lastExitCode = 1

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
  Write-Host "[verify-loop] attempt=$attempt/$MaxAttempts profile=$Profile"

  $startedAt = [DateTimeOffset]::UtcNow
  $attemptExitCode = 0
  try {
    $global:LASTEXITCODE = 0
    & $verifyCommand *> $null
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
      $attemptExitCode = $LASTEXITCODE
    }
  } catch {
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
      $attemptExitCode = $LASTEXITCODE
    } else {
      $attemptExitCode = 1
    }
  }
  $lastExitCode = $attemptExitCode
  $durationMs = [math]::Round(([DateTimeOffset]::UtcNow - $startedAt).TotalMilliseconds)

  $diagnostics = @()
  if ($attemptExitCode -ne 0) {
    Write-Host "[verify-loop] verify failed on attempt $attempt; running diagnostics"
    $diagnostics = @(Invoke-Diagnostics -RepoRoot $repoRoot)
  }

  $record = [ordered]@{
    generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    profile = $Profile
    attempt = $attempt
    maxAttempts = $MaxAttempts
    verifyCommand = [string]$verifyCommand
    verifyExitCode = $attemptExitCode
    durationMs = $durationMs
    diagnostics = $diagnostics
    outcome = if ($attemptExitCode -eq 0) { "pass" } else { "fail" }
  }
  Add-Content -Path $loopLogPath -Value ($record | ConvertTo-Json -Depth 10 -Compress)

  if ($attemptExitCode -eq 0) {
    Write-Host "[verify-loop] verify passed on attempt $attempt"
    $completed = $true
    break
  }
}

if (-not $completed) {
  throw "[verify-loop] failed after $MaxAttempts attempts. See $loopLogPath."
}

Write-Host "[verify-loop] completed. evidence=$loopLogPath"
