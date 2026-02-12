Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\verify-telemetry.ps1")

$run = New-VerifyRun -Mode "ci" -RepoRoot $repoRoot

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Command
  )

  Write-Host "[verify-ci] $Name"
  $start = [DateTimeOffset]::UtcNow
  Invoke-Expression $Command
  $stepDuration = ([DateTimeOffset]::UtcNow - $start)

  if ($LASTEXITCODE -ne 0) {
    Add-VerifyStep -Run $run -Name $Name -Command $Command -DurationMs ([math]::Round($stepDuration.TotalMilliseconds)) -Status "failed"
    throw "[verify-ci] step failed: $Name"
  }

  Add-VerifyStep -Run $run -Name $Name -Command $Command -DurationMs ([math]::Round($stepDuration.TotalMilliseconds)) -Status "passed"
}

try {
  Invoke-Step -Name "workflow policy gate (ci)" -Command "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-policy-gate.ps1 -Mode ci"
  Invoke-Step -Name "lint" -Command "npm run lint"
  Invoke-Step -Name "typecheck" -Command "npm run typecheck"
  Invoke-Step -Name "unit and integration tests" -Command "npm run test"
  Invoke-Step -Name "e2e tests" -Command "npm run test:e2e"
  Invoke-Step -Name "build" -Command "npm run build"
  Invoke-Step -Name "OpenSpec strict validation" -Command "openspec validate --all --strict --no-interactive"
  Invoke-Step -Name "collect metrics snapshot" -Command "npm run metrics:collect"
  Invoke-Step -Name "workflow indicator gate" -Command "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-indicator-gate.ps1"
  Complete-VerifyRun -Run $run -Status "passed"
  Write-Host "[verify-ci] completed"
} catch {
  Complete-VerifyRun -Run $run -Status "failed" -FailedStep ($run.steps[-1].name) -ErrorMessage $_.Exception.Message
  throw
} finally {
  Write-VerifyRun -Run $run -RepoRoot $repoRoot
}
