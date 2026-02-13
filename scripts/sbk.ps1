param(
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Show-Usage {
  Write-Host "sbk <command> [args]"
  Write-Host ""
  Write-Host "Commands:"
  Write-Host "  init --owner <name> [--project-type backend|frontend|fullstack]"
  Write-Host "  verify:fast | verify | verify:ci | verify:loop"
  Write-Host "  policy | docs-sync | doctor | doctor:json"
  Write-Host "  memory:context | metrics:collect"
  Write-Host "  new-change <change-id>"
  Write-Host "  record-session <args passed to add_session.py>"
}

function Invoke-ScriptCommand {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [AllowEmptyCollection()][string[]]$ScriptArgs = @()
  )

  $shell = "powershell"
  if (-not (Get-Command powershell -ErrorAction SilentlyContinue)) {
    $shell = "pwsh"
  }

  & $shell -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs
  if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
    throw "command failed: $ScriptPath (exit code $LASTEXITCODE)"
  }
}

function Invoke-ExternalCommand {
  param(
    [Parameter(Mandatory = $true)][string]$Command,
    [AllowEmptyCollection()][string[]]$CommandArgs = @()
  )

  & $Command @CommandArgs
  if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
    throw "command failed: $Command (exit code $LASTEXITCODE)"
  }
}

if ($null -eq $Args -or $Args.Count -eq 0) {
  Show-Usage
  exit 0
}

$command = $Args[0]
$rest = @()
if ($Args.Count -gt 1) {
  $rest = @($Args[1..($Args.Count - 1)])
}

switch ($command) {
  "verify:fast" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "verify-fast.ps1") -ScriptArgs $rest
    break
  }
  "verify" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "verify.ps1") -ScriptArgs $rest
    break
  }
  "verify:ci" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "verify-ci.ps1") -ScriptArgs $rest
    break
  }
  "verify:loop" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "verify-loop.ps1") -ScriptArgs $rest
    break
  }
  "policy" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "workflow-policy-gate.ps1") -ScriptArgs $rest
    break
  }
  "docs-sync" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "workflow-docs-sync-gate.ps1") -ScriptArgs $rest
    break
  }
  "doctor" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "workflow-doctor.ps1") -ScriptArgs $rest
    break
  }
  "doctor:json" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "workflow-doctor-json.ps1") -ScriptArgs $rest
    break
  }
  "memory:context" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "memory-context.ps1") -ScriptArgs $rest
    break
  }
  "metrics:collect" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "collect-metrics.ps1") -ScriptArgs $rest
    break
  }
  "new-change" {
    if ($rest.Count -lt 1 -or [string]::IsNullOrWhiteSpace($rest[0])) {
      throw "new-change requires a change id. Example: sbk new-change sbk-universal-sidecar"
    }
    Invoke-ExternalCommand -Command "openspec" -CommandArgs @("new", "change", $rest[0])
    break
  }
  "record-session" {
    $sessionArgs = @((Join-Path $repoRoot ".trellis\\scripts\\add_session.py")) + $rest
    Invoke-ExternalCommand -Command "python" -CommandArgs $sessionArgs
    break
  }
  "init" {
    $owner = ""
    $projectType = "fullstack"

    for ($i = 0; $i -lt $rest.Count; $i++) {
      $token = $rest[$i]
      if ($token -eq "--owner" -and ($i + 1) -lt $rest.Count) {
        $owner = $rest[$i + 1]
        $i++
        continue
      }
      if ($token -eq "--project-type" -and ($i + 1) -lt $rest.Count) {
        $projectType = $rest[$i + 1]
        $i++
        continue
      }
    }

    if ([string]::IsNullOrWhiteSpace($owner)) {
      throw "init requires --owner <name>"
    }

    Invoke-ExternalCommand -Command "python" -CommandArgs @((Join-Path $repoRoot ".trellis\\scripts\\init_developer.py"), $owner)
    Invoke-ExternalCommand -Command "python" -CommandArgs @((Join-Path $repoRoot ".trellis\\scripts\\create_bootstrap.py"), $projectType)
    break
  }
  default {
    throw "unknown sbk command: $command"
  }
}
