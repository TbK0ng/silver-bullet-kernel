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
  Write-Host "  reference-map --file <path> --line <n> --column <n> [--max-results <n>] [--adapter <name>] [--target-repo-root <path>]"
  Write-Host "  safe-delete-candidates --file <path> --line <n> --column <n> [--max-results <n>] [--adapter <name>] [--target-repo-root <path>]"
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

function Invoke-NodeTsSemanticOperation {
  param(
    [Parameter(Mandatory = $true)][ValidateSet("rename", "reference-map", "safe-delete-candidates")][string]$Operation,
    [Parameter(Mandatory = $true)][string]$File,
    [Parameter(Mandatory = $true)][int]$Line,
    [Parameter(Mandatory = $true)][int]$Column,
    [string]$NewName = "",
    [Parameter(Mandatory = $true)][bool]$DryRun,
    [Parameter(Mandatory = $true)][int]$MaxResults
  )

  $scriptPath = Join-Path $repoRoot "scripts\\semantic-rename.ts"
  if (-not (Test-Path $scriptPath -PathType Leaf)) {
    throw "semantic-rename.ts backend missing: $scriptPath"
  }

  $args = @(
    "tsx",
    $scriptPath,
    "--operation",
    $Operation,
    "--file",
    $File,
    "--line",
    "$Line",
    "--column",
    "$Column",
    "--maxResults",
    "$MaxResults"
  )
  if ($Operation -eq "rename") {
    $args += @("--newName", $NewName)
  }
  if ($DryRun) {
    $args += "--dryRun"
  }

  $output = ""
  if (-not [string]::IsNullOrWhiteSpace($env:npm_execpath)) {
    $nodeCommand = (Get-Command node -ErrorAction SilentlyContinue)
    if ($null -eq $nodeCommand) {
      throw "node runtime not found for TypeScript semantic backend"
    }
    $output = & $nodeCommand.Source $env:npm_execpath "exec" "--" @args 2>&1
  } elseif (Get-Command npx -ErrorAction SilentlyContinue) {
    $output = & npx @args 2>&1
  } else {
    throw "cannot execute TypeScript semantic backend (npm exec / npx unavailable)"
  }

  if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
    throw ("typescript semantic backend failed: {0}" -f ($output -join "`n"))
  }

  $raw = ($output | Out-String).Trim()
  return ($raw | ConvertFrom-Json)
}

function Invoke-PythonSemanticOperation {
  param(
    [Parameter(Mandatory = $true)][ValidateSet("rename", "reference-map", "safe-delete-candidates")][string]$Operation,
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)][string]$File,
    [Parameter(Mandatory = $true)][int]$Line,
    [Parameter(Mandatory = $true)][int]$Column,
    [string]$NewName = "",
    [Parameter(Mandatory = $true)][bool]$DryRun,
    [Parameter(Mandatory = $true)][int]$MaxResults
  )

  $runtime = Get-PythonRuntimeCommand
  if ($null -eq $runtime) {
    throw "python runtime unavailable: install python/py/uv"
  }

  $scriptPath = Join-Path $repoRoot "scripts\\semantic-python.py"
  if (-not (Test-Path $scriptPath -PathType Leaf)) {
    throw "semantic-python.py backend missing: $scriptPath"
  }

  $args = @(
    $runtime.args + @(
      $scriptPath,
      "--operation",
      $Operation,
      "--targetRepoRoot",
      $TargetRepoRoot,
      "--file",
      $File,
      "--line",
      "$Line",
      "--column",
      "$Column",
      "--maxResults",
      "$MaxResults"
    )
  )
  if ($Operation -eq "rename") {
    $args += @("--newName", $NewName)
  }
  if ($DryRun) {
    $args += "--dryRun"
  }

  $output = & $runtime.command @args 2>&1
  if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
    throw ("python semantic backend failed: {0}" -f ($output -join "`n"))
  }
  $raw = ($output | Out-String).Trim()
  return ($raw | ConvertFrom-Json)
}

function Invoke-IndexedSemanticOperation {
  param(
    [Parameter(Mandatory = $true)][ValidateSet("go", "java", "rust")][string]$Language,
    [Parameter(Mandatory = $true)][ValidateSet("rename", "reference-map", "safe-delete-candidates")][string]$Operation,
    [Parameter(Mandatory = $true)][string]$TargetRepoRoot,
    [Parameter(Mandatory = $true)][string]$File,
    [Parameter(Mandatory = $true)][int]$Line,
    [Parameter(Mandatory = $true)][int]$Column,
    [string]$NewName = "",
    [Parameter(Mandatory = $true)][bool]$DryRun,
    [Parameter(Mandatory = $true)][int]$MaxResults
  )

  $runtime = Get-PythonRuntimeCommand
  if ($null -eq $runtime) {
    throw "python runtime unavailable: install python/py/uv for symbol-index backend"
  }

  $scriptPath = Join-Path $repoRoot "scripts\\semantic-index.py"
  if (-not (Test-Path $scriptPath -PathType Leaf)) {
    throw "semantic-index.py backend missing: $scriptPath"
  }

  $args = @(
    $runtime.args + @(
      $scriptPath,
      "--operation",
      $Operation,
      "--language",
      $Language,
      "--targetRepoRoot",
      $TargetRepoRoot,
      "--file",
      $File,
      "--line",
      "$Line",
      "--column",
      "$Column",
      "--maxResults",
      "$MaxResults"
    )
  )
  if ($Operation -eq "rename") {
    $args += @("--newName", $NewName)
  }
  if ($DryRun) {
    $args += "--dryRun"
  }

  $output = & $runtime.command @args 2>&1
  if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
    throw ("symbol-index semantic backend failed: {0}" -f ($output -join "`n"))
  }
  $raw = ($output | Out-String).Trim()
  return ($raw | ConvertFrom-Json)
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

  Set-Content -Path $reportPath -Value ($Payload | ConvertTo-Json -Depth 30) -Encoding UTF8
  Add-Content -Path $auditPath -Value ($Payload | ConvertTo-Json -Depth 30)
}

