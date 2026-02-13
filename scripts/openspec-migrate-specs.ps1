param(
  [string]$Change = "",
  [switch]$Apply,
  [switch]$NoValidate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Invoke-OpenSpec {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Args
  )

  Push-Location $repoRoot
  try {
    & openspec @Args
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
      throw "openspec command failed: openspec $($Args -join ' ')"
    }
  } finally {
    Pop-Location
  }
}

function Invoke-OpenSpecJson {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Args
  )

  Push-Location $repoRoot
  try {
    $raw = & openspec @Args
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
      throw "openspec command failed: openspec $($Args -join ' ')"
    }

    $text = [string]::Join([Environment]::NewLine, @($raw))
    if ([string]::IsNullOrWhiteSpace($text)) {
      throw "openspec returned empty JSON response."
    }
    return ($text | ConvertFrom-Json)
  } finally {
    Pop-Location
  }
}

function Resolve-ChangeName {
  param([string]$RequestedChange)

  if (-not [string]::IsNullOrWhiteSpace($RequestedChange)) {
    return $RequestedChange
  }

  $listResult = Invoke-OpenSpecJson -Args @("list", "--json")
  $activeChanges = @($listResult.changes)

  if ($activeChanges.Count -eq 1) {
    return [string]$activeChanges[0].name
  }

  if ($activeChanges.Count -eq 0) {
    throw "no active OpenSpec changes found."
  }

  $names = @($activeChanges | ForEach-Object { [string]$_.name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  throw ("multiple active changes found; pass --change <id>. available: " + ($names -join ", "))
}

function Get-RelativeRepoPath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $fullRoot = [System.IO.Path]::GetFullPath($Root)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  if ($fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $fullPath.Substring($fullRoot.Length).TrimStart('\', '/') -replace "\\", "/"
  }
  return $fullPath -replace "\\", "/"
}

$resolvedChange = Resolve-ChangeName -RequestedChange $Change
$deltaSpecsRoot = Join-Path $repoRoot "openspec\\changes\\$resolvedChange\\specs"

if (-not (Test-Path $deltaSpecsRoot)) {
  throw "delta specs directory not found: $deltaSpecsRoot"
}

$deltaFiles = @(
  Get-ChildItem -Path $deltaSpecsRoot -Recurse -File |
    Where-Object { $_.Name -eq "spec.md" }
)

if ($deltaFiles.Count -eq 0) {
  Write-Host "[migrate-specs] no delta spec files found under openspec/changes/$resolvedChange/specs"
  exit 0
}

$plan = @()
foreach ($deltaFile in $deltaFiles) {
  $capability = [string](Split-Path -Path (Split-Path -Path $deltaFile.FullName -Parent) -Leaf)
  if ([string]::IsNullOrWhiteSpace($capability)) {
    continue
  }

  $targetPath = Join-Path $repoRoot "openspec\\specs\\$capability\\spec.md"
  $action = if (Test-Path $targetPath) { "update" } else { "create" }

  $plan += [PSCustomObject]@{
    capability = $capability
    sourcePath = $deltaFile.FullName
    targetPath = $targetPath
    action = $action
  }
}

if ($plan.Count -eq 0) {
  Write-Host "[migrate-specs] no eligible spec migrations found."
  exit 0
}

Write-Host "## Spec Migration Plan ($resolvedChange)"
foreach ($entry in $plan | Sort-Object capability) {
  $sourceRel = Get-RelativeRepoPath -Root $repoRoot -Path $entry.sourcePath
  $targetRel = Get-RelativeRepoPath -Root $repoRoot -Path $entry.targetPath
  Write-Host ("- [{0}] {1}: {2} -> {3}" -f $entry.action, $entry.capability, $sourceRel, $targetRel)
}

if (-not $Apply) {
  Write-Host ""
  Write-Host "[migrate-specs] dry-run complete. Re-run with --apply to sync delta specs into openspec/specs."
  exit 0
}

foreach ($entry in $plan) {
  $targetDir = Split-Path -Path $entry.targetPath -Parent
  if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  }

  $content = Get-Content -Path $entry.sourcePath -Raw -Encoding UTF8
  Set-Content -Path $entry.targetPath -Encoding UTF8 -Value $content
}

Write-Host ""
Write-Host ("[migrate-specs] applied {0} spec file(s)." -f $plan.Count)

if (-not $NoValidate) {
  Write-Host "[migrate-specs] running strict OpenSpec validation..."
  Invoke-OpenSpec -Args @("validate", "--all", "--strict", "--no-interactive")
}
