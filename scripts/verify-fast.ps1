Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\verify-telemetry.ps1")

$run = New-VerifyRun -Mode "fast" -RepoRoot $repoRoot

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Command
  )

  Write-Host "[verify-fast] $Name"
  $start = [DateTimeOffset]::UtcNow
  Invoke-Expression $Command
  $stepDuration = ([DateTimeOffset]::UtcNow - $start)

  if ($LASTEXITCODE -ne 0) {
    Add-VerifyStep -Run $run -Name $Name -Command $Command -DurationMs ([math]::Round($stepDuration.TotalMilliseconds)) -Status "failed"
    throw "[verify-fast] step failed: $Name"
  }

  Add-VerifyStep -Run $run -Name $Name -Command $Command -DurationMs ([math]::Round($stepDuration.TotalMilliseconds)) -Status "passed"
}

try {
  Invoke-Step -Name "workflow policy gate (local)" -Command "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-policy-gate.ps1 -Mode local"
  Invoke-Step -Name "lint" -Command "npm run lint"
  Invoke-Step -Name "typecheck" -Command "npm run typecheck"
  Complete-VerifyRun -Run $run -Status "passed"
  Write-Host "[verify-fast] completed"
} catch {
  Complete-VerifyRun -Run $run -Status "failed" -FailedStep ($run.steps[-1].name) -ErrorMessage $_.Exception.Message
  throw
} finally {
  Write-VerifyRun -Run $run -RepoRoot $repoRoot
}
