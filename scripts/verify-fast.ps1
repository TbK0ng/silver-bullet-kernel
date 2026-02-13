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

$run = New-VerifyRun -Mode "fast" -RepoRoot $sbkRoot

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory
  )

  Write-Host "[verify-fast] $Name"
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
    throw "[verify-fast] step failed: $Name. $($_.Exception.Message)"
  }
}

try {
  $policyScriptPath = Join-Path $PSScriptRoot "workflow-policy-gate.ps1"
  $policyCommand = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-policy-gate.ps1 -Mode local"
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
    -Name "workflow policy gate (local)" `
    -Command $policyCommand `
    -Action {
    & $policyScriptPath -Mode local -TargetConfigPath $TargetConfigPath -Adapter $Adapter -Profile $Profile
  } `
    -WorkingDirectory $sbkRoot

  if ([bool]$runtime.docsSync.enabled) {
    $docsSyncScriptPath = Join-Path $PSScriptRoot "workflow-docs-sync-gate.ps1"
    Invoke-Step `
      -Name "workflow docs sync gate (local)" `
      -Command "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1 -Mode local" `
      -Action {
      & $docsSyncScriptPath -Mode local -TargetConfigPath $TargetConfigPath
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

  $commands = @(Get-SbkVerifyCommands -Runtime $runtime -Mode "fast")
  foreach ($command in $commands) {
    Invoke-Step `
      -Name "adapter[$($runtime.adapter)] fast: $command" `
      -Command $command `
      -Action {
      Invoke-Expression $command
    } `
      -WorkingDirectory $runtime.targetRepoRoot
  }

  Complete-VerifyRun -Run $run -Status "passed"
  Write-Host "[verify-fast] completed adapter=$($runtime.adapter) profile=$($runtime.profile)"
} catch {
  $failedStep = if ($run.steps.Count -gt 0) { $run.steps[-1].name } else { "verify-fast bootstrap" }
  if ($run.steps.Count -eq 0) {
    Add-VerifyStep -Run $run -Name $failedStep -Command "initialization" -DurationMs 0 -Status "failed"
  }
  Complete-VerifyRun -Run $run -Status "failed" -FailedStep $failedStep -ErrorMessage $_.Exception.Message
  throw
} finally {
  Write-VerifyRun -Run $run -RepoRoot $sbkRoot
}
