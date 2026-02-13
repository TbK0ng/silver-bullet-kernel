param(
  [string]$TargetConfigPath = "",
  [string]$TargetRepoRoot = "",
  [string]$Adapter = "",
  [string]$Profile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sbkRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\verify-telemetry.ps1")
. (Join-Path $PSScriptRoot "common\\sbk-runtime.ps1")

$runtime = Get-SbkRuntimeContext `
  -SbkRoot $sbkRoot `
  -TargetConfigPath $TargetConfigPath `
  -TargetRepoRoot $TargetRepoRoot `
  -AdapterOverride $Adapter `
  -ProfileOverride $Profile

function Resolve-CiMetricsPath {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot
  )

  $relativePath = ".metrics/verify-runs-ci.jsonl"
  $policyPath = Join-Path $RepoRoot "workflow-policy.json"
  if (Test-Path $policyPath) {
    try {
      $policy = Get-Content -Path $policyPath -Encoding UTF8 | ConvertFrom-Json
      if ($null -ne $policy.telemetry -and -not [string]::IsNullOrWhiteSpace([string]$policy.telemetry.ciVerifyRunsPath)) {
        $relativePath = [string]$policy.telemetry.ciVerifyRunsPath
      }
    } catch {
      # Keep fallback path.
    }
  }

  if ([System.IO.Path]::IsPathRooted($relativePath)) {
    return $relativePath
  }
  return (Join-Path $RepoRoot $relativePath)
}

$ciMetricsPath = Resolve-CiMetricsPath -RepoRoot $sbkRoot
$ciMetricsDir = Split-Path -Path $ciMetricsPath -Parent
if (-not (Test-Path $ciMetricsDir)) {
  New-Item -ItemType Directory -Path $ciMetricsDir | Out-Null
}
if (Test-Path $ciMetricsPath) {
  Remove-Item -Path $ciMetricsPath -Force
}
$env:WORKFLOW_VERIFY_RUNS_PATH = $ciMetricsPath
Write-Host "[verify-ci] telemetry_path=$ciMetricsPath"

$run = New-VerifyRun -Mode "ci" -RepoRoot $sbkRoot

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory
  )

  Write-Host "[verify-ci] $Name"
  $start = [DateTimeOffset]::UtcNow

  try {
    Push-Location $WorkingDirectory
    try {
      $global:LASTEXITCODE = 0
      & $Action
      if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
        throw "command exited with code $LASTEXITCODE"
      }
    } finally {
      Pop-Location
    }

    $stepDuration = ([DateTimeOffset]::UtcNow - $start)
    Add-VerifyStep -Run $run -Name $Name -Command $Command -DurationMs ([math]::Round($stepDuration.TotalMilliseconds)) -Status "passed"
  } catch {
    $stepDuration = ([DateTimeOffset]::UtcNow - $start)
    Add-VerifyStep -Run $run -Name $Name -Command $Command -DurationMs ([math]::Round($stepDuration.TotalMilliseconds)) -Status "failed"
    throw "[verify-ci] step failed: $Name. $($_.Exception.Message)"
  }
}

try {
  $policyScriptPath = Join-Path $PSScriptRoot "workflow-policy-gate.ps1"
  $policyCommand = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-policy-gate.ps1 -Mode ci"
  if (-not [string]::IsNullOrWhiteSpace($TargetConfigPath)) {
    $policyCommand += " -TargetConfigPath $TargetConfigPath"
  }
  if (-not [string]::IsNullOrWhiteSpace($Adapter)) {
    $policyCommand += " -Adapter $Adapter"
  }
  if (-not [string]::IsNullOrWhiteSpace($Profile)) {
    $policyCommand += " -Profile $Profile"
  }
  Invoke-Step `
    -Name "workflow policy gate (ci)" `
    -Command $policyCommand `
    -Action {
    & $policyScriptPath -Mode ci -TargetConfigPath $TargetConfigPath -Adapter $Adapter -Profile $Profile
  } `
    -WorkingDirectory $sbkRoot

  if ([bool]$runtime.docsSync.enabled) {
    $docsSyncScriptPath = Join-Path $PSScriptRoot "workflow-docs-sync-gate.ps1"
    Invoke-Step `
      -Name "workflow docs sync gate (ci)" `
      -Command "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode ci" `
      -Action {
      & $docsSyncScriptPath -Mode ci -TargetConfigPath $TargetConfigPath
    } `
      -WorkingDirectory $sbkRoot
  }

  $skillParityScriptPath = Join-Path $PSScriptRoot "workflow-skill-parity-gate.ps1"
  Invoke-Step `
    -Name "workflow skill parity gate" `
    -Command "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-skill-parity-gate.ps1" `
    -Action {
    & $skillParityScriptPath
  } `
    -WorkingDirectory $sbkRoot

  $ciCommands = @(Get-SbkVerifyCommands -Runtime $runtime -Mode "ci")
  foreach ($command in $ciCommands) {
    Invoke-Step `
      -Name "adapter[$($runtime.adapter)] ci: $command" `
      -Command $command `
      -Action {
      Invoke-Expression $command
    } `
      -WorkingDirectory $runtime.targetRepoRoot
  }

  Invoke-Step `
    -Name "OpenSpec strict validation" `
    -Command "openspec validate --all --strict --no-interactive" `
    -Action {
    openspec validate --all --strict --no-interactive
  } `
    -WorkingDirectory $sbkRoot
  Invoke-Step `
    -Name "collect metrics snapshot" `
    -Command "npm run metrics:collect" `
    -Action {
    npm run metrics:collect
  } `
    -WorkingDirectory $sbkRoot
  Invoke-Step `
    -Name "workflow indicator gate" `
    -Command "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-indicator-gate.ps1" `
    -Action {
    & (Join-Path $PSScriptRoot "workflow-indicator-gate.ps1")
  } `
    -WorkingDirectory $sbkRoot

  Complete-VerifyRun -Run $run -Status "passed"
  Write-Host "[verify-ci] completed adapter=$($runtime.adapter) profile=$($runtime.profile)"
} catch {
  $failedStep = if ($run.steps.Count -gt 0) { $run.steps[-1].name } else { "verify-ci bootstrap" }
  if ($run.steps.Count -eq 0) {
    Add-VerifyStep -Run $run -Name $failedStep -Command "initialization" -DurationMs 0 -Status "failed"
  }
  Complete-VerifyRun -Run $run -Status "failed" -FailedStep $failedStep -ErrorMessage $_.Exception.Message
  throw
} finally {
  Write-VerifyRun -Run $run -RepoRoot $sbkRoot
}
