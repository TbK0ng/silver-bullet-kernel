param(
  [string]$TargetConfigPath = "",
  [string]$TargetRepoRoot = "",
  [string]$Adapter = "",
  [string]$Profile = "",
  [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sbkRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "common\\sbk-runtime.ps1")

$runtime = Get-SbkRuntimeContext `
  -SbkRoot $sbkRoot `
  -TargetConfigPath $TargetConfigPath `
  -TargetRepoRoot $TargetRepoRoot `
  -AdapterOverride $Adapter `
  -ProfileOverride $Profile

function Normalize-RepoPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  return ($Path.Trim() -replace "\\", "/")
}

function Get-ChangedFiles {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $lines = @()
  Push-Location $RepoRoot
  try {
    $lines = @(git -c core.quotepath=false status --porcelain=v1)
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
      throw "git status failed in $RepoRoot"
    }
  } finally {
    Pop-Location
  }

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

function Invoke-ValidationCommand {
  param(
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory
  )

  Push-Location $WorkingDirectory
  try {
    $global:LASTEXITCODE = 0
    $null = Invoke-Expression $Command
    if (($LASTEXITCODE -is [int]) -and $LASTEXITCODE -ne 0) {
      return [PSCustomObject]@{
        command = $Command
        status = "fail"
      }
    }
    return [PSCustomObject]@{
      command = $Command
      status = "pass"
    }
  } finally {
    Pop-Location
  }
}

$unitTestSpecs = @(
  ".trellis/spec/unit-test/index.md",
  ".trellis/spec/unit-test/conventions.md",
  ".trellis/spec/unit-test/integration-patterns.md",
  ".trellis/spec/unit-test/mock-strategies.md"
)

foreach ($specPath in $unitTestSpecs) {
  $fullPath = Join-Path $sbkRoot ($specPath -replace "/", "\\")
  if (-not (Test-Path $fullPath)) {
    throw "required unit-test spec missing: $specPath"
  }
}

$changedFiles = @(Get-ChangedFiles -RepoRoot $runtime.targetRepoRoot)
$changedAreaText = if ($changedFiles.Count -eq 0) { "none" } else { ($changedFiles -join ", ") }

$testScope = if ($changedFiles.Count -eq 0) {
  "No local file changes detected. Keep existing UT baseline."
} else {
  $testFilePatterns = @("(^|/)(test|tests)/", "\.test\.", "\.spec\.", "_test\.", "Test\.")
  $testTouched = $false
  foreach ($file in $changedFiles) {
    foreach ($pattern in $testFilePatterns) {
      if ($file -match $pattern) {
        $testTouched = $true
        break
      }
    }
    if ($testTouched) {
      break
    }
  }

  if ($testTouched) {
    "Integration + regression focus (tests already touched); ensure changed assertions cover edge paths."
  } else {
    "Add or update tests for changed behavior (unit first, integration where workflow boundaries changed)."
  }
}

Write-Host "## UT Coverage Plan"
Write-Host "- Changed areas: $changedAreaText"
Write-Host "- Test scope (unit/integration/regression): $testScope"
Write-Host ""
Write-Host "## Test Updates"
Write-Host "- Added: (to fill after test edits)"
Write-Host "- Updated: (to fill after test edits)"
Write-Host ""
Write-Host "## Validation"

$validationResults = @()
if ($SkipValidation) {
  Write-Host "- skipped: true (--skip-validation)"
} else {
  $commands = @(Get-SbkVerifyCommands -Runtime $runtime -Mode "full")
  if ($commands.Count -eq 0) {
    $commands = @(Get-SbkVerifyCommands -Runtime $runtime -Mode "fast")
  }

  if ($commands.Count -eq 0) {
    throw "no adapter verify commands resolved for improve-ut validation."
  }

  foreach ($command in $commands) {
    Write-Host "- running: $command"
    $result = Invoke-ValidationCommand -Command $command -WorkingDirectory $runtime.targetRepoRoot
    $validationResults += $result
    Write-Host ("  result: {0}" -f $result.status)
    if ($result.status -ne "pass") {
      break
    }
  }
}

Write-Host ""
Write-Host "## Gaps / Follow-ups"
if ($changedFiles.Count -eq 0) {
  Write-Host "- No file deltas detected; no additional UT actions required."
} elseif ($SkipValidation) {
  Write-Host "- Validation skipped; run adapter full verify commands before merge."
} else {
  $failed = @($validationResults | Where-Object { $_.status -ne "pass" })
  if ($failed.Count -gt 0) {
    Write-Host ("- Validation failed at: {0}" -f $failed[0].command)
    throw "improve-ut validation failed"
  }
  Write-Host "- none"
}
