param(
  [string]$TargetRepoRoot = ".",
  [ValidateSet("minimal", "full")][string]$Preset = "full",
  [switch]$Overwrite,
  [switch]$SkipPackageScriptInjection
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sbkRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$targetRoot = if ([System.IO.Path]::IsPathRooted($TargetRepoRoot)) {
  $resolved = Resolve-Path -LiteralPath $TargetRepoRoot -ErrorAction SilentlyContinue
  if ($null -ne $resolved) { $resolved.Path } else { $TargetRepoRoot }
} else {
  Resolve-Path (Join-Path $sbkRoot ($TargetRepoRoot -replace "/", "\")) | Select-Object -ExpandProperty Path
}

if (-not (Test-Path $targetRoot)) {
  throw "target repository path does not exist: $targetRoot"
}

$stats = [ordered]@{
  copied = 0
  overwritten = 0
  skipped = 0
}

function Normalize-RelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  return ($Path -replace "\\", "/").Trim("/")
}

function Resolve-SourceFile {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $sourcePath = Join-Path $Root ($RelativePath -replace "/", "\")
  if (Test-Path $sourcePath -PathType Leaf) {
    return (Resolve-Path $sourcePath).Path
  }
  return $null
}

function Get-FilesFromRelativeDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativeDirectory
  )

  $directoryPath = Join-Path $Root ($RelativeDirectory -replace "/", "\")
  if (-not (Test-Path $directoryPath -PathType Container)) {
    return @()
  }

  $files = @()
  $resolvedDir = (Resolve-Path $directoryPath).Path
  foreach ($item in Get-ChildItem -Path $resolvedDir -Recurse -File) {
    $relative = Normalize-RelativePath -Path ($item.FullName.Substring($Root.Length).TrimStart("\", "/"))
    $files += [PSCustomObject]@{
      source = $item.FullName
      relative = $relative
    }
  }
  return @($files)
}

function Is-ExcludedRelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $normalized = Normalize-RelativePath -Path $RelativePath
  $excludedPrefixes = @(
    ".git/",
    "node_modules/",
    ".metrics/",
    "trellis-worktrees/",
    ".venv/",
    ".trellis/workspace/",
    ".trellis/tasks/"
  )

  foreach ($prefix in $excludedPrefixes) {
    if ($normalized.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  return $false
}

function Get-MinimalPresetFiles {
  param(
    [Parameter(Mandatory = $true)][string]$Root
  )

  $relativeFiles = @(
    "AGENTS.md",
    "CLAUDE.md",
    "workflow-policy.json",
    "sbk.config.json",
    ".claude/agents/dispatch.md",
    ".github/workflows/ci.yml",
    "scripts/sbk.ps1",
    "scripts/sbk-install.ps1",
    "scripts/common/sbk-runtime.ps1",
    "scripts/common/verify-telemetry.ps1",
    "scripts/verify-fast.ps1",
    "scripts/verify.ps1",
    "scripts/verify-ci.ps1",
    "scripts/verify-loop.ps1",
    "scripts/workflow-policy-gate.ps1",
    "scripts/workflow-indicator-gate.ps1",
    "scripts/workflow-doctor.ps1",
    "scripts/memory-context.ps1",
    "openspec/specs/codex-workflow-kernel/spec.md",
    "openspec/specs/workflow-security-policy/spec.md"
  )

  $files = @()
  foreach ($relative in $relativeFiles) {
    $source = Resolve-SourceFile -Root $Root -RelativePath $relative
    if ($null -eq $source) {
      continue
    }
    $files += [PSCustomObject]@{
      source = $source
      relative = Normalize-RelativePath -Path $relative
    }
  }
  return @($files)
}

function Get-FullPresetFiles {
  param(
    [Parameter(Mandatory = $true)][string]$Root
  )

  $relativeDirs = @(
    "scripts",
    "config",
    "docs",
    "openspec/specs",
    ".trellis/spec",
    ".trellis/scripts",
    ".claude",
    ".codex",
    ".agents",
    ".github/workflows"
  )
  $relativeFiles = @(
    "AGENTS.md",
    "CLAUDE.md",
    "workflow-policy.json",
    "sbk.config.json"
  )

  $files = @()
  foreach ($relative in $relativeFiles) {
    $source = Resolve-SourceFile -Root $Root -RelativePath $relative
    if ($null -eq $source) {
      continue
    }
    $files += [PSCustomObject]@{
      source = $source
      relative = Normalize-RelativePath -Path $relative
    }
  }

  foreach ($relativeDir in $relativeDirs) {
    $files += Get-FilesFromRelativeDirectory -Root $Root -RelativeDirectory $relativeDir
  }

  $unique = @{}
  foreach ($item in $files) {
    $key = Normalize-RelativePath -Path ([string]$item.relative)
    if (Is-ExcludedRelativePath -RelativePath $key) {
      continue
    }
    if (-not $unique.ContainsKey($key)) {
      $unique[$key] = [PSCustomObject]@{
        source = [string]$item.source
        relative = $key
      }
    }
  }

  return @($unique.Values | Sort-Object -Property relative)
}

function Copy-FilesToTarget {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Files,
    [Parameter(Mandatory = $true)][string]$DestinationRoot,
    [Parameter(Mandatory = $true)][bool]$AllowOverwrite,
    [Parameter(Mandatory = $true)][hashtable]$Summary
  )

  foreach ($file in $Files) {
    $relative = Normalize-RelativePath -Path ([string]$file.relative)
    $source = [string]$file.source
    $destination = Join-Path $DestinationRoot ($relative -replace "/", "\")
    $destinationDir = Split-Path $destination -Parent
    if (-not (Test-Path $destinationDir)) {
      New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    if (Test-Path $destination) {
      if (-not $AllowOverwrite) {
        $Summary["skipped"]++
        continue
      }
      Copy-Item -Path $source -Destination $destination -Force
      $Summary["overwritten"]++
      continue
    }

    Copy-Item -Path $source -Destination $destination -Force
    $Summary["copied"]++
  }
}

function Update-PackageScripts {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot
  )

  $packagePath = Join-Path $RepoRoot "package.json"
  if (-not (Test-Path $packagePath -PathType Leaf)) {
    return [PSCustomObject]@{
      packageFound = $false
      scriptsAdded = 0
      scriptsExisting = 0
    }
  }

  $packageRaw = Get-Content -Path $packagePath -Encoding UTF8 -Raw
  $packageJson = $packageRaw | ConvertFrom-Json
  if ($null -eq $packageJson.scripts) {
    $packageJson | Add-Member -MemberType NoteProperty -Name scripts -Value ([pscustomobject]@{})
  }

  $desiredScripts = [ordered]@{
    "sbk" = "powershell -ExecutionPolicy Bypass -File ./scripts/sbk.ps1"
    "verify:fast" = "powershell -ExecutionPolicy Bypass -File ./scripts/verify-fast.ps1"
    "verify" = "powershell -ExecutionPolicy Bypass -File ./scripts/verify.ps1"
    "verify:ci" = "powershell -ExecutionPolicy Bypass -File ./scripts/verify-ci.ps1"
    "verify:loop" = "powershell -ExecutionPolicy Bypass -File ./scripts/verify-loop.ps1"
    "workflow:policy" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-policy-gate.ps1"
    "workflow:gate" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-indicator-gate.ps1"
    "workflow:doctor" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-doctor.ps1"
    "workflow:doctor:json" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-doctor-json.ps1"
    "workflow:docs-sync" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-docs-sync-gate.ps1"
    "workflow:skill-parity" = "powershell -ExecutionPolicy Bypass -File ./scripts/workflow-skill-parity-gate.ps1"
    "memory:context" = "powershell -ExecutionPolicy Bypass -File ./scripts/memory-context.ps1"
    "metrics:collect" = "powershell -ExecutionPolicy Bypass -File ./scripts/collect-metrics.ps1"
  }
  $requiredScriptFiles = [ordered]@{
    "sbk" = "scripts/sbk.ps1"
    "verify:fast" = "scripts/verify-fast.ps1"
    "verify" = "scripts/verify.ps1"
    "verify:ci" = "scripts/verify-ci.ps1"
    "verify:loop" = "scripts/verify-loop.ps1"
    "workflow:policy" = "scripts/workflow-policy-gate.ps1"
    "workflow:gate" = "scripts/workflow-indicator-gate.ps1"
    "workflow:doctor" = "scripts/workflow-doctor.ps1"
    "workflow:doctor:json" = "scripts/workflow-doctor-json.ps1"
    "workflow:docs-sync" = "scripts/workflow-docs-sync-gate.ps1"
    "workflow:skill-parity" = "scripts/workflow-skill-parity-gate.ps1"
    "memory:context" = "scripts/memory-context.ps1"
    "metrics:collect" = "scripts/collect-metrics.ps1"
  }

  $scriptsAdded = 0
  $scriptsExisting = 0
  foreach ($scriptName in $desiredScripts.Keys) {
    $requiredRelative = [string]$requiredScriptFiles[$scriptName]
    $scriptPath = Join-Path $RepoRoot ($requiredRelative -replace "/", "\")
    if (-not (Test-Path $scriptPath -PathType Leaf)) {
      continue
    }

    $existingProperty = $packageJson.scripts.PSObject.Properties[$scriptName]
    if ($null -ne $existingProperty) {
      $scriptsExisting++
      continue
    }

    $packageJson.scripts | Add-Member -MemberType NoteProperty -Name $scriptName -Value $desiredScripts[$scriptName]
    $scriptsAdded++
  }

  if ($scriptsAdded -gt 0) {
    $updated = $packageJson | ConvertTo-Json -Depth 100
    Set-Content -Path $packagePath -Value $updated -Encoding UTF8
  }

  return [PSCustomObject]@{
    packageFound = $true
    scriptsAdded = $scriptsAdded
    scriptsExisting = $scriptsExisting
  }
}

$filesToCopy = if ($Preset -eq "minimal") {
  Get-MinimalPresetFiles -Root $sbkRoot
} else {
  Get-FullPresetFiles -Root $sbkRoot
}

Copy-FilesToTarget -Files $filesToCopy -DestinationRoot $targetRoot -AllowOverwrite ([bool]$Overwrite) -Summary $stats

$packageSummary = [PSCustomObject]@{
  packageFound = $false
  scriptsAdded = 0
  scriptsExisting = 0
}
if (-not $SkipPackageScriptInjection) {
  $packageSummary = Update-PackageScripts -RepoRoot $targetRoot
}

Write-Host ("[sbk-install] preset={0} target={1}" -f $Preset, $targetRoot)
Write-Host ("[sbk-install] files_total={0} copied={1} overwritten={2} skipped={3}" -f $filesToCopy.Count, $stats.copied, $stats.overwritten, $stats.skipped)
if ($SkipPackageScriptInjection) {
  Write-Host "[sbk-install] package script injection skipped by flag"
} elseif ($packageSummary.packageFound) {
  Write-Host ("[sbk-install] package_json_scripts added={0} existing={1}" -f $packageSummary.scriptsAdded, $packageSummary.scriptsExisting)
} else {
  Write-Host "[sbk-install] package.json not found, script injection skipped"
}
