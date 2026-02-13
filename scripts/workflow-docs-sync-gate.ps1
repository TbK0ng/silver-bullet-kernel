param(
  [ValidateSet("local", "ci")][string]$Mode = "local",
  [string]$BaseRef = "",
  [string]$TargetConfigPath = "",
  [switch]$NoReport,
  [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\sbk-runtime.ps1")

$runtime = Get-SbkRuntimeContext -SbkRoot $repoRoot -TargetConfigPath $TargetConfigPath
$metricsOutputDir = Join-Path $repoRoot ".metrics"
$reportMd = Join-Path $metricsOutputDir "workflow-docs-sync-gate.md"
$reportJson = Join-Path $metricsOutputDir "workflow-docs-sync-gate.json"

function Normalize-RepoPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  return ($Path.Trim() -replace "\\", "/")
}

function Get-WorkingTreeFiles {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $lines = @(git -c core.quotepath=false -C $RepoRoot status --porcelain=v1)
  $files = @()
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
      continue
    }

    $pathPart = $line.Substring(3).Trim()
    if ($pathPart.Contains("->")) {
      $segments = $pathPart.Split("->")
      $pathPart = $segments[$segments.Length - 1].Trim()
    }

    $files += Normalize-RepoPath -Path $pathPart
  }

  return @($files | Select-Object -Unique)
}

function Get-BranchDeltaFiles {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $false)][string]$BaseRefArg
  )

  $resolvedBaseRef = $BaseRefArg
  if ([string]::IsNullOrWhiteSpace($resolvedBaseRef)) {
    $resolvedBaseRef = $env:WORKFLOW_BASE_REF
  }
  if ([string]::IsNullOrWhiteSpace($resolvedBaseRef) -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_BASE_REF)) {
    $resolvedBaseRef = "origin/$($env:GITHUB_BASE_REF.Trim())"
  }
  if ([string]::IsNullOrWhiteSpace($resolvedBaseRef)) {
    git -C $RepoRoot rev-parse --verify --quiet origin/main *> $null
    if ($LASTEXITCODE -eq 0) {
      $resolvedBaseRef = "origin/main"
    }
  }

  if ([string]::IsNullOrWhiteSpace($resolvedBaseRef)) {
    return [ordered]@{
      available = $false
      reason = "No base ref available."
      baseRef = ""
      files = @()
    }
  }

  $baseSha = [string](git -C $RepoRoot rev-parse --verify --quiet $resolvedBaseRef | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($baseSha)) {
    return [ordered]@{
      available = $false
      reason = "Unable to resolve base ref '$resolvedBaseRef'."
      baseRef = $resolvedBaseRef
      files = @()
    }
  }

  $mergeBase = [string](git -C $RepoRoot merge-base HEAD $resolvedBaseRef | Select-Object -First 1)
  if ([string]::IsNullOrWhiteSpace($mergeBase)) {
    return [ordered]@{
      available = $false
      reason = "Unable to resolve merge-base for '$resolvedBaseRef'."
      baseRef = $resolvedBaseRef
      files = @()
    }
  }

  $files = @(git -c core.quotepath=false -C $RepoRoot diff --name-only "$($mergeBase.Trim())..HEAD" |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { Normalize-RepoPath -Path $_ })

  return [ordered]@{
    available = $true
    reason = ""
    baseRef = $resolvedBaseRef
    files = @($files | Select-Object -Unique)
  }
}

function Test-IsTriggerFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Prefixes,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ExactFiles
  )

  foreach ($prefix in $Prefixes) {
    if ($Path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  foreach ($exactFile in $ExactFiles) {
    if ($Path.Equals($exactFile, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  return $false
}

$docsSync = $runtime.docsSync
$gateEnabled = [bool]$docsSync.enabled
$changedFiles = @()
$deltaInfo = $null
if ($Mode -eq "ci") {
  $deltaInfo = Get-BranchDeltaFiles -RepoRoot $repoRoot -BaseRefArg $BaseRef
  if ([bool]$deltaInfo.available) {
    $changedFiles = @($deltaInfo.files)
  }
} else {
  $changedFiles = @(Get-WorkingTreeFiles -RepoRoot $repoRoot)
}

$triggerPrefixes = @($docsSync.triggerPathPrefixes)
$triggerFiles = @($docsSync.triggerPathFiles)
$requiredDocs = @($docsSync.requiredDocs)
$triggerHits = @($changedFiles | Where-Object {
    Test-IsTriggerFile -Path $_ -Prefixes $triggerPrefixes -ExactFiles $triggerFiles
  })
$docsHits = @()
foreach ($file in $changedFiles) {
  foreach ($docPath in $requiredDocs) {
    if ($file.Equals($docPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      $docsHits += $file
      break
    }
  }
}
$docsHits = @($docsHits | Select-Object -Unique)

$passed = $true
$reason = ""
if (-not $gateEnabled) {
  $passed = $true
  $reason = "docs sync gate disabled"
} elseif ($triggerHits.Count -eq 0) {
  $passed = $true
  $reason = "no runtime trigger files changed"
} elseif ($docsHits.Count -eq 0) {
  $passed = $false
  $reason = "runtime contract changed without required docs updates"
}

$summary = [ordered]@{
  generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
  mode = $Mode
  enabled = $gateEnabled
  passed = $passed
  reason = $reason
  runtime = [ordered]@{
    configPath = $runtime.runtimeConfigPath
    adapter = $runtime.adapter
    profile = $runtime.profile
  }
  delta = if ($null -eq $deltaInfo) {
    [ordered]@{ available = $true; reason = "local mode"; baseRef = "" }
  } else {
    [ordered]@{ available = [bool]$deltaInfo.available; reason = [string]$deltaInfo.reason; baseRef = [string]$deltaInfo.baseRef }
  }
  triggerHits = $triggerHits
  docsHits = $docsHits
  requiredDocs = $requiredDocs
}

if (-not $NoReport) {
  if (-not (Test-Path $metricsOutputDir)) {
    New-Item -ItemType Directory -Path $metricsOutputDir | Out-Null
  }

  $lines = @()
  $lines += "# Workflow Docs Sync Gate"
  $lines += ""
  $lines += "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))"
  $lines += "- mode: $Mode"
  $lines += "- enabled: $gateEnabled"
  $lines += "- passed: $passed"
  $lines += "- reason: $reason"
  $lines += ""
  $lines += "## Trigger Hits"
  $lines += ""
  if ($triggerHits.Count -eq 0) {
    $lines += "none"
  } else {
    foreach ($trigger in $triggerHits) {
      $lines += "- $trigger"
    }
  }
  $lines += ""
  $lines += "## Required Docs Hits"
  $lines += ""
  if ($docsHits.Count -eq 0) {
    $lines += "none"
  } else {
    foreach ($doc in $docsHits) {
      $lines += "- $doc"
    }
  }

  Set-Content -Path $reportMd -Encoding UTF8 -Value $lines
  Set-Content -Path $reportJson -Encoding UTF8 -Value ($summary | ConvertTo-Json -Depth 10)
}

if (-not $Quiet) {
  Write-Host "[workflow-docs-sync-gate] mode=$Mode enabled=$gateEnabled passed=$passed"
}

if (-not $passed) {
  throw "workflow docs sync gate failed"
}
