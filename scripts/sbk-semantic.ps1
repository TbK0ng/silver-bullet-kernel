param(
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$CommandArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\sbk-runtime.ps1")

function Show-Usage {
  Write-Host "sbk semantic <operation> [args]"
  Write-Host ""
  Write-Host "Operations:"
  Write-Host "  rename --file <path> --line <n> --column <n> --new-name <name> [--dry-run] [--adapter <name>] [--target-repo-root <path>]"
  Write-Host "  reference-map [unsupported in this build]"
  Write-Host "  safe-delete-candidates [unsupported in this build]"
}

function Resolve-TargetRepoRoot {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )
  $resolved = Resolve-SbkPath -BasePath $repoRoot -Path $Path
  if (-not (Test-Path $resolved -PathType Container)) {
    throw "target repository path does not exist: $resolved"
  }
  return (Resolve-Path -LiteralPath $resolved).Path
}

function Get-PythonRuntimeCommand {
  $candidates = @(
    [PSCustomObject]@{ command = "python"; args = @() },
    [PSCustomObject]@{ command = "py"; args = @("-3") },
    [PSCustomObject]@{ command = "uv"; args = @("run", "python") }
  )
  foreach ($candidate in $candidates) {
    if (-not (Get-Command $candidate.command -ErrorAction SilentlyContinue)) {
      continue
    }
    $probeArgs = @($candidate.args + @("--version"))
    & $candidate.command @probeArgs *> $null
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -eq 0) {
      return $candidate
    }
  }
  return $null
}

function Invoke-NodeTsRename {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)][string]$File,
    [Parameter(Mandatory = $true)][int]$Line,
    [Parameter(Mandatory = $true)][int]$Column,
    [Parameter(Mandatory = $true)][string]$NewName,
    [Parameter(Mandatory = $true)][bool]$DryRun
  )

  $scriptPath = Join-Path $repoRoot "scripts\\semantic-rename.ts"
  if (-not (Test-Path $scriptPath -PathType Leaf)) {
    throw "semantic-rename.ts backend missing: $scriptPath"
  }

  $output = ""
  if (-not [string]::IsNullOrWhiteSpace($env:npm_execpath)) {
    $nodeCommand = (Get-Command node -ErrorAction SilentlyContinue)
    if ($null -eq $nodeCommand) {
      throw "node runtime not found for TypeScript semantic backend"
    }
    $args = @(
      $env:npm_execpath,
      "exec",
      "--",
      "tsx",
      $scriptPath,
      "--file",
      $File,
      "--line",
      "$Line",
      "--column",
      "$Column",
      "--newName",
      $NewName
    )
    if ($DryRun) {
      $args += "--dryRun"
    }
    $output = & $nodeCommand.Source @args 2>&1
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
      throw ("typescript backend failed: {0}" -f ($output -join "`n"))
    }
  } elseif (Get-Command npx -ErrorAction SilentlyContinue) {
    $args = @(
      "tsx",
      $scriptPath,
      "--file",
      $File,
      "--line",
      "$Line",
      "--column",
      "$Column",
      "--newName",
      $NewName
    )
    if ($DryRun) {
      $args += "--dryRun"
    }
    $output = & npx @args 2>&1
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
      throw ("typescript backend failed: {0}" -f ($output -join "`n"))
    }
  } else {
    throw "cannot execute TypeScript semantic backend (npm exec / npx unavailable)"
  }

  $raw = ($output | Out-String).Trim()
  return ($raw | ConvertFrom-Json)
}

function Invoke-PythonRename {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)][string]$File,
    [Parameter(Mandatory = $true)][int]$Line,
    [Parameter(Mandatory = $true)][int]$Column,
    [Parameter(Mandatory = $true)][string]$NewName,
    [Parameter(Mandatory = $true)][bool]$DryRun
  )

  $runtime = Get-PythonRuntimeCommand
  if ($null -eq $runtime) {
    throw "python backend unavailable: install python/py/uv for semantic rename"
  }

  $scriptPath = Join-Path $repoRoot "scripts\\semantic-python.py"
  if (-not (Test-Path $scriptPath -PathType Leaf)) {
    throw "semantic-python.py backend missing: $scriptPath"
  }

  $args = @($runtime.args + @(
      $scriptPath,
      "--file",
      $File,
      "--line",
      "$Line",
      "--column",
      "$Column",
      "--newName",
      $NewName
    ))
  if ($DryRun) {
    $args += "--dryRun"
  }

  $output = & $runtime.command @args 2>&1
  if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
    throw ("python backend failed: {0}" -f ($output -join "`n"))
  }
  $raw = ($output | Out-String).Trim()
  return ($raw | ConvertFrom-Json)
}

function Invoke-FailClosedExternalBackend {
  param(
    [Parameter(Mandatory = $true)][string]$Adapter,
    [Parameter(Mandatory = $true)][string]$Backend
  )

  $tool = ""
  $hint = ""
  switch ($Adapter) {
    "go" {
      $tool = "gopls"
      $hint = "install gopls and configure deterministic rename wiring"
    }
    "java" {
      $tool = "jdtls"
      $hint = "install jdtls and configure deterministic rename wiring"
    }
    "rust" {
      $tool = "rust-analyzer"
      $hint = "install rust-analyzer and configure deterministic rename wiring"
    }
    default {
      $tool = $Backend
      $hint = "configure semantic backend command for this adapter"
    }
  }

  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "semantic backend unavailable for adapter '$Adapter': required tool '$tool' not found; $hint"
  }

  throw "semantic backend '$tool' detected but deterministic invocation contract is not configured; fail-closed"
}