function Get-OperationCapability {
  param(
    [Parameter(Mandatory = $true)]$Runtime,
    [Parameter(Mandatory = $true)][ValidateSet("rename", "reference-map", "safe-delete-candidates")][string]$Operation
  )

  $semantic = Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object (Get-SbkPropertyValue -Object $Runtime -Name "resolvedAdapter") -Name "capabilities") -Name "semantic"
  if ($null -eq $semantic) {
    throw "adapter '$($Runtime.adapter)' has no semantic capability metadata"
  }

  switch ($Operation) {
    "rename" { return Get-SbkPropertyValue -Object $semantic -Name "rename" }
    "reference-map" { return Get-SbkPropertyValue -Object $semantic -Name "referenceMap" }
    "safe-delete-candidates" { return Get-SbkPropertyValue -Object $semantic -Name "safeDeleteCandidates" }
    default { return $null }
  }
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
$maxResults = 200

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
    "--max-results" {
      if (($i + 1) -lt $rest.Count) { $maxResults = [int]$rest[$i + 1]; $i++ }
      continue
    }
    "--maxResults" {
      if (($i + 1) -lt $rest.Count) { $maxResults = [int]$rest[$i + 1]; $i++ }
      continue
    }
  }
}

if ($operation -notin @("rename", "reference-map", "safe-delete-candidates")) {
  throw "unknown semantic operation: $operation"
}
if ([string]::IsNullOrWhiteSpace($file) -or $line -le 0 -or $column -le 0) {
  throw "semantic operation requires --file, --line, --column"
}
if ($operation -eq "rename" -and [string]::IsNullOrWhiteSpace($newName)) {
  throw "semantic rename requires --new-name"
}
if ($maxResults -le 0) {
  throw "max-results must be a positive integer"
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
  $capability = Get-OperationCapability -Runtime $runtime -Operation $operation
  if ($null -eq $capability) {
    throw "adapter '$($runtime.adapter)' has no '$operation' capability declaration"
  }
  $supported = [bool](Get-SbkPropertyValue -Object $capability -Name "supported")
  $backend = [string](Get-SbkPropertyValue -Object $capability -Name "backend")
  if (-not $supported) {
    throw "semantic operation '$operation' is unsupported for adapter '$($runtime.adapter)'"
  }
  $payload.backend = $backend

  $result = $null
  switch ($runtime.adapter) {
    "node-ts" {
      $result = Invoke-NodeTsSemanticOperation `
        -Operation $operation `
        -File $file `
        -Line $line `
        -Column $column `
        -NewName $newName `
        -DryRun $dryRun `
        -MaxResults $maxResults
    }
    "python" {
      $result = Invoke-PythonSemanticOperation `
        -Operation $operation `
        -TargetRepoRoot $targetRepoRoot `
        -File $file `
        -Line $line `
        -Column $column `
        -NewName $newName `
        -DryRun $dryRun `
        -MaxResults $maxResults
    }
    "go" {
      $result = Invoke-IndexedSemanticOperation `
        -Language "go" `
        -Operation $operation `
        -TargetRepoRoot $targetRepoRoot `
        -File $file `
        -Line $line `
        -Column $column `
        -NewName $newName `
        -DryRun $dryRun `
        -MaxResults $maxResults
    }
    "java" {
      $result = Invoke-IndexedSemanticOperation `
        -Language "java" `
        -Operation $operation `
        -TargetRepoRoot $targetRepoRoot `
        -File $file `
        -Line $line `
        -Column $column `
        -NewName $newName `
        -DryRun $dryRun `
        -MaxResults $maxResults
    }
    "rust" {
      $result = Invoke-IndexedSemanticOperation `
        -Language "rust" `
        -Operation $operation `
        -TargetRepoRoot $targetRepoRoot `
        -File $file `
        -Line $line `
        -Column $column `
        -NewName $newName `
        -DryRun $dryRun `
        -MaxResults $maxResults
    }
    default {
      throw "no semantic backend registered for adapter '$($runtime.adapter)'"
    }
  }

  $payload.status = "passed"
  $payload.reason = "operation completed"
  $payload.result = $result
  $payload.remediation = @("none")
  Write-SemanticReports -TargetRepoRoot $targetRepoRoot -Payload $payload
  Write-Host ($payload | ConvertTo-Json -Depth 30)
} catch {
  $payload.status = "failed"
  $payload.reason = $_.Exception.Message
  $payload.remediation = @(
    "Check semantic capability metadata in config/adapters/*.json.",
    "Ensure backend prerequisites are installed (node/python where required).",
    "Re-run with --dry-run to inspect deterministic output before applying."
  )
  Write-SemanticReports -TargetRepoRoot $targetRepoRoot -Payload $payload
  Write-Host ($payload | ConvertTo-Json -Depth 30)
  throw
}
