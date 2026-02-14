param(
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\sbk-runtime.ps1")

function Show-Usage {
  Write-Host "sbk <command> [args]"
  Write-Host ""
  Write-Host "Commands:"
  Write-Host "  init --owner <name> [--project-type backend|frontend|fullstack]"
  Write-Host "  greenfield [--adapter node-ts|python|go|java|rust] [--project-name <name>] [--project-type backend|frontend|fullstack] [--no-language-stubs] [--force]"
  Write-Host "  blueprint [list|apply|verify] ..."
  Write-Host "  intake [analyze|plan|verify] ..."
  Write-Host "  adapter [list|validate|register|doctor] ..."
  Write-Host "  semantic [rename|reference-map|safe-delete-candidates] ..."
  Write-Host "  fleet [collect|report|doctor] ..."
  Write-Host "  install [--target-repo-root <path>] [--preset minimal|full] [--channel stable|beta] [--overwrite] [--skip-package-scripts]"
  Write-Host "  upgrade [--target-repo-root <path>] [--preset minimal|full] [--channel stable|beta] [--skip-package-scripts]"
  Write-Host "  capabilities [--platform <name>] [--target-repo-root <path>]"
  Write-Host "  explore [--change <id>]"
  Write-Host "  improve-ut [--skip-validation]"
  Write-Host "  migrate-specs [--change <id>] [--apply] [--unsafe-overwrite]"
  Write-Host "  parallel [plan|start|status|cleanup] [args]"
  Write-Host "  verify:fast | verify | verify:ci | verify:loop"
  Write-Host "  policy | docs-sync | skill-parity | doctor | doctor:json"
  Write-Host "  memory:context | metrics:collect"
  Write-Host "  new-change <change-id>"
  Write-Host "  record-session <args passed to add_session.py>"
}

function Show-Capabilities {
  param(
    [string]$PlatformOverride = "",
    [string]$TargetRepoRoot = ""
  )

  $capabilities = Get-SbkPlatformCapabilities `
    -SbkRoot $repoRoot `
    -PlatformOverride $PlatformOverride `
    -TargetRepoRoot $TargetRepoRoot

  Write-Host "sbk platform capabilities"
  Write-Host ""
  Write-Host "source: $($capabilities.path)"
  Write-Host "selected_platform: $($capabilities.selectedPlatformName)"
  Write-Host "target_repo_root: $($capabilities.targetRepoRoot)"
  Write-Host ""
  Write-Host "matrix:"

  foreach ($platform in @($capabilities.platforms | Sort-Object { [string](Get-SbkPropertyValue -Object $_ -Name "name") })) {
    $name = [string](Get-SbkPropertyValue -Object $platform -Name "name")
    $displayName = [string](Get-SbkPropertyValue -Object $platform -Name "displayName")
    $supportsCliAgents = [bool](Get-SbkPropertyValue -Object $platform -Name "supportsCliAgents")
    $supportsSession = [bool](Get-SbkPropertyValue -Object $platform -Name "supportsSessionIdOnCreate")
    $supportsResume = [bool](Get-SbkPropertyValue -Object $platform -Name "supportsResume")
    $supportsSkipPermissions = [bool](Get-SbkPropertyValue -Object $platform -Name "supportsSkipPermissions")
    $manualMode = [bool](Get-SbkPropertyValue -Object $platform -Name "manualMode")
    $resumeHint = [string](Get-SbkPropertyValue -Object $platform -Name "resumeHint")

    Write-Host ("- {0} ({1})" -f $name, $displayName)
    Write-Host ("  cli_agents={0} session_id_on_create={1} resume={2} skip_permissions={3} manual_mode={4}" -f $supportsCliAgents, $supportsSession, $supportsResume, $supportsSkipPermissions, $manualMode)
    if (-not [string]::IsNullOrWhiteSpace($resumeHint)) {
      Write-Host ("  hint: {0}" -f $resumeHint)
    }
  }
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

$script:SbkPythonRuntime = $null

function Get-SbkPythonRuntime {
  if ($null -ne $script:SbkPythonRuntime) {
    return $script:SbkPythonRuntime
  }

  $candidates = @(
    [PSCustomObject]@{
      command = "python"
      prefix = @()
      probe = @("--version")
      label = "python"
    },
    [PSCustomObject]@{
      command = "py"
      prefix = @("-3")
      probe = @("-3", "--version")
      label = "py -3"
    },
    [PSCustomObject]@{
      command = "uv"
      prefix = @("run", "python")
      probe = @("run", "python", "--version")
      label = "uv run python"
    }
  )

  foreach ($candidate in $candidates) {
    if (-not (Get-Command $candidate.command -ErrorAction SilentlyContinue)) {
      continue
    }

    & $candidate.command @($candidate.probe) *> $null
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -eq 0) {
      $script:SbkPythonRuntime = $candidate
      return $candidate
    }
  }

  throw "no Python runtime found. Install python or py launcher, or ensure uv is available."
}

function Invoke-SbkPythonScript {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [AllowEmptyCollection()][string[]]$ScriptArgs = @()
  )

  $runtime = Get-SbkPythonRuntime
  & $runtime.command @($runtime.prefix + @($ScriptPath) + $ScriptArgs)
  if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
    throw "command failed: $($runtime.label) $ScriptPath (exit code $LASTEXITCODE)"
  }
}

function Show-ParallelUsage {
  Write-Host "sbk parallel <operation> [args]"
  Write-Host ""
  Write-Host "Operations:"
  Write-Host "  plan     -> .trellis/scripts/multi_agent/plan.py"
  Write-Host "  start    -> .trellis/scripts/multi_agent/start.py"
  Write-Host "  status   -> .trellis/scripts/multi_agent/status.py"
  Write-Host "  cleanup  -> .trellis/scripts/multi_agent/cleanup.py"
  Write-Host ""
  Write-Host "Examples:"
  Write-Host "  sbk parallel plan --name auth --type backend --requirement ""Improve login flow"" --platform codex"
  Write-Host "  sbk parallel start .trellis/tasks/01-01-auth --platform codex"
  Write-Host "  sbk parallel status --list"
  Write-Host "  sbk parallel cleanup sbk-codex-auth -y"
}

function Invoke-SbkParallel {
  param(
    [AllowEmptyCollection()][string[]]$ParallelArgs = @()
  )

  if ($ParallelArgs.Count -eq 0) {
    $scriptPath = Join-Path $repoRoot ".trellis\\scripts\\multi_agent\\status.py"
    Invoke-SbkPythonScript -ScriptPath $scriptPath
    return
  }

  $operationToken = [string]$ParallelArgs[0]
  if ($operationToken -in @("--help", "-h", "help")) {
    Show-ParallelUsage
    return
  }

  $operation = $operationToken.ToLowerInvariant()
  $rest = @()
  if ($ParallelArgs.Count -gt 1) {
    $rest = @($ParallelArgs[1..($ParallelArgs.Count - 1)])
  }

  $scriptPath = switch ($operation) {
    "plan" { Join-Path $repoRoot ".trellis\\scripts\\multi_agent\\plan.py" }
    "start" { Join-Path $repoRoot ".trellis\\scripts\\multi_agent\\start.py" }
    "status" { Join-Path $repoRoot ".trellis\\scripts\\multi_agent\\status.py" }
    "cleanup" { Join-Path $repoRoot ".trellis\\scripts\\multi_agent\\cleanup.py" }
    default { $null }
  }

  if ($null -eq $scriptPath) {
    if ($operationToken.StartsWith("-")) {
      $scriptPath = Join-Path $repoRoot ".trellis\\scripts\\multi_agent\\status.py"
      Invoke-SbkPythonScript -ScriptPath $scriptPath -ScriptArgs $ParallelArgs
      return
    }
    throw "unknown parallel operation: $operationToken"
  }

  Invoke-SbkPythonScript -ScriptPath $scriptPath -ScriptArgs $rest
}

function Convert-SbkScriptArgs {
  param(
    [AllowEmptyCollection()][string[]]$RawArgs = @(),
    [Parameter(Mandatory = $true)][hashtable]$TokenMap
  )

  $normalized = @()
  foreach ($token in $RawArgs) {
    if ($TokenMap.ContainsKey($token)) {
      $normalized += [string]$TokenMap[$token]
    } else {
      $normalized += $token
    }
  }

  return @($normalized)
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
  "capabilities" {
    $platformOverride = ""
    $targetRepoRoot = ""
    for ($i = 0; $i -lt $rest.Count; $i++) {
      $token = $rest[$i]
      if ($token -eq "--platform" -and ($i + 1) -lt $rest.Count) {
        $platformOverride = $rest[$i + 1]
        $i++
        continue
      }
      if ($token -eq "--target-repo-root" -and ($i + 1) -lt $rest.Count) {
        $targetRepoRoot = $rest[$i + 1]
        $i++
        continue
      }
    }

    Show-Capabilities -PlatformOverride $platformOverride -TargetRepoRoot $targetRepoRoot
    break
  }
  "docs-sync" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "workflow-docs-sync-gate.ps1") -ScriptArgs $rest
    break
  }
  "skill-parity" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "workflow-skill-parity-gate.ps1") -ScriptArgs $rest
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
    $sessionScript = Join-Path $repoRoot ".trellis\\scripts\\add_session.py"
    Invoke-SbkPythonScript -ScriptPath $sessionScript -ScriptArgs $rest
    break
  }
  "explore" {
    $scriptArgs = Convert-SbkScriptArgs -RawArgs $rest -TokenMap @{
      "--change" = "-Change"
      "--include-apply-context" = "-IncludeApplyContext"
    }
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "openspec-explore.ps1") -ScriptArgs $scriptArgs
    break
  }
  "improve-ut" {
    $scriptArgs = Convert-SbkScriptArgs -RawArgs $rest -TokenMap @{
      "--target-config-path" = "-TargetConfigPath"
      "--target-repo-root" = "-TargetRepoRoot"
      "--adapter" = "-Adapter"
      "--profile" = "-Profile"
      "--skip-validation" = "-SkipValidation"
    }
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "workflow-improve-ut.ps1") -ScriptArgs $scriptArgs
    break
  }
  "migrate-specs" {
    $scriptArgs = Convert-SbkScriptArgs -RawArgs $rest -TokenMap @{
      "--change" = "-Change"
      "--apply" = "-Apply"
      "--no-validate" = "-NoValidate"
      "--unsafe-overwrite" = "-UnsafeOverwrite"
    }
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "openspec-migrate-specs.ps1") -ScriptArgs $scriptArgs
    break
  }
  "greenfield" {
    $scriptArgs = Convert-SbkScriptArgs -RawArgs $rest -TokenMap @{
      "--adapter" = "-Adapter"
      "--project-name" = "-ProjectName"
      "--project-type" = "-ProjectType"
      "--no-language-stubs" = "-NoLanguageStubs"
      "--force" = "-Force"
    }
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "greenfield-bootstrap.ps1") -ScriptArgs $scriptArgs
    break
  }
  "blueprint" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "sbk-blueprint.ps1") -ScriptArgs $rest
    break
  }
  "intake" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "sbk-intake.ps1") -ScriptArgs $rest
    break
  }
  "adapter" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "sbk-adapter.ps1") -ScriptArgs $rest
    break
  }
  "semantic" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "sbk-semantic.ps1") -ScriptArgs $rest
    break
  }
  "fleet" {
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "sbk-fleet.ps1") -ScriptArgs $rest
    break
  }
  "install" {
    $scriptArgs = Convert-SbkScriptArgs -RawArgs $rest -TokenMap @{
      "--target-repo-root" = "-TargetRepoRoot"
      "--preset" = "-Preset"
      "--channel" = "-Channel"
      "--overwrite" = "-Overwrite"
      "--skip-package-scripts" = "-SkipPackageScriptInjection"
    }
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "sbk-install.ps1") -ScriptArgs $scriptArgs
    break
  }
  "upgrade" {
    $scriptArgs = Convert-SbkScriptArgs -RawArgs $rest -TokenMap @{
      "--target-repo-root" = "-TargetRepoRoot"
      "--preset" = "-Preset"
      "--channel" = "-Channel"
      "--skip-package-scripts" = "-SkipPackageScriptInjection"
    }
    if (-not ($scriptArgs -contains "-Overwrite")) {
      $scriptArgs += "-Overwrite"
    }
    Invoke-ScriptCommand -ScriptPath (Join-Path $PSScriptRoot "sbk-install.ps1") -ScriptArgs $scriptArgs
    break
  }
  "parallel" {
    Invoke-SbkParallel -ParallelArgs $rest
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

    Invoke-SbkPythonScript -ScriptPath (Join-Path $repoRoot ".trellis\\scripts\\init_developer.py") -ScriptArgs @($owner)
    Invoke-SbkPythonScript -ScriptPath (Join-Path $repoRoot ".trellis\\scripts\\create_bootstrap.py") -ScriptArgs @($projectType)
    break
  }
  default {
    throw "unknown sbk command: $command"
  }
}
