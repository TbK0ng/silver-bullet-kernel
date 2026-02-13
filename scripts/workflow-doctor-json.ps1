Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$doctorScript = Join-Path $PSScriptRoot "workflow-doctor.ps1"
$reportJson = Join-Path $repoRoot ".metrics\\workflow-doctor.json"

& $doctorScript -Quiet

if (-not (Test-Path $reportJson)) {
  throw "workflow doctor json report missing: $reportJson"
}

Get-Content -Path $reportJson -Encoding UTF8