function Write-SemanticReports {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)]$Payload
  )

  $metricsDir = Join-Path $TargetRepoRoot ".metrics"
  if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
  }

  $reportPath = Join-Path $metricsDir "semantic-operation-report.json"
  $auditPath = Join-Path $metricsDir "semantic-operation-audit.jsonl"

  Set-Content -Path $reportPath -Value ($Payload | ConvertTo-Json -Depth 20) -Encoding UTF8
  Add-Content -Path $auditPath -Value ($Payload | ConvertTo-Json -Depth 20)
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

$targetRepoRootRaw = "."
$adapterOverride = ""
$profileOverride = ""
$file = ""
$line = 0
$column = 0
$newName = ""
$dryRun = $false

for ($i = 0; $i -lt $rest.Count; $i++) {
  $token = [string]$rest[$i]
  switch ($token) {
    "--target-repo-root" {
      if (($i + 1) -lt $rest.Count) { $targetRepoRootRaw = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--adapter" {
      if (($i + 1) -lt $rest.Count) { $adapterOverride = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--profile" {
      if (($i + 1) -lt $rest.Count) { $profileOverride = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--file" {
      if (($i + 1) -lt $rest.Count) { $file = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--line" {
      if (($i + 1) -lt $rest.Count) { $line = [int]$rest[$i + 1]; $i++ }
      continue
    }
    "--column" {
      if (($i + 1) -lt $rest.Count) { $column = [int]$rest[$i + 1]; $i++ }
      continue
    }
    "--new-name" {
      if (($i + 1) -lt $rest.Count) { $newName = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--newName" {
      if (($i + 1) -lt $rest.Count) { $newName = [string]$rest[$i + 1]; $i++ }
      continue
    }
    "--dry-run" {
      $dryRun = $true
      continue
    }
    "--dryRun" {
      $dryRun = $true
      continue
    }
  }
}

$targetRepoRoot = Resolve-TargetRepoRoot -Path $targetRepoRootRaw
$runtime = Get-SbkRuntimeContext `
  -SbkRoot $repoRoot `
  -TargetRepoRoot $targetRepoRoot `
  -AdapterOverride $adapterOverride `
  -ProfileOverride $profileOverride

$payload = [ordered]@{
  generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
  operation = $operation
  adapter = $runtime.adapter
  targetRepoRoot = $targetRepoRoot
  profile = $runtime.profile
  status = "failed"
  backend = ""
  reason = ""
  result = $null
  remediation = @()
}

try {
  switch ($operation.ToLowerInvariant()) {
    "rename" {
      if ([string]::IsNullOrWhiteSpace($file) -or $line -le 0 -or $column -le 0 -or [string]::IsNullOrWhiteSpace($newName)) {
        throw "semantic rename requires --file, --line, --column, --new-name"
      }

      $semantic = Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $runtime -Name "resolvedAdapter") -Name "capabilities") -Name "semantic"
      if ($null -eq $semantic) {
        throw "adapter '$($runtime.adapter)' has no semantic capability metadata"
      }

      $renameCapability = Get-SbkPropertyValue -Object $semantic -Name "rename"
      $supported = [bool](Get-SbkPropertyValue -Object $renameCapability -Name "supported")
      $backend = [string](Get-SbkPropertyValue -Object $renameCapability -Name "backend")
      if (-not $supported) {
        throw "semantic rename unsupported for adapter '$($runtime.adapter)'"
      }
      $payload.backend = $backend

      $result = $null
      switch ($runtime.adapter) {
        "node-ts" {
          $result = Invoke-NodeTsRename `
            -TargetRepoRoot $targetRepoRoot `
            -File $file `
            -Line $line `
            -Column $column `
            -NewName $newName `
            -DryRun $dryRun
        }
        "python" {
          $result = Invoke-PythonRename `
            -TargetRepoRoot $targetRepoRoot `
            -File $file `
            -Line $line `
            -Column $column `
            -NewName $newName `
            -DryRun $dryRun
        }
        "go" {
          Invoke-FailClosedExternalBackend -Adapter "go" -Backend $backend
        }
        "java" {
          Invoke-FailClosedExternalBackend -Adapter "java" -Backend $backend
        }
        "rust" {
          Invoke-FailClosedExternalBackend -Adapter "rust" -Backend $backend
        }
        default {
          throw "no semantic rename backend registered for adapter '$($runtime.adapter)'"
        }
      }

      $payload.status = "passed"
      $payload.reason = "operation completed"
      $payload.result = $result
      $payload.remediation = @("none")
      Write-SemanticReports -TargetRepoRoot $targetRepoRoot -Payload $payload
      Write-Host ($payload | ConvertTo-Json -Depth 20)
      break
    }
    "reference-map" {
      throw "reference-map operation is declared but not enabled in this build; fail-closed"
    }
    "safe-delete-candidates" {
      throw "safe-delete-candidates operation is declared but not enabled in this build; fail-closed"
    }
    default {
      throw "unknown semantic operation: $operation"
    }
  }
} catch {
  $payload.status = "failed"
  $payload.reason = $_.Exception.Message
  $payload.remediation = @(
    "Check adapter semantic capability metadata in config/adapters/*.json.",
    "Use adapter-specific backend tooling or switch to supported adapter.",
    "Re-run with --dry-run after backend dependencies are available."
  )
  Write-SemanticReports -TargetRepoRoot $targetRepoRoot -Payload $payload
  Write-Host ($payload | ConvertTo-Json -Depth 20)
  throw
}
