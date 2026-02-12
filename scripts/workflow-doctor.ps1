Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$docsGeneratedDir = Join-Path $repoRoot "xxx_docs\\generated"
$reportMd = Join-Path $docsGeneratedDir "workflow-doctor.md"
$reportJson = Join-Path $docsGeneratedDir "workflow-doctor.json"

if (-not (Test-Path $docsGeneratedDir)) {
  New-Item -ItemType Directory -Path $docsGeneratedDir | Out-Null
}

function Add-Check {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Checks,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][bool]$Passed,
    [Parameter(Mandatory = $true)][string]$Details,
    [Parameter(Mandatory = $true)][string]$Remediation
  )
  $check = [PSCustomObject]@{
      name = $Name
      passed = $Passed
      details = $Details
      remediation = $Remediation
    }
  $Checks.Add($check) | Out-Null
}

$checks = New-Object 'System.Collections.Generic.List[object]'

# Runtime checks
$nodeVersionRaw = (node -v).Trim()
$nodeVersion = [version]($nodeVersionRaw.TrimStart("v"))
$requiredNode = [version]"20.19.0"
Add-Check -Checks $checks `
  -Name "Node version >= 20.19.0" `
  -Passed ($nodeVersion -ge $requiredNode) `
  -Details "detected=$nodeVersionRaw" `
  -Remediation "Install Node.js >= 20.19.0"

$openSpecVersion = ""
$openSpecOk = $true
try {
  $openSpecVersion = (openspec --version).Trim()
} catch {
  $openSpecOk = $false
  $openSpecVersion = "not-found"
}
Add-Check -Checks $checks `
  -Name "OpenSpec CLI available" `
  -Passed $openSpecOk `
  -Details "version=$openSpecVersion" `
  -Remediation "Run: npm install -g @fission-ai/openspec@latest"

# Structure checks
$requiredPaths = @(
  ".trellis/spec/guides/constitution.md",
  ".trellis/spec/guides/memory-governance.md",
  ".codex/skills",
  "openspec/specs",
  "scripts/verify-ci.ps1",
  "scripts/collect-metrics.ps1",
  "xxx_docs/00-index.md"
)

foreach ($p in $requiredPaths) {
  $fullPath = Join-Path $repoRoot $p
  Add-Check -Checks $checks `
    -Name "Path exists: $p" `
    -Passed (Test-Path $fullPath) `
    -Details $fullPath `
    -Remediation "Regenerate or restore missing workflow asset."
}

# Process checks
$activeChanges = 0
try {
  $activeChanges = @(Get-ChildItem -Path (Join-Path $repoRoot "openspec\\changes") -Directory | Where-Object { $_.Name -ne "archive" }).Count
} catch {
  $activeChanges = -1
}
Add-Check -Checks $checks `
  -Name "OpenSpec active changes readable" `
  -Passed ($activeChanges -ge 0) `
  -Details "active_changes=$activeChanges" `
  -Remediation "Ensure openspec structure exists and is readable."

$metricsFile = Join-Path $repoRoot ".metrics\\verify-runs.jsonl"
$metricsExists = Test-Path $metricsFile
Add-Check -Checks $checks `
  -Name "Verify telemetry present" `
  -Passed $metricsExists `
  -Details "path=$metricsFile" `
  -Remediation "Run: npm run verify:fast or npm run verify:ci"

$overallPassed = (@($checks | Where-Object { -not $_.passed }).Count -eq 0)
$timestamp = [DateTimeOffset]::UtcNow.ToString("o")

$checksForJson = @()
foreach ($item in $checks) {
  $checksForJson += @{
    name = [string]$item.name
    passed = [bool]$item.passed
    details = [string]$item.details
    remediation = [string]$item.remediation
  }
}

$summary = @{
  generatedAt = [string]$timestamp
  overallPassed = [bool]$overallPassed
  checks = $checksForJson
}

$lines = @()
$lines += "# Workflow Doctor Report"
$lines += ""
$lines += "- generated_at_utc: $([DateTimeOffset]::UtcNow.ToString("u"))"
$lines += "- overall_status: $(if ($overallPassed) { "PASS" } else { "DEGRADED" })"
$lines += ""
$lines += "## Checks"
$lines += ""
$lines += "| Check | Status | Details | Remediation |"
$lines += "| --- | --- | --- | --- |"
foreach ($c in $checks) {
  $status = if ($c.passed) { "PASS" } else { "FAIL" }
  $lines += "| $($c.name) | $status | $($c.details) | $($c.remediation) |"
}

Set-Content -Path $reportMd -Encoding UTF8 -Value $lines
Set-Content -Path $reportJson -Encoding UTF8 -Value ($summary | ConvertTo-Json -Depth 8)

Write-Host "Wrote report: $reportMd"
Write-Host "Wrote summary: $reportJson"

if (-not $overallPassed) {
  throw "workflow doctor failed: one or more checks are not healthy"
}
