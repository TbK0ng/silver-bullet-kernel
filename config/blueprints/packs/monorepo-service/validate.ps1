param(
  [Parameter(Mandatory = $true)][string]$TargetRepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$required = @(
  "docs/architecture/monorepo-topology.md",
  "pnpm-workspace.yaml",
  ".sbk/verify-map.json"
)

$missing = @()
foreach ($relative in $required) {
  $path = Join-Path $TargetRepoRoot ($relative -replace "/", "\")
  if (-not (Test-Path $path)) {
    $missing += $relative
  }
}

if ($missing.Count -gt 0) {
  throw "[blueprint-validate] monorepo-service missing artifacts: $($missing -join ', ')"
}
